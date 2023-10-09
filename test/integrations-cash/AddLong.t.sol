// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import {CrossMarginCashFixture} from "./CrossMarginCashFixture.t.sol";

import {TokenType} from "grappa/config/enums.sol";
import "grappa/config/constants.sol";
import "grappa/config/errors.sol";

import "../../src/config/errors.sol";
import "../../src/config/types.sol";

import "../mocks/MockERC20.sol";

import {ActionArgs} from "../../src/settled-cash/types.sol";

// solhint-disable-next-line contract-name-camelcase
contract TestAddLong_CMC is CrossMarginCashFixture {
    uint256 public expiry;

    function setUp() public {
        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(engine), type(uint256).max);

        weth.mint(address(this), 100 * 1e18);
        weth.approve(address(engine), type(uint256).max);

        expiry = block.timestamp + 1 days;

        oracle.setSpotPrice(address(weth), 3000 * UNIT);
    }

    function testAddLongCallToken() public {
        uint256 depositAmount = 1 * 1e18;

        uint256 strikePrice = 4000 * UNIT;
        uint256 amount = 1 * UNIT;

        uint256 tokenId = getTokenId(TokenType.CALL, pidEthCollat, expiry, strikePrice, 0);
        uint256 tokenId2 = getTokenId(TokenType.CALL, pidEthCollat, expiry, 2 * strikePrice, 0);

        // prepare: mint tokens
        ActionArgs[] memory _actions = new ActionArgs[](4);
        _actions[0] = createAddCollateralAction(wethId, address(this), depositAmount);
        _actions[1] = createMintAction(tokenId, address(this), amount);
        _actions[2] = createAddCollateralAction(wethId, address(this), depositAmount);
        _actions[3] = createMintAction(tokenId2, address(this), amount);
        engine.execute(address(this), _actions);

        option.setApprovalForAll(address(engine), true);

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createAddLongAction(tokenId, amount, address(this));
        engine.execute(address(this), actions);

        assertEq(option.balanceOf(address(this), tokenId), 0);
        assertEq(option.balanceOf(address(engine), tokenId), amount);
        assertEq(option.balanceOf(address(this), tokenId2), amount);
        assertEq(option.balanceOf(address(engine), tokenId2), 0);
    }

    function testAddLongPutToken() public {
        uint256 depositAmount = 4000 * 1e6;

        uint256 strikePrice = 4000 * UNIT;
        uint256 amount = 1 * UNIT;

        uint256 tokenId = getTokenId(TokenType.PUT, pidUsdcCollat, expiry, strikePrice, 0);
        uint256 tokenId2 = getTokenId(TokenType.PUT, pidUsdcCollat, expiry, 2 * strikePrice, 0);

        // prepare: mint tokens
        ActionArgs[] memory _actions = new ActionArgs[](4);
        _actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        _actions[1] = createMintAction(tokenId, address(this), amount);
        _actions[2] = createAddCollateralAction(usdcId, address(this), depositAmount * 2);
        _actions[3] = createMintAction(tokenId2, address(this), amount);
        engine.execute(address(this), _actions);

        option.setApprovalForAll(address(engine), true);

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createAddLongAction(tokenId, amount, address(this));
        engine.execute(address(this), actions);

        assertEq(option.balanceOf(address(this), tokenId), 0);
        assertEq(option.balanceOf(address(engine), tokenId), amount);
        assertEq(option.balanceOf(address(this), tokenId2), amount);
        assertEq(option.balanceOf(address(engine), tokenId2), 0);
    }
}
