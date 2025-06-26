// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { CredentialRecord, CredentialMetadata, CredentialStatus } from "./CredentialType.sol";

/**
 * @title ICredentialRegistry
 * @dev Interface for W3C Verifiable Credentials Registry following VC Data Model v1.1
 * 
 * This interface defines the core functionality for managing Verifiable Credentials
 * on-chain while maintaining compliance with W3C standards and optimizing for
 * Ethereum's storage and gas cost constraints.
 * 
 * Key Design Principles:
 * - W3C VC Data Model v1.1 compliance
 * - Role-based access control (Trustee/Endorser/Steward)
 * - Gas-efficient operations with batch support
 * - Comprehensive credential lifecycle management
 * - Support for credential status lists and revocation
 */
interface ICredentialRegistry {

    // ========================================================================
    // EVENTS - W3C VC LIFECYCLE TRACKING
    // ========================================================================

    /**
     * @dev Emitted when a Verifiable Credential is issued
     * @param credentialId keccak256 hash of the credential content
     * @param actor Address that issued the credential
     * @param identity Ethereum address of the holder
     * @param issuerDid keccak256 hash of the issuer's DID
     * @param holderDid keccak256 hash of the holder's DID
     * @param credentialCid Content Identifier (CID) pointing to the full credential data
     */
    event CredentialIssued(
        bytes32 indexed credentialId,
        address indexed actor,
        address indexed identity,
        bytes32 issuerDid,
        bytes32 holderDid,
        string credentialCid
    );

    // /**
    //  * @dev Emitted when a Verifiable Credential status is updated
    //  * @param credentialHash keccak256 hash of the credential
    //  * @param previousStatus Previous status of the credential
    //  * @param newStatus New status of the credential
    //  * @param updatedBy Address that performed the update
    //  * @param reason Optional reason for the status change
    //  */
    // event CredentialUpdated(
    //     bytes32 indexed credentialHash,
    //     CredentialStatus previousStatus,
    //     CredentialStatus newStatus,
    //     address indexed updatedBy,
    //     string reason
    // );

    // /**
    //  * @dev Emitted when a Verifiable Credential is revoked
    //  * @param credentialHash keccak256 hash of the revoked credential
    //  * @param issuer keccak256 hash of the issuer's DID
    //  * @param revokedAt Unix timestamp of revocation
    //  * @param reason Reason for revocation
    //  */
    // event CredentialRevoked(
    //     bytes32 indexed credentialHash,
    //     bytes32 indexed issuer,
    //     uint256 revokedAt,
    //     string reason
    // );

    // /**
    //  * @dev Emitted when a Verifiable Credential is suspended
    //  * @param credentialHash keccak256 hash of the suspended credential
    //  * @param issuer keccak256 hash of the issuer's DID
    //  * @param suspendedAt Unix timestamp of suspension
    //  * @param reason Reason for suspension
    //  */
    // event CredentialSuspended(
    //     bytes32 indexed credentialHash,
    //     bytes32 indexed issuer,
    //     uint256 suspendedAt,
    //     string reason
    // );

    // /**
    //  * @dev Emitted when a Verifiable Credential is reactivated from suspended status
    //  * @param credentialHash keccak256 hash of the reactivated credential
    //  * @param issuer keccak256 hash of the issuer's DID
    //  * @param reactivatedAt Unix timestamp of reactivation
    //  */
    // event CredentialReactivated(
    //     bytes32 indexed credentialHash,
    //     bytes32 indexed issuer,
    //     uint256 reactivatedAt
    // );

    // /**
    //  * @dev Emitted when an issuer is registered in the registry
    //  * @param issuerDid keccak256 hash of the issuer's DID
    //  * @param issuerAddress Ethereum address associated with the issuer
    //  * @param registeredBy Address that registered the issuer
    //  */
    // event IssuerRegistered(
    //     bytes32 indexed issuerDid,
    //     address indexed issuerAddress,
    //     address indexed registeredBy
    // );

