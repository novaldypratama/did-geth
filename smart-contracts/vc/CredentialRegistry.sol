// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { IRoleControl } from "../contracts/auth/IRoleControl.sol";
import { Unauthorized } from "../contracts/auth/AuthErrors.sol";

import { IDidRegistry } from "../contracts/did/IDidRegistry.sol";
import { ICredentialRegistry } from "./ICredentialRegistry.sol";
import { CredentialRecord, CredentialStatus, CredentialMetadata } from "./CredentialType.sol";

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
    
    /**
    * @dev Reference to the role control contract for access management
    * @notice This contract uses role-based access control to manage who can issue, update, and revoke credentials.
    * @notice Only authorized roles (Trustees or Issuers) can perform operations on credentials.
    */
    IRoleControl private immutable _roleControl;

    /**
    * @dev Reference to the DID registry for managing issuer and holder DIDs
    * @notice This contract relies on the DID registry to validate issuers and holders.
    * @notice It ensures that only registered and active DIDs can issue or hold credentials.
    * @notice The DID registry is used to resolve DIDs and check their status.
    * @notice This contract does not manage DIDs directly, but interacts with the DID registry
    * @notice to ensure that issuers and holders are valid.
    * @notice The DID registry is expected to implement the IDidRegistry interface.
    * @notice This contract does not create or update DIDs, it only validates them.
    */
    IDidRegistry private immutable _didRegistry;

    mapping(bytes32 credentialId => CredentialRecord credentialRecord) private _credentials;
    
    mapping(bytes32 credentialId => address issuer) public _issuerOf;
    mapping(bytes32 credentialId => address holder) public _holderOf;

    // ========================================================================
    // MODIFIERS FOR ACCESS CONTROL AND VALIDATION
    // ========================================================================

    /**
    * @dev Ensures caller has required role for the operation
    */
    modifier _onlyAuthorizedRole() {
        _roleControl.isTrusteeOrIssuer(msg.sender);
        _;
    }

    // modifier _issuerExist(bytes32 issuerDid) {
    //     if (issuerDid == bytes32(0)) {
    //         revert IssuerNotFound(issuerDid);
    //     }
    //     _;
    // }

    // modifier _holderExist(bytes32 holderDid) {
    //     if (holderDid == bytes32(0)) {
    //         revert HolderNotFound(holderDid);
    //     }
    //     _;
    // }

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
}
