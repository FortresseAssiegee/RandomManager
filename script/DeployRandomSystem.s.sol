// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import "../src/RandomManager.sol";
import "../src/RandomProject.sol";
import "../src/verifier/BN254BLSVerifier.sol";

contract DeployRandomSystem is Script {
    function run() external returns (RandomProject implementation, BN254BLSVerifier verifier, RandomManager manager) {
        vm.startBroadcast();

        implementation = new RandomProject();
        verifier = new BN254BLSVerifier();
        manager = new RandomManager(address(implementation), address(verifier));

        vm.stopBroadcast();

        console2.log("RandomProject implementation:", address(implementation));
        console2.log("BN254BLSVerifier:", address(verifier));
        console2.log("RandomManager:", address(manager));
    }
}
