// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import "../src/settled-physical/CrossMarginPhysicalEngine.sol";

contract DeployPhysicalMarginEngine is Script {
    function run() external {
        console.log("Deployer", msg.sender);

        vm.startBroadcast();

        // ============ Deploy Cross Margin Engine (Upgradable) ============== //
        address engineImplementation =
            address(new CrossMarginPhysicalEngine(vm.envAddress("PomaceProxy"), vm.envAddress("PomaceOptionToken"), vm.envAddress("RolesAuthorityProxy")));

        console.log("CrossMargin Physical Engine: \t\t", engineImplementation);

        vm.stopBroadcast();
    }

    function deployCrossMarginPhysicalEngine(address pomace, address optionToken) public {}
}
