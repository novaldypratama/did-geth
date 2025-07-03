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
    CredentialIsRevoked,
    CredentialIsSuspended,
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
    * @dev Mappings to track holder relationships for credentials
    */
    mapping(bytes32 credentialId => address holder) private _holderOf;

    /**
    * @dev Cache for frequently accessed DID hashes
    */
    mapping(bytes32 credentialId => bytes32 issuerDid) private _issuerDidCache;
    mapping(bytes32 credentialId => bytes32 holderDid) private _holderDidCache;

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

    /**
    * @dev Modifier that ensures credential is not revoked
    */
    modifier _credentialNotRevoked(bytes32 credentialId) {
        CredentialStatus status = _credentials[credentialId].metadata.status;
        if (status == CredentialStatus.REVOKED) {
            revert CredentialIsRevoked(
                credentialId, 
                uint64(block.timestamp),
                "Cannot resolve revoked credential"
            );
        }
        _;
    }
    
    /**
    * @dev Modifier that ensures the caller is the credential issuer
    */
    modifier _onlyCredentialIssuer(bytes32 credentialId) {
        require(_credentials[credentialId].issuer == msg.sender, "Only issuer");
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

    modifier _validStatusTransition(bytes32 credentialId, CredentialStatus newStatus) {
        CredentialStatus currentStatus = _credentials[credentialId].metadata.status;
    
        // Prevent transition to NONE (invalid operational status)
        if (newStatus == CredentialStatus.NONE) {
            revert InvalidStatusTransition(
                credentialId,
                uint8(currentStatus),
                uint8(newStatus),
                "Cannot transition to NONE status"
            );
        }

        // Handle transitions from ACTIVE
        if (currentStatus == CredentialStatus.ACTIVE) {
            if (newStatus != CredentialStatus.SUSPENDED && newStatus != CredentialStatus.REVOKED) {
                revert InvalidStatusTransition(
                    credentialId,
                    uint8(currentStatus),
                    uint8(newStatus),
                    string(abi.encodePacked(
                        "ACTIVE can only transition to SUSPENDED or REVOKED, not ",
                        _statusToString(newStatus)
                    ))
                );
            }
        }
        // Handle transitions from SUSPENDED
        else if (currentStatus == CredentialStatus.SUSPENDED) {
            if (newStatus != CredentialStatus.ACTIVE && newStatus != CredentialStatus.REVOKED) {
                revert InvalidStatusTransition(
                    credentialId,
                    uint8(currentStatus),
                    uint8(newStatus),
                    string(abi.encodePacked(
                        "SUSPENDED can only transition to ACTIVE or REVOKED, not ",
                        _statusToString(newStatus)
                    ))
                );
            }
        }
        // REVOKED is a terminal state - no transitions allowed
        else if (currentStatus == CredentialStatus.REVOKED) {
            revert InvalidStatusTransition(
                credentialId,
                uint8(currentStatus),
                uint8(newStatus),
                "REVOKED is a terminal state - no further transitions allowed"
            );
        }
        // NONE should not be a current status in normal operations
        else if (currentStatus == CredentialStatus.NONE) {
            revert InvalidStatusTransition(
                credentialId,
                uint8(currentStatus),
                uint8(newStatus),
                "Cannot transition from NONE status - credential may not exist"
            );
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

    /// @inheritdoc ICredentialRegistry
    function updateCredentialStatus(
        address actor,
        bytes32 credentialId,
        CredentialStatus previousStatus,
        CredentialStatus newStatus,
        string calldata reason
    ) public virtual 
        _credentialExists(credentialId) 
        _onlyAuthorizedRole 
        _validIssuer(actor)
        _validStatusTransition(credentialId, newStatus)
    {
        // Cache storage references for gas optimization
        CredentialRecord storage credential = _credentials[credentialId];
        CredentialMetadata storage metadata = credential.metadata;
        
        // Verify actor is the issuer or has sufficient privileges
        if (actor != msg.sender) { 
            revert IssuerNotAuthorized(actor, "Insufficient privileges for status update");
        }

        // Optimistic concurrency control: Verify current status matches expected
        if (metadata.status != previousStatus) {
            revert InvalidStatusTransition(
                credentialId,
                uint8(metadata.status),
                uint8(newStatus),
                string(abi.encodePacked(
                    "Status mismatch: expected ",
                    _statusToString(previousStatus),
                    ", found ",
                    _statusToString(metadata.status)
                ))
            );
        }

        // // Validate the proposed status transition
        // if (!_isValidStatusTransition(metadata.status, newStatus)) {
        //     revert InvalidStatusTransition(
        //         credentialId,
        //         uint8(metadata.status),
        //         uint8(newStatus),
        //         string(abi.encodePacked(
        //             "Invalid transition from ",
        //             _statusToString(metadata.status),
        //             " to ",
        //             _statusToString(newStatus)
        //         ))
        //     );
        // }

        // Prevent redundant updates (gas optimization)
        if (metadata.status == newStatus) {
            return; // No change needed
        }

        // Store previous status for event emission
        CredentialStatus oldStatus = metadata.status;

        // Update status with timestamp
        metadata.status = newStatus;
        
        // Emit event for status update with detailed information
        emit CredentialStatusUpdated(
            credentialId,
            oldStatus,
            newStatus,
            actor,
            reason
        );

        // Emit specific lifecycle events for better indexing and monitoring
        uint64 currentTimestamp = uint64(block.timestamp);
        
        if (newStatus == CredentialStatus.REVOKED) {
            emit CredentialRevoked(credentialId, currentTimestamp, reason);
        } else if (newStatus == CredentialStatus.SUSPENDED) {
            emit CredentialSuspended(credentialId, currentTimestamp, reason);
        } else if (newStatus == CredentialStatus.ACTIVE && oldStatus == CredentialStatus.SUSPENDED) {
            // Emit reactivation event when credential is restored from suspended state
            emit CredentialReactivated(credentialId, currentTimestamp, reason);
        }
    }

    function resolveCredential(
        bytes32 credentialId
    ) public view virtual _credentialExists(credentialId) _credentialNotRevoked(credentialId) returns (CredentialRecord memory credentialRecord) {
        return _credentials[credentialId];
    }

    function getIssuerDidHash(bytes32 credentialId) public view returns (bytes32) {
        bytes32 cached = _issuerDidCache[credentialId];
        if (cached != bytes32(0)) return cached;
        
        // Compute and potentially cache
        return keccak256(abi.encodePacked("did:ethr:", _credentials[credentialId].issuer));
    }

    // function cacheDidHash(bytes32 credentialId, address holder) _onlyAuthorizedRole external {
    //     // Only cache if frequently accessed
    //     CredentialRecord storage cred = _credentials[credentialId];

    //     bytes32 holderDid = keccak256(abi.encodePacked("did:ethr:", cred.issuer));
    //     bytes32 holderDid = keccak256(abi.encodePacked("did:ethr:", holder));

    //     _issuerDidCache[credentialId] = issuerDid;
    //     _holderDidCache[credentialId] = holderDid;
    // }

    function getHolder(bytes32 credentialId) external view returns (address) {
        address cachedHolder = _holderOf[credentialId];
        if (cachedHolder != address(0)) return cachedHolder;
        
        // Fallback to event parsing (off-chain indexing)
        revert("Holder not cached - use event logs");
    }
    
    // function cacheHolder(bytes32 credentialId, address holder) external {
    //     require(_credentials[credentialId].issuer == msg.sender, "Only issuer");
    //     _holderDidCache[credentialId] = holder;
    // }

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
            issuer: actor,
            metadata: CredentialMetadata({
                issuanceDate: uint64(block.timestamp),
                expirationDate: 0, // Default to no expiration
                status: CredentialStatus.ACTIVE // Default status
            })
        });
        
        // Offload holder relationships into side mappings
        _holderOf[credentialId] = identity;

        _issuerDidCache[credentialId] = issuerDid;
        _holderDidCache[credentialId] = holderDid;
        
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

    // /**
    // * @dev Validates credential status transitions according to W3C VC lifecycle
    // * @param currentStatus The current status of the credential
    // * @param newStatus The proposed new status
    // * @return bool True if the transition is valid, false otherwise
    // * 
    // * Valid transitions:
    // * - ACTIVE → SUSPENDED (temporary suspension)
    // * - ACTIVE → REVOKED (permanent revocation)
    // * - SUSPENDED → ACTIVE (reactivation)
    // * - SUSPENDED → REVOKED (revoke suspended credential)
    // * 
    // * Invalid transitions:
    // * - Any status → NONE (NONE is not a valid operational status)
    // * - REVOKED → any other status (revocation is terminal)
    // * - Any status → same status (redundant, but handled separately)
    // */
    // function _isValidStatusTransition(
    //     CredentialStatus currentStatus,
    //     CredentialStatus newStatus
    // ) internal pure returns (bool) {
    //     // Prevent transition to NONE
    //     if (newStatus == CredentialStatus.NONE) {
    //         return false;
    //     }

    //     // Allow transition from ACTIVE to SUSPENDED or REVOKED
    //     if (currentStatus == CredentialStatus.ACTIVE) {
    //         return newStatus == CredentialStatus.SUSPENDED || 
    //                newStatus == CredentialStatus.REVOKED;
    //     }

    //     // Allow transition from SUSPENDED to ACTIVE or REVOKED
    //     if (currentStatus == CredentialStatus.SUSPENDED) {
    //         return newStatus == CredentialStatus.ACTIVE || 
    //                newStatus == CredentialStatus.REVOKED;
    //     }

    //     // REVOKED is a terminal state - no transitions allowed
    //     if (currentStatus == CredentialStatus.REVOKED) {
    //         return false;
    //     }

    //     return false;
    // }

    /**
    * @dev Converts CredentialStatus enum to human-readable string
    * @param status The credential status to convert
    * @return string representation of the status
    * @notice Used for generating descriptive error messages
    */
    function _statusToString(CredentialStatus status) internal pure returns (string memory) {
        if (status == CredentialStatus.NONE) return "NONE";
        if (status == CredentialStatus.ACTIVE) return "ACTIVE";
        if (status == CredentialStatus.REVOKED) return "REVOKED";
        if (status == CredentialStatus.SUSPENDED) return "SUSPENDED";
        return "UNKNOWN";
    }
}