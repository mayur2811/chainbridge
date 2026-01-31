// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ValidatorSet.sol";

/**
 * @title MessageVerifier
 * @notice Verifies bridge messages using multi-sig validation
 * @dev Acts as the "glue" between BridgeRouter and ValidatorSet
 *
 * WHY THIS CONTRACT?
 * BridgeRouter needs to verify that validators approved a bridge.
 * Instead of putting all verification logic in Router, we separate it.
 *
 * BENEFITS:
 * 1. Clean separation of concerns
 * 2. Easy to upgrade verification logic
 * 3. Reusable across different bridge components
 *
 * FLOW:
 * 1. Router calls verifyBridgeMessage(data, signatures)
 * 2. MessageVerifier creates hash from data
 * 3. MessageVerifier asks ValidatorSet to verify signatures
 * 4. Returns true if enough valid signatures, else reverts
 */
contract MessageVerifier {
    // ============================================
    // STATE VARIABLES
    // ============================================

    /**
     * @notice Reference to the ValidatorSet contract
     * @dev This is where we check if signatures are valid
     */
    ValidatorSet public validatorSet;

    /**
     * @notice This chain's ID
     * @dev Used to verify messages are for THIS chain
     */
    uint256 public immutable CHAIN_ID;

    // ============================================
    // ERRORS
    // ============================================

    error InvalidValidatorSet();
    error ChainMismatch();
    error VerificationFailed();

    // ============================================
    // EVENTS
    // ============================================

    event MessageVerified(
        bytes32 indexed messageHash,
        uint256 signaturesProvided
    );

    event ValidatorSetUpdated(address indexed oldSet, address indexed newSet);

    // ============================================
    // CONSTRUCTOR
    // ============================================

    /**
     * @notice Deploy with reference to ValidatorSet
     * @param _validatorSet Address of ValidatorSet contract
     *
     * Example:
     * new MessageVerifier(0xValidatorSetAddress)
     */
    constructor(address _validatorSet) {
        if (_validatorSet == address(0)) revert InvalidValidatorSet();

        validatorSet = ValidatorSet(_validatorSet);
        CHAIN_ID = block.chainid;
    }

    // ============================================
    // MAIN VERIFICATION FUNCTIONS
    // ============================================

    /**
     * @notice Verify a bridge lock message (for minting on destination)
     * @param token Original token address
     * @param recipient Who should receive wrapped tokens
     * @param amount How many tokens
     * @param sourceChainId Where tokens were locked
     * @param nonce Unique lock ID from source chain
     * @param signatures Array of validator signatures
     * @return True if verification passes
     *
     * CALLED BY: BridgeRouter.completeBridge()
     *
     * FLOW:
     * 1. Check this message is for OUR chain
     * 2. Create hash from all parameters
     * 3. Ask ValidatorSet to verify signatures
     * 4. If enough valid signatures → return true
     * 5. If not → revert!
     */
    function verifyBridgeLock(
        address token,
        address recipient,
        uint256 amount,
        uint256 sourceChainId,
        uint256 nonce,
        bytes[] calldata signatures
    ) external returns (bool) {
        // Create message hash
        bytes32 messageHash = hashBridgeLock(
            token,
            recipient,
            amount,
            sourceChainId,
            CHAIN_ID, // Destination is THIS chain
            nonce
        );

        // Verify with ValidatorSet
        bool valid = validatorSet.verifySignatures(messageHash, signatures);

        if (!valid) revert VerificationFailed();

        emit MessageVerified(messageHash, signatures.length);
        return true;
    }

    /**
     * @notice Verify a burn message (for releasing on source)
     * @param token Original token address
     * @param recipient Who should receive original tokens
     * @param amount How many tokens burned
     * @param sourceChainId Where tokens were burned (wrapped token chain)
     * @param nonce Unique burn ID from source chain
     * @param signatures Array of validator signatures
     * @return True if verification passes
     *
     * CALLED BY: BridgeRouter.releaseBridge()
     *
     * Similar to verifyBridgeLock but for the reverse flow:
     * User burned wrapped tokens → Release original tokens
     */
    function verifyBridgeBurn(
        address token,
        address recipient,
        uint256 amount,
        uint256 sourceChainId,
        uint256 nonce,
        bytes[] calldata signatures
    ) external returns (bool) {
        // Create message hash
        bytes32 messageHash = hashBridgeBurn(
            token,
            recipient,
            amount,
            sourceChainId,
            CHAIN_ID, // Release on THIS chain
            nonce
        );

        // Verify with ValidatorSet
        bool valid = validatorSet.verifySignatures(messageHash, signatures);

        if (!valid) revert VerificationFailed();

        emit MessageVerified(messageHash, signatures.length);
        return true;
    }

    // ============================================
    // HASH FUNCTIONS
    // ============================================

    /**
     * @notice Create hash for a lock message
     * @dev Validators sign this hash to approve minting
     *
     * IMPORTANT: Hash includes ALL details to prevent:
     * - Amount manipulation (can't mint more than locked)
     * - Recipient manipulation (can't steal to different address)
     * - Chain manipulation (can't mint on wrong chain)
     * - Replay attacks (nonce is unique)
     */
    function hashBridgeLock(
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
                    "BRIDGE_LOCK", // Type identifier
                    token,
                    recipient,
                    amount,
                    sourceChainId,
                    destChainId,
                    nonce
                )
            );
    }

    /**
     * @notice Create hash for a burn message
     * @dev Validators sign this hash to approve releasing
     */
    function hashBridgeBurn(
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
                    "BRIDGE_BURN", // Type identifier
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
    // VIEW FUNCTIONS
    // ============================================

    /**
     * @notice Get the configured threshold from ValidatorSet
     */
    function getThreshold() external view returns (uint256) {
        return validatorSet.threshold();
    }

    /**
     * @notice Get validator count from ValidatorSet
     */
    function getValidatorCount() external view returns (uint256) {
        return validatorSet.getValidatorCount();
    }

    /**
     * @notice Check if an address is a validator
     */
    function isValidator(address account) external view returns (bool) {
        return validatorSet.isValidator(account);
    }
}
