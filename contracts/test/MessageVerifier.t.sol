// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MessageVerifier.sol";
import "../src/ValidatorSet.sol";

/**
 * @title MessageVerifierTest
 * @notice Unit tests for MessageVerifier contract
 */
contract MessageVerifierTest is Test {
    // ============================================
    // STATE VARIABLES
    // ============================================

    MessageVerifier public verifier;
    ValidatorSet public validatorSet;

    address public owner = address(1);

    // Private keys for test validators
    uint256 public pk1 = 0x1;
    uint256 public pk2 = 0x2;
    uint256 public pk3 = 0x3;

    // Derived addresses
    address public validator1;
    address public validator2;
    address public validator3;

    // Test data
    address public testToken = address(100);
    address public testRecipient = address(200);
    uint256 public testAmount = 1000e6;
    uint256 public sourceChainId = 1; // Ethereum
    uint256 public testNonce = 1;

    // ============================================
    // SETUP
    // ============================================

    function setUp() public {
        // Get addresses from private keys
        validator1 = vm.addr(pk1);
        validator2 = vm.addr(pk2);
        validator3 = vm.addr(pk3);

        // Create validator set
        address[] memory validators = new address[](3);
        validators[0] = validator1;
        validators[1] = validator2;
        validators[2] = validator3;

        vm.startPrank(owner);
        validatorSet = new ValidatorSet(owner, validators, 2); // 2-of-3
        verifier = new MessageVerifier(address(validatorSet));
        vm.stopPrank();
    }

    // ============================================
    // CONSTRUCTOR TESTS
    // ============================================

    /**
     * @notice Test constructor sets correct values
     */
    function test_Constructor_SetsCorrectValues() public view {
        assertEq(address(verifier.validatorSet()), address(validatorSet));
        assertEq(verifier.CHAIN_ID(), block.chainid);
    }

    /**
     * @notice Test constructor reverts with zero address
     */
    function test_Constructor_RevertIfZeroAddress() public {
        vm.expectRevert(MessageVerifier.InvalidValidatorSet.selector);
        new MessageVerifier(address(0));
    }

    // ============================================
    // HASH FUNCTION TESTS
    // ============================================

    /**
     * @notice Test hashBridgeLock is deterministic
     */
    function test_HashBridgeLock_Deterministic() public view {
        bytes32 hash1 = verifier.hashBridgeLock(
            testToken,
            testRecipient,
            testAmount,
            sourceChainId,
            block.chainid,
            testNonce
        );

        bytes32 hash2 = verifier.hashBridgeLock(
            testToken,
            testRecipient,
            testAmount,
            sourceChainId,
            block.chainid,
            testNonce
        );

        assertEq(hash1, hash2);
    }

    /**
     * @notice Test hashBridgeLock differs from hashBridgeBurn
     */
    function test_HashBridgeLock_DiffersFromBurn() public view {
        bytes32 lockHash = verifier.hashBridgeLock(
            testToken,
            testRecipient,
            testAmount,
            sourceChainId,
            block.chainid,
            testNonce
        );

        bytes32 burnHash = verifier.hashBridgeBurn(
            testToken,
            testRecipient,
            testAmount,
            sourceChainId,
            block.chainid,
            testNonce
        );

        assertTrue(lockHash != burnHash);
    }

    /**
     * @notice Test different nonces produce different hashes
     */
    function test_HashBridgeLock_UniquePerNonce() public view {
        bytes32 hash1 = verifier.hashBridgeLock(
            testToken,
            testRecipient,
            testAmount,
            sourceChainId,
            block.chainid,
            1
        );

        bytes32 hash2 = verifier.hashBridgeLock(
            testToken,
            testRecipient,
            testAmount,
            sourceChainId,
            block.chainid,
            2
        );

        assertTrue(hash1 != hash2);
    }

    // ============================================
    // VERIFICATION TESTS
    // ============================================

    /**
     * @notice Test verifyBridgeLock with valid signatures
     */
    function test_VerifyBridgeLock_Success() public {
        // Create message hash
        bytes32 msgHash = verifier.hashBridgeLock(
            testToken,
            testRecipient,
            testAmount,
            sourceChainId,
            block.chainid,
            testNonce
        );

        // Get signatures from 2 validators (threshold = 2)
        bytes[] memory sigs = _createSignatures(msgHash, pk1, pk2);

        // Verify
        bool valid = verifier.verifyBridgeLock(
            testToken,
            testRecipient,
            testAmount,
            sourceChainId,
            testNonce,
            sigs
        );

        assertTrue(valid);
    }

    /**
     * @notice Test verifyBridgeBurn with valid signatures
     */
    function test_VerifyBridgeBurn_Success() public {
        // Create message hash
        bytes32 msgHash = verifier.hashBridgeBurn(
            testToken,
            testRecipient,
            testAmount,
            sourceChainId,
            block.chainid,
            testNonce
        );

        // Get signatures
        bytes[] memory sigs = _createSignatures(msgHash, pk1, pk3);

        // Verify
        bool valid = verifier.verifyBridgeBurn(
            testToken,
            testRecipient,
            testAmount,
            sourceChainId,
            testNonce,
            sigs
        );

        assertTrue(valid);
    }

    /**
     * @notice Test verification fails with insufficient signatures
     */
    function test_VerifyBridgeLock_RevertIfNotEnoughSignatures() public {
        bytes32 msgHash = verifier.hashBridgeLock(
            testToken,
            testRecipient,
            testAmount,
            sourceChainId,
            block.chainid,
            testNonce
        );

        // Only 1 signature (need 2)
        bytes[] memory sigs = new bytes[](1);
        bytes32 ethHash = _toEthSignedMessageHash(msgHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk1, ethHash);
        sigs[0] = abi.encodePacked(r, s, v);

        vm.expectRevert(ValidatorSet.NotEnoughSignatures.selector);
        verifier.verifyBridgeLock(
            testToken,
            testRecipient,
            testAmount,
            sourceChainId,
            testNonce,
            sigs
        );
    }

    // ============================================
    // VIEW FUNCTION TESTS
    // ============================================

    /**
     * @notice Test getThreshold returns correct value
     */
    function test_GetThreshold() public view {
        assertEq(verifier.getThreshold(), 2);
    }

    /**
     * @notice Test getValidatorCount returns correct value
     */
    function test_GetValidatorCount() public view {
        assertEq(verifier.getValidatorCount(), 3);
    }

    /**
     * @notice Test isValidator returns correct values
     */
    function test_IsValidator() public view {
        assertTrue(verifier.isValidator(validator1));
        assertTrue(verifier.isValidator(validator2));
        assertTrue(verifier.isValidator(validator3));
        assertFalse(verifier.isValidator(address(999)));
    }

    // ============================================
    // HELPER FUNCTIONS
    // ============================================

    function _toEthSignedMessageHash(
        bytes32 hash
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)
            );
    }

    function _createSignatures(
        bytes32 messageHash,
        uint256 privKey1,
        uint256 privKey2
    ) internal pure returns (bytes[] memory) {
        bytes32 ethHash = _toEthSignedMessageHash(messageHash);

        bytes[] memory sigs = new bytes[](2);

        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(privKey1, ethHash);
        sigs[0] = abi.encodePacked(r1, s1, v1);

        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(privKey2, ethHash);
        sigs[1] = abi.encodePacked(r2, s2, v2);

        return sigs;
    }
}
