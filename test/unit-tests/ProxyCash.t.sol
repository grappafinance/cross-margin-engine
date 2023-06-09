// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import "forge-std/Test.sol";

import "../../src/settled-cash/CrossMarginCashEngine.sol";
import "../../src/settled-cash/CrossMarginCashEngineProxy.sol";

import {MockEngineV2} from "../mocks/MockEngineV2.sol";

import "grappa/config/enums.sol";
import "grappa/config/constants.sol";
import "grappa/config/errors.sol";

/**
 * @dev test on implementation contract
 */
contract CashEngineProxyTest is Test {
    CrossMarginCashEngine public implementation;
    CrossMarginCashEngine public engine;

    constructor() {
        implementation = new CrossMarginCashEngine(address(0), address(0), address(0x01));
        bytes memory data = abi.encodeWithSelector(CrossMarginCashEngine.initialize.selector, address(this));

        engine = CrossMarginCashEngine(address(new CrossMarginCashEngineProxy(address(implementation), data)));
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
