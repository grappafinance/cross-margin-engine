// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import {CrossMarginPhysicalFixture} from "./CrossMarginPhysicalFixture.t.sol";

import "pomace/config/enums.sol";
import "pomace/config/types.sol";
import "pomace/config/constants.sol";
import "pomace/config/errors.sol";

import "../../src/config/types.sol";

import "pomace/test/mocks/MockERC20.sol";

// solhint-disable-next-line contract-name-camelcase
contract TestMint_CMP is CrossMarginPhysicalFixture {
    uint256 public expiry;
    uint256 public exerciseWindow;

    function setUp() public {
        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(engine), type(uint256).max);

        weth.mint(address(this), 100 * 1e18);
        weth.approve(address(engine), type(uint256).max);

        expiry = block.timestamp + 14 days;
        exerciseWindow = 300;
    }

    function testMintCall() public {
        uint256 depositAmount = 1 * 1e18;

        uint256 strikePrice = 4000 * UNIT;
        uint256 amount = 1 * UNIT;

        uint256 tokenId = getTokenId(TokenType.CALL, pidEthCollat, expiry, strikePrice, exerciseWindow);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(wethId, address(this), depositAmount);
        actions[1] = createMintAction(tokenId, address(this), amount);
        engine.execute(address(this), actions);

        (Position[] memory shorts,,) = engine.marginAccounts(address(this));

        assertEq(shorts.length, 1);
        assertEq(shorts[0].tokenId, tokenId);
        assertEq(shorts[0].amount, amount);

        assertEq(option.balanceOf(address(this), tokenId), amount);
    }

    function testMintPut() public {
        uint256 depositAmount = 2000 * 1e6;

        uint256 strikePrice = 2000 * UNIT;
        uint256 amount = 1 * UNIT;

        uint256 tokenId = getTokenId(TokenType.PUT, pidUsdcCollat, expiry, strikePrice, exerciseWindow);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        actions[1] = createMintAction(tokenId, address(this), amount);
        engine.execute(address(this), actions);

        (Position[] memory shorts,,) = engine.marginAccounts(address(this));

        assertEq(shorts.length, 1);
        assertEq(shorts[0].tokenId, tokenId);
        assertEq(shorts[0].amount, amount);

        assertEq(option.balanceOf(address(this), tokenId), amount);
    }

    function testMintCallAndPutInSameAccount() public {
        uint256 callDepositAmount = 1 * 1e18;

        uint256 callStrikePrice = 4000 * UNIT;
        uint256 callAmount = 1 * UNIT;

        uint256 callTokenId = getTokenId(TokenType.CALL, pidEthCollat, expiry, callStrikePrice, exerciseWindow);

        ActionArgs[] memory actions = new ActionArgs[](4);
        actions[0] = createAddCollateralAction(wethId, address(this), callDepositAmount);
        actions[1] = createMintAction(callTokenId, address(this), callAmount);

        uint256 putDepositAmount = 2000 * 1e6;

        uint256 putStrikePrice = 2000 * UNIT;
        uint256 putAmount = 1 * UNIT;

        uint256 putTokenId = getTokenId(TokenType.PUT, pidUsdcCollat, expiry, putStrikePrice, exerciseWindow);

        actions[2] = createAddCollateralAction(usdcId, address(this), putDepositAmount);
        actions[3] = createMintAction(putTokenId, address(this), putAmount);

        engine.execute(address(this), actions);

        (Position[] memory shorts,, Balance[] memory collaterals) = engine.marginAccounts(address(this));

        assertEq(shorts.length, 2);
        assertEq(shorts[0].tokenId, callTokenId);
        assertEq(shorts[1].tokenId, putTokenId);
        assertEq(shorts[0].amount, callAmount);
        assertEq(shorts[1].amount, putAmount);

        assertEq(collaterals.length, 2);
        assertEq(collaterals[0].collateralId, wethId);
        assertEq(collaterals[1].collateralId, usdcId);
        assertEq(collaterals[0].amount, callDepositAmount);
        assertEq(collaterals[1].amount, putDepositAmount);

        assertEq(option.balanceOf(address(this), callTokenId), callAmount);
        assertEq(option.balanceOf(address(this), putTokenId), putAmount);
    }

    function testCannotMintExpiredOption() public {
        uint256 strikePrice = 2000 * UNIT;
        uint256 amount = 1 * UNIT;

        uint256 tokenId = getTokenId(TokenType.PUT, pidUsdcCollat, block.timestamp, strikePrice, exerciseWindow);

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createMintAction(tokenId, address(this), amount);

        vm.expectRevert(PM_InvalidExpiry.selector);
        engine.execute(address(this), actions);
    }

    function testCannotMintCallWithLittleCollateral() public {
        uint256 depositAmount = 100 * 1e6;

        uint256 strikePrice = 4000 * UNIT;
        uint256 amount = 1 * UNIT;

        uint256 tokenId = getTokenId(TokenType.CALL, pidEthCollat, expiry, strikePrice, exerciseWindow);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        actions[1] = createMintAction(tokenId, address(this), amount);

        vm.expectRevert(BM_AccountUnderwater.selector);
        engine.execute(address(this), actions);
    }

    function testCannotMintPutWithLittleCollateral() public {
        uint256 depositAmount = 100 * 1e6;

        uint256 strikePrice = 2000 * UNIT;
        uint256 amount = 1 * UNIT;

        uint256 tokenId = getTokenId(TokenType.PUT, pidUsdcCollat, expiry, strikePrice, exerciseWindow);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        actions[1] = createMintAction(tokenId, address(this), amount);

        vm.expectRevert(BM_AccountUnderwater.selector);
        engine.execute(address(this), actions);
    }

    function testCannotMintWithoutCollateral() public {
        uint256 strikePrice = 3000 * UNIT;
        uint256 amount = 1 * UNIT;

        uint256 tokenId = getTokenId(TokenType.CALL, pidEthCollat, expiry, strikePrice, exerciseWindow);

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createMintAction(tokenId, address(this), amount);

        vm.expectRevert(BM_AccountUnderwater.selector);
        engine.execute(address(this), actions);
    }
}
