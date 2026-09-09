// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {BN254BLSVerifier} from "../src/verifier/BN254BLSVerifier.sol";
import {BLS256} from "../src/libraries/BLS256.sol";
import {Pairing} from "../src/libraries/Pairing.sol";

contract BLSVerifierTest is Test {
    BN254BLSVerifier public verifier;

    function setUp() public {
        verifier = new BN254BLSVerifier();
    }

    function testVerifyValidSignature() public {
        assertTrue(verifier.verifyPoint(Pairing.P1(), Pairing.P1(), Pairing.P2()));
    }

    function testRejectInvalidSignature() public {
        BLS256.G1Point memory invalidSignature = Pairing.scalarMul(Pairing.P1(), 2);

        assertFalse(verifier.verifyPoint(Pairing.P1(), invalidSignature, Pairing.P2()));
    }

    function testRejectWrongMessage() public {
        BLS256.G1Point memory wrongMessage = Pairing.scalarMul(Pairing.P1(), 2);

        assertFalse(verifier.verifyPoint(wrongMessage, Pairing.P1(), Pairing.P2()));
    }

    function testVerifyBytes32MessageWithMatchingSignature() public {
        bytes32 message = bytes32(uint256(123));
        BLS256.G1Point memory signature = verifier.hashToG1(message);

        assertTrue(verifier.verify(message, signature, Pairing.P2()));
    }

    function testRejectBytes32MessageWithWrongSignature() public {
        bytes32 message = bytes32(uint256(123));
        BLS256.G1Point memory wrongSignature = Pairing.P1();

        assertFalse(verifier.verify(message, wrongSignature, Pairing.P2()));
    }
}
