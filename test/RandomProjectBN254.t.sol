// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {RandomProject} from "../src/RandomProject.sol";
import {BN254BLSVerifier} from "../src/verifier/BN254BLSVerifier.sol";
import {BLS256} from "../src/libraries/BLS256.sol";
import {Pairing} from "../src/libraries/Pairing.sol";

contract RandomProjectBN254Test is Test {
    RandomProject public randomProject;
    BN254BLSVerifier public verifier;

    bytes32 internal constant USER_SEED = bytes32("userSeed");

    function setUp() public {
        verifier = new BN254BLSVerifier();
        randomProject = new RandomProject();
        randomProject.initialize(address(this), address(this), bytes32(uint256(1)), address(verifier), Pairing.P2());
    }

    function testFulfillRandomnessWithBN254Verifier() public {
        uint256 requestId = randomProject.requestRandomness(USER_SEED);
        bytes32 message = randomProject.getRequestMessage(requestId);
        BLS256.G1Point memory signature = verifier.hashToG1(message);

        randomProject.fulfillRandomness(requestId, signature);

        uint256 randomness = randomProject.getRandomness(requestId);
        assertTrue(randomness != 0);
    }

    function testRejectWrongBN254Signature() public {
        uint256 requestId = randomProject.requestRandomness(USER_SEED);

        vm.expectRevert(RandomProject.InvalidSignature.selector);
        randomProject.fulfillRandomness(requestId, Pairing.P1());
    }
}
