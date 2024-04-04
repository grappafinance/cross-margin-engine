// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import "../src/settled-physical/CrossMarginPhysicalEngine.sol";

interface IOptionProtocol {
    function registerAsset(address asset) external returns (uint8);
}

contract RegisterAssets is Script {
    function run() external {
        console.log("Deployer", msg.sender);

        vm.startBroadcast();

        IOptionProtocol protocol = IOptionProtocol(vm.envAddress(""));

        uint8 usdcId = protocol.registerAsset(vm.envAddress("USDC"));
        console.log("USDC: \t\t", vm.envAddress("USDC"));
        console.log("   -> Registered ID:", usdcId);

        uint8 wethId = protocol.registerAsset(vm.envAddress("WETH"));
        console.log("WETH: \t\t", vm.envAddress("WETH"));
        console.log("   -> Registered ID:", wethId);

        uint8 wbtcId = protocol.registerAsset(vm.envAddress("WBTC"));
        console.log("WBTC: \t\t", vm.envAddress("WBTC"));
        console.log("   -> Registered ID:", wbtcId);

        uint8 usycId = protocol.registerAsset(vm.envAddress("USYC"));
        console.log("USYC: \t\t", vm.envAddress("USYC"));
        console.log("   -> Registered ID:", usycId);

        uint8 hnBTCId = protocol.registerAsset(vm.envAddress("hnBTC"));
        console.log("hnBTC: \t\t", vm.envAddress("hnBTC"));
        console.log("   -> Registered ID:", hnBTCId);

        uint8 hnADAId = protocol.registerAsset(vm.envAddress("hnADA"));
        console.log("hnADA: \t\t", vm.envAddress("hnADA"));
        console.log("   -> Registered ID:", hnADAId);

        uint8 hnBTC_Anchorage_TOId = protocol.registerAsset(vm.envAddress("hnBTC_Anchorage_TO"));
        console.log("hnBTC_Anchorage_TO: \t", vm.envAddress("hnBTC_Anchorage_TO"));
        console.log("   -> Registered ID:", hnBTC_Anchorage_TOId);

        // uint8 hnWSTETHId = protocol.registerAsset(vm.envAddress("hnWSTETH"));
        // console.log("hnWSTETH: \t\t", vm.envAddress("hnWSTETH"));
        // console.log("   -> Registered ID:", hnWSTETHId);

        // uint8 hnZRXId = protocol.registerAsset(vm.envAddress("hnZRX"));
        // console.log("hnZRX: \t\t", vm.envAddress("hnZRX"));
        // console.log("   -> Registered ID:", hnZRXId);

        // uint8 hnMATICId = protocol.registerAsset(vm.envAddress("hnMATIC"));
        // console.log("hnMATIC: \t\t", vm.envAddress("hnMATIC"));
        // console.log("   -> Registered ID:", hnMATICId);

        // uint8 maticId = protocol.registerAsset(vm.envAddress("MATIC"));
        // console.log("MATIC: \t\t", vm.envAddress("MATIC"));
        // console.log("   -> Registered ID:", maticId);

        // uint8 hnETHId = protocol.registerAsset(vm.envAddress("hnETH"));
        // console.log("hnETH: \t\t", vm.envAddress("hnETH"));
        // console.log("   -> Registered ID:", hnETHId);

        vm.stopBroadcast();
    }
}
