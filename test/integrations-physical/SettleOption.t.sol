// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import {CrossMarginPhysicalFixture} from "./CrossMarginPhysicalFixture.t.sol";
import "../mocks/MockERC20.sol";

import "pomace/config/enums.sol";
import "pomace/config/types.sol";
import "pomace/config/constants.sol";
import "pomace/config/errors.sol";

import "../../src/config/errors.sol";
import "../../src/config/types.sol";

// solhint-disable-next-line contract-name-camelcase
contract TestSettleOption_CMP is CrossMarginPhysicalFixture {
    uint256 public expiry;
    uint256 public exerciseWindow;

    uint64 private amount = uint64(1 * UNIT);
    uint256 private tokenId;
    uint64 private strike;
    uint256 private depositAmount = 1 ether;

    function setUp() public {
        weth.mint(address(this), 1000 * 1e18);
        weth.approve(address(engine), type(uint256).max);

        expiry = block.timestamp + 14 days;
        exerciseWindow = 300;

        strike = uint64(4000 * UNIT);
    }

    function testGetsNothingFromOptionPastExerciseWindow() public {
        tokenId = getTokenId(TokenType.CALL, pidEthCollat, expiry, strike, exerciseWindow);

        vm.warp(expiry + 299);

        (, uint8 debtId, uint256 debt, uint8 payoutId, uint256 payout) = pomace.getDebtAndPayout(tokenId, uint64(UNIT));

        assertEq(debtId, usdcId);
        assertEq(debt, uint256(strike));
        assertEq(payoutId, wethId);
        assertEq(payout, depositAmount);

        vm.warp(expiry + 301);

        (,, debt,, payout) = pomace.getDebtAndPayout(tokenId, uint64(UNIT));

        assertEq(debt, 0);
        assertEq(payout, 0);
    }
}

// solhint-disable-next-line contract-name-camelcase
contract TestSettleCoveredCall_CMP is CrossMarginPhysicalFixture {
    uint256 public expiry;
    uint256 public exerciseWindow;

    uint64 private amount = uint64(1 * UNIT);
    uint256 private tokenId;
    uint64 private strike;
    uint256 private depositAmount = 1 ether;

    function setUp() public {
        weth.mint(address(this), 1000 * 1e18);
        weth.approve(address(engine), type(uint256).max);

        expiry = block.timestamp + 14 days;
        exerciseWindow = 300;

        strike = uint64(4000 * UNIT);

        tokenId = getTokenId(TokenType.CALL, pidEthCollat, expiry, strike, exerciseWindow);
        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(wethId, address(this), depositAmount);
        // give option to alice
        actions[1] = createMintAction(tokenId, alice, amount);

        // mint option
        engine.execute(address(this), actions);

        // expire option
        vm.warp(expiry);
    }

    function testShouldGetCallPayoutAndDeductedDebt() public {
        vm.startPrank(alice);
        usdc.mint(alice, 1000_000 * 1e6);
        usdc.approve(address(engine), type(uint256).max);
        vm.stopPrank();

        uint256 wethBefore = weth.balanceOf(alice);
        uint256 usdcBefore = usdc.balanceOf(alice);
        uint256 optionBefore = option.balanceOf(alice, tokenId);

        vm.startPrank(alice);
        (Balance memory debt, Balance memory payout) = pomace.settleOption(alice, tokenId, amount);
        vm.stopPrank();

        uint256 expectedDebt = uint256(strike);
        uint256 expectedPayout = uint256(amount) * 1e18 / UNIT;

        assertEq(debt.collateralId, usdcId);
        assertEq(debt.amount, expectedDebt);
        assertEq(payout.collateralId, wethId);
        assertEq(payout.amount, expectedPayout);

        uint256 wethAfter = weth.balanceOf(alice);
        uint256 usdcAfter = usdc.balanceOf(alice);
        uint256 optionAfter = option.balanceOf(alice, tokenId);

        assertEq(wethAfter, wethBefore + expectedPayout);
        assertEq(usdcBefore, usdcAfter + expectedDebt);
        assertEq(optionBefore, optionAfter + amount);
    }

    function testShouldGetCallPayoutAndDeductedDebtFromSender() public {
        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(engine), type(uint256).max);

        uint256 wethBefore = weth.balanceOf(alice);
        uint256 usdcBefore = usdc.balanceOf(address(this));
        uint256 optionBefore = option.balanceOf(alice, tokenId);

        vm.startPrank(alice);
        engine.setAccountAccess(address(this), type(uint256).max);
        vm.stopPrank();

        (Balance memory debt, Balance memory payout) = pomace.settleOption(alice, tokenId, amount);

        uint256 expectedDebt = uint256(strike);
        uint256 expectedPayout = uint256(amount) * 1e18 / UNIT;

        assertEq(debt.collateralId, usdcId);
        assertEq(debt.amount, expectedDebt);
        assertEq(payout.collateralId, wethId);
        assertEq(payout.amount, expectedPayout);

        uint256 wethAfter = weth.balanceOf(alice);
        uint256 usdcAfter = usdc.balanceOf(address(this));
        uint256 optionAfter = option.balanceOf(alice, tokenId);

        assertEq(wethAfter, wethBefore + expectedPayout);
        assertEq(usdcBefore, usdcAfter + expectedDebt);
        assertEq(optionBefore, optionAfter + amount);
    }
}

