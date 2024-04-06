// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import "openzeppelin/utils/Create2.sol";
import "openzeppelin/utils/Strings.sol";

import "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

import "../src/settled-cash/CrossMarginCashEngine.sol";
import "../src/settled-cash/CrossMarginCashEngineProxy.sol";

import "../test/utils/Utilities.sol";

contract Deploy is Script, Utilities {
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

        bytes memory engineData =
            abi.encodeWithSelector(CrossMarginCashEngine.initialize.selector, vm.envAddress("CrossMarginOwner"));
        address engine = address(new CrossMarginCashEngineProxy(engineImplementation, engineData));

        console.log("CrossMargin Cash Engine: \t\t\t", engineImplementation);
        console.log("CrossMargin Cash Engine Proxy: \t\t", engine);

        vm.stopBroadcast();
    }
}
