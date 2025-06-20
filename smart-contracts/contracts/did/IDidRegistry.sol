// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { DidRecord, DidStatus, MultiHash } from "./DidTypeNew.sol";

/**
 * @title IDidRegistry
 * @dev Interface for DID document management following W3C DID Core specification
 */
interface IDidRegistry {
    /**
     * @dev Emitted when a new DID is created
     * @param identity Address of the created DID
     * @param docHash Hash of the DID document for verification
     * @param versionId Initial version ID (block number)
     */
    event DIDCreated(address indexed identity, bytes docHash, uint256 versionId);

    /**
     * @dev Emitted when a DID document is updated
     * @param identity Address of the updated DID
     * @param docHash Hash of the updated DID document
     * @param versionId New version ID (block number)
     */
    event DIDUpdated(address indexed identity, bytes docHash, uint256 versionId);

    /**
     * @dev Emitted when a DID is deactivated
     * @param identity Address of the deactivated DID
     * @param versionId New version ID (block number)
     */
    event DIDDeactivated(address indexed identity, uint256 versionId);

    /**
     * @dev Creates a new DID with document content and its hash
     * @param identity Address of DID identity owner
     * @param hashFunction The hash function code used in the MultiHash
     * @param digestLength The length of the digest
     * @param digest The document digest in MultiHash format
     * @param docHash JSON Canonicalized Serialization hash for verification
     */
    function createDid(
        address identity, 
        uint8 hashFunction,
        uint8 digestLength,
        bytes32 digest,
        bytes calldata docHash
    ) external;

    /**
     * @dev Creates a DID with off-chain signature (for delegated transactions)
     * @param identity Address of DID identity owner
     * @param sigV Part of EcDSA signature
     * @param sigR Part of EcDSA signature
     * @param sigS Part of EcDSA signature
     * @param hashFunction The hash function code used in the MultiHash
     * @param digestLength The length of the digest
     * @param digest The document digest in MultiHash format
     * @param docHash JSON Canonicalized Serialization hash for verification
     */
    function createDidSigned(
        address identity,
        uint8 sigV,
        bytes32 sigR,
        bytes32 sigS,
        uint8 hashFunction,
        uint8 digestLength,
        bytes32 digest,
        bytes calldata docHash
    ) external;

    /**
     * @dev Updates an existing DID document
     * @param identity Address of the DID to update
     * @param hashFunction The hash function code used in the MultiHash
     * @param digestLength The length of the digest
     * @param digest The document digest in MultiHash format
     * @param docHash Updated hash of DID document
     */
    function updateDid(
        address identity, 
        uint8 hashFunction,
        uint8 digestLength,
        bytes32 digest,
        bytes calldata docHash
    ) external;

    /**
     * @dev Updates a DID with off-chain signature
     * @param identity Address of the DID to update
     * @param sigV Part of EcDSA signature
     * @param sigR Part of EcDSA signature
     * @param sigS Part of EcDSA signature
     * @param hashFunction The hash function code used in the MultiHash
     * @param digestLength The length of the digest
     * @param digest The document digest in MultiHash format
     * @param docHash Updated hash of DID document
     */
    function updateDidSigned(
        address identity,
        uint8 sigV,
        bytes32 sigR,
        bytes32 sigS,
        uint8 hashFunction,
        uint8 digestLength,
        bytes32 digest,
        bytes calldata docHash
    ) external;

    /**
     * @dev Deactivates an existing DID
     * @param identity Address of the DID to deactivate
     */
    function deactivateDid(address identity) external;

    /**
     * @dev Deactivates a DID with off-chain signature
     * @param identity Address of the DID to deactivate
     * @param sigV Part of EcDSA signature
     * @param sigR Part of EcDSA signature
     * @param sigS Part of EcDSA signature
     */
    function deactivateDidSigned(address identity, uint8 sigV, bytes32 sigR, bytes32 sigS) external;

    /**
     * @dev Resolves a DID to get its document and metadata
     * @param identity Address of the DID to resolve
     * @return didRecord The DID record containing document, hash, and metadata
     */
    function resolveDid(address identity) external view returns (DidRecord memory didRecord);

    /**
     * @dev Checks if a DID exists
     * @param identity Address to check
     * @return exists True if the DID exists
     */
    function didExists(address identity) external view returns (bool exists);

    /**
     * @dev Checks if a DID is active (not deactivated)
     * @param identity Address to check
     * @return active True if the DID exists and is active
     */
    function isDidActive(address identity) external view returns (bool active);

    /**
     * @dev Gets the current status of a DID
     * @param identity Address of the DID
     * @return status Current status of the DID
     */
    function getDidStatus(address identity) external view returns (DidStatus status);

    /**
     * @dev Validates if provided hash matches the stored document hash
     * @param identity Address of the DID
     * @param hash Hash to validate against the stored document hash
     * @return valid True if hashes match
     */
    function validateDocumentHash(address identity, bytes calldata hash) external view returns (bool valid);

    /**
     * @dev Returns the MultiHash data for a DID document
     * @param identity Address of the DID
     * @return multiHash The MultiHash structure for the document
     */
    function getDocumentMultiHash(address identity) external view returns (MultiHash memory multiHash);

    /**
     * @dev Gets the current version ID of a DID document
     * @param identity Address of the DID
     * @return versionId The current version ID
     */
    function getDocumentVersion(address identity) external view returns (uint256 versionId);
}
