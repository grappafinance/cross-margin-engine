// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

// import test base and helpers.
import {CrossMarginPhysicalFixture, Role} from "../integrations-physical/CrossMarginPhysicalFixture.t.sol";

import {ActionArgs} from "pomace/config/types.sol";
import "pomace/config/errors.sol";

import "../../src/config/errors.sol";
import "../../src/settled-physical/types.sol";

contract CrossMarginPhysicalEngineAccessTest is CrossMarginPhysicalFixture {
    uint256 private depositAmount = 100 * 1e6;

    address private subAccountIdToModify;

    function setUp() public {
        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(engine), type(uint256).max);

        usdc.mint(alice, 1000_000 * 1e6);

        vm.startPrank(alice);
        usdc.approve(address(engine), type(uint256).max);
        vm.stopPrank();

        subAccountIdToModify = address(uint160(alice) ^ uint160(1));

        vm.startPrank(alice);
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createAddCollateralAction(usdcId, alice, depositAmount);
        engine.execute(subAccountIdToModify, actions);
        vm.stopPrank();
    }

    function testTransferCMAccount() public {
        vm.startPrank(alice);
        engine.transferAccount(subAccountIdToModify, address(this));
        vm.stopPrank();

        // can access subaccount!
        _assertCanAccessAccount(address(this), true);

        (,, Balance[] memory collaterals) = engine.marginAccounts(address(this));

        assertEq(collaterals.length, 1);
        assertEq(collaterals[0].collateralId, usdcId);
        assertEq(collaterals[0].amount, depositAmount * 2);
    }

    function testCannotTransferUnAuthorizedAccount() public {
        vm.expectRevert(NoAccess.selector);
        engine.transferAccount(alice, address(this));
    }

    function testCannotTransferToOverrideAnotherAccount() public {
        // write something to account "address(this)"
        _assertCanAccessAccount(address(this), true);

        vm.startPrank(alice);
        vm.expectRevert(CM_AccountIsNotEmpty.selector);
        engine.transferAccount(subAccountIdToModify, address(this));
        vm.stopPrank();
    }

    function testCanAccessAccountIfOriginIsFundAdmin() public {
        rolesAuthority.setUserRole(tx.origin, Role.System_FundAdmin, true);
        _assertCanAccessAccount(alice, true);
    }

    function testCanAccessAccountIfOriginIsSender() public {
        rolesAuthority.setUserRole(address(this), Role.System_FundAdmin, true);
        // add capability for fund admin to run execute
        rolesAuthority.setRoleCapability(Role.System_FundAdmin, address(engine), engine.execute.selector, true);
        // remove the other role to make sure that only System_FundAdmin is present
        rolesAuthority.setUserRole(address(this), Role.Investor_MFFeederDomestic, false);

        // prank for address(this) is necessary to set tx.origin to address(this)
        // by default tx.origin is DefaultSender address which is not the same as address(this)
        vm.startPrank(address(this), address(this));
        _assertCanAccessAccount(alice, true);
        vm.stopPrank();
    }

    function testCannotAccessAccountIfOriginIsSenderNotFA() public {
        // prank for address(this) is necessary to set tx.origin to address(this)
        // by default tx.origin is DefaultSender address which is not the same as address(this)
        vm.startPrank(address(this), address(this));
        _assertCanAccessAccount(alice, false);
        vm.stopPrank();
    }

    function testCannotAccessAccountIfOriginIsNotAdmin() public {
        assertEq(rolesAuthority.doesUserHaveRole(tx.origin, Role.System_FundAdmin), false);
        _assertCanAccessAccount(alice, false);
    }

    function testCannotAccessAccountIfCallerHasNoRole() public {
        rolesAuthority.setUserRole(tx.origin, Role.System_FundAdmin, true);

        _assertCanAccessAccount(alice, true);

        // remove role and perform sanity check that it was removed and no other roles are present
        rolesAuthority.setUserRole(address(this), Role.Investor_MFFeederDomestic, false);

        assertEq(rolesAuthority.doesUserHaveRole(address(this), Role.Investor_MFFeederDomestic), false);
        assertEq(rolesAuthority.getUserRoles(address(this)), bytes32(0));

        // now caller should not be able to access the account
        _assertCanAccessAccount(alice, false);
    }

    function _assertCanAccessAccount(address subAccountId, bool _canAccess) internal {
        // we can update the account now
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);

        if (!_canAccess) vm.expectRevert(NoAccess.selector);

        engine.execute(subAccountId, actions);
    }
}

