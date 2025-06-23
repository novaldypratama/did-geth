// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

/**
 * @title DID Types
 * @dev Optimized data structures for DID document storage with efficient packing
 */

/**
 * @dev DidRecord holds the DID Document and its associated metadata
 * @notice Contains the document content, its hash, and metadata
 */
struct DidRecord {
    bytes32 docHash;      // keccak256 hash of JSON Canonicalized Serialization (JCS)
    DidMetadata metadata; // Associated metadata
}

/**
 * @dev DidMetadata holds additional properties associated with the DID
 * @notice Fields are ordered to optimize storage packing
    * @param owner The address of the DID owner
    * @param created Timestamp of when the DID was created
    * @param updated Timestamp of the last update to the DID
    * @param versionId The version identifier for the DID document
    * @param deactivated Indicates if the DID has been deactivated
 * @notice This structure is designed to minimize storage costs by packing related fields together
 */
struct DidMetadata {
    address owner;
    uint64 created;
    uint64 updated;
    uint32 versionId;
    DidStatus status;
}

/**
 * @dev DidDocumentStatus defines the possible states of a DID document
 */
enum DidStatus {
    NONE,       // Not created/invalid
    ACTIVE,     // Valid and usable
    DEACTIVATED // No longer usable but record is maintained
}
