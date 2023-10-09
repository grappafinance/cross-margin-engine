// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import {CrossMarginCashFixture} from "./CrossMarginCashFixture.t.sol";
import {stdError} from "forge-std/Test.sol";

import "grappa/config/types.sol";
import "grappa/config/enums.sol";
import "grappa/config/constants.sol";
import "grappa/config/errors.sol";

import "../../src/config/errors.sol";
import "../../src/settled-cash/types.sol";

// solhint-disable-next-line contract-name-camelcase
contract TestBurnOption_CMC is CrossMarginCashFixture {
    uint256 public expiry;
    uint256 public strikePrice = 4000 * UNIT;
    uint256 public depositAmount = 1 ether;
    uint256 public amount = 1 * UNIT;
    uint256 public tokenId;

    event CashOptionTokenBurned(address subAccount, uint256 tokenId, uint256 amount);

    function setUp() public {
        weth.mint(address(this), depositAmount);
        weth.approve(address(engine), type(uint256).max);

        expiry = block.timestamp + 14 days;

        oracle.setSpotPrice(address(weth), 3000 * UNIT);

        // mint a 3000 strike call first
        tokenId = getTokenId(TokenType.CALL, pidEthCollat, expiry, strikePrice, 0);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(wethId, address(this), depositAmount);
        actions[1] = createMintAction(tokenId, address(this), amount);
        engine.execute(address(this), actions);
    }

    function testBurn() public {
        // build burn account
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createBurnAction(tokenId, address(this), amount);

        vm.expectEmit(true, true, true, true);
        emit CashOptionTokenBurned(address(this), tokenId, amount);

        // action
        engine.execute(address(this), actions);
        (Position[] memory shorts,,) = engine.marginAccounts(address(this));

        // check result
        assertEq(shorts.length, 0);

        assertEq(option.balanceOf(address(this), tokenId), 0);
    }

    function testCannotBurnWithWrongTokenId() public {
        address subAccount = address(uint160(address(this)) - 1);

        // badId: usdc Id
        uint256 badTokenId = getTokenId(TokenType.CALL, pidUsdcCollat, expiry, strikePrice, 0);
        // build burn account
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createBurnAction(badTokenId, address(this), amount);

        // action
        vm.expectRevert(CM_InvalidToken.selector);
        engine.execute(subAccount, actions); // execute on subaccount
    }

    function testCannotBurnForEmptyAccount() public {
        address subAccount = address(uint160(address(this)) - 1);

        // build burn account
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createBurnAction(tokenId, address(this), amount);

        // action
        vm.expectRevert(CM_InvalidToken.selector);
        engine.execute(subAccount, actions); // execute on subaccount
    }

    function testCannotBurnWhenOptionTokenBalanceIsLow() public {
        // prepare: transfer some optionToken out
        option.safeTransferFrom(address(this), alice, tokenId, 1, "");

        // build burn arg
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createBurnAction(tokenId, address(this), amount);

        // expect
        vm.expectRevert(stdError.arithmeticError);
        engine.execute(address(this), actions);
    }

    function testCannotBurnFromUnAuthorizedAccount() public {
        // send option to alice
        option.safeTransferFrom(address(this), alice, tokenId, amount, "");

        // build burn arg: try building with alice's options
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createBurnAction(tokenId, alice, amount);

        // expect error
        vm.expectRevert(BM_InvalidFromAddress.selector);
        engine.execute(address(this), actions);
    }
}

