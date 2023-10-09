// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import {CrossMarginPhysicalFixture} from "./CrossMarginPhysicalFixture.t.sol";

import "pomace/config/enums.sol";
import "pomace/config/types.sol";
import "pomace/config/constants.sol";
import "pomace/config/errors.sol";

import "../../src/settled-physical/types.sol";

import "pomace-test/mocks/MockERC20.sol";

// solhint-disable-next-line contract-name-camelcase
contract TestSettleOptionPartialMargin_CMP is CrossMarginPhysicalFixture {
    MockERC20 internal lsEth;
    MockERC20 internal sdyc;

    uint8 internal lsEthId;
    uint8 internal sdycId;

    uint32 internal pidLsEthCollat;
    uint32 internal pidSdycCollat;

    uint256 public expiry;
    uint256 public exerciseWindow;

    function setUp() public {
        weth.mint(address(this), 1000 * 1e18);
        weth.approve(address(engine), type(uint256).max);

        usdc.mint(address(this), 100_000 * 1e16);
        usdc.approve(address(engine), type(uint256).max);

        lsEth = new MockERC20("LsETH", "LsETH", 18);
        vm.label(address(lsEth), "LsETH");

        sdyc = new MockERC20("SDYC", "SDYC", 6);
        vm.label(address(sdyc), "SDYC");

        lsEthId = pomace.registerAsset(address(lsEth));
        sdycId = pomace.registerAsset(address(sdyc));

        pomace.setCollateralizable(address(weth), address(lsEth), true);
        pomace.setCollateralizable(address(usdc), address(sdyc), true);

        // engine.setCollateralizableMask(address(weth), address(lsEth), true);
        // engine.setCollateralizableMask(address(usdc), address(sdyc), true);

        pidLsEthCollat = pomace.getProductId(address(engine), address(weth), address(usdc), address(lsEth));
        pidSdycCollat = pomace.getProductId(address(engine), address(weth), address(usdc), address(sdyc));

        lsEth.mint(address(this), 100 * 1e18);
        lsEth.approve(address(engine), type(uint256).max);

        sdyc.mint(address(this), 1000_000 * 1e6);
        sdyc.approve(address(engine), type(uint256).max);

        expiry = block.timestamp + 14 days;
        exerciseWindow = 300;

        oracle.setSpotPrice(address(weth), 3000 * UNIT);
        oracle.setSpotPrice(address(lsEth), 3000 * UNIT);
        oracle.setSpotPrice(address(sdyc), 1 * UNIT);
        oracle.setSpotPrice(address(usdc), 1 * UNIT);
    }

    function testCall() public {
        uint256 strikePrice = 4000 * UNIT;
        uint256 amount = 1 * UNIT;
        uint256 depositAmount = 1 * 1e18;

        uint256 tokenId = getTokenId(TokenType.CALL, pidLsEthCollat, expiry, strikePrice, exerciseWindow);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(lsEthId, address(this), depositAmount);
        actions[1] = createMintAction(tokenId, alice, amount);
        engine.execute(address(this), actions);

        uint256 wethExpiryPrice = 5000 * UNIT;
        uint256 lsEthExpiryPrice = 5200 * UNIT; // staked eth worth more due to rewards

        oracle.setExpiryPrice(address(lsEth), address(weth), lsEthExpiryPrice * UNIT / wethExpiryPrice);

        vm.warp(expiry);

        uint256 lsEthBefore = lsEth.balanceOf(alice);
        uint256 expectedPayout = wethExpiryPrice * UNIT / lsEthExpiryPrice * (depositAmount / UNIT);

        pomace.settleOption(alice, tokenId, amount);

        uint256 lsEthAfter = lsEth.balanceOf(alice);
        assertEq(lsEthAfter, lsEthBefore + expectedPayout);

        vm.warp(expiry + exerciseWindow + 1);

        actions = new ActionArgs[](1);
        actions[0] = createSettleAction();
        engine.execute(address(this), actions);

        (,, Balance[] memory collateralsAfter) = engine.marginAccounts(address(this));
        assertEq(collateralsAfter.length, 2);
        assertEq(collateralsAfter[0].collateralId, lsEthId);
        assertEq(collateralsAfter[0].amount, depositAmount - expectedPayout);
        assertEq(collateralsAfter[1].collateralId, usdcId);
        assertEq(collateralsAfter[1].amount, 4000 * 1e6);
    }

    function testPut() public {
        uint256 strikePrice = 2000 * UNIT;
        uint256 amount = 1 * UNIT;
        uint256 depositAmount = 2000 * 1e6;

        uint256 tokenId = getTokenId(TokenType.PUT, pidSdycCollat, expiry, strikePrice, exerciseWindow);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(sdycId, address(this), depositAmount);
        actions[1] = createMintAction(tokenId, alice, amount);
        engine.execute(address(this), actions);

        uint256 wethExpiryPrice = 1000 * UNIT;
        uint256 sdycExpiryPrice = 1_040000; // worth more due to interest ($1.04)

        oracle.setExpiryPrice(address(weth), address(usdc), wethExpiryPrice);
        oracle.setExpiryPrice(address(sdyc), address(usdc), sdycExpiryPrice);

        vm.warp(expiry);

        uint256 sdycBefore = sdyc.balanceOf(alice);
        uint256 expectedPayout = strikePrice * UNIT / sdycExpiryPrice;

        pomace.settleOption(alice, tokenId, amount);

        uint256 sdycAfter = sdyc.balanceOf(alice);
        assertEq(sdycAfter, sdycBefore + expectedPayout);

        vm.warp(expiry + exerciseWindow + 1);

        actions = new ActionArgs[](1);
        actions[0] = createSettleAction();
        engine.execute(address(this), actions);

        (,, Balance[] memory collateralsAfter) = engine.marginAccounts(address(this));
        assertEq(collateralsAfter.length, 2);
        assertEq(collateralsAfter[0].collateralId, sdycId);
        assertEq(collateralsAfter[0].amount, depositAmount - expectedPayout);
        assertEq(collateralsAfter[1].collateralId, wethId);
        assertEq(collateralsAfter[1].amount, 1 * 1e18);
    }
}