    // /**
    //  * @dev Emitted when an issuer is deactivated
    //  * @param issuerDid keccak256 hash of the issuer's DID
    //  * @param deactivatedAt Unix timestamp of deactivation
    //  * @param deactivatedBy Address that deactivated the issuer
    //  */
    // event IssuerDeactivated(
    //     bytes32 indexed issuerDid,
    //     uint256 deactivatedAt,
    //     address indexed deactivatedBy
    // );

    // ========================================================================
    // CORE CREDENTIAL MANAGEMENT FUNCTIONS
    // ========================================================================

    /**
     * @dev Issues a new Verifiable Credential
     * 
     * Requirements:
     * - Caller must have TRUSTEE, ENDORSER, or STEWARD role
     * - Issuer must be registered and active
     * - Credential must not already exist
     * - Credential must follow W3C VC Data Model v1.1 format
     * - Issuance date must not be in the future
     * - Expiration date must be after issuance date (if set)
     * 
     * @param identity Ethereum address of the holder
     * @param credentialId keccak256 hash of the credential content
     * @param issuerDid keccak256 hash of the issuer's DID
     * @param holderDid keccak256 hash of the holder's DID
     * @param credentialCid Content Identifier (CID) pointing to the full credential data
     * 
     * Emits: CredentialIssued event
     * 
     * Reverts with:
     * - CredentialAlreadyExists if credential hash already exists
     * - IssuerNotFound if issuer is not registered
     * - IssuerNotAuthorized if issuer is not active
     * - InvalidIssuanceDate if issuance date is invalid
     * - InvalidExpirationDate if expiration date is before issuance date
     * - InsufficientRole if caller lacks required role
     */
    function issueCredential(
        address identity,
        bytes32 credentialId,
        bytes32 issuerDid,
        bytes32 holderDid,
        string calldata credentialCid
    ) external;

    // /**
    //  * @dev Issues a Verifiable Credential with off-chain signature (meta-transaction)
    //  * 
    //  * This function enables gasless credential issuance where the issuer signs
    //  * the transaction off-chain and another party submits it on their behalf.
    //  * 
    //  * @param credentialId keccak256 hash of the credential content
    //  * @param credentialCid Content Identifier (CID) pointing to the full credential data
    //  * @param sigV ECDSA signature recovery id (v)
    //  * @param sigR ECDSA signature part (r)
    //  * @param sigS ECDSA signature part (s)
    //  * @param identity Ethereum address of the holder
    //  * @param nonce Unique nonce to prevent replay attacks
    //  * 
    //  * Emits: CredentialIssued event
    //  * 
    //  * Reverts with:
    //  * - SignatureVerificationFailed if signature is invalid
    //  * - InvalidNonce if nonce is incorrect or already used
    //  */
    // function issueCredentialSigned(
    //     address identity,
    //     uint8 sigV,
    //     bytes32 sigR,
    //     bytes32 sigS,
    //     bytes32 credentialId,
    //     string calldata credentialCid,
    //     uint256 nonce
    // ) external;

    // /**
    //  * @dev Retrieves a Verifiable Credential by its hash
    //  * 
    //  * @param credentialHash keccak256 hash of the credential to retrieve
    //  * @return credentialRecord Complete credential record with metadata
    //  * 
    //  * Reverts with:
    //  * - CredentialNotFound if credential doesn't exist
    //  */
    // function getCredential(bytes32 credentialHash) 
    //     external 
    //     view 
    //     returns (CredentialRecord memory credentialRecord);

    // /**
    //  * @dev Verifies if a Verifiable Credential is valid and active
    //  * 
    //  * Performs comprehensive validation including:
    //  * - Credential existence
    //  * - Expiration checking
    //  * - Status validation (not revoked/suspended)
    //  * - Issuer status validation
    //  * 
    //  * @param credentialHash keccak256 hash of the credential to verify
    //  * @return isValid True if credential is valid and usable
    //  * @return status Current status of the credential
    //  * @return reason Human-readable reason if credential is invalid
    //  * 
    //  * Note: This function does not revert for invalid credentials,
    //  * but returns the validation result and reason.
    //  */
    // function verifyCredential(bytes32 credentialHash)
    //     external
    //     view
    //     returns (
    //         bool isValid,
    //         CredentialStatus status,
    //         string memory reason
    //     );

