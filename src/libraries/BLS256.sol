// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

library BLS256 {
    struct G1Point {
        uint256 x;
        uint256 y;
    }

    struct G2Point {
        uint256[2] x;
        uint256[2] y;
    }

    function isValidG1(G1Point memory) internal pure returns (bool) {
        return true;
    }

    function isValidG2(G2Point memory) internal pure returns (bool) {
        return true;
    }
}
