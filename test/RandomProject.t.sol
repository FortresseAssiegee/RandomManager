// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../src/RandomProject.sol";
import "../src/verifier/MockBLSVerifier.sol";
import "../src/libraries/BLS256.sol";

contract RandomProjectTest is Test {
    RandomProject public randomProject;
    MockBLSVerifier public mockVerifier;
    bytes32 internal constant USER_SEED = bytes32("userSeed");
    address internal constant NON_OWNER = address(0xBEEF);

    function _publicKey() internal pure returns (BLS256.G2Point memory) {
        return BLS256.G2Point({x: [uint256(0), uint256(0)], y: [uint256(0), uint256(0)]});
    }

    function _signature() internal pure returns (BLS256.G1Point memory) {
        return BLS256.G1Point({x: 0, y: 0});
    }

    function setUp() public {
        console.log("setUp function");
        randomProject = new RandomProject();
        mockVerifier = new MockBLSVerifier();
        randomProject.initialize(address(this), address(this), bytes32(uint256(1)), address(mockVerifier), _publicKey());
        console.log("RandomProject initialized");
    }

    function test_requestRandomness() public {
        console.log("test_requestRandomness function");
        uint256 requestId = randomProject.requestRandomness(USER_SEED);
        console.log("requestRandomness called");
        assertEq(requestId, 1);
        assertEq(randomProject.requestId(), 1);
    }

    function test_getRequest() public {
        uint256 requestId = randomProject.requestRandomness(USER_SEED);

        (address requester, bytes32 userSeed, uint256 blockNumber, uint256 randomness, uint8 status) =
            randomProject.getRequest(requestId);

        assertEq(requester, address(this));
        assertEq(userSeed, USER_SEED);
        assertEq(blockNumber, block.number);
        assertEq(randomness, 0);
        assertEq(uint256(status), uint256(RandomProject.RequestStatus.Pending));
    }

    function test_getRequestMessage() public {
        console.log("test_getRequestMessage function");
        randomProject.requestRandomness(USER_SEED);
        bytes32 message = randomProject.getRequestMessage(1);
        assertTrue(message != bytes32(0));
        console.log("getRequestMessage called");
    }

    function test_fulfillRandomness() public {
        console.log("test_fulfillRandomness function");
        randomProject.requestRandomness(USER_SEED);
        randomProject.fulfillRandomness(1, _signature());
        console.log("fulfillRandomness called");
    }

    function test_cannotFulfillUnknownRequest() public {
        vm.expectRevert(abi.encodeWithSelector(RandomProject.RequestNotFound.selector, 1));
        randomProject.fulfillRandomness(1, _signature());
    }

    function test_cannotFulfillTwice() public {
        randomProject.requestRandomness(USER_SEED);
        randomProject.fulfillRandomness(1, _signature());

        vm.expectRevert(abi.encodeWithSelector(RandomProject.RequestNotPending.selector, 1));
        randomProject.fulfillRandomness(1, _signature());
    }

    function test_fulfillRevertsWhenVerifierReturnsFalse() public {
        randomProject.requestRandomness(USER_SEED);
        mockVerifier.setResult(false);

        vm.expectRevert(RandomProject.InvalidSignature.selector);
        randomProject.fulfillRandomness(1, _signature());
    }

    function test_getRandomness() public {
        console.log("test_getRandomness function");
        randomProject.requestRandomness(USER_SEED);
        randomProject.fulfillRandomness(1, _signature());
        uint256 randomness = randomProject.getRandomness(1);
        assertTrue(randomness != 0);
        console.log("getRandomness called");
    }

    function test_cannotGetRandomnessBeforeFulfilled() public {
        randomProject.requestRandomness(USER_SEED);

        vm.expectRevert(abi.encodeWithSelector(RandomProject.RandomnessNotFulfilled.selector, 1));
        randomProject.getRandomness(1);
    }

    function test_consumeRandomness() public {
        randomProject.requestRandomness(USER_SEED);
        randomProject.fulfillRandomness(1, _signature());

        uint256 consumed = randomProject.consumeRandomness(1);

        assertTrue(consumed != 0);

        (,,, uint256 randomness, uint8 status) = randomProject.getRequest(1);
        assertEq(randomness, consumed);
        assertEq(uint256(status), uint256(RandomProject.RequestStatus.Consumed));
    }

    function test_cannotConsumeTwice() public {
        randomProject.requestRandomness(USER_SEED);
        randomProject.fulfillRandomness(1, _signature());
        randomProject.consumeRandomness(1);

        vm.expectRevert(abi.encodeWithSelector(RandomProject.RandomnessNotFulfilled.selector, 1));
        randomProject.consumeRandomness(1);
    }

    function test_nonOwnerCannotConsume() public {
        randomProject.requestRandomness(USER_SEED);
        randomProject.fulfillRandomness(1, _signature());

        vm.prank(NON_OWNER);
        vm.expectRevert();
        randomProject.consumeRandomness(1);
    }

    function test_setPublicKey() public {
        console.log("test_setPublicKey function");
        randomProject.setPublicKey(_publicKey());
        console.log("setPublicKey called");
    }

    function test_nonOwnerCannotSetPublicKey() public {
        vm.prank(NON_OWNER);
        vm.expectRevert();
        randomProject.setPublicKey(_publicKey());
    }

    function test_pauseAndUnpause() public {
        console.log("test_pauseAndUnpause function");
        randomProject.pause();
        console.log("pause called");
        randomProject.unpause();
        console.log("unpause called");
    }

    function test_nonOwnerCannotPause() public {
        vm.prank(NON_OWNER);
        vm.expectRevert();
        randomProject.pause();
    }

    function test_nonOwnerCannotUnpause() public {
        randomProject.pause();

        vm.prank(NON_OWNER);
        vm.expectRevert();
        randomProject.unpause();
    }

    function test_requestRevertsWhenPaused() public {
        randomProject.pause();

        vm.expectRevert();
        randomProject.requestRandomness(USER_SEED);
    }

    function test_fulfillRevertsWhenPaused() public {
        randomProject.requestRandomness(USER_SEED);
        randomProject.pause();

        vm.expectRevert();
        randomProject.fulfillRandomness(1, _signature());
    }

    function test_getRequestRevertsForUnknownRequest() public {
        vm.expectRevert(abi.encodeWithSelector(RandomProject.RequestNotFound.selector, 1));
        randomProject.getRequest(1);
    }

    function test_getRequestMessageRevertsForUnknownRequest() public {
        vm.expectRevert(abi.encodeWithSelector(RandomProject.RequestNotFound.selector, 1));
        randomProject.getRequestMessage(1);
    }
}
