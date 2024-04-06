// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import "../src/settled-cash/CrossMarginCashEngine.sol";

contract Deploy is Script {
    function run() external {
        console.log("Deployer", msg.sender);

        vm.startBroadcast();

        address engineImplementation = address(
            new CrossMarginCashEngine(
                vm.envAddress("GrappaProxy"),
                vm.envAddress("GrappaOptionToken"),
                vm.envAddress("CrossMarginCashOracle"),
                vm.envAddress("RolesAuthorityProxy")
            )
        );

        console.log("CrossMargin Cash Engine: \t\t\t", engineImplementation);

        vm.stopBroadcast();
    }
}
