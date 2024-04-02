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
        implementation = new CrossMarginCashEngine(address(0), address(0), address(0x01), address(0x02));
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

    function testCannotPermitAccountAccessCrossProxy() public {
        uint256 pKey = 0x10101;
        uint8 v;
        bytes32 r;
        bytes32 s;
        bytes32 msgTypeHash =
            keccak256("PermitAccountAccess(address subAccount,address actor,uint256 allowedExecutions,uint256 nonce)");
        // create a new engine proxy with the same implementation
        CrossMarginCashEngine engine2 = CrossMarginCashEngine(
            address(
                new CrossMarginCashEngineProxy(
                    address(implementation), abi.encodeWithSelector(CrossMarginCashEngine.initialize.selector, address(this))
                )
            )
        );

        address account = vm.addr(pKey);
        uint160 maskedId = uint160(account) | 0xFF;

        // sanity check
        assertEq(engine.allowedExecutionLeft(maskedId, address(this)), 0);
        assertEq(engine2.allowedExecutionLeft(maskedId, address(this)), 0);

        (v, r, s) = vm.sign(
            pKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    engine.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(msgTypeHash, account, address(this), type(uint256).max, 0))
                )
            )
        );

        // assert that implementation contract reverts on invalid signature if called directly
        vm.expectRevert(CM_InvalidSignature.selector);
        implementation.permitAccountAccess(account, address(this), type(uint256).max, v, r, s);

        // assert that second proxy contract reverts on invalid signature
        vm.expectRevert(CM_InvalidSignature.selector);
        engine2.permitAccountAccess(account, address(this), type(uint256).max, v, r, s);

        // can permit access for the first proxy
        engine.permitAccountAccess(account, address(this), type(uint256).max, v, r, s);

        assertEq(engine.allowedExecutionLeft(maskedId, address(this)), type(uint256).max);
        assertEq(engine2.allowedExecutionLeft(maskedId, address(this)), 0);

        // check that proxy 1 and 2 domain separators are incompatible
        (v, r, s) = vm.sign(
            pKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    engine2.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(msgTypeHash, account, address(this), type(uint256).max, 1))
                )
            )
        );

        vm.expectRevert(CM_InvalidSignature.selector);
        engine.permitAccountAccess(account, address(this), type(uint256).max, v, r, s);

        // sign message for the second proxy
        (v, r, s) = vm.sign(
            pKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    engine2.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(msgTypeHash, account, address(this), type(uint256).max, 0))
                )
            )
        );

        // can permit access for the second proxy
        engine2.permitAccountAccess(account, address(this), type(uint256).max, v, r, s);
        assertEq(engine2.allowedExecutionLeft(maskedId, address(this)), type(uint256).max);
    }
}
