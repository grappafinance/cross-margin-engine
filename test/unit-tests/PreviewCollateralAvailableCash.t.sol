// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import {CrossMarginCashFixture} from "../integrations-cash/CrossMarginCashFixture.t.sol";

import "grappa/config/types.sol";
import "grappa/config/constants.sol";

import "../../src/config/types.sol";

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
