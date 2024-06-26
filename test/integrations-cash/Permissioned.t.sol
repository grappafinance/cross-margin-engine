// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import {CrossMarginCashFixture, Role} from "./CrossMarginCashFixture.t.sol";

import "grappa/config/types.sol";
import "grappa/config/enums.sol";
import "grappa/config/constants.sol";
import "grappa/config/errors.sol";

import "../../src/config/errors.sol";
import "../../src/config/types.sol";

import "../mocks/MockERC20.sol";

contract Permissioned_CMC is CrossMarginCashFixture {
    uint256 public expiry;
    uint256 public tokenId;
    uint256 public amount;
    uint256 public depositAmount;

    function setUp() public {
        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(engine), type(uint256).max);

        weth.mint(address(this), 100 * 1e18);
        weth.approve(address(engine), type(uint256).max);

        depositAmount = 1 * 1e18;

        uint256 strikePrice = 4000 * UNIT;

        amount = 1 * UNIT;

        expiry = block.timestamp + 14 days;

        tokenId = getTokenId(TokenType.CALL, pidEthCollat, expiry, strikePrice, 0);

        oracle.setSpotPrice(address(weth), 3000 * UNIT);
    }

    function testCannotExecute() public {
        rolesAuthority.setUserRole(address(this), Role.Investor_MFFeederDomestic, false);

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createAddCollateralAction(wethId, address(this), 1000 * UNIT);

        vm.expectRevert(NoAccess.selector);
        engine.execute(address(this), actions);
    }

    function testCanExecute() public {
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createAddCollateralAction(wethId, address(this), 1000 * UNIT);

        engine.execute(address(this), actions);

        (,, Balance[] memory collaterals) = engine.marginAccounts(address(this));
        assertEq(collaterals.length, 1);
    }

    function testCannotSettleOption() public {
        rolesAuthority.setUserRole(alice, Role.Investor_MFFeederDomestic, false);

        _mintOptionToAlice();

        oracle.setExpiryPrice(address(weth), address(usdc), 5000 * UNIT);

        vm.warp(expiry);

        vm.startPrank(alice);
        vm.expectRevert(NoAccess.selector);
        grappa.settleOption(alice, tokenId, amount);
    }

    function testAliceCanSettleOption() public {
        _mintOptionToAlice();

        oracle.setExpiryPrice(address(weth), address(usdc), 5000 * UNIT);

        vm.warp(expiry);

        vm.startPrank(alice);
        grappa.settleOption(alice, tokenId, amount);
        vm.stopPrank();
    }

    function _mintOptionToAlice() public {
        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(wethId, address(this), depositAmount);
        actions[1] = createMintAction(tokenId, alice, amount);
        engine.execute(address(this), actions);
    }
}
