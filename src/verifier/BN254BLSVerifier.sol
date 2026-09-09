// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IBLSVerifier} from "../interfaces/IBLSVerifier.sol";
import {BLS256} from "../libraries/BLS256.sol";
import {Pairing} from "../libraries/Pairing.sol";

contract BN254BLSVerifier is IBLSVerifier {
    uint256 internal constant GROUP_ORDER =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;

    function verify(bytes32 message, BLS256.G1Point calldata signature, BLS256.G2Point calldata publicKey)
        external
        view
        returns (bool)
    {
        return verifyPoint(hashToG1(message), signature, publicKey);
    }

    function verifyPoint(
        BLS256.G1Point memory messagePoint,
        BLS256.G1Point calldata signature,
        BLS256.G2Point calldata publicKey
    ) public view returns (bool) {
        return Pairing.pairingProd2(Pairing.negate(signature), Pairing.P2(), messagePoint, publicKey);
    }

    function hashToG1(bytes32 message) public view returns (BLS256.G1Point memory) {
        uint256 scalar = uint256(message) % GROUP_ORDER;
        if (scalar == 0) {
            scalar = 1;
        }

        return Pairing.scalarMul(Pairing.P1(), scalar);
    }
}
