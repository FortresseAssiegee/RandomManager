// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../libraries/BLS256.sol";

interface IRandomManager {
    function implementation() external view returns (address);
    function verifier() external view returns (address);

    function createProject(bytes32 projectId, address owner, bytes32 userSalt, BLS256.G2Point calldata publicKey)
        external
        returns (address proxy);

    function predictProjectAddress(bytes32 projectId, address owner, bytes32 userSalt) external view returns (address);

    function getProjectProxy(bytes32 projectId) external view returns (address);
    function isProjectProxy(address proxy) external view returns (bool);
}
