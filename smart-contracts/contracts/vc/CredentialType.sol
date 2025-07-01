// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

/**
 * @title CredentialTypes
 * @dev Data structures for Verifiable Credentials following W3C VC Data Model v1.1
 * @notice These structures are designed to be gas-efficient and storage-optimized
 * while adhering to the W3C Verifiable Credentials Data Model v1.1 specification.
 */

/** 
 * @title MultiHash
 * @dev Represents a multi-hash structure for storing content identifiers (CIDs).
 * @notice This structure is used to store the hash function, digest length, and the actual digest.
 * @param hashFunction - The hash function used (e.g., SHA-256)
 * @param digestLength - The length of the digest in bytes
 * @param digest - The actual hash digest, typically a bytes32 value
 * @notice This structure is optimized for storage and retrieval of content identifiers, such as those
 
struct MultiHash {
    uint8 hashFunction; // 0x12 (SHA-256)
    uint8 digestLength; // 0x20 (32 bytes for SHA-256)
    bytes32 digest;     // 32 bytes - fixed size for SHA-256 content digest
}
*/

/**
 * @title CredentialRecord
 * @dev Holds the verifiable credential data and its associated metadata.
 *
 * @param credentialHash - keccak256 hash of the JSON Canonicalization Scheme representation
 * @param metadata - Additional metadata associated with the credential
 */
struct CredentialRecord {
    bytes32 credentialHash;        // Using bytes32 for fixed-size storage optimization since it's a keccak256 hash
    CredentialMetadata metadata;
}

/**
 * @title CredentialMetadata
 * @dev Holds essential metadata for a verifiable credential.
 * Storage-optimized by packing related fields together to minimize slot usage.
 * @notice This structure is designed to be gas-efficient while providing necessary information about the credential.
 * @notice The fields are ordered to optimize storage packing and reduce gas costs.
 *
 * @param issuanceDate - Timestamp indicating when the credential was issued
 * @param expirationDate - Timestamp indicating when the credential expires (0 for no expiration)
 * @param status - Reserved for future credential status flags (1 = default)
 */
struct CredentialMetadata {
    uint64 issuanceDate;        // 8 bytes - reduced from uint256 since Unix timestamps fit in uint64
    uint64 expirationDate;      // 8 bytes - reduced from uint256 for the same reason
    CredentialStatus status;    // 1 byte - added for extensibility while optimizing packing
}

/**
 * @title CredentialStatus
 * @dev Defines the possible states of a Verifiable Credential
 * @dev CredentialStatus defines the possible states of a Verifiable Credential
 * @notice This enum is used to track the lifecycle of a credential, allowing for future extensibility.
 */
enum CredentialStatus {
    NONE,       // Not created/invalid
    ACTIVE,     // Valid and usable
    REVOKED,    // Credential has been revoked and is no longer valid
    SUSPENDED   // No longer usable but record is maintained
}
