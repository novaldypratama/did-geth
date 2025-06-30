// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { IRoleControl } from "../auth/IRoleControl.sol";
import { Unauthorized } from "../auth/AuthErrors.sol";

import { DidHashMismatch, IncorrectDidFormat, IdenticalDidAddress } from "../did/DidErrors.sol";
import { IDidRegistry } from "../did/IDidRegistry.sol";

import { ICredentialRegistry } from "./ICredentialRegistry.sol";
import { CredentialRecord, CredentialMetadata, CredentialStatus } from "./CredentialType.sol";

import {
    CredentialAlreadyExists,
    CredentialNotFound,
    CredentialExpired,
    CredentialRevoked,
    CredentialSuspended,
    InvalidStatusTransition,
    IssuerNotFound,
    IssuerNotAuthorized,
    IssuerHasBeenDeactivated,
    HolderNotFound,
    HolderNotAuthorized,
    InvalidCredentialHolder,
    InvalidIssuanceDate,
    InvalidExpirationDate,
    NotCredentialOwner
} from "./CredentialErrors.sol";

contract CredentialRegistry is ICredentialRegistry {
    
    /// @dev Reference to the role control contract for access management
    IRoleControl private immutable _roleControl;

    /**
    * @dev Reference to the DID registry for managing issuer and holder DIDs
    */
    IDidRegistry private immutable _didRegistry;

    mapping(bytes32 credentialId => CredentialRecord credentialRecord) private _credentials;
    
    /**
    * @dev Mappings to track issuer and holder relationships for credentials
    */
    mapping(bytes32 credentialId => address issuer) public _issuerOf;
    mapping(bytes32 credentialId => address holder) public _holderOf;

    /**
    * @dev DID-based relationship mappings (for DID-based queries)
    */
    mapping(bytes32 credentialId => bytes32 issuerDid) public _issuerDidOf;
    mapping(bytes32 credentialId => bytes32 holderDid) public _holderDidOf;

    /**
    * @dev Reverse lookup indexes for efficient querying
    * @notice These enable O(1) access to credential lists by address or DID
    */
    mapping(address issuer => bytes32[] credentialId) private _issuerCredentials;
    mapping(address holder => bytes32[] credentialId) private _holderCredentials;

    mapping(bytes32 issuerDid => bytes32[] credentialId) private _issuerDidCreds;
    mapping(bytes32 holderDid => bytes32[] credentialId) private _holderDidCreds;

    // ========================================================================
    // MODIFIERS FOR ACCESS CONTROL AND VALIDATION
    // ========================================================================

    /**
    * @dev Ensures caller has required role for the operation
    */
    modifier _onlyAuthorizedRole() {
        _roleControl.isTrusteeOrIssuer(msg.sender);
        _;
        // if (!_roleControl.isTrusteeOrIssuer(msg.sender)) {
        //     revert Unauthorized(msg.sender);
        // }
        // _;
    }

    /**
     * @dev Ensures credential exists
     */
    modifier _credentialExists(bytes32 credentialId) {
        if (_credentials[credentialId].metadata.issuanceDate == 0) {
            revert CredentialNotFound(credentialId);
        }
        _;
    }

    /**
     * @dev Ensures credential ID is unique (not already issued)
     */
    modifier _uniqueCredentialId(bytes32 credentialId){
        if (_credentials[credentialId].metadata.issuanceDate != 0) {
            revert CredentialAlreadyExists(credentialId);
        }
        _;
    }
    
    // /**
    //  * @dev Ensures credential is valid (not revoked, suspended, or expired)
    //  */
    // modifier _credentialValid(bytes32 credentialId) {
    //     CredentialRecord memory credential = _credentials[credentialId];
        
    //     // Check if revoked
    //     if (credential.status.revoked) {
    //         revert CredentialRevoked(credentialId, 0, "Credential revoked");
    //     }
        
    //     // Check if expired
    //     if (credential.metadata.expirationDate != 0 && 
    //         credential.metadata.expirationDate <= block.timestamp) {
    //         revert CredentialExpired(
    //             credentialId, 
    //             credential.metadata.expirationDate, 
    //             uint64(block.timestamp)
    //         );
    //     }
    //     _;
    // }

    /**
    * @dev Validates issuer is registered, active, and authorized
    * @param actor Address attempting to issue credentials
    */
    modifier _validIssuer(address actor) {
        // Check if DID exists and is active in one call
        if (!_didRegistry.didActive(actor)) {
            // Determine if DID exists but inactive, or doesn't exist
            if (_didRegistry.didExists(actor)) {
                revert IssuerHasBeenDeactivated(actor, "Cannot issue credentials with deactivated DID");
            } else {
                revert IssuerNotFound(actor);
            }
        }
        
        // Verify actor controls their DID (redundancy check for security)
        if (_didRegistry.resolveDid(actor).metadata.owner != actor) {
            revert IssuerNotAuthorized(actor, "DID not controlled by issuer address");
        }
        _;
    }

    /**
    * @dev Validates holder is registered, active, and authorized
    * @param holderAddress Address of the credential holder
    */
    modifier _validHolder(address holderAddress) {
        // Check if DID exists and is active in one call
        if (!_didRegistry.didActive(holderAddress)) {
            // Determine if DID exists but inactive, or doesn't exist
            if (_didRegistry.didExists(holderAddress)) {
                revert HolderNotAuthorized(holderAddress, "Cannot hold credentials with deactivated DID");
            } else {
                revert HolderNotFound(holderAddress);
            }
        }
        
        // Verify holder address controls their DID
        if (_didRegistry.resolveDid(holderAddress).metadata.owner != holderAddress) {
            revert InvalidCredentialHolder(holderAddress, "DID not controlled by holder address");
        }
        _;
    }

    // /**
    // * @dev Minimal but critical on-chain DID validation
    // * Purpose: Prevent attacks and ensure data integrity
    // */
    // modifier _validateDidParameters(bytes32 issuerDid, bytes32 holderDid) {
    //     // 1. Prevent zero/empty DIDs
    //     if (issuerDid == bytes32(0)) revert IncorrectDidFormat(issuerDid, "Issuer DID cannot be empty");
    //     if (holderDid == bytes32(0)) revert IncorrectDidFormat(holderDid, "Holder DID cannot be empty");
        
    //     // 2. Prevent identical issuer/holder (self-issuance detection)
    //     if (issuerDid == holderDid) revert IdenticalDidAddress(issuerDid, holderDid, "Issuer and holder cannot be identical");
    //     _;
    // }

    // /**
    // * @dev Cross-reference DID hashes with actual addresses
    // * Purpose: Ensure DID consistency with identity addresses
    // */
    // modifier _validateDidConsistency(
    //     address identity,
    //     address actor, 
    //     bytes32 issuerDid, 
    //     bytes32 holderDid
    // ) {
    //     // Verify issuer DID corresponds to actor address
    //     bytes32 expectedIssuerDidHash = keccak256(abi.encodePacked("did:ethr:", actor));
    //     if (issuerDid != expectedIssuerDidHash) {
    //         revert DidHashMismatch(expectedIssuerDidHash, issuerDid, "Issuer DID does not match actor address");
    //     }
        
    //     // Verify holder DID corresponds to identity address  
    //     bytes32 expectedHolderDidHash = keccak256(abi.encodePacked("did:ethr:", identity));
    //     if (holderDid != expectedHolderDidHash) {
    //         revert DidHashMismatch(expectedHolderDidHash, holderDid, "Holder DID does not match identity address");
    //     }
    //     _;
    // }

    // /**
    //  * @dev Ensures caller is authorized to modify credential (issuer or has role)
    //  */
    // modifier _authorizedForCredential(bytes32 credentialId) {
    //     OptimizedCredentialRecord storage credential = _credentials[credentialId];
    //     if (credential.metadata.issuanceDate == 0) {
    //         revert CredentialNotFound(credentialId);
    //     }

    //     // Get issuer hash from ID mapping
    //     bytes32 issuerHash = _issuerIdToHash[credential.metadata.issuerId];
    //     IssuerInfo storage issuer = _issuers[issuerHash];
        
    //     // Allow if caller is the issuer or has required role
    //     if (issuer.issuerAddress != msg.sender) {
    //         try _roleControl.isTrusteeOrIssuer(msg.sender) {
    //             // Caller has required role
    //         } catch {
    //             revert IssuerNotAuthorized(issuerHash, "modify credential");
    //         }
    //     }
    //     _;
    // }

    /**
     * @dev  Constructor to initialize the CredentialRegistry with role control and DID registry addresses
     * @param roleControlAddress The address of the RoleControl contract for access management
     * @param didRegistryAddress The address of the DidRegistry contract for managing DIDs
     * @notice This constructor ensures that both addresses are valid and not zero.
     */
    constructor(address roleControlAddress, address didRegistryAddress) {
        require(roleControlAddress != address(0), "Invalid role control address");
        require(didRegistryAddress != address(0), "Invalid DID registry address");
        
        _roleControl = IRoleControl(roleControlAddress);
        _didRegistry = IDidRegistry(didRegistryAddress);
    }

    /**
     * @notice Issues a new credential
     * @param credentialId The keccak256 hash of the credential
     * @param issuerDid The keccak256 hash of the issuer's DID
     * @param holderDid The keccak256 hash of the holder's DID
     * @param credentialCid The content identifier (CID) pointing to the full credential data
     */
    function issueCredential(
        address identity,
        bytes32 credentialId,
        bytes32 issuerDid,
        bytes32 holderDid,
        string calldata credentialCid
    ) public virtual {
        _issueCredential(identity, msg.sender, credentialId, issuerDid, holderDid, credentialCid);
    }

    /// @inheritdoc ICredentialRegistry
    function issueCredentialSigned(
        address identity,
        uint8 sigV,
        bytes32 sigR,
        bytes32 sigS,
        bytes32 credentialId,
        bytes32 issuerDid,
        bytes32 holderDid,
        string calldata credentialCid
    ) public virtual {
        bytes32 hash = keccak256(
            abi.encodePacked(bytes1(0x19), bytes1(0), address(this), identity, "issueCredential", credentialId, issuerDid, holderDid, credentialCid)
        );
        // Verify signature
        address actor = ecrecover(hash, sigV, sigR, sigS);
        if (actor == address(0)) {
            revert Unauthorized(actor);
        }

        // Call internal function to issue credential
        _issueCredential(identity, actor, credentialId, issuerDid, holderDid, credentialCid);
    }

    function resolveCredential(
        bytes32 credentialId
    ) public view virtual _credentialExists(credentialId) returns (CredentialRecord memory credentialRecord) {
        return _credentials[credentialId];
    }

    /**
    * @dev Internal credential issuance with optimized validation and storage
    */
    function _issueCredential(
        address identity,
        address actor,
        bytes32 credentialId,
        bytes32 issuerDid,
        bytes32 holderDid,
        string calldata credentialCid
    )
        internal
        _onlyAuthorizedRole
        _validIssuer(actor)
        _validHolder(identity)
        _uniqueCredentialId(credentialId)
    {
        // DID validation
        _validateDidParameters(issuerDid, holderDid, actor, identity);

        // Store credential record (PRIMARY STORAGE BY CREDENTIAL ID)
        _credentials[credentialId] = CredentialRecord({
            credentialHash: credentialId,
            metadata: CredentialMetadata({
                issuanceDate: uint64(block.timestamp),
                expirationDate: 0, // Default to no expiration
                status: CredentialStatus.ACTIVE // Default status
            })
        });
        
        // Offload issuer/holder relationships into side mappings
        _issuerOf[credentialId] = actor;
        _holderOf[credentialId] = identity;

        _issuerDidOf[credentialId] = issuerDid;
        _holderDidOf[credentialId] = holderDid;

        // Update reverse lookup indexes for efficient querying
        _issuerCredentials[actor].push(credentialId);
        _holderCredentials[identity].push(credentialId);

        _issuerDidCreds[issuerDid].push(credentialId);
        _holderDidCreds[holderDid].push(credentialId);
        
        // Emit event for credential issuance
        emit CredentialIssued(
            credentialId,
            actor,
            identity,
            issuerDid,
            holderDid,
            credentialCid
        );
    }

    /**
    * @dev Validates DID parameters for credential issuance
    */
    function _validateDidParameters(
        bytes32 issuerDid,
        bytes32 holderDid,
        address actor,
        address identity
    ) internal pure {
        // Prevent zero/empty DIDs
        if (issuerDid == bytes32(0)) revert IncorrectDidFormat(issuerDid, "Issuer DID cannot be empty");
        if (holderDid == bytes32(0)) revert IncorrectDidFormat(holderDid, "Holder DID cannot be empty");
        
        // Prevent identical issuer/holder (self-issuance detection)
        if (issuerDid == holderDid) revert IdenticalDidAddress(issuerDid, holderDid, "Issuer and holder cannot be identical");

        // Verify issuer DID corresponds to actor address
        bytes32 expectedIssuerDidHash = keccak256(abi.encodePacked("did:ethr:", actor));
        if (issuerDid != expectedIssuerDidHash) {
            revert DidHashMismatch(expectedIssuerDidHash, issuerDid, "Issuer DID does not match actor address");
        }
        
        // Verify holder DID corresponds to identity address  
        bytes32 expectedHolderDidHash = keccak256(abi.encodePacked("did:ethr:", identity));
        if (holderDid != expectedHolderDidHash) {
            revert DidHashMismatch(expectedHolderDidHash, holderDid, "Holder DID does not match identity address");
        }
    }

}
