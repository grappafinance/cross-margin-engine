// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import {CrossMarginCashFixture} from "../integrations-cash/CrossMarginCashFixture.t.sol";

import "grappa/config/types.sol";
import "grappa/config/constants.sol";

import "../../src/config/types.sol";
import "../mocks/MockERC20.sol";

contract TestPreviewCollateralAvailable_CMC is CrossMarginCashFixture {
    function setUp() public {}

    function testPreviewCollateralAvailableNoCollat() public {
        Position[] memory longs = new Position[](0);
        Position[] memory shorts = new Position[](0);
        Balance[] memory collaterals = new Balance[](0);

        (address[] memory addresses, uint256[] memory amounts, bool isUnderWater) =
            engine.previewCollateralAvailable(shorts, longs, collaterals);

        assertEq(addresses.length, 0);
        assertEq(amounts.length, 0);
        assertEq(isUnderWater, false);
    }

    function testPreviewCollateralAvailable() public {
        uint80 usdcStrikePrice = 1600 * 1e6;
        uint80 wethStrikePrice = 1 * 1e18;

        Balance[] memory collaterals = new Balance[](2);
        collaterals[0] = Balance({collateralId: usdcId, amount: usdcStrikePrice});
        collaterals[1] = Balance({collateralId: wethId, amount: wethStrikePrice});

        Position[] memory longs = new Position[](0);
        Position[] memory shorts = new Position[](2);

        uint256 putTokenId = getTokenId(TokenType.PUT, pidUsdcCollat, block.timestamp + 14 days, usdcStrikePrice, 0);
        uint256 callTokenId = getTokenId(TokenType.CALL, pidEthCollat, block.timestamp + 14 days, wethStrikePrice, 0);

        shorts[0] = Position({tokenId: putTokenId, amount: uint64(1 * UNIT)});
        shorts[1] = Position({tokenId: callTokenId, amount: uint64(1 * UNIT)});

        (address[] memory addresses, uint256[] memory amounts, bool isUnderWater) =
            engine.previewCollateralAvailable(shorts, longs, collaterals);

        assertEq(addresses.length, 2);
        assertEq(addresses[0], address(usdc));
        assertEq(addresses[1], address(weth));

        assertEq(amounts.length, 2);
        assertEq(amounts[0], 0);
        assertEq(amounts[1], 0);

        assertEq(isUnderWater, false);
    }

    function testPreviewCollateralAvailableUsingHalf() public {
        uint80 usdcStrikePrice = 1600 * 1e6;
        uint80 wethStrikePrice = 1 * 1e18;

        Balance[] memory collaterals = new Balance[](2);
        collaterals[0] = Balance({collateralId: usdcId, amount: 2 * usdcStrikePrice});
        collaterals[1] = Balance({collateralId: wethId, amount: 2 * wethStrikePrice});

        Position[] memory longs = new Position[](0);
        Position[] memory shorts = new Position[](2);

        uint256 putTokenId = getTokenId(TokenType.PUT, pidUsdcCollat, block.timestamp + 14 days, usdcStrikePrice, 0);
        uint256 callTokenId = getTokenId(TokenType.CALL, pidEthCollat, block.timestamp + 14 days, wethStrikePrice, 0);

        shorts[0] = Position({tokenId: putTokenId, amount: uint64(1 * UNIT)});
        shorts[1] = Position({tokenId: callTokenId, amount: uint64(1 * UNIT)});

        (address[] memory addresses, uint256[] memory amounts, bool isUnderWater) =
            engine.previewCollateralAvailable(shorts, longs, collaterals);

        assertEq(addresses.length, 2);
        assertEq(addresses[0], address(usdc));
        assertEq(addresses[1], address(weth));

        assertEq(amounts.length, 2);
        assertEq(amounts[0], usdcStrikePrice);
        assertEq(amounts[1], wethStrikePrice);

        assertEq(isUnderWater, false);
    }

    function testPreviewCollateralAvailableUnderwater() public {
        uint80 usdcStrikePrice = 1600 * 1e6;
        uint256 tokenId = getTokenId(TokenType.PUT, pidUsdcCollat, block.timestamp + 14 days, usdcStrikePrice, 0);

        Balance[] memory collaterals = new Balance[](1);
        collaterals[0] = Balance({collateralId: usdcId, amount: usdcStrikePrice});

        Position[] memory longs = new Position[](0);
        Position[] memory shorts = new Position[](1);
        shorts[0] = Position({tokenId: tokenId, amount: uint64(2 * UNIT)});

        (address[] memory addresses, uint256[] memory amounts, bool isUnderWater) =
            engine.previewCollateralAvailable(shorts, longs, collaterals);

        assertEq(addresses.length, 1);
        assertEq(addresses[0], address(usdc));

        assertEq(amounts.length, 1);
        assertEq(amounts[0], 0);

        assertEq(isUnderWater, true);
    }

    function testPreviewCollateralAvailableUnusedCollat() public {
        Balance[] memory collaterals = new Balance[](2);
        collaterals[0] = Balance({collateralId: usdcId, amount: 1600 * 1e6});
        collaterals[1] = Balance({collateralId: wethId, amount: 1 * 1e18});

        Position[] memory longs = new Position[](0);
        Position[] memory shorts = new Position[](0);

        (address[] memory addresses, uint256[] memory amounts, bool isUnderWater) =
            engine.previewCollateralAvailable(shorts, longs, collaterals);

        assertEq(addresses.length, 2);
        assertEq(addresses[0], address(0));
        assertEq(addresses[1], address(0));

        assertEq(amounts.length, 2);
        assertEq(amounts[0], 0);
        assertEq(amounts[1], 0);

        assertEq(isUnderWater, false);
    }
}

