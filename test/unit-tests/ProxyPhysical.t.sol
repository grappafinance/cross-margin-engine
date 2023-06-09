// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import "forge-std/Test.sol";

import "../../src/settled-physical/CrossMarginPhysicalEngine.sol";
import "../../src/settled-physical/CrossMarginPhysicalEngineProxy.sol";

import {MockEngineV2} from "../mocks/MockEngineV2.sol";

import "../../src/config/errors.sol";
import "pomace/config/enums.sol";
import "pomace/config/constants.sol";

/**
 * @dev test on implementation contract
 */
contract PhysicalEngineProxyTest is Test {
    CrossMarginPhysicalEngine public implementation;
    CrossMarginPhysicalEngine public engine;

    constructor() {
        implementation = new CrossMarginPhysicalEngine(address(0), address(0));
        bytes memory data = abi.encodeWithSelector(CrossMarginPhysicalEngine.initialize.selector, address(this));

        engine = CrossMarginPhysicalEngine(address(new CrossMarginPhysicalEngineProxy(address(implementation), data)));
    }

    function testImplementationContractOwnerIsZero() public {
        assertEq(implementation.owner(), address(0));
    }

    function testImplementationIsInitialized() public {
        vm.expectRevert("Initializable: contract is already initialized");
        implementation.initialize(address(this));
    }

    function testProxyOwnerIsSelf() public {
        assertEq(engine.owner(), address(this));
    }

    function testProxyIsInitialized() public {
        vm.expectRevert("Initializable: contract is already initialized");
        engine.initialize(address(this));
    }

    function testCannotUpgradeFromNonOwner() public {
        vm.prank(address(0xaa));
        vm.expectRevert("Ownable: caller is not the owner");
        engine.upgradeTo(address(0));
    }

    function testCanUpgradeToAnotherUUPSContract() public {
        MockEngineV2 v2 = new MockEngineV2();

        engine.upgradeTo(address(v2));

        assertEq(MockEngineV2(address(engine)).version(), 2);
    }

    function testCannotUpgradeTov3() public {
        MockEngineV2 v2 = new MockEngineV2();
        MockEngineV2 v3 = new MockEngineV2();

        engine.upgradeTo(address(v2));

        vm.expectRevert("not upgrdable anymore");
        engine.upgradeTo(address(v3));
    }
}
