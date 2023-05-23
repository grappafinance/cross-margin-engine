// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import "openzeppelin/utils/Create2.sol";
import "openzeppelin/utils/Strings.sol";

import "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

import "grappa/core/Grappa.sol";

import {CrossMarginCashEngine} from "../src/settled-cash/CrossMarginCashEngine.sol";
import {CrossMarginCashEngineProxy} from "../src/settled-cash/CrossMarginCashEngineProxy.sol";

import "../test/utils/Utilities.sol";

contract Deploy is Script, Utilities {
    function run() external {
        vm.startBroadcast();

        // // deploy and register Cross Margin Engine
        // deployCrossMarginEngine(grappa, optionToken);

        // Todo: transfer ownership to Grappa multisig and Hashnote accordingly.
        vm.stopBroadcast();
    }

    function deployCrossMarginEngine(Grappa grappa, address optionToken) public returns (address crossMarginEngine) {
        // ============ Deploy Cross Margin Engine (Upgradable) ============== //
        address engineImplementation = address(new CrossMarginCashEngine(address(grappa), optionToken, address(0)));
        bytes memory engineData = abi.encode(CrossMarginCashEngine.initialize.selector);
        crossMarginEngine = address(new CrossMarginCashEngineProxy(engineImplementation, engineData));

        console.log("CrossMargin Engine: \t\t", crossMarginEngine);

        // ============ Register Full Margin Engine ============== //
        {
            uint256 engineId = grappa.registerEngine(crossMarginEngine);
            console.log("   -> Registered ID:", engineId);
        }
    }
}
