// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import "../src/settled-physical/CrossMarginPhysicalEngine.sol";

interface IContract {
    function setCollateralizable(address _asset0, address _asset1, bool _value) external;
}

contract RegisterCollateralizable is Script {
    function run() external {
        console.log("Deployer", msg.sender);

        vm.startBroadcast();

        IContract app = IContract(vm.envAddress("CrossMarginCashEngineProxy"));
        app.setCollateralizable(vm.envAddress("USDC"), vm.envAddress("USYC"), true);

        app = IContract(vm.envAddress("PomaceProxy"));
        app.setCollateralizable(vm.envAddress("USDC"), vm.envAddress("USYC"), true);

        vm.stopBroadcast();
    }
}
