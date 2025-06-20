// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

/**
 * @title DID Types
 * @dev Optimized data structures for DID document storage with efficient packing
 */

/**
 * @dev DidMetadata holds additional properties associated with the DID
 * @notice Fields are ordered to optimize storage packing
 */
struct DidMetadata {
    // Slot 1 (32 bytes)
    address owner;    // 20 bytes
    bool deactivated; // 1 byte
    // 11 bytes padding

    // Slot 2 (32 bytes)
    uint256 created;  // 32 bytes

    // Slot 3 (32 bytes)
    uint256 updated;  // 32 bytes

    // Slot 4 (32 bytes)
    uint256 versionId; // 32 bytes
}

struct MultiHash {
    uint8 hashFunction;
    uint8 digestLength;
    bytes32 digest;
}

/**
 * @dev DidRecord holds the DID Document and its associated metadata
 * @notice Contains the document content, its hash, and metadata
 */
struct DidRecord {
    MultiHash document;   // DID Document content (CID - Content Identifier)
    bytes docHash;        // keccak256 hash of JSON Canonicalized Serialization (JCS)
    DidMetadata metadata; // Associated metadata
}

/**
 * @dev DidDocumentStatus defines the possible states of a DID document
 */
enum DidStatus {
    NONE,       // Not created/invalid
    ACTIVE,     // Valid and usable
    DEACTIVATED // No longer usable but record is maintained
}
