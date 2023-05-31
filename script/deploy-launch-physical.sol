// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import "openzeppelin/utils/Create2.sol";
import "openzeppelin/utils/Strings.sol";

import "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

import "../src/settled-physical/CrossMarginPhysicalEngine.sol";
import "../src/settled-physical/CrossMarginPhysicalEngineProxy.sol";

import "../test/utils/Utilities.sol";

contract DeployPhysicalMarginEngine is Script, Utilities {
    function run() external {
        vm.startBroadcast();

        address pomace = vm.envAddress("PomaceProxy");
        address optionToken = vm.envAddress("PomaceOptionToken");

        // deploy and register Cross Margin Engine
        deployCrossMarginPhysicalEngine(pomace, optionToken);

        vm.stopBroadcast();
    }

    function deployCrossMarginPhysicalEngine(address pomace, address optionToken) public returns (address crossMarginEngine) {
        // ============ Deploy Cross Margin Engine (Upgradable) ============== //
        address engineImplementation = address(new CrossMarginPhysicalEngine(pomace, optionToken));
        bytes memory engineData =
            abi.encodeWithSelector(CrossMarginPhysicalEngine.initialize.selector, vm.envAddress("CrossMarginOwner"));
        crossMarginEngine = address(new CrossMarginPhysicalEngineProxy(engineImplementation, engineData));

        console.log("CrossMargin Physical Engine: \t\t\t", engineImplementation);
        console.log("CrossMargin Physical Engine Proxy: \t\t", crossMarginEngine);
    }

    // add a function prefixed with test here so forge coverage will ignore this file
    function testChill() public {}
}
