// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../interfaces/IBLSVerifier.sol";
import "../libraries/BLS256.sol";

// 假验证器
contract MockBLSVerifier is IBLSVerifier {
    bool public result = true;

    function setResult(bool result_) external {
        result = result_;
    }

    function verify(bytes32, BLS256.G1Point calldata, BLS256.G2Point calldata) external view returns (bool) {
        return result;
    }

    function verifyPoint(BLS256.G1Point calldata, BLS256.G1Point calldata, BLS256.G2Point calldata)
        external
        view
        returns (bool)
    {
        return result;
    }
}