// solhint-disable-next-line contract-name-camelcase
contract TestSettleCollateralizedPut_CMP is CrossMarginPhysicalFixture {
    uint256 public expiry;
    uint256 public exerciseWindow;

    uint64 private amount = uint64(1 * UNIT);
    uint256 private tokenId;
    uint64 private strike;
    uint256 private depositAmount = 2000 * 1e6;

    function setUp() public {
        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(engine), type(uint256).max);

        expiry = block.timestamp + 14 days;
        exerciseWindow = 300;

        strike = uint64(2000 * UNIT);

        tokenId = getTokenId(TokenType.PUT, pidUsdcCollat, expiry, strike, exerciseWindow);
        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        // give option to alice
        actions[1] = createMintAction(tokenId, alice, amount);

        // mint option
        engine.execute(address(this), actions);

        // expire option
        vm.warp(expiry);
    }

    function testShouldGetPutPayoutAndDeductedDebt() public {
        vm.startPrank(alice);
        weth.mint(alice, 1000 * 1e18);
        weth.approve(address(engine), type(uint256).max);
        vm.stopPrank();

        uint256 wethBefore = weth.balanceOf(alice);
        uint256 usdcBefore = usdc.balanceOf(alice);
        uint256 optionBefore = option.balanceOf(alice, tokenId);

        vm.startPrank(alice);
        (Balance memory debt, Balance memory payout) = pomace.settleOption(alice, tokenId, amount);
        vm.stopPrank();

        uint256 expectedDebt = uint256(amount) * 1e18 / UNIT;
        uint256 expectedPayout = uint256(strike);

        assertEq(debt.collateralId, wethId);
        assertEq(debt.amount, expectedDebt);
        assertEq(payout.collateralId, usdcId);
        assertEq(payout.amount, expectedPayout);

        uint256 wethAfter = weth.balanceOf(alice);
        uint256 usdcAfter = usdc.balanceOf(alice);
        uint256 optionAfter = option.balanceOf(alice, tokenId);

        assertEq(wethBefore, wethAfter + expectedDebt);
        assertEq(usdcAfter, usdcBefore + expectedPayout);
        assertEq(optionBefore, optionAfter + amount);
    }

    function testShouldGetPutPayoutAndDeductedDebtFromSender() public {
        weth.mint(address(this), 1000 * 1e18);
        weth.approve(address(engine), type(uint256).max);

        uint256 wethBefore = weth.balanceOf(address(this));
        uint256 usdcBefore = usdc.balanceOf(alice);
        uint256 optionBefore = option.balanceOf(alice, tokenId);

        vm.startPrank(alice);
        engine.setAccountAccess(address(this), type(uint256).max);
        vm.stopPrank();

        (Balance memory debt, Balance memory payout) = pomace.settleOption(alice, tokenId, amount);

        uint256 expectedDebt = uint256(amount) * 1e18 / UNIT;
        uint256 expectedPayout = uint256(strike);

        assertEq(debt.collateralId, wethId);
        assertEq(debt.amount, expectedDebt);
        assertEq(payout.collateralId, usdcId);
        assertEq(payout.amount, expectedPayout);

        uint256 wethAfter = weth.balanceOf(address(this));
        uint256 usdcAfter = usdc.balanceOf(alice);
        uint256 optionAfter = option.balanceOf(alice, tokenId);

        assertEq(wethBefore, wethAfter + expectedDebt);
        assertEq(usdcAfter, usdcBefore + expectedPayout);
        assertEq(optionBefore, optionAfter + amount);
    }
}

