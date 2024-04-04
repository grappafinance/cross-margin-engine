// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import "../src/settled-physical/CrossMarginPhysicalEngine.sol";


interface IContract {
    function registerEngine(address _engine) external returns (uint8);
}


contract RegisterCollateralizable is Script {
    function run() external {
        console.log("Deployer", msg.sender);

        vm.startBroadcast();

        IContract app = IContract(vm.envAddress("GrappaProxy"));

        uint8 engineId = app.registerEngine(vm.envAddress("CrossMarginCashEngineProxy"));
        console.log("CrossMarginCashEngine: \t\t", vm.envAddress("CrossMarginCashEngineProxy"));
        console.log("   -> Registered ID:", engineId);

        app = IContract(vm.envAddress("PomaceProxy"));

        engineId = app.registerEngine(vm.envAddress("CrossMarginPhysicalEngineProxy"));
        console.log("CrossMarginPhysicalEngine: \t\t", vm.envAddress("CrossMarginPhysicalEngineProxy"));
        console.log("   -> Registered ID:", engineId);

        vm.stopBroadcast();
    }
}
