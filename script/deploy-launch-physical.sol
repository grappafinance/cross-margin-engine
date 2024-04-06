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
        console.log("Deployer", msg.sender);

        vm.startBroadcast();

        address pomace = vm.envAddress("PomaceProxy");
        address optionToken = vm.envAddress("PomaceOptionToken");
        address authority = vm.envAddress("RolesAuthorityProxy");

        address engineImplementation = address(new CrossMarginPhysicalEngine(pomace, optionToken, authority));
        bytes memory engineData =
            abi.encodeWithSelector(CrossMarginPhysicalEngine.initialize.selector, vm.envAddress("CrossMarginOwner"));
        console.logBytes(engineData);
        address engine = address(new CrossMarginPhysicalEngineProxy(engineImplementation, engineData));

        console.log("CrossMargin Physical Engine: \t\t", engineImplementation);
        console.log("CrossMargin Physical Engine Proxy: \t", engine);

        vm.stopBroadcast();
    }
}
