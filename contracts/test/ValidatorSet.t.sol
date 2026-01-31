// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/ValidatorSet.sol";

/**
 * @title ValidatorSetTest
 * @notice Unit tests for ValidatorSet contract
 */
contract ValidatorSetTest is Test {
    // ============================================
    // STATE VARIABLES
    // ============================================

    ValidatorSet public validatorSet;

    address public owner = address(1);
    address public validator1 = address(10);
    address public validator2 = address(11);
    address public validator3 = address(12);
    address public validator4 = address(13);
    address public validator5 = address(14);
    address public nonValidator = address(99);

    // ============================================
    // SETUP
    // ============================================

    function setUp() public {
        // Create initial validators array
        address[] memory initialValidators = new address[](3);
        initialValidators[0] = validator1;
        initialValidators[1] = validator2;
        initialValidators[2] = validator3;

        // Deploy with 3 validators, threshold 2
        vm.prank(owner);
        validatorSet = new ValidatorSet(owner, initialValidators, 2);
    }

    // ============================================
    // CONSTRUCTOR TESTS
    // ============================================

    /**
     * @notice Test constructor sets correct values
     */
    function test_Constructor_SetsCorrectValues() public view {
        assertEq(validatorSet.getValidatorCount(), 3);
        assertEq(validatorSet.threshold(), 2);
        assertTrue(validatorSet.isValidator(validator1));
        assertTrue(validatorSet.isValidator(validator2));
        assertTrue(validatorSet.isValidator(validator3));
        assertFalse(validatorSet.isValidator(nonValidator));
    }

    /**
     * @notice Test constructor reverts with threshold 0
     */
    function test_Constructor_RevertIfZeroThreshold() public {
        address[] memory validators = new address[](3);
        validators[0] = validator1;
        validators[1] = validator2;
        validators[2] = validator3;

        vm.prank(owner);
        vm.expectRevert(ValidatorSet.InvalidThreshold.selector);
        new ValidatorSet(owner, validators, 0);
    }

    /**
     * @notice Test constructor reverts with threshold > validators
     */
    function test_Constructor_RevertIfThresholdTooHigh() public {
        address[] memory validators = new address[](3);
        validators[0] = validator1;
        validators[1] = validator2;
        validators[2] = validator3;

        vm.prank(owner);
        vm.expectRevert(ValidatorSet.InvalidThreshold.selector);
        new ValidatorSet(owner, validators, 5); // 5 > 3
    }

    // ============================================
    // SIGNATURE VERIFICATION TESTS
    // ============================================

    /**
     * @notice Test signature verification with valid signatures
     * NOTE: Simplified test to avoid stack-too-deep errors
     */
    function test_VerifySignatures_Success() public {
        // Use fixed private keys
        uint256 pk1 = 0x1;
        uint256 pk2 = 0x2;

        // Create validator set with signers from these keys
        address[] memory signers = new address[](2);
        signers[0] = vm.addr(pk1);
        signers[1] = vm.addr(pk2);

        vm.prank(owner);
        ValidatorSet testSet = new ValidatorSet(owner, signers, 2);

        // Create and sign message
        bytes32 msgHash = keccak256("test message");
        bytes[] memory sigs = _createSignatures(msgHash, pk1, pk2);

        // Verify signatures
        assertTrue(testSet.verifySignatures(msgHash, sigs));
    }

    /**
     * @dev Helper to create signatures (avoids stack too deep)
     */
    function _createSignatures(
        bytes32 messageHash,
        uint256 pk1,
        uint256 pk2
    ) internal pure returns (bytes[] memory) {
        bytes32 ethHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );

        bytes[] memory sigs = new bytes[](2);

        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(pk1, ethHash);
        sigs[0] = abi.encodePacked(r1, s1, v1);

        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(pk2, ethHash);
        sigs[1] = abi.encodePacked(r2, s2, v2);

        return sigs;
    }

    /**
     * @notice Test verification reverts with not enough signatures
     */
    function test_VerifySignatures_RevertIfNotEnough() public {
        bytes32 messageHash = keccak256("test message");
        bytes[] memory signatures = new bytes[](1);
        signatures[0] = abi.encodePacked(bytes32(0), bytes32(0), uint8(27));

        vm.expectRevert(ValidatorSet.NotEnoughSignatures.selector);
        validatorSet.verifySignatures(messageHash, signatures);
    }

    // ============================================
    // ADD VALIDATOR TESTS
    // ============================================

    /**
     * @notice Test owner can add validator
     */
    function test_AddValidator_Success() public {
        vm.prank(owner);
        validatorSet.addValidator(validator4);

        assertTrue(validatorSet.isValidator(validator4));
        assertEq(validatorSet.getValidatorCount(), 4);
    }

    /**
     * @notice Test cannot add duplicate validator
     */
    function test_AddValidator_RevertIfAlreadyValidator() public {
        vm.prank(owner);
        vm.expectRevert(ValidatorSet.AlreadyValidator.selector);
        validatorSet.addValidator(validator1); // Already added
    }

    /**
     * @notice Test non-owner cannot add validator
     */
    function test_AddValidator_RevertIfNotOwner() public {
        vm.prank(validator1);
        vm.expectRevert(); // Ownable error
        validatorSet.addValidator(validator4);
    }

    // ============================================
    // REMOVE VALIDATOR TESTS
    // ============================================

    /**
     * @notice Test owner can remove validator
     */
    function test_RemoveValidator_Success() public {
        vm.prank(owner);
        validatorSet.removeValidator(validator3);

        assertFalse(validatorSet.isValidator(validator3));
        assertEq(validatorSet.getValidatorCount(), 2);
    }

    /**
     * @notice Test removing validator adjusts threshold
     */
    function test_RemoveValidator_AdjustsThreshold() public {
        // Start: 3 validators, threshold 2
        // Remove 2 validators
        vm.startPrank(owner);
        validatorSet.removeValidator(validator2);
        validatorSet.removeValidator(validator3);
        vm.stopPrank();

        // Now: 1 validator, threshold should be 1 (can't be > count)
        assertEq(validatorSet.getValidatorCount(), 1);
        assertEq(validatorSet.threshold(), 1);
    }

    /**
     * @notice Test cannot remove non-validator
     */
    function test_RemoveValidator_RevertIfNotValidator() public {
        vm.prank(owner);
        vm.expectRevert(ValidatorSet.NotValidator.selector);
        validatorSet.removeValidator(nonValidator);
    }

    // ============================================
    // UPDATE THRESHOLD TESTS
    // ============================================

    /**
     * @notice Test owner can update threshold
     */
    function test_UpdateThreshold_Success() public {
        vm.prank(owner);
        validatorSet.updateThreshold(3);

        assertEq(validatorSet.threshold(), 3);
    }

    /**
     * @notice Test cannot set threshold > validator count
     */
    function test_UpdateThreshold_RevertIfTooHigh() public {
        vm.prank(owner);
        vm.expectRevert(ValidatorSet.InvalidThreshold.selector);
        validatorSet.updateThreshold(5); // Only 3 validators
    }

    /**
     * @notice Test cannot set threshold to 0
     */
    function test_UpdateThreshold_RevertIfZero() public {
        vm.prank(owner);
        vm.expectRevert(ValidatorSet.InvalidThreshold.selector);
        validatorSet.updateThreshold(0);
    }

    // ============================================
    // VIEW FUNCTION TESTS
    // ============================================

    /**
     * @notice Test getValidators returns all validators
     */
    function test_GetValidators() public view {
        address[] memory validators = validatorSet.getValidators();

        assertEq(validators.length, 3);
        assertEq(validators[0], validator1);
        assertEq(validators[1], validator2);
        assertEq(validators[2], validator3);
    }

    /**
     * @notice Test checkValidator function
     */
    function test_CheckValidator() public view {
        assertTrue(validatorSet.checkValidator(validator1));
        assertFalse(validatorSet.checkValidator(nonValidator));
    }

    // ============================================
    // HASH FUNCTION TESTS
    // ============================================

    /**
     * @notice Test message hash is deterministic
     */
    function test_GetBridgeMessageHash_Deterministic() public view {
        bytes32 hash1 = validatorSet.getBridgeMessageHash(
            address(100), // token
            address(200), // recipient
            1000, // amount
            1, // sourceChainId
            42161, // destChainId
            5 // nonce
        );

        bytes32 hash2 = validatorSet.getBridgeMessageHash(
            address(100),
            address(200),
            1000,
            1,
            42161,
            5
        );

        assertEq(hash1, hash2);
    }

    /**
     * @notice Test different inputs produce different hashes
     */
    function test_GetBridgeMessageHash_UniquePerInput() public view {
        bytes32 hash1 = validatorSet.getBridgeMessageHash(
            address(100),
            address(200),
            1000,
            1,
            42161,
            5
        );

        bytes32 hash2 = validatorSet.getBridgeMessageHash(
            address(100),
            address(200),
            1000,
            1,
            42161,
            6 // Different nonce
        );

        assertTrue(hash1 != hash2);
    }
}
