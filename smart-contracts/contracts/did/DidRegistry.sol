// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { IRoleControl } from "../auth/IRoleControl.sol";
import { Unauthorized } from "../auth/AuthErrors.sol";
import { 
    DidAlreadyExist, 
    DidHasBeenDeactivated, 
    DidNotFound, 
    NotIdentityOwner, 
    InvalidDidDocument, 
    DidHashMismatch 
} from "./DidErrors.sol";
import { DidRecord, DidMetadata, DidStatus, MultiHash } from "./DidTypeNew.sol";
import { IDidRegistry } from "./IDidRegistry.sol";

/**
 * @title DidRegistry
 * @dev Implementation of DID operations following W3C DID Core specification
 * with optimized storage and gas efficiency using MultiHash for IPFS/IPLD integration
 */
contract DidRegistry is IDidRegistry {
    // Role control contract for authorization
    IRoleControl internal _roleControl;

    // DID records storage - maps identity address to DID record
    mapping(address identity => DidRecord didRecord) private _dids;

    // MODIFIERS

    /**
     * @dev Ensures the DID exists
     */
    modifier _didExist(address identity) {
        if (_dids[identity].metadata.created == 0) revert DidNotFound(identity);
        _;
    }

    /**
     * @dev Ensures the DID does not exist
     */
    modifier _didNotExist(address identity) {
        if (_dids[identity].metadata.created != 0) revert DidAlreadyExist(identity);
        _;
    }

    /**
     * @dev Ensures the DID is active
     */
    modifier _didIsActive(address identity) {
        if (_dids[identity].metadata.deactivated) revert DidHasBeenDeactivated(identity, "access");
        _;
    }

    /**
     * @dev Ensures caller has Trustee role
     */
    modifier _senderIsTrustee() {
        try _roleControl.isTrustee(msg.sender) {
            // Successfully validated as Trustee
        } catch (bytes memory) {
            revert Unauthorized(msg.sender);
        }
        _;
    }

    /**
     * @dev Ensures caller has Issuer role
     */
    modifier _senderIsIssuer() {
        try _roleControl.isIssuer(msg.sender) {
            // Successfully validated as Issuer
        } catch (bytes memory) {
            revert Unauthorized(msg.sender);
        }
        _;
    }

    /**
     * @dev Ensures caller is either Trustee or Issuer
     */
    modifier _senderIsTrusteeOrIssuer() {
        try _roleControl.isTrusteeOrIssuer(msg.sender) {
            // Successfully validated as either Trustee or Issuer
        } catch (bytes memory) {
            revert Unauthorized(msg.sender);
        }
        _;
    }

    /**
     * @dev Ensures caller is either DID owner or a trustee
     */
    modifier _senderIsIdentityOwnerOrTrustee(address identity) {
        if (msg.sender == identity) {
            // Caller is the identity owner
        } else {
            try _roleControl.isTrustee(msg.sender) {
                // Successfully validated as Trustee
            } catch (bytes memory) {
                revert Unauthorized(msg.sender);
            }
        }
        _;
    }

    /**
     * @dev Ensures actor is the DID owner
     */
    modifier _identityOwner(address identity, address actor) {
        if (identity != actor) revert NotIdentityOwner(actor, identity);
        _;
    }

    /**
     * @dev Constructor to initialize role control contract
     * @param roleControlContractAddress Address of role control contract
     */
    constructor(address roleControlContractAddress) {
        require(roleControlContractAddress != address(0), "Role control address cannot be zero");
        _roleControl = IRoleControl(roleControlContractAddress);
    }

    // PUBLIC FUNCTIONS - IMPLEMENTATION OF INTERFACE

    /// @inheritdoc IDidRegistry
    function createDid(
        address identity, 
        uint8 hashFunction,
        uint8 digestLength,
        bytes32 digest,
        bytes calldata docHash
    ) public override {
        _createDid(identity, msg.sender, hashFunction, digestLength, digest, docHash);
    }

    /// @inheritdoc IDidRegistry
    function createDidSigned(
        address identity,
        uint8 sigV,
        bytes32 sigR,
        bytes32 sigS,
        uint8 hashFunction,
        uint8 digestLength,
        bytes32 digest,
        bytes calldata docHash
    ) public override {
        // Recreate the signed message hash
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0x19), 
                bytes1(0), 
                address(this), 
                identity, 
                "createDid", 
                hashFunction, 
                digestLength, 
                digest, 
                docHash
            )
        );
        
        // Recover the signer from signature
        address signer = ecrecover(hash, sigV, sigR, sigS);
        
        // Call internal function with recovered signer
        _createDid(identity, signer, hashFunction, digestLength, digest, docHash);
    }

    /// @inheritdoc IDidRegistry
    function updateDid(
        address identity, 
        uint8 hashFunction,
        uint8 digestLength,
        bytes32 digest,
        bytes calldata docHash
    ) public override {
        _updateDid(identity, msg.sender, hashFunction, digestLength, digest, docHash);
    }

    /// @inheritdoc IDidRegistry
    function updateDidSigned(
        address identity,
        uint8 sigV,
        bytes32 sigR,
        bytes32 sigS,
        uint8 hashFunction,
        uint8 digestLength,
        bytes32 digest,
        bytes calldata docHash
    ) public override {
        // Recreate the signed message hash
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0x19), 
                bytes1(0), 
                address(this), 
                identity, 
                "updateDid", 
                hashFunction, 
                digestLength, 
                digest, 
                docHash
            )
        );
        
        // Recover the signer from signature
        address signer = ecrecover(hash, sigV, sigR, sigS);
        
        // Call internal function with recovered signer
        _updateDid(identity, signer, hashFunction, digestLength, digest, docHash);
    }

    /// @inheritdoc IDidRegistry
    function deactivateDid(address identity) public override {
        _deactivateDid(identity, msg.sender);
    }

    /// @inheritdoc IDidRegistry
    function deactivateDidSigned(
        address identity,
        uint8 sigV,
        bytes32 sigR,
        bytes32 sigS
    ) public override {
        // Recreate the signed message hash
        bytes32 hash = keccak256(
            abi.encodePacked(bytes1(0x19), bytes1(0), address(this), identity, "deactivateDid")
        );
        
        // Recover the signer from signature
        address signer = ecrecover(hash, sigV, sigR, sigS);
        
        // Call internal function with recovered signer
        _deactivateDid(identity, signer);
    }

    /// @inheritdoc IDidRegistry
    function resolveDid(address identity) public view override _didExist(identity) returns (DidRecord memory didRecord) {
        return _dids[identity];
    }

    /// @inheritdoc IDidRegistry
    function didExists(address identity) public view override returns (bool exists) {
        return _dids[identity].metadata.created != 0;
    }

    /// @inheritdoc IDidRegistry
    function isDidActive(address identity) public view override returns (bool active) {
        if (!didExists(identity)) return false;
        return !_dids[identity].metadata.deactivated;
    }

    /// @inheritdoc IDidRegistry
    function getDidStatus(address identity) public view override returns (DidStatus status) {
        if (!didExists(identity)) return DidStatus.NONE;
        return _dids[identity].metadata.deactivated ? DidStatus.DEACTIVATED : DidStatus.ACTIVE;
    }

    /// @inheritdoc IDidRegistry
    function validateDocumentHash(address identity, bytes calldata hash) public view override _didExist(identity) returns (bool valid) {
        bytes memory storedHash = _dids[identity].docHash;
        return keccak256(abi.encodePacked(storedHash)) == keccak256(abi.encodePacked(hash));
    }

    /// @inheritdoc IDidRegistry
    function getDocumentMultiHash(address identity) public view override _didExist(identity) returns (MultiHash memory multiHash) {
        return _dids[identity].document;
    }

    /// @inheritdoc IDidRegistry
    function getDocumentVersion(address identity) public view override _didExist(identity) returns (uint256 versionId) {
        return _dids[identity].metadata.versionId;
    }

    // INTERNAL FUNCTIONS

    /**
     * @dev Internal function to create a new DID
     * @param identity Address of the DID
     * @param actor Address of the actor (sender or recovered signer)
     * @param hashFunction The hash function code used in the MultiHash
     * @param digestLength The length of the digest
     * @param digest The document digest in MultiHash format
     * @param docHash Hash of the DID document for verification
     */
    function _createDid(
        address identity,
        address actor,
        uint8 hashFunction,
        uint8 digestLength,
        bytes32 digest,
        bytes calldata docHash
    ) 
        internal 
        _didNotExist(identity) 
        _identityOwner(identity, actor) 
        _senderIsTrusteeOrIssuer
    {
        // Validate inputs first
        if (digest == bytes32(0)) revert InvalidDidDocument("Empty document digest not allowed");
        if (docHash.length == 0) revert InvalidDidDocument("Empty document hash not allowed");
        
        // Update MultiHash document structure
        _dids[identity].document.hashFunction = hashFunction;
        _dids[identity].document.digestLength = digestLength;
        _dids[identity].document.digest = digest;
        
        // Set document hash
        _dids[identity].docHash = docHash;
        
        // Optimize storage packing by setting fields in order
        _dids[identity].metadata.owner = identity;
        _dids[identity].metadata.deactivated = false;
        _dids[identity].metadata.created = block.timestamp;
        _dids[identity].metadata.updated = block.timestamp;
        _dids[identity].metadata.versionId = block.number;

        // Emit event
        emit DIDCreated(identity, docHash, block.number);
    }

    /**
     * @dev Internal function to update a DID
     * @param identity Address of the DID
     * @param actor Address of the actor (sender or recovered signer)
     * @param hashFunction The hash function code used in the MultiHash
     * @param digestLength The length of the digest
     * @param digest The document digest in MultiHash format
     * @param docHash Updated hash of the DID document
     */
    function _updateDid(
        address identity,
        address actor,
        uint8 hashFunction,
        uint8 digestLength,
        bytes32 digest,
        bytes calldata docHash
    )
        internal
        _didExist(identity)
        _didIsActive(identity)
        _identityOwner(identity, actor)
        _senderIsIdentityOwnerOrTrustee(identity)
    {
        // Validate inputs first
        if (digest == bytes32(0)) revert InvalidDidDocument("Empty document digest not allowed");
        if (docHash.length == 0) revert InvalidDidDocument("Empty document hash not allowed");
        
        // Update MultiHash document structure
        _dids[identity].document.hashFunction = hashFunction;
        _dids[identity].document.digestLength = digestLength;
        _dids[identity].document.digest = digest;
        
        // Set document hash
        _dids[identity].docHash = docHash;
        
        // Update metadata
        _dids[identity].metadata.updated = block.timestamp;
        _dids[identity].metadata.versionId = block.number;

        // Emit event with new version ID for tracking
        emit DIDUpdated(identity, docHash, block.number);
    }

    /**
     * @dev Internal function to deactivate a DID
     * @param identity Address of the DID
     * @param actor Address of the actor (sender or recovered signer)
     */
    function _deactivateDid(
        address identity,
        address actor
    )
        internal
        _didExist(identity)
        _didIsActive(identity)
        _identityOwner(identity, actor)
        _senderIsIdentityOwnerOrTrustee(identity)
    {
        // Update state variables
        _dids[identity].metadata.deactivated = true;
        _dids[identity].metadata.updated = block.timestamp;
        _dids[identity].metadata.versionId = block.number;

        // Emit event
        emit DIDDeactivated(identity, block.number);
    }
}
