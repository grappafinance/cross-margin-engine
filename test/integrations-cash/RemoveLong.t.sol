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

// solhint-disable-next-line contract-name-camelcase
contract TestRemoveLong_CMC is CrossMarginCashFixture {
    uint256 public expiry;

    function setUp() public {
        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(engine), type(uint256).max);

        weth.mint(address(this), 100 * 1e18);
        weth.approve(address(engine), type(uint256).max);

        expiry = block.timestamp + 1 days;

        oracle.setSpotPrice(address(weth), 3000 * UNIT);
    }

    function testRemoveLongToken() public {
        uint256 depositAmount = 1 * 1e18;

        uint256 strikePrice = 4000 * UNIT;
        uint256 amount = 1 * UNIT;

        uint256 tokenId = getTokenId(TokenType.CALL, pidEthCollat, expiry, strikePrice, 0);

        // prepare: mint tokens
        ActionArgs[] memory _actions = new ActionArgs[](2);
        _actions[0] = createAddCollateralAction(wethId, address(this), depositAmount);
        _actions[1] = createMintAction(tokenId, address(this), amount);
        engine.execute(address(this), _actions);

        option.setApprovalForAll(address(engine), true);

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createAddLongAction(tokenId, amount, address(this));
        engine.execute(address(this), actions);

        actions[0] = createRemoveLongAction(tokenId, amount, address(this));
        engine.execute(address(this), actions);

        assertEq(option.balanceOf(address(engine), tokenId), 0);
        assertEq(option.balanceOf(address(this), tokenId), amount);
    }
}