    // /**
    //  * @dev Updates the status of a Verifiable Credential
    //  * 
    //  * Requirements:
    //  * - Caller must be the issuer or have appropriate role
    //  * - Credential must exist
    //  * - Status transition must be valid
    //  * 
    //  * @param credentialHash keccak256 hash of the credential
    //  * @param newStatus New status to set
    //  * @param reason Optional reason for the status change
    //  * 
    //  * Emits: CredentialStatusUpdated event
    //  * 
    //  * Reverts with:
    //  * - CredentialNotFound if credential doesn't exist
    //  * - IssuerNotAuthorized if caller lacks permission
    //  * - InvalidStatusTransition if status change is not allowed
    //  */
    // function updateCredentialStatus(
    //     bytes32 credentialHash,
    //     CredentialStatus newStatus,
    //     string calldata reason
    // ) external;

    // // ========================================================================
    // // CREDENTIAL LIFECYCLE MANAGEMENT
    // // ========================================================================

    // /**
    //  * @dev Revokes a Verifiable Credential
    //  * 
    //  * Once revoked, a credential can never be reactivated.
    //  * 
    //  * Requirements:
    //  * - Caller must be the issuer or have TRUSTEE role
    //  * - Credential must exist and not already be revoked
    //  * 
    //  * @param credentialHash keccak256 hash of the credential to revoke
    //  * @param reason Reason for revocation
    //  * 
    //  * Emits: CredentialRevoked event
    //  */
    // function revokeCredential(
    //     bytes32 credentialHash,
    //     string calldata reason
    // ) external;

    // /**
    //  * @dev Suspends a Verifiable Credential temporarily
    //  * 
    //  * Suspended credentials can be reactivated later.
    //  * 
    //  * Requirements:
    //  * - Caller must be the issuer or have TRUSTEE/ENDORSER role
    //  * - Credential must exist and be currently active
    //  * 
    //  * @param credentialHash keccak256 hash of the credential to suspend
    //  * @param reason Reason for suspension
    //  * 
    //  * Emits: CredentialSuspended event
    //  */
    // function suspendCredential(
    //     bytes32 credentialHash,
    //     string calldata reason
    // ) external;

    // /**
    //  * @dev Reactivates a suspended Verifiable Credential
    //  * 
    //  * Requirements:
    //  * - Caller must be the issuer or have TRUSTEE/ENDORSER role
    //  * - Credential must exist and be currently suspended
    //  * 
    //  * @param credentialHash keccak256 hash of the credential to reactivate
    //  * 
    //  * Emits: CredentialReactivated event
    //  */
    // function reactivateCredential(bytes32 credentialHash) external;

    // // ========================================================================
    // // ISSUER MANAGEMENT FUNCTIONS
    // // ========================================================================

    // /**
    //  * @dev Registers a new credential issuer
    //  * 
    //  * Requirements:
    //  * - Caller must have TRUSTEE role
    //  * - Issuer must not already be registered
    //  * 
    //  * @param issuerDid keccak256 hash of the issuer's DID
    //  * @param issuerAddress Ethereum address associated with the issuer
    //  * 
    //  * Emits: IssuerRegistered event
    //  */
    // function registerIssuer(
    //     bytes32 issuerDid,
    //     address issuerAddress
    // ) external;

    // /**
    //  * @dev Deactivates a credential issuer
    //  * 
    //  * Requirements:
    //  * - Caller must have TRUSTEE role
    //  * - Issuer must be registered and currently active
    //  * 
    //  * @param issuerDid keccak256 hash of the issuer's DID
    //  * 
    //  * Emits: IssuerDeactivated event
    //  */
    // function deactivateIssuer(bytes32 issuerDid) external;

    // /**
    //  * @dev Checks if an issuer is registered and active
    //  * 
    //  * @param issuerDid keccak256 hash of the issuer's DID
    //  * @return isRegistered True if issuer is registered
    //  * @return isActive True if issuer is active
    //  * @return issuerAddress Ethereum address associated with the issuer
    //  */
    // function getIssuerStatus(bytes32 issuerDid)
    //     external
    //     view
    //     returns (
    //         bool isRegistered,
    //         bool isActive,
    //         address issuerAddress
    //     );
}
