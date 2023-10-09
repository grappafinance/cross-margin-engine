// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import {CrossMarginCashFixture} from "./CrossMarginCashFixture.t.sol";

import "grappa/config/types.sol";
import "grappa/config/enums.sol";
import "grappa/config/constants.sol";
import "grappa/config/errors.sol";

import "../../src/config/errors.sol";
import "../../src/config/types.sol";

import "../mocks/MockERC20.sol";

import {ActionArgs} from "../../src/settled-cash/types.sol";

// solhint-disable-next-line contract-name-camelcase
contract TestMintIntoAccount_CMC is CrossMarginCashFixture {
    uint256 public expiry;

    function setUp() public {
        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(engine), type(uint256).max);

        weth.mint(address(this), 100 * 1e18);
        weth.approve(address(engine), type(uint256).max);

        expiry = block.timestamp + 14 days;

        oracle.setSpotPrice(address(weth), 3000 * UNIT);
    }

    function testMintIntoAccountCall() public {
        uint256 depositAmount = 1 * 1e18;

        uint256 strikePrice = 4000 * UNIT;
        uint256 amount = 1 * UNIT;

        uint256 tokenId = getTokenId(TokenType.CALL, pidEthCollat, expiry, strikePrice, 0);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(wethId, address(this), depositAmount);
        actions[1] = createMintIntoAccountAction(tokenId, address(this), amount);
        engine.execute(address(this), actions);

        (Position[] memory shorts, Position[] memory longs,) = engine.marginAccounts(address(this));

        assertEq(shorts.length, 1);
        assertEq(shorts[0].tokenId, tokenId);
        assertEq(shorts[0].amount, amount);

        assertEq(longs.length, 1);
        assertEq(longs[0].tokenId, tokenId);
        assertEq(longs[0].amount, amount);

        assertEq(option.balanceOf(address(this), tokenId), 0);
        assertEq(option.balanceOf(address(engine), tokenId), amount);
    }
}
