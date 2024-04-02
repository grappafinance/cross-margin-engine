// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import "../src/settled-cash/CrossMarginCashEngine.sol";

contract Deploy is Script {
    function run() external {
        console.log("Deployer", msg.sender);

        vm.startBroadcast();

        address grappa = vm.envAddress("GrappaProxy");
        address optionToken = vm.envAddress("GrappaOptionToken");

        // // deploy and register Cross Margin Engine
        deployCrossMarginEngine(grappa, optionToken);

        vm.stopBroadcast();
    }

    function deployCrossMarginEngine(address grappa, address optionToken) public {
        // ============ Deploy Cross Margin Engine (Upgradable) ============== //
        address engineImplementation = address(
            new CrossMarginCashEngine(
                address(grappa), optionToken, vm.envAddress("CrossMarginCashOracle"), vm.envAddress("RolesAuthorityProxy")
            )
        );

        console.log("CrossMargin Cash Engine: \t\t\t", engineImplementation);
    }
}