contract CrossMarginPhysicalEngineSignedAccessTest is CrossMarginPhysicalFixture {
    using stdStorage for StdStorage;

    bytes32 constant ACCOUNT_ACCESS_TYPEHASH =
        keccak256("PermitAccountAccess(address subAccount,address actor,uint256 allowedExecutions,uint256 nonce)");

    address private account;
    uint256 private privateKey = 0xBEEF;

    event AccountAuthorizationUpdate(uint160 maskId, address account, uint256 updatesAllowed);

    constructor() CrossMarginPhysicalFixture() {
        account = vm.addr(privateKey);

        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(engine), type(uint256).max);

        // assert that no access is granted
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createAddCollateralAction(usdcId, address(this), 100 * 1e6);

        vm.expectRevert(NoAccess.selector);
        engine.execute(account, actions);

        // assert that allowedExecutionLeft is 0
        assertEq(engine.allowedExecutionLeft(uint160(account) | 0xFF, address(this)), 0);
    }

    function testCanSetAccess() public {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    engine.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(ACCOUNT_ACCESS_TYPEHASH, account, address(this), type(uint256).max, 0))
                )
            )
        );

        uint160 maskedId = uint160(account) | 0xFF;

        vm.expectEmit(true, true, true, true);
        emit AccountAuthorizationUpdate(maskedId, address(this), type(uint256).max);

        engine.permitAccountAccess(account, address(this), type(uint256).max, v, r, s);

        assertEq(engine.allowedExecutionLeft(maskedId, address(this)), type(uint256).max);

        // we can update the account now
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createAddCollateralAction(usdcId, address(this), 100 * 1e6);

        engine.execute(account, actions);
    }

    function testCanSetAccessToZero() public {
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    engine.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(ACCOUNT_ACCESS_TYPEHASH, account, address(this), type(uint256).max, 0))
                )
            )
        );

        uint160 maskedId = uint160(account) | 0xFF;

        vm.expectEmit(true, true, true, true);
        emit AccountAuthorizationUpdate(maskedId, address(this), type(uint256).max);

        engine.permitAccountAccess(account, address(this), type(uint256).max, v, r, s);

        assertEq(engine.allowedExecutionLeft(maskedId, address(this)), type(uint256).max);

        // we can update the account now
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createAddCollateralAction(usdcId, address(this), 100 * 1e6);

        engine.execute(account, actions);

        (v, r, s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    engine.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(ACCOUNT_ACCESS_TYPEHASH, account, address(this), 0, 1))
                )
            )
        );

        vm.expectEmit(true, true, true, true);
        emit AccountAuthorizationUpdate(maskedId, address(this), 0);

        engine.permitAccountAccess(account, address(this), 0, v, r, s);

        assertEq(engine.allowedExecutionLeft(maskedId, address(this)), 0);
    }

    function testRevertsOnNoSignature() public {
        vm.expectRevert(CM_InvalidSignature.selector);
        engine.permitAccountAccess(account, address(this), type(uint256).max, 0, bytes32(""), bytes32(""));
    }

    function testRevertsOnInvalidPrivateKey() public {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            0xCAFE,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    engine.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(ACCOUNT_ACCESS_TYPEHASH, account, address(this), type(uint256).max, 0))
                )
            )
        );

        vm.expectRevert(CM_InvalidSignature.selector);
        engine.permitAccountAccess(account, address(this), type(uint256).max, v, r, s);
    }

    function testRevertsOnInvalidNonce() public {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    engine.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(ACCOUNT_ACCESS_TYPEHASH, account, address(this), type(uint256).max, 1))
                )
            )
        );

        vm.expectRevert(CM_InvalidSignature.selector);
        engine.permitAccountAccess(account, address(this), type(uint256).max, v, r, s);
    }

    function testRevertsOnInvalidActor() public {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    engine.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(ACCOUNT_ACCESS_TYPEHASH, account, address(this), type(uint256).max, 0))
                )
            )
        );

        vm.expectRevert(CM_InvalidSignature.selector);
        engine.permitAccountAccess(account, alice, type(uint256).max, v, r, s);
    }

    function testRevertsOnInvalidAccount() public {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    engine.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(ACCOUNT_ACCESS_TYPEHASH, alice, address(this), type(uint256).max, 0))
                )
            )
        );

        vm.expectRevert(CM_InvalidSignature.selector);
        engine.permitAccountAccess(alice, address(this), type(uint256).max, v, r, s);
    }

    function testRevertsOnMismatchingAccount() public {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    engine.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(ACCOUNT_ACCESS_TYPEHASH, account, address(this), type(uint256).max, 0))
                )
            )
        );

        vm.expectRevert(CM_InvalidSignature.selector);
        engine.permitAccountAccess(alice, address(this), type(uint256).max, v, r, s);
    }

    function testRevertsOnInvalidExecutionsNum() public {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    engine.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(ACCOUNT_ACCESS_TYPEHASH, account, address(this), 10, 0))
                )
            )
        );

        vm.expectRevert(CM_InvalidSignature.selector);
        engine.permitAccountAccess(account, address(this), type(uint256).max, v, r, s);
    }
}