// solhint-disable-next-line contract-name-camelcase
contract TestSettleShortPositions_CMP is CrossMarginPhysicalFixture {
    uint256 public expiry;
    uint256 public exerciseWindow;

    uint64 private amount = uint64(1 * UNIT);
    uint64 private strike;
    uint256 private wethDepositAmount = 1 ether;
    uint256 private usdcDepositAmount = 4000 * 1e6;

    function setUp() public {
        weth.mint(address(this), 1000 * 1e18);
        weth.approve(address(engine), type(uint256).max);

        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(engine), type(uint256).max);

        expiry = block.timestamp + 14 days;
        exerciseWindow = 300;

        strike = uint64(4000 * UNIT);
    }

    function testSellerCannotClearCallDebtAfterExpiryBeforeWindowClosed() public {
        uint256 tokenId = getTokenId(TokenType.CALL, pidEthCollat, expiry, strike, exerciseWindow);

        _mintTokens(tokenId, wethId, wethDepositAmount);

        (Position[] memory shortsBefore,, Balance[] memory collateralsBefore) = engine.marginAccounts(address(this));

        // settle margin account
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSettleAction();
        engine.execute(address(this), actions);

        //margin account should not be reset
        (Position[] memory shortsAfter,, Balance[] memory collateralsAfter) = engine.marginAccounts(address(this));

        assertEq(shortsBefore.length, shortsAfter.length);
        assertEq(collateralsBefore.length, collateralsAfter.length);
    }

    function testSellerCanClearCallDebtAfterWindowClosed() public {
        uint256 tokenId = getTokenId(TokenType.CALL, pidEthCollat, expiry, strike, exerciseWindow);

        _mintTokens(tokenId, wethId, wethDepositAmount);

        vm.warp(expiry + exerciseWindow + 1);

        (,, Balance[] memory collateralsBefore) = engine.marginAccounts(address(this));

        // settle margin account
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSettleAction();
        engine.execute(address(this), actions);

        //margin account should be reset
        (Position[] memory shorts,, Balance[] memory collateralsAfter) = engine.marginAccounts(address(this));

        assertEq(shorts.length, 0);
        assertEq(collateralsAfter[0].collateralId, collateralsBefore[0].collateralId);
        assertEq(collateralsAfter[0].amount, collateralsBefore[0].amount);
    }

    function testSellerCanClearPartialCallDebtAfterWindowClosed() public {
        uint256 tokenId = getTokenId(TokenType.CALL, pidEthCollat, expiry, strike, exerciseWindow);

        _mintTokens(tokenId, wethId, wethDepositAmount);

        vm.warp(expiry);

        vm.startPrank(alice);
        usdc.mint(alice, 1000_000 * 1e6);
        usdc.approve(address(engine), type(uint256).max);

        pomace.settleOption(alice, tokenId, amount / 2);
        vm.stopPrank();

        vm.warp(expiry + exerciseWindow + 1);

        (,, Balance[] memory collateralsBefore) = engine.marginAccounts(address(this));

        // settle margin account
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSettleAction();
        engine.execute(address(this), actions);

        //margin account should be reset
        (Position[] memory shorts,, Balance[] memory collateralsAfter) = engine.marginAccounts(address(this));

        assertEq(shorts.length, 0);
        assertEq(collateralsAfter[0].collateralId, collateralsBefore[0].collateralId);
        assertEq(collateralsAfter[0].amount, collateralsBefore[0].amount / 2);
    }

    function testSellerCannotClearPutDebtAfterExpiryBeforeWindowClosed() public {
        uint256 tokenId = getTokenId(TokenType.PUT, pidUsdcCollat, expiry, strike, exerciseWindow);

        _mintTokens(tokenId, usdcId, usdcDepositAmount);

        (Position[] memory shortsBefore,, Balance[] memory collateralsBefore) = engine.marginAccounts(address(this));

        // settle margin account
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSettleAction();
        engine.execute(address(this), actions);

        //margin account should not be reset
        (Position[] memory shortsAfter,, Balance[] memory collateralsAfter) = engine.marginAccounts(address(this));

        assertEq(shortsBefore.length, shortsAfter.length);
        assertEq(collateralsBefore.length, collateralsAfter.length);
    }

    function testSellerCanClearPutDebtAfterWindowClosed() public {
        uint256 tokenId = getTokenId(TokenType.PUT, pidUsdcCollat, expiry, strike, exerciseWindow);

        _mintTokens(tokenId, usdcId, usdcDepositAmount);

        vm.warp(expiry + exerciseWindow + 1);

        (,, Balance[] memory collateralsBefore) = engine.marginAccounts(address(this));

        // settle margin account
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSettleAction();
        engine.execute(address(this), actions);

        //margin account should be reset
        (Position[] memory shorts,, Balance[] memory collateralsAfter) = engine.marginAccounts(address(this));

        assertEq(shorts.length, 0);
        assertEq(collateralsAfter[0].collateralId, collateralsBefore[0].collateralId);
        assertEq(collateralsAfter[0].amount, collateralsBefore[0].amount);
    }

    function testSellerCanClearPartialPutDebtAfterWindowClosed() public {
        uint256 tokenId = getTokenId(TokenType.PUT, pidUsdcCollat, expiry, strike, exerciseWindow);

        _mintTokens(tokenId, usdcId, usdcDepositAmount);

        vm.warp(expiry);

        vm.startPrank(alice);
        weth.mint(alice, 1000 * 1e18);
        weth.approve(address(engine), type(uint256).max);

        pomace.settleOption(alice, tokenId, amount / 2);
        vm.stopPrank();

        vm.warp(expiry + exerciseWindow + 1);

        (,, Balance[] memory collateralsBefore) = engine.marginAccounts(address(this));

        // settle margin account
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSettleAction();
        engine.execute(address(this), actions);

        //margin account should be reset
        (Position[] memory shorts,, Balance[] memory collateralsAfter) = engine.marginAccounts(address(this));

        assertEq(shorts.length, 0);
        assertEq(collateralsAfter[0].collateralId, collateralsBefore[0].collateralId);
        assertEq(collateralsAfter[0].amount, collateralsBefore[0].amount / 2);
    }

    function _mintTokens(uint256 tokenId, uint8 collateralId, uint256 depositAmount) internal {
        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(collateralId, address(this), depositAmount);
        // give option to alice
        actions[1] = createMintAction(tokenId, alice, amount);

        // mint option
        engine.execute(address(this), actions);

        // expire option
        vm.warp(expiry);
    }
}