// solhint-disable-next-line contract-name-camelcase
contract TestBurnOptionFromAccount_CMC is CrossMarginCashFixture {
    uint256 public depositAmount = 1 ether;
    uint256 public amount = 1 * UNIT;
    uint256 public tokenId;

    event CashOptionTokenBurned(address subAccount, uint256 tokenId, uint256 amount);

    function setUp() public {
        weth.mint(address(this), 1 * 1e18);
        weth.approve(address(engine), type(uint256).max);

        weth.mint(alice, 1 * 1e18);

        vm.startPrank(alice);
        weth.approve(address(engine), type(uint256).max);
        engine.setAccountAccess(address(this), type(uint256).max);
        vm.stopPrank();

        oracle.setSpotPrice(address(weth), 1900 * UNIT);

        tokenId = getTokenId(TokenType.CALL, pidEthCollat, block.timestamp + 1 days, 4000 * 1e6, 0);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(wethId, alice, depositAmount);
        actions[1] = createMintIntoAccountAction(tokenId, address(this), amount);
        engine.execute(alice, actions);

        option.setApprovalForAll(address(engine), true);
    }

    function testBurnFromAccount() public {
        Position[] memory shorts;
        Position[] memory longs;

        (shorts, longs,) = engine.marginAccounts(address(this));

        assertEq(shorts.length, 0);
        assertEq(longs.length, 1);
        assertEq(longs[0].tokenId, tokenId);

        (shorts, longs,) = engine.marginAccounts(alice);

        assertEq(shorts.length, 1);
        assertEq(shorts[0].tokenId, tokenId);
        assertEq(longs.length, 0);

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createBurnShortInAccountAction(tokenId, address(this), amount);

        // decreases longs
        vm.expectEmit(true, true, true, true);
        emit CashOptionTokenBurned(address(this), tokenId, amount);

        // decreases shorts
        vm.expectEmit(true, true, true, true);
        emit CashOptionTokenBurned(alice, tokenId, amount);

        engine.execute(alice, actions);

        (shorts, longs,) = engine.marginAccounts(address(this));

        assertEq(shorts.length, 0);
        assertEq(longs.length, 0);

        (shorts, longs,) = engine.marginAccounts(alice);

        assertEq(shorts.length, 0);
        assertEq(longs.length, 0);
    }

    function testCanBurnFromSubAccount() public {
        address subAccount = address(uint160(address(this)) ^ uint160(1));

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createAddCollateralAction(wethId, address(this), depositAmount);
        engine.execute(subAccount, actions);

        actions[0] = createTransferShortAction(tokenId, subAccount, amount);
        engine.execute(alice, actions);

        Position[] memory shorts;
        Position[] memory longs;

        (shorts, longs,) = engine.marginAccounts(address(this));

        assertEq(shorts.length, 0);
        assertEq(longs.length, 1);
        assertEq(longs[0].tokenId, tokenId);

        (shorts, longs,) = engine.marginAccounts(subAccount);

        assertEq(shorts.length, 1);
        assertEq(shorts[0].tokenId, tokenId);
        assertEq(longs.length, 0);

        (shorts, longs,) = engine.marginAccounts(alice);

        assertEq(shorts.length, 0);
        assertEq(longs.length, 0);

        actions[0] = createBurnShortInAccountAction(tokenId, address(this), amount);

        // decreases longs
        vm.expectEmit(true, true, true, true);
        emit CashOptionTokenBurned(address(this), tokenId, amount);

        // decreases shorts
        vm.expectEmit(true, true, true, true);
        emit CashOptionTokenBurned(subAccount, tokenId, amount);

        engine.execute(subAccount, actions);
    }

    function testCannotBurnFromEmptySubAccount() public {
        address subAccount = address(uint160(address(this)) ^ uint160(1));

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createBurnShortInAccountAction(tokenId, address(this), amount);

        vm.expectRevert(CM_InvalidToken.selector);
        engine.execute(subAccount, actions);
    }

    function testCannotBurnFromWithWrongTokenId() public {
        uint256 badTokenId = getTokenId(TokenType.CALL, pidUsdcCollat, block.timestamp + 1 days, 4000 * 1e6, 0);

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createBurnShortInAccountAction(badTokenId, address(this), amount);

        vm.expectRevert(CM_InvalidToken.selector);
        engine.execute(alice, actions);
    }

    function testCannotBurnWhenOptionTokenBalanceIsLow() public {
        vm.prank(address(engine));
        option.safeTransferFrom(address(engine), address(this), tokenId, 1, "");

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createBurnShortInAccountAction(tokenId, address(this), amount);

        vm.expectRevert(stdError.arithmeticError);
        engine.execute(alice, actions);
    }

    function testCannotBurnFromUnAuthorizedAccount() public {
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createBurnShortInAccountAction(tokenId, alice, amount);

        // expect error
        vm.expectRevert(BM_InvalidFromAddress.selector);
        engine.execute(address(this), actions);
    }
}
