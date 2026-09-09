// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../libraries/BLS256.sol";

interface IBLSVerifier {
    function verify(bytes32 message, BLS256.G1Point calldata signature, BLS256.G2Point calldata publicKey)
        external
        view
        returns (bool);

    function verifyPoint(
        BLS256.G1Point calldata messagePoint,
        BLS256.G1Point calldata signature,
        BLS256.G2Point calldata publicKey
    ) external view returns (bool);
}
