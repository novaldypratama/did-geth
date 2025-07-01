// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { DidRecord, DidStatus } from "./DidTypeNew.sol";

/**
 * @title IDidRegistry
 * @dev Interface for DID document management following W3C DID Core specification
 */
interface IDidRegistry {
    /**
     * @dev Emitted when a new DID is created
     * @param identity Address of the created DID
     * @param docHash Hash of the DID document
     */
    event DIDCreated(address indexed identity, bytes32 docHash);

    /**
     * @dev Emitted when a DID document is updated
     * @param identity Address of the updated DID
     * @param docHash Hash of the updated DID document
     * @param versionId New version ID
     */
    event DIDUpdated(address indexed identity, bytes32 docHash, uint32 versionId);

    /**
     * @dev Emitted when a DID is deactivated
     * @param identity Address of the deactivated DID
     */
    event DIDDeactivated(address indexed identity);

    /**
     * @dev Creates a new DID with document hash
     * @param identity Address of DID identity owner
     * @param docHash Hash of DID document for integrity verification
     */
    function createDid(address identity, bytes32 docHash) external;

    /**
     * @dev Creates a DID with off-chain signature (for delegated transactions)
     * @param identity Address of DID identity owner
     * @param sigV Part of EcDSA signature
     * @param sigR Part of EcDSA signature
     * @param sigS Part of EcDSA signature
     * @param docHash Hash of DID document for integrity verification
     */
    function createDidSigned(
        address identity,
        uint8 sigV,
        bytes32 sigR,
        bytes32 sigS,
        bytes32 docHash
    ) external;

    /**
     * @dev Updates an existing DID document
     * @param identity Address of the DID to update
     * @param docHash Updated hash of DID document
     */
    function updateDid(address identity, bytes32 docHash) external;

    /**
     * @dev Updates a DID with off-chain signature
     * @param identity Address of the DID to update
     * @param sigV Part of EcDSA signature
     * @param sigR Part of EcDSA signature
     * @param sigS Part of EcDSA signature
     * @param docHash Updated hash of DID document
     */
    function updateDidSigned(
        address identity,
        uint8 sigV,
        bytes32 sigR,
        bytes32 sigS,
        bytes32 docHash
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
    function deactivateDidSigned(
        address identity,
        uint8 sigV,
        bytes32 sigR,
        bytes32 sigS
    ) external;

    /**
     * @dev Resolves a DID to get its record
     * @param identity Address of the DID to resolve
     * @return didRecord The DID record containing hash and metadata
     */
    function resolveDid(address identity) external view returns (DidRecord memory didRecord);

    /**
     * @dev Checks if a DID exists
     * @param identity Address to check
     * @return exists True if the DID exists
     */
    function didExists(address identity) external view returns (bool exists);

    /**
     * @dev Checks if a DID is active
     * @param identity Address of the DID to check
     * @return isActive True if the DID is active
     */
    function didActive(address identity) external view returns (bool isActive);

    // /**
    //  * @dev Gets the current status of a DID
    //  * @param identity Address of the DID
    //  * @return status Current status of the DID
    //  */
    // function getDidStatus(address identity) external view returns (DidStatus status);

    /**
     * @dev Validates if provided hash matches the stored document hash
     * @param identity Address of the DID
     * @param hash Hash to validate against the stored document hash
     * @return valid True if hashes match
     */
    function validateDocumentHash(address identity, bytes32 hash) external view returns (bool valid);
}