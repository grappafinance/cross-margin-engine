// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import "openzeppelin/utils/Create2.sol";
import "openzeppelin/utils/Strings.sol";

import "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

import "pomace/core/OptionToken.sol";
import "pomace/core/OptionTokenDescriptor.sol";
import "pomace/core/Pomace.sol";
import "pomace/core/PomaceProxy.sol";
import "../src/CrossMarginPhysicalEngine.sol";
import "../src/CrossMarginPhysicalEngineProxy.sol";

import "../test/utils/Utilities.sol";

contract Deploy is Script, Utilities {
    function run() external {
        vm.startBroadcast();

        // deploy and register Cross Margin Engine
        // deployCrossMarginEngine(pomace, optionToken);

        // Todo: transfer ownership to Pomace multisig and Hashnote accordingly.
        vm.stopBroadcast();
    }

    function deployCrossMarginEngine(Pomace pomace, address optionToken) public returns (address crossMarginEngine) {
        // ============ Deploy Cross Margin Engine (Upgradable) ============== //
        address engineImplementation = address(new CrossMarginPhysicalEngine(address(pomace), optionToken));
        bytes memory engineData = abi.encode(CrossMarginPhysicalEngine.initialize.selector);
        crossMarginEngine = address(new CrossMarginPhysicalEngineProxy(engineImplementation, engineData));

        console.log("CrossMargin Engine: \t\t", crossMarginEngine);

        // ============ Register Full Margin Engine ============== //
        {
            uint256 engineId = pomace.registerEngine(crossMarginEngine);
            console.log("   -> Registered ID:", engineId);
        }
    }

    // add a function prefixed with test here so forge coverage will ignore this file
    function testChill() public {}
}
