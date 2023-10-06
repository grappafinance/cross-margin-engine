// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import "openzeppelin/utils/Create2.sol";
import "openzeppelin/utils/Strings.sol";

import "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

import "../src/settled-cash/CrossMarginCashEngine.sol";
import "../src/settled-cash/CrossMarginCashEngineProxy.sol";

import {Utilities} from "../test/utils/Utilities.sol";

contract Deploy is Script, Utilities {
    function run() external {
        console.log("Deployer", msg.sender);

        vm.startBroadcast();

        address grappa = vm.envAddress("GrappaProxy");
        address optionToken = vm.envAddress("GrappaOptionToken");

        // // deploy and register Cross Margin Engine
        deployCrossMarginEngine(grappa, optionToken);

        vm.stopBroadcast();
    }

    function deployCrossMarginEngine(address grappa, address optionToken) public returns (address crossMarginEngine) {
        // ============ Deploy Cross Margin Engine (Upgradable) ============== //
        address engineImplementation =
            address(new CrossMarginCashEngine(address(grappa), optionToken, vm.envAddress("CrossMarginCashOracle")));
        bytes memory engineData =
            abi.encodeWithSelector(CrossMarginCashEngine.initialize.selector, vm.envAddress("CrossMarginOwner"));
        crossMarginEngine = address(new CrossMarginCashEngineProxy(engineImplementation, engineData));

        console.log("CrossMargin Cash Engine: \t\t\t", engineImplementation);
        console.log("CrossMargin Cash Engine Proxy: \t\t", crossMarginEngine);
    }

    // add a function prefixed with test here so forge coverage will ignore this file
    function testChill() public {}
}