// solhint-disable-next-line contract-name-camelcase
contract TestExerciseLongPositions_CMP is CrossMarginPhysicalFixture {
    uint256 public expiry;
    uint256 public exerciseWindow;

    uint64 private amount = uint64(1 * UNIT);
    uint64 private strike;
    uint256 private wethDepositAmount = 1 ether;
    uint256 private usdcDepositAmount = 4000 * 1e6;

    function setUp() public {
        weth.mint(alice, 1000 * 1e18);
        weth.mint(address(this), 1000 * 1e18);
        weth.approve(address(engine), type(uint256).max);

        usdc.mint(alice, 1000_000 * 1e6);
        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(engine), type(uint256).max);

        vm.startPrank(alice);
        weth.approve(address(engine), type(uint256).max);
        usdc.approve(address(engine), type(uint256).max);
        vm.stopPrank();

        expiry = block.timestamp + 14 days;
        exerciseWindow = 300;

        strike = uint64(4000 * UNIT);
    }

    function testCannotClearLongWithExceededAmount() public {
        uint256 tokenId = getTokenId(TokenType.CALL, pidEthCollat, expiry, strike, exerciseWindow);

        _mintTokens(tokenId, wethId, wethDepositAmount);

        vm.expectRevert(CML_ExceedsAmount.selector);

        // settle margin account
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createExerciseTokenAction(tokenId, amount + 1);
        engine.execute(address(this), actions);
    }

    function testCanClearLongPortion() public {
        uint256 tokenId = getTokenId(TokenType.CALL, pidEthCollat, expiry, strike, exerciseWindow);

        _mintTokens(tokenId, wethId, wethDepositAmount);

        vm.warp(expiry + exerciseWindow);

        // settle margin account
        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(usdcId, address(this), usdcDepositAmount / 2);
        actions[1] = createExerciseTokenAction(tokenId, amount / 2);
        engine.execute(address(this), actions);

        //margin account should be reset
        (, Position[] memory longs, Balance[] memory collaterals) = engine.marginAccounts(address(this));

        assertEq(longs.length, 1);
        assertEq(longs[0].tokenId, tokenId);
        assertEq(longs[0].amount, amount / 2);

        assertEq(collaterals.length, 1);
        assertEq(collaterals[0].collateralId, wethId);
        assertEq(collaterals[0].amount, wethDepositAmount / 2);

        vm.warp(expiry + exerciseWindow + 1);

        actions = new ActionArgs[](1);
        actions[0] = createExerciseTokenAction(0, 0);
        engine.execute(address(this), actions);

        (, Position[] memory longsAfter, Balance[] memory collateralsAfter) = engine.marginAccounts(address(this));

        assertEq(longsAfter.length, 0);
        assertEq(collateralsAfter.length, 1);
        assertEq(collateralsAfter[0].collateralId, wethId);
        assertEq(collateralsAfter[0].amount, wethDepositAmount / 2);
    }

    function testCannotClearLongCallAfterWindowClosed() public {
        uint256 tokenId = getTokenId(TokenType.CALL, pidEthCollat, expiry, strike, exerciseWindow);

        _mintTokens(tokenId, wethId, wethDepositAmount);

        vm.warp(expiry + exerciseWindow + 1);

        // settle margin account
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createExerciseTokenAction(tokenId, amount);
        engine.execute(address(this), actions);

        //margin account should be reset
        (, Position[] memory longs, Balance[] memory collaterals) = engine.marginAccounts(address(this));

        assertEq(longs.length, 0);
        assertEq(collaterals.length, 0);
    }

    function testCanClearLongCallAfterExpiryBeforeWindowClosed() public {
        uint256 tokenId = getTokenId(TokenType.CALL, pidEthCollat, expiry, strike, exerciseWindow);

        _mintTokens(tokenId, wethId, wethDepositAmount);

        vm.warp(expiry + exerciseWindow);

        // settle margin account
        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(usdcId, address(this), usdcDepositAmount);
        actions[1] = createExerciseTokenAction(tokenId, amount);
        engine.execute(address(this), actions);

        //margin account should be reset
        (, Position[] memory longs, Balance[] memory collaterals) = engine.marginAccounts(address(this));

        assertEq(longs.length, 0);
        assertEq(collaterals.length, 1);
        assertEq(collaterals[0].collateralId, wethId);
        assertEq(collaterals[0].amount, wethDepositAmount);
    }

    function testCanClearMultipleLongCallAfterExpiryBeforeWindowClosed() public {
        uint256 tokenId1 = getTokenId(TokenType.CALL, pidEthCollat, expiry, strike, exerciseWindow + 1 hours);
        uint256 tokenId2 = getTokenId(TokenType.CALL, pidEthCollat, expiry + 1 hours, strike, exerciseWindow);

        _mintTokens(tokenId1, wethId, wethDepositAmount);
        _mintTokens(tokenId2, wethId, wethDepositAmount);

        vm.warp(expiry + 1 hours);

        // settle margin account
        ActionArgs[] memory actions = new ActionArgs[](3);
        actions[0] = createAddCollateralAction(usdcId, address(this), usdcDepositAmount * 2);
        actions[1] = createExerciseTokenAction(tokenId1, amount);
        actions[2] = createExerciseTokenAction(tokenId2, amount);
        engine.execute(address(this), actions);

        //margin account should be reset
        (, Position[] memory longs, Balance[] memory collaterals) = engine.marginAccounts(address(this));

        assertEq(longs.length, 0);
        assertEq(collaterals.length, 1);
        assertEq(collaterals[0].collateralId, wethId);
        assertEq(collaterals[0].amount, wethDepositAmount * 2);
    }

    function testCannotClearLongPutAfterWindowClosed() public {
        uint256 tokenId = getTokenId(TokenType.PUT, pidUsdcCollat, expiry, strike, exerciseWindow);

        _mintTokens(tokenId, usdcId, usdcDepositAmount);

        vm.warp(expiry + exerciseWindow + 1);

        // settle margin account
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createExerciseTokenAction(tokenId, amount);
        engine.execute(address(this), actions);

        //margin account should be reset
        (, Position[] memory longs, Balance[] memory collaterals) = engine.marginAccounts(address(this));

        assertEq(longs.length, 0);
        assertEq(collaterals.length, 0);
    }

    function testCanClearPutBeforeWindowClosed() public {
        uint256 tokenId = getTokenId(TokenType.PUT, pidUsdcCollat, expiry, strike, exerciseWindow);

        _mintTokens(tokenId, usdcId, usdcDepositAmount);

        vm.warp(expiry + exerciseWindow);

        // settle margin account
        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(wethId, address(this), wethDepositAmount);
        actions[1] = createExerciseTokenAction(tokenId, amount);
        engine.execute(address(this), actions);

        //margin account should be reset
        (, Position[] memory longs, Balance[] memory collaterals) = engine.marginAccounts(address(this));

        assertEq(longs.length, 0);
        assertEq(collaterals.length, 1);
        assertEq(collaterals[0].collateralId, usdcId);
        assertEq(collaterals[0].amount, usdcDepositAmount);
    }

    function testCanClearPortionPut() public {
        uint256 tokenId = getTokenId(TokenType.PUT, pidUsdcCollat, expiry, strike, exerciseWindow);

        _mintTokens(tokenId, usdcId, usdcDepositAmount);

        vm.warp(expiry + exerciseWindow);

        // settle margin account
        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(wethId, address(this), wethDepositAmount);
        actions[1] = createExerciseTokenAction(tokenId, amount);
        engine.execute(address(this), actions);

        //margin account should be reset
        (, Position[] memory longs, Balance[] memory collaterals) = engine.marginAccounts(address(this));

        assertEq(longs.length, 0);
        assertEq(collaterals.length, 1);
        assertEq(collaterals[0].collateralId, usdcId);
        assertEq(collaterals[0].amount, usdcDepositAmount);
    }

    function _mintTokens(uint256 tokenId, uint8 collateralId, uint256 depositAmount) internal {
        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(collateralId, alice, depositAmount);
        // give option to alice
        actions[1] = createMintIntoAccountAction(tokenId, address(this), amount);

        // mint option
        vm.startPrank(alice);
        engine.execute(alice, actions);
        vm.stopPrank();

        // expire option
        vm.warp(expiry);
    }
}

