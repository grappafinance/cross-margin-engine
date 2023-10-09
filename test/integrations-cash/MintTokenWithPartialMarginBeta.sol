// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import {CrossMarginCashFixture} from "./CrossMarginCashFixture.t.sol";

import "grappa/config/types.sol";
import "grappa/config/enums.sol";
import "grappa/config/constants.sol";
import "grappa/config/errors.sol";

import "../../src/config/errors.sol";
import "../../src/settled-cash/types.sol";

import "../mocks/MockERC20.sol";

// solhint-disable-next-line contract-name-camelcase
contract TestMintWithPartialMarginBeta_CMC is CrossMarginCashFixture {
    MockERC20 internal lsEth;
    MockERC20 internal sdyc;
    MockERC20 internal usdt;
    uint8 internal lsEthId;
    uint8 internal sdycId;
    uint8 internal usdtId;

    address internal usdcAddr;
    address internal wethAddr;
    address internal lsEthAddr;
    address internal sdycAddr;
    address internal usdtAddr;

    // usdc strike & sdyc collateralized  call / put
    uint40 internal pidSdycCollat;
    uint40 internal pidUsdtSdycCollat;

    // eth strike & lsEth collateralized call / put
    uint40 internal pidLsEthCollat;

    uint256 public expiry;

    function setUp() public {
        usdcAddr = address(usdc);
        wethAddr = address(weth);

        lsEth = new MockERC20("LsETH", "LsETH", 18);
        lsEthAddr = address(lsEth);
        vm.label(lsEthAddr, "LsETH");

        sdyc = new MockERC20("SDYC", "SDYC", 6);
        sdycAddr = address(sdyc);
        vm.label(sdycAddr, "SDYC");

        usdt = new MockERC20("USDT", "USDT", 6);
        usdtAddr = address(usdt);
        vm.label(usdtAddr, "USDT");

        sdycId = grappa.registerAsset(sdycAddr);
        lsEthId = grappa.registerAsset(lsEthAddr);
        usdtId = grappa.registerAsset(usdtAddr);

        engine.setCollateralizable(wethAddr, lsEthAddr, true);
        engine.setCollateralizable(usdcAddr, sdycAddr, true);
        engine.setCollateralizable(usdcAddr, usdtAddr, true);
        engine.setCollateralizable(usdtAddr, sdycAddr, true);

        oracle.setSpotPrice(wethAddr, 1 * UNIT);
        oracle.setSpotPrice(lsEthAddr, 1 * UNIT);
        oracle.setSpotPrice(sdycAddr, 1 * UNIT);
        oracle.setSpotPrice(usdcAddr, 1 * UNIT);
        oracle.setSpotPrice(usdtAddr, 1 * UNIT);

        pidSdycCollat = grappa.getProductId(address(oracle), address(engine), wethAddr, usdcAddr, sdycAddr);
        pidUsdtSdycCollat = grappa.getProductId(address(oracle), address(engine), wethAddr, usdtAddr, sdycAddr);
        pidLsEthCollat = grappa.getProductId(address(oracle), address(engine), wethAddr, usdcAddr, lsEthAddr);

        sdyc.mint(address(this), 1000_000 * 1e6);
        sdyc.approve(address(engine), type(uint256).max);

        usdt.mint(address(this), 1000_000 * 1e6);
        usdt.approve(address(engine), type(uint256).max);

        lsEth.mint(address(this), 100 * 1e18);
        lsEth.approve(address(engine), type(uint256).max);

        expiry = block.timestamp + 14 days;

        oracle.setSpotPrice(wethAddr, 3000 * UNIT);
    }

    function testRemovePartialMarginMask() public {
        engine.setCollateralizable(lsEthAddr, wethAddr, true);
        assertEq(engine.isCollateralizable(wethAddr, lsEthAddr), true);

        engine.setCollateralizable(wethAddr, lsEthAddr, false);

        assertEq(engine.isCollateralizable(wethAddr, lsEthAddr), false);
        assertEq(engine.isCollateralizable(lsEthAddr, wethAddr), true);
        assertEq(engine.isCollateralizable(usdcAddr, sdycAddr), true);
        assertEq(engine.isCollateralizable(usdcAddr, usdtAddr), true);
        assertEq(engine.isCollateralizable(usdtAddr, sdycAddr), true);
    }

    function testSameAssetPartialMarginMask() public {
        assertEq(engine.isCollateralizable(wethAddr, wethAddr), true);
    }

    function testMintCall() public {
        uint256 depositAmount = 1 * 1e18;

        uint256 strikePrice = 4000 * UNIT;
        uint256 amount = 1 * UNIT;

        uint256 tokenId = getTokenId(TokenType.CALL, pidLsEthCollat, expiry, strikePrice, 0);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(lsEthId, address(this), depositAmount);
        actions[1] = createMintAction(tokenId, address(this), amount);
        engine.execute(address(this), actions);

        (Position[] memory shorts,,) = engine.marginAccounts(address(this));

        assertEq(shorts.length, 1);
        assertEq(shorts[0].tokenId, tokenId);
        assertEq(shorts[0].amount, amount);

        assertEq(option.balanceOf(address(this), tokenId), amount);
    }

    function testMintCallWithHigherValueCollateral() public {
        oracle.setSpotPrice(address(lsEth), 1.25 * 1e6);

        uint256 depositAmount = 0.8 * 1e18;

        uint256 strikePrice = 4000 * UNIT;
        uint256 amount = 1 * UNIT;

        uint256 tokenId = getTokenId(TokenType.CALL, pidLsEthCollat, expiry, strikePrice, 0);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(lsEthId, address(this), depositAmount);
        actions[1] = createMintAction(tokenId, address(this), amount);
        engine.execute(address(this), actions);

        (Position[] memory shorts,,) = engine.marginAccounts(address(this));

        assertEq(shorts.length, 1);
        assertEq(shorts[0].tokenId, tokenId);
        assertEq(shorts[0].amount, amount);

        assertEq(option.balanceOf(address(this), tokenId), amount);
    }

    function testMintCallWithSimilarCollateral() public {
        uint256 depositAmount = 1 * 1e18;

        uint256 strikePrice = 4000 * UNIT;
        uint256 amount = 1 * UNIT;

        uint256 tokenId1 = getTokenId(TokenType.CALL, pidLsEthCollat, expiry, strikePrice, 0);
        uint256 tokenId2 = getTokenId(TokenType.CALL, pidEthCollat, expiry, strikePrice, 0);

        ActionArgs[] memory actions = new ActionArgs[](3);
        actions[0] = createAddCollateralAction(lsEthId, address(this), depositAmount * 2);
        actions[1] = createMintAction(tokenId1, address(this), amount);
        actions[2] = createMintAction(tokenId2, address(this), amount);
        engine.execute(address(this), actions);

        (Position[] memory shorts,,) = engine.marginAccounts(address(this));

        assertEq(shorts.length, 2);
        assertEq(shorts[0].tokenId, tokenId1);
        assertEq(shorts[0].amount, amount);
        assertEq(shorts[1].tokenId, tokenId2);
        assertEq(shorts[1].amount, amount);

        assertEq(option.balanceOf(address(this), tokenId1), amount);
        assertEq(option.balanceOf(address(this), tokenId2), amount);
    }

    function testMintPut() public {
        uint256 depositAmount = 2000 * 1e6;

        uint256 strikePrice = 2000 * UNIT;
        uint256 amount = 1 * UNIT;

        uint256 tokenId = getTokenId(TokenType.PUT, pidSdycCollat, expiry, strikePrice, 0);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(sdycId, address(this), depositAmount);
        actions[1] = createMintAction(tokenId, address(this), amount);
        engine.execute(address(this), actions);

        (Position[] memory shorts,,) = engine.marginAccounts(address(this));

        assertEq(shorts.length, 1);
        assertEq(shorts[0].tokenId, tokenId);
        assertEq(shorts[0].amount, amount);

        assertEq(option.balanceOf(address(this), tokenId), amount);
    }

    function testMintPutWithHigherValueCollateral() public {
        oracle.setSpotPrice(address(sdyc), 1.25 * 1e6);

        uint256 depositAmount = 1600 * 1e6;

        uint256 strikePrice = 2000 * UNIT;
        uint256 amount = 1 * UNIT;

        uint256 tokenId = getTokenId(TokenType.PUT, pidSdycCollat, expiry, strikePrice, 0);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(sdycId, address(this), depositAmount);
        actions[1] = createMintAction(tokenId, address(this), amount);
        engine.execute(address(this), actions);

        (Position[] memory shorts,,) = engine.marginAccounts(address(this));

        assertEq(shorts.length, 1);
        assertEq(shorts[0].tokenId, tokenId);
        assertEq(shorts[0].amount, amount);

        assertEq(option.balanceOf(address(this), tokenId), amount);
    }

    function testMintPutWithSimilarCollateral() public {
        uint256 depositAmount = 2000 * 1e6;

        uint256 strikePrice = 2000 * UNIT;
        uint256 amount = 1 * UNIT;

        uint256 tokenId1 = getTokenId(TokenType.PUT, pidSdycCollat, expiry, strikePrice, 0);
        uint256 tokenId2 = getTokenId(TokenType.PUT, pidUsdcCollat, expiry, strikePrice, 0);

        ActionArgs[] memory actions = new ActionArgs[](3);
        actions[0] = createAddCollateralAction(sdycId, address(this), depositAmount * 2);
        actions[1] = createMintAction(tokenId1, address(this), amount);
        actions[2] = createMintAction(tokenId2, address(this), amount);
        engine.execute(address(this), actions);

        (Position[] memory shorts,,) = engine.marginAccounts(address(this));

        assertEq(shorts.length, 2);
        assertEq(shorts[0].tokenId, tokenId1);
        assertEq(shorts[0].amount, amount);
        assertEq(shorts[1].tokenId, tokenId2);
        assertEq(shorts[1].amount, amount);

        assertEq(option.balanceOf(address(this), tokenId1), amount);
        assertEq(option.balanceOf(address(this), tokenId2), amount);
    }

    function testCannotMintTooLittleCollateral() public {
        uint256 amount = 1 * UNIT;

        uint256 tokenId1 = getTokenId(TokenType.PUT, pidUsdcCollat, expiry, 1000 * UNIT, 0);
        uint256 tokenId2 = getTokenId(TokenType.PUT, pidUsdtSdycCollat, expiry, 2000 * UNIT, 0);

        ActionArgs[] memory actions = new ActionArgs[](4);
        actions[0] = createAddCollateralAction(usdtId, address(this), 900 * 1e6);
        actions[1] = createAddCollateralAction(sdycId, address(this), 1200 * 1e6);
        actions[2] = createMintAction(tokenId1, address(this), amount);
        actions[3] = createMintAction(tokenId2, address(this), amount);

        vm.expectRevert(BM_AccountUnderwater.selector);

        engine.execute(address(this), actions);
    }

    function testMintMixedBag() public {
        uint256 amount = 1 * UNIT;

        uint256 tokenId1 = getTokenId(TokenType.PUT, pidUsdcCollat, expiry, 1000 * UNIT, 0);
        uint256 tokenId2 = getTokenId(TokenType.PUT, pidUsdtSdycCollat, expiry, 2000 * UNIT, 0);
        uint256 tokenId3 = getTokenId(TokenType.CALL, pidEthCollat, expiry, 3000 * UNIT, 0);

        ActionArgs[] memory actions = new ActionArgs[](6);
        actions[0] = createAddCollateralAction(usdtId, address(this), 1800 * 1e6);
        actions[1] = createAddCollateralAction(sdycId, address(this), 1200 * 1e6);
        actions[2] = createAddCollateralAction(lsEthId, address(this), 1 * 1e18);
        actions[3] = createMintAction(tokenId1, address(this), amount);
        actions[4] = createMintAction(tokenId2, address(this), amount);
        actions[5] = createMintAction(tokenId3, address(this), amount);
        engine.execute(address(this), actions);

        (Position[] memory shorts,,) = engine.marginAccounts(address(this));

        assertEq(shorts.length, 3);
    }

    function testMintMixedBagWithVariableValueCollateral() public {
        oracle.setSpotPrice(address(usdt), 0.96 * 1e6);
        oracle.setSpotPrice(address(sdyc), 1.25 * 1e6);
        oracle.setSpotPrice(address(lsEth), 1.6 * 1e6);

        uint256 amount = 1 * UNIT;

        uint256 tokenId1 = getTokenId(TokenType.PUT, pidUsdcCollat, expiry, 1000 * UNIT, 0);
        uint256 tokenId2 = getTokenId(TokenType.PUT, pidSdycCollat, expiry, 2000 * UNIT, 0);
        uint256 tokenId3 = getTokenId(TokenType.CALL, pidEthCollat, expiry, 3000 * UNIT, 0);

        ActionArgs[] memory actions = new ActionArgs[](6);
        actions[0] = createAddCollateralAction(usdtId, address(this), 1875 * 1e6); // 1800 USD
        actions[1] = createAddCollateralAction(sdycId, address(this), 960 * 1e6); // 1200 USD
        actions[2] = createAddCollateralAction(lsEthId, address(this), 0.625 * 1e18); //    1 ETH
        actions[3] = createMintAction(tokenId1, address(this), amount);
        actions[4] = createMintAction(tokenId2, address(this), amount);
        actions[5] = createMintAction(tokenId3, address(this), amount);
        engine.execute(address(this), actions);

        (Position[] memory shorts,,) = engine.marginAccounts(address(this));

        assertEq(shorts.length, 3);
    }
}
