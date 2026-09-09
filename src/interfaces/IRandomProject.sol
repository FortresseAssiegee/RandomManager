// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../libraries/BLS256.sol";

interface IRandomProject {
    function initialize(
        address manager,
        address owner,
        bytes32 projectId,
        address verifier,
        BLS256.G2Point calldata publicKey
    ) external;

    function requestRandomness(bytes32 userSeed) external returns (uint256 requestId);

    function fulfillRandomness(uint256 requestId, BLS256.G1Point calldata signature) external;

    function getRequestMessage(uint256 requestId) external view returns (bytes32);
    function getRandomness(uint256 requestId) external view returns (uint256);
    function consumeRandomness(uint256 requestId) external returns (uint256);

    function getRequest(uint256 requestId)
        external
        view
        returns (address requester, bytes32 userSeed, uint256 blockNumber, uint256 randomness, uint8 status);
}