// solhint-disable-next-line contract-name-camelcase
contract TestSettleSocializedLosses_CMP is CrossMarginPhysicalFixture {
    uint256 public expiry;
    uint256 public exerciseWindow;

    uint64 private amount = uint64(1 * UNIT);
    uint256 private tokenId;
    uint64 private strike;
    uint256 private depositAmount = 4000 * 1e6;

    function setUp() public {
        weth.mint(bob, 1000 * 1e18);
        vm.prank(bob);
        weth.approve(address(engine), type(uint256).max);

        weth.mint(address(this), 1000 * 1e18);
        weth.approve(address(engine), type(uint256).max);

        usdc.mint(alice, 1000_000 * 1e6);
        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(engine), type(uint256).max);

        vm.prank(alice);
        usdc.approve(address(engine), type(uint256).max);

        expiry = block.timestamp + 14 days;
        exerciseWindow = 300;

        strike = uint64(4000 * UNIT);

        tokenId = getTokenId(TokenType.PUT, pidUsdcCollat, expiry, strike, exerciseWindow);
    }

    function testSocializeLoss() public {
        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        actions[1] = createMintAction(tokenId, bob, amount);
        engine.execute(address(this), actions);

        actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(usdcId, alice, depositAmount);
        actions[1] = createMintAction(tokenId, bob, amount);
        vm.prank(alice);
        engine.execute(alice, actions);

        vm.warp(expiry);

        vm.prank(bob);
        pomace.settleOption(bob, tokenId, amount);

        vm.warp(expiry + exerciseWindow + 1);

        actions = new ActionArgs[](1);
        actions[0] = createSettleAction();
        engine.execute(address(this), actions);

        actions = new ActionArgs[](1);
        actions[0] = createSettleAction();
        vm.prank(alice);
        engine.execute(alice, actions);

        (Position[] memory shorts,, Balance[] memory collaterals) = engine.marginAccounts(address(this));
        assertEq(shorts.length, 0);
        assertEq(collaterals.length, 2);
        assertEq(collaterals[0].collateralId, usdcId);
        assertEq(collaterals[0].amount, depositAmount / 2);
        assertEq(collaterals[1].collateralId, wethId);
        assertEq(collaterals[1].amount, 1e18 / 2);

        (shorts,, collaterals) = engine.marginAccounts(alice);
        assertEq(shorts.length, 0);
        assertEq(collaterals.length, 2);
        assertEq(collaterals[0].collateralId, usdcId);
        assertEq(collaterals[0].amount, depositAmount / 2);
        assertEq(collaterals[1].collateralId, wethId);
        assertEq(collaterals[1].amount, 1e18 / 2);
    }
}
