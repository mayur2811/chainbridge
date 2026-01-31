// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title ValidatorSet
 * @notice Manages multi-sig validators for secure bridge operations
 * @dev Implements N-of-M threshold signature verification
 *
 * WHY MULTI-SIG?
 * Single validator = Single point of failure
 * If hacked, all bridge funds at risk!
 *
 * Multi-sig = Multiple validators must agree
 * Example: 3-of-5 means 3 validators must sign
 * If 1-2 are hacked, funds still safe!
 *
 * HOW IT WORKS:
 * 1. Bridge event happens (tokens locked or burned)
 * 2. Each validator creates a signature off-chain
 * 3. Someone submits all signatures to contract
 * 4. Contract verifies: Are there enough valid signatures?
 * 5. If yes → Execute bridge operation
 * 6. If no → Revert!
 */
contract ValidatorSet is Ownable {
    using ECDSA for bytes32;

    // ============================================
    // STATE VARIABLES
    // ============================================

    /**
     * @notice List of all validator addresses
     * @dev Used to iterate through validators
     */
    address[] public validators;

    /**
     * @notice Quick lookup: is this address a validator?
     * @dev isValidator[0xABC] = true means 0xABC is a validator
     */
    mapping(address => bool) public isValidator;

    /**
     * @notice How many signatures are required
     * @dev Example: threshold = 3 means 3 validators must sign
     */
    uint256 public threshold;

    /**
     * @notice Maximum number of validators allowed
     * @dev Prevents gas issues with too many validators
     */
    uint256 public constant MAX_VALIDATORS = 20;

    // ============================================
    // EVENTS
    // ============================================

    event ValidatorAdded(address indexed validator);
    event ValidatorRemoved(address indexed validator);
    event ThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);

    // ============================================
    // ERRORS (Gas-efficient error handling)
    // ============================================

    error AlreadyValidator();
    error NotValidator();
    error InvalidThreshold();
    error TooManyValidators();
    error InvalidSignature();
    error NotEnoughSignatures();
    error DuplicateSignature();

    // ============================================
    // CONSTRUCTOR
    // ============================================

    /**
     * @notice Deploy with initial validators and threshold
     * @param initialOwner Admin address
     * @param _validators Initial validator addresses
     * @param _threshold How many must sign (e.g., 3 for 3-of-5)
     *
     * Example: Deploy with 5 validators, require 3 signatures
     * new ValidatorSet(admin, [v1, v2, v3, v4, v5], 3)
     */
    constructor(
        address initialOwner,
        address[] memory _validators,
        uint256 _threshold
    ) Ownable(initialOwner) {
        // Validate inputs
        if (_validators.length > MAX_VALIDATORS) revert TooManyValidators();
        if (_threshold == 0 || _threshold > _validators.length)
            revert InvalidThreshold();

        // Add initial validators
        for (uint256 i = 0; i < _validators.length; i++) {
            address validator = _validators[i];

            // Check not zero address and not duplicate
            require(validator != address(0), "Invalid validator address");
            if (isValidator[validator]) revert AlreadyValidator();

            isValidator[validator] = true;
            validators.push(validator);

            emit ValidatorAdded(validator);
        }

        threshold = _threshold;
    }

    // ============================================
    // SIGNATURE VERIFICATION
    // ============================================

    /**
     * @notice Verify that enough validators signed a message
     * @param messageHash The hash of the message that was signed
     * @param signatures Array of signatures from validators
     * @return True if threshold reached with valid unique signatures
     *
     * HOW SIGNATURES WORK:
     * 1. Create message: "Bridge 100 USDC to 0xUser on chain 42161"
     * 2. Hash the message: keccak256(message) = 0xABC...
     * 3. Validators sign the hash with their private keys
     * 4. Submit signatures to this function
     * 5. Function recovers signer from each signature
     * 6. Checks: Is signer a validator? Is it unique?
     */
    function verifySignatures(
        bytes32 messageHash,
        bytes[] calldata signatures
    ) public view returns (bool) {
        // Must have enough signatures
        if (signatures.length < threshold) revert NotEnoughSignatures();

        // Track which validators have signed (prevent duplicates)
        address[] memory signers = new address[](signatures.length);
        uint256 validCount = 0;

        // Convert to Ethereum signed message hash
        // This adds "\x19Ethereum Signed Message:\n32" prefix
        bytes32 ethSignedHash = MessageHashUtils.toEthSignedMessageHash(
            messageHash
        );

        for (uint256 i = 0; i < signatures.length; i++) {
            // Recover signer address from signature
            address signer = ECDSA.recover(ethSignedHash, signatures[i]);

            // Is this signer a validator?
            if (!isValidator[signer]) continue; // Skip invalid

            // Check for duplicate signatures
            for (uint256 j = 0; j < validCount; j++) {
                if (signers[j] == signer) revert DuplicateSignature();
            }

            // Valid unique signature!
            signers[validCount] = signer;
            validCount++;

            // Early exit if threshold reached
            if (validCount >= threshold) {
                return true;
            }
        }

        // Not enough valid signatures
        revert NotEnoughSignatures();
    }

    /**
     * @notice Create the message hash for a bridge operation
     * @param token Token being bridged
     * @param recipient Who receives tokens
     * @param amount How many tokens
     * @param sourceChainId Where tokens came from
     * @param nonce Unique transaction ID
     * @return Hash to be signed by validators
     *
     * This creates a unique hash for each bridge transaction
     * Validators sign THIS hash, not raw data
     */
    function getBridgeMessageHash(
        address token,
        address recipient,
        uint256 amount,
        uint256 sourceChainId,
        uint256 destChainId,
        uint256 nonce
    ) public pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    token,
                    recipient,
                    amount,
                    sourceChainId,
                    destChainId,
                    nonce
                )
            );
    }

    // ============================================
    // ADMIN FUNCTIONS
    // ============================================

    /**
     * @notice Add a new validator
     * @param validator Address to add
     */
    function addValidator(address validator) external onlyOwner {
        require(validator != address(0), "Invalid address");
        if (isValidator[validator]) revert AlreadyValidator();
        if (validators.length >= MAX_VALIDATORS) revert TooManyValidators();

        isValidator[validator] = true;
        validators.push(validator);

        emit ValidatorAdded(validator);
    }

    /**
     * @notice Remove a validator
     * @param validator Address to remove
     *
     * NOTE: This also adjusts threshold if needed
     * Example: Remove validator from 5 → 4 validators
     * If threshold was 5, it becomes 4 (can't require more than exist)
     */
    function removeValidator(address validator) external onlyOwner {
        if (!isValidator[validator]) revert NotValidator();

        isValidator[validator] = false;

        // Remove from array (find and swap with last)
        for (uint256 i = 0; i < validators.length; i++) {
            if (validators[i] == validator) {
                validators[i] = validators[validators.length - 1];
                validators.pop();
                break;
            }
        }

        // Adjust threshold if now too high
        if (threshold > validators.length) {
            uint256 oldThreshold = threshold;
            threshold = validators.length;
            emit ThresholdUpdated(oldThreshold, threshold);
        }

        emit ValidatorRemoved(validator);
    }

    /**
     * @notice Update the signature threshold
     * @param newThreshold New number of required signatures
     */
    function updateThreshold(uint256 newThreshold) external onlyOwner {
        if (newThreshold == 0 || newThreshold > validators.length) {
            revert InvalidThreshold();
        }

        uint256 oldThreshold = threshold;
        threshold = newThreshold;

        emit ThresholdUpdated(oldThreshold, newThreshold);
    }

    // ============================================
    // VIEW FUNCTIONS
    // ============================================

    /**
     * @notice Get total number of validators
     */
    function getValidatorCount() external view returns (uint256) {
        return validators.length;
    }

    /**
     * @notice Get all validators
     */
    function getValidators() external view returns (address[] memory) {
        return validators;
    }

    /**
     * @notice Check if address is a validator
     */
    function checkValidator(address account) external view returns (bool) {
        return isValidator[account];
    }
}
