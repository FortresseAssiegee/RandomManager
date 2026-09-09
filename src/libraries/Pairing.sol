// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {BLS256} from "./BLS256.sol";

library Pairing {
    uint256 internal constant FIELD_MODULUS =
        21888242871839275222246405745257275088696311157297823662689037894645226208583;

    function P1() internal pure returns (BLS256.G1Point memory) {
        return BLS256.G1Point(1, 2);
    }

    function P2() internal pure returns (BLS256.G2Point memory) {
        return BLS256.G2Point(
            [
                uint256(11559732032986387107991004021392285783925812861821192530917403151452391805634),
                uint256(10857046999023057135944570762232829481370756359578518086990519993285655852781)
            ],
            [
                uint256(4082367875863433681332203403145435568316851327593401208105741076214120093531),
                uint256(8495653923123431417604973247489272438418190587263600148770280649306958101930)
            ]
        );
    }

    function negate(BLS256.G1Point memory p) internal pure returns (BLS256.G1Point memory) {
        if (p.x == 0 && p.y == 0) {
            return BLS256.G1Point(0, 0);
        }

        return BLS256.G1Point(p.x, FIELD_MODULUS - (p.y % FIELD_MODULUS));
    }

    function addition(BLS256.G1Point memory p1, BLS256.G1Point memory p2)
        internal
        view
        returns (BLS256.G1Point memory r)
    {
        uint256[4] memory input;
        input[0] = p1.x;
        input[1] = p1.y;
        input[2] = p2.x;
        input[3] = p2.y;

        bool success;
        assembly {
            success := staticcall(gas(), 6, input, 0x80, r, 0x40)
        }
        require(success, "pairing-add-failed");
    }

    function scalarMul(BLS256.G1Point memory p, uint256 s) internal view returns (BLS256.G1Point memory r) {
        uint256[3] memory input;
        input[0] = p.x;
        input[1] = p.y;
        input[2] = s;

        bool success;
        assembly {
            success := staticcall(gas(), 7, input, 0x60, r, 0x40)
        }
        require(success, "pairing-mul-failed");
    }

    function pairing(BLS256.G1Point[] memory p1, BLS256.G2Point[] memory p2) internal view returns (bool) {
        require(p1.length == p2.length, "pairing-length-mismatch");

        uint256 elements = p1.length;
        uint256 inputSize = elements * 6;
        uint256[] memory input = new uint256[](inputSize);

        for (uint256 i = 0; i < elements; i++) {
            uint256 j = i * 6;
            input[j] = p1[i].x;
            input[j + 1] = p1[i].y;
            input[j + 2] = p2[i].x[0];
            input[j + 3] = p2[i].x[1];
            input[j + 4] = p2[i].y[0];
            input[j + 5] = p2[i].y[1];
        }

        uint256[1] memory out;
        bool success;

        assembly {
            success := staticcall(gas(), 8, add(input, 0x20), mul(inputSize, 0x20), out, 0x20)
        }

        require(success, "pairing-opcode-failed");
        return out[0] != 0;
    }

    function pairingProd2(
        BLS256.G1Point memory a1,
        BLS256.G2Point memory a2,
        BLS256.G1Point memory b1,
        BLS256.G2Point memory b2
    ) internal view returns (bool) {
        BLS256.G1Point[] memory p1 = new BLS256.G1Point[](2);
        BLS256.G2Point[] memory p2 = new BLS256.G2Point[](2);

        p1[0] = a1;
        p1[1] = b1;

        p2[0] = a2;
        p2[1] = b2;

        return pairing(p1, p2);
    }
}
