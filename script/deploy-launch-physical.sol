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
import "../src/settled-physical/CrossMarginPhysicalEngine.sol";
import "../src/settled-physical/CrossMarginPhysicalEngineProxy.sol";

import "../test/utils/Utilities.sol";

contract DeployPhysicalMarginEngine is Script, Utilities {
    function run() external {
        vm.startBroadcast();

        Pomace pomace = Pomace(vm.envAddress("PomaceProxy"));
        address optionToken = vm.envAddress("PomaceOptionToken");

        // deploy and register Cross Margin Engine
        deployCrossMarginPhysicalEngine(pomace, optionToken);

        // Todo: transfer ownership to Pomace multisig and Hashnote accordingly.
        vm.stopBroadcast();
    }

    function deployCrossMarginPhysicalEngine(Pomace pomace, address optionToken) public returns (address crossMarginEngine) {
        uint256 nonce = vm.getNonce(msg.sender);
        console.log("nonce", nonce);
        console.log("Deployer", msg.sender);

        // ============ Deploy Cross Margin Engine (Upgradable) ============== //
        address engineImplementation = address(new CrossMarginPhysicalEngine(address(pomace), optionToken));
        bytes memory engineData = abi.encode(CrossMarginPhysicalEngine.initialize.selector);
        crossMarginEngine = address(new CrossMarginPhysicalEngineProxy(engineImplementation, engineData));

        console.log("CrossMargin Physical Engine: \t\t\t", engineImplementation);
        console.log("CrossMargin Physical Engine Proxy: \t\t", crossMarginEngine);
    }

    // add a function prefixed with test here so forge coverage will ignore this file
    function testChill() public {}
}
