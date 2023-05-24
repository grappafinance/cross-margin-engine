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
contract TestMintWithPartialMarginBeta_CMP is CrossMarginPhysicalFixture {
    MockERC20 internal lsEth;
    MockERC20 internal sdyc;
    MockERC20 internal usdt;
    uint8 internal lsEthId;
    uint8 internal sdycId;
    uint8 internal usdtId;

    // usdc strike & sdyc collateralized  call / put
    uint32 internal pidSdycCollat;
    uint32 internal pidUsdtSdycCollat;

    // eth strike & lsEth collateralized call / put
    uint32 internal pidLsEthCollat;

    uint256 public expiry;
    uint256 public exerciseWindow;

    function setUp() public {
        address usdcAddr = address(usdc);
        address wethAddr = address(weth);

        lsEth = new MockERC20("LsETH", "LsETH", 18);
        address lsEthAddr = address(lsEth);
        vm.label(lsEthAddr, "LsETH");

        sdyc = new MockERC20("SDYC", "SDYC", 6);
        address sdycAddr = address(sdyc);
        vm.label(sdycAddr, "SDYC");

        usdt = new MockERC20("USDT", "USDT", 6);
        address usdtAddr = address(usdt);
        vm.label(usdtAddr, "USDT");

        sdycId = pomace.registerAsset(sdycAddr);
        lsEthId = pomace.registerAsset(lsEthAddr);
        usdtId = pomace.registerAsset(usdtAddr);

        pomace.setCollateralizable(wethAddr, lsEthAddr, true);
        pomace.setCollateralizable(usdcAddr, sdycAddr, true);
        pomace.setCollateralizable(usdcAddr, usdtAddr, true);
        pomace.setCollateralizable(usdtAddr, sdycAddr, true);

        oracle.setSpotPrice(wethAddr, 1 * UNIT);
        oracle.setSpotPrice(lsEthAddr, 1 * UNIT);
        oracle.setSpotPrice(sdycAddr, 1 * UNIT);
        oracle.setSpotPrice(usdcAddr, 1 * UNIT);
        oracle.setSpotPrice(usdtAddr, 1 * UNIT);

        pidSdycCollat = pomace.getProductId(address(engine), wethAddr, usdcAddr, sdycAddr);
        pidUsdtSdycCollat = pomace.getProductId(address(engine), wethAddr, usdtAddr, sdycAddr);
        pidLsEthCollat = pomace.getProductId(address(engine), wethAddr, usdcAddr, lsEthAddr);

        sdyc.mint(address(this), 1000_000 * 1e6);
        sdyc.approve(address(engine), type(uint256).max);

        usdt.mint(address(this), 1000_000 * 1e6);
        usdt.approve(address(engine), type(uint256).max);

        lsEth.mint(address(this), 100 * 1e18);
        lsEth.approve(address(engine), type(uint256).max);

        expiry = block.timestamp + 14 days;
        exerciseWindow = 300;
    }

    function testMintCall() public {
        uint256 depositAmount = 1 * 1e18;

        uint256 strikePrice = 4000 * UNIT;
        uint256 amount = 1 * UNIT;

        uint256 tokenId = getTokenId(TokenType.CALL, pidLsEthCollat, expiry, strikePrice, exerciseWindow);

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

        uint256 tokenId = getTokenId(TokenType.CALL, pidLsEthCollat, expiry, strikePrice, exerciseWindow);

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

        uint256 tokenId1 = getTokenId(TokenType.CALL, pidLsEthCollat, expiry, strikePrice, exerciseWindow);
        uint256 tokenId2 = getTokenId(TokenType.CALL, pidEthCollat, expiry, strikePrice, exerciseWindow);

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

        uint256 tokenId = getTokenId(TokenType.PUT, pidSdycCollat, expiry, strikePrice, exerciseWindow);

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

        uint256 tokenId = getTokenId(TokenType.PUT, pidSdycCollat, expiry, strikePrice, exerciseWindow);

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

        uint256 tokenId1 = getTokenId(TokenType.PUT, pidSdycCollat, expiry, strikePrice, exerciseWindow);
        uint256 tokenId2 = getTokenId(TokenType.PUT, pidUsdcCollat, expiry, strikePrice, exerciseWindow);

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

        uint256 tokenId1 = getTokenId(TokenType.PUT, pidUsdcCollat, expiry, 1000 * UNIT, exerciseWindow);
        uint256 tokenId2 = getTokenId(TokenType.PUT, pidUsdtSdycCollat, expiry, 2000 * UNIT, exerciseWindow);

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

        uint256 tokenId1 = getTokenId(TokenType.PUT, pidUsdcCollat, expiry, 1000 * UNIT, exerciseWindow);
        uint256 tokenId2 = getTokenId(TokenType.PUT, pidUsdtSdycCollat, expiry, 2000 * UNIT, exerciseWindow);
        uint256 tokenId3 = getTokenId(TokenType.CALL, pidEthCollat, expiry, 3000 * UNIT, exerciseWindow);

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

        uint256 tokenId1 = getTokenId(TokenType.PUT, pidUsdcCollat, expiry, 1000 * UNIT, exerciseWindow);
        uint256 tokenId2 = getTokenId(TokenType.PUT, pidSdycCollat, expiry, 2000 * UNIT, exerciseWindow);
        uint256 tokenId3 = getTokenId(TokenType.CALL, pidEthCollat, expiry, 3000 * UNIT, exerciseWindow);

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