contract TestPreviewCollateralAvailablePM_CMC is CrossMarginCashFixture {
    MockERC20 internal lsEth;
    MockERC20 internal usyc;

    uint8 internal lsEthId;
    uint8 internal usycId;

    uint40 internal pidLsEthCollat;
    uint40 internal pidUsycCollat;

    uint256 public expiry;

    function setUp() public {
        lsEth = new MockERC20("LsETH", "LsETH", 18);
        vm.label(address(lsEth), "LsETH");

        usyc = new MockERC20("USYC", "USYC", 6);
        vm.label(address(usyc), "USYC");

        lsEthId = grappa.registerAsset(address(lsEth));
        usycId = grappa.registerAsset(address(usyc));

        engine.setCollateralizable(address(weth), address(lsEth), true);
        engine.setCollateralizable(address(usdc), address(usyc), true);

        pidLsEthCollat = grappa.getProductId(address(oracle), address(engine), address(weth), address(usdc), address(lsEth));
        pidUsycCollat = grappa.getProductId(address(oracle), address(engine), address(weth), address(usdc), address(usyc));

        lsEth.mint(address(this), 100 * 1e18);
        usyc.mint(address(this), 1000_000 * 1e6);

        expiry = block.timestamp + 14 days;

        oracle.setSpotPrice(address(lsEth), 3000 * UNIT);
        oracle.setSpotPrice(address(usyc), 1 * UNIT);
    }

    function testPreviewCollateralEqualShortLong() public {
        uint256 depositAmount = 1 * 1e18;

        uint256 strikePrice = 4000 * UNIT;
        uint256 amount = 1 * UNIT;

        uint256 tokenId = getTokenId(TokenType.CALL, pidEthCollat, expiry, strikePrice, 0);

        Position[] memory longs = new Position[](1);
        Position[] memory shorts = new Position[](1);
        Balance[] memory collaterals = new Balance[](1);

        collaterals[0] = Balance({collateralId: wethId, amount: uint80(depositAmount)});
        shorts[0] = Position({tokenId: tokenId, amount: uint64(amount)});
        longs[0] = Position({tokenId: tokenId, amount: uint64(amount)});

        (address[] memory addresses, uint256[] memory amounts, bool isUnderWater) =
            engine.previewCollateralAvailable(shorts, longs, collaterals);

        assertEq(addresses.length, 1);
        assertEq(addresses[0], address(0));
        assertEq(amounts.length, 1);
        assertEq(amounts[0], 0);
        assertEq(isUnderWater, false);
    }

    function testPreviewCollateralEqualCallSpread() public {
        uint256 depositAmount = 1 * 1e18;

        uint256 strikePrice = 4000 * UNIT;
        uint256 amount = 1 * UNIT;

        uint256 strikeSpread = 1 * UNIT;

        uint256 shortId = getTokenId(TokenType.CALL, pidEthCollat, expiry, strikePrice - strikeSpread, 0);
        uint256 longId = getTokenId(TokenType.CALL, pidEthCollat, expiry, strikePrice, 0);

        Position[] memory longs = new Position[](1);
        Position[] memory shorts = new Position[](1);
        Balance[] memory collaterals = new Balance[](1);

        collaterals[0] = Balance({collateralId: wethId, amount: uint80(depositAmount)});
        shorts[0] = Position({tokenId: shortId, amount: uint64(amount)});
        longs[0] = Position({tokenId: longId, amount: uint64(amount)});

        (address[] memory addresses, uint256[] memory amounts, bool isUnderWater) =
            engine.previewCollateralAvailable(shorts, longs, collaterals);

        uint256 underlyingRequired = (((strikeSpread * UNIT) / strikePrice) * (10 ** (18 - 6)));

        assertEq(addresses.length, 1);
        assertEq(addresses[0], address(weth));
        assertEq(amounts.length, 1);
        assertEq(amounts[0], depositAmount - underlyingRequired);
        assertEq(isUnderWater, false);
    }

    function testPreviewCollateralEqualPutSpread() public {
        uint256 depositAmount = 2000 * 1e6;

        uint256 strikePrice = 2000 * UNIT;
        uint256 amount = 1 * UNIT;

        uint256 strikeSpread = 1;

        uint256 tokenId = getTokenId(TokenType.PUT, pidUsdcCollat, expiry, strikePrice, 0);
        uint256 tokenId2 = getTokenId(TokenType.PUT, pidUsdcCollat, expiry, strikePrice - strikeSpread, 0);

        Position[] memory longs = new Position[](1);
        Position[] memory shorts = new Position[](1);
        Balance[] memory collaterals = new Balance[](1);

        collaterals[0] = Balance({collateralId: usdcId, amount: uint80(depositAmount)});
        shorts[0] = Position({tokenId: tokenId, amount: uint64(amount)});
        longs[0] = Position({tokenId: tokenId2, amount: uint64(amount)});

        (address[] memory addresses, uint256[] memory amounts, bool isUnderWater) =
            engine.previewCollateralAvailable(shorts, longs, collaterals);

        uint256 strikeSpreadScaled = strikeSpread * (10 ** (6 - 6));

        assertEq(addresses.length, 1);
        assertEq(addresses[0], address(usdc));
        assertEq(amounts.length, 1);
        assertEq(amounts[0], depositAmount - strikeSpreadScaled);
        assertEq(isUnderWater, false);
    }

    function testPreviewCollateralAvailablePut() public {
        uint256 strikePrice = 2000 * UNIT;
        uint256 amount = 1 * UNIT;
        uint256 depositAmount = 2000 * 1e6;

        uint256 tokenId = getTokenId(TokenType.PUT, pidUsycCollat, expiry, strikePrice, 0);

        Position[] memory longs = new Position[](0);
        Position[] memory shorts = new Position[](1);
        Balance[] memory collaterals = new Balance[](1);

        collaterals[0] = Balance({collateralId: usycId, amount: uint80(depositAmount)});
        shorts[0] = Position({tokenId: tokenId, amount: uint64(amount)});

        uint256 newUsycPrice = 1_040000; // worth more due to interest ($1.04)

        oracle.setSpotPrice(address(usyc), newUsycPrice);

        (address[] memory addresses, uint256[] memory amounts, bool isUnderWater) =
            engine.previewCollateralAvailable(shorts, longs, collaterals);

        assertEq(addresses.length, 1);
        assertEq(addresses[0], address(usyc));
        assertEq(amounts.length, 1);
        assertEq(amounts[0], depositAmount - strikePrice * UNIT / newUsycPrice);
        assertEq(isUnderWater, false);
    }

    function testPreviewCollateralAvailableCall() public {
        uint256 strikePrice = 4000 * UNIT;
        uint256 amount = 1 * UNIT;
        uint256 depositAmount = 1 * 1e18;

        uint256 tokenId = getTokenId(TokenType.CALL, pidLsEthCollat, expiry, strikePrice, 0);

        Position[] memory longs = new Position[](0);
        Position[] memory shorts = new Position[](1);
        Balance[] memory collaterals = new Balance[](1);

        collaterals[0] = Balance({collateralId: lsEthId, amount: uint80(depositAmount)});
        shorts[0] = Position({tokenId: tokenId, amount: uint64(amount)});

        uint256 newLsEthPrice = 3200 * UNIT;
        oracle.setSpotPrice(address(lsEth), newLsEthPrice);

        (address[] memory addresses, uint256[] memory amounts, bool isUnderWater) =
            engine.previewCollateralAvailable(shorts, longs, collaterals);

        assertEq(addresses.length, 1);
        assertEq(addresses[0], address(lsEth));
        assertEq(amounts.length, 1);
        assertEq(amounts[0], depositAmount - depositAmount * UNIT / newLsEthPrice);
        assertEq(isUnderWater, false);
    }
}
