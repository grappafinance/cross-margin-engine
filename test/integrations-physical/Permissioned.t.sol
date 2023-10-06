// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import {CrossMarginPhysicalFixture} from "./CrossMarginPhysicalFixture.t.sol";

import "pomace/config/enums.sol";
import "pomace/config/types.sol";
import "pomace/config/constants.sol";
import "pomace/config/errors.sol";

import "pomace-test/mocks/MockERC20.sol";

import "../../src/config/types.sol";

contract Permissioned_CMP is CrossMarginPhysicalFixture {
    uint256 public expiry;
    uint256 public exerciseWindow;
    uint256 public tokenId;
    uint256 public amount;
    uint256 public depositAmount;

    function setUp() public {
        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(engine), type(uint256).max);

        weth.mint(address(this), 100 * 1e18);
        weth.approve(address(engine), type(uint256).max);

        engine.setWhitelist(address(whitelist));

        depositAmount = 1 * 1e18;

        uint256 strikePrice = 4000 * UNIT;

        amount = 1 * UNIT;

        expiry = block.timestamp + 14 days;
        exerciseWindow = 300;

        tokenId = getTokenId(TokenType.CALL, pidEthCollat, expiry, strikePrice, exerciseWindow);
    }

    function testCannotExecute() public {
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createAddCollateralAction(wethId, address(this), 1000 * UNIT);

        vm.expectRevert(NoAccess.selector);
        engine.execute(address(this), actions);
    }

    function testCanExecute() public {
        whitelist.setEngineAccess(address(this), true);

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createAddCollateralAction(wethId, address(this), 1000 * UNIT);

        engine.execute(address(this), actions);

        (,, Balance[] memory collaterals) = engine.marginAccounts(address(this));
        assertEq(collaterals.length, 1);
    }

    function testCannotSettleOption() public {
        whitelist.setEngineAccess(address(this), true);

        _mintOptionToAlice();

        vm.warp(expiry);

        vm.startPrank(alice);
        vm.expectRevert(NoAccess.selector);
        pomace.settleOption(alice, tokenId, amount);
    }

    function testAliceCanSettleOption() public {
        whitelist.setEngineAccess(address(this), true);
        whitelist.setEngineAccess(alice, true);

        vm.prank(alice);
        usdc.approve(address(engine), type(uint256).max);

        _mintOptionToAlice();

        vm.warp(expiry);

        vm.startPrank(alice);
        pomace.settleOption(alice, tokenId, amount);
        vm.stopPrank();
    }

    function _mintOptionToAlice() public {
        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(wethId, address(this), depositAmount);
        actions[1] = createMintAction(tokenId, alice, amount);
        engine.execute(address(this), actions);
    }
}
