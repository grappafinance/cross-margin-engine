// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import {CrossMarginPhysicalFixture} from "./CrossMarginPhysicalFixture.t.sol";

import "pomace/config/enums.sol";
import "pomace/config/types.sol";
import "pomace/config/constants.sol";
import "pomace/config/errors.sol";

import "../../src/settled-physical/types.sol";
import "../../src/libraries/AccountUtil.sol";

contract PreviewCollateralReqBase_CMP is CrossMarginPhysicalFixture {
    uint8 constant PUT = uint8(0);
    uint8 constant CALL = uint8(1);

    uint256 public expiry;

    struct OptionPosition {
        TokenType tokenType;
        uint256 strike;
        int256 amount;
    }

    function _optionPosition(uint8 tokenType, uint256 strike, int256 amount) internal pure returns (OptionPosition memory op) {
        if (strike <= UNIT) strike = strike * UNIT;
        return OptionPosition(TokenType(tokenType), strike, amount * sUNIT);
    }

    function _previewMinCollateral(OptionPosition[] memory postions) internal view returns (Balance[] memory balances) {
        (Position[] memory shorts, Position[] memory longs) = _convertPositions(postions);
        balances = engine.previewMinCollateral(shorts, longs);
    }

    function _convertPositions(OptionPosition[] memory positions)
        internal
        view
        returns (Position[] memory shorts, Position[] memory longs)
    {
        for (uint256 i = 0; i < positions.length; i++) {
            OptionPosition memory position = positions[i];

            uint256 tokenId = TokenType.CALL == position.tokenType ? _callTokenId(position.strike) : _putTokenId(position.strike);

            if (position.amount < 0) {
                shorts = AccountUtil.append(shorts, Position(tokenId, uint64(uint256(-position.amount))));
            } else {
                longs = AccountUtil.append(longs, Position(tokenId, uint64(uint256(position.amount))));
            }
        }
    }

    function _callTokenId(uint256 _strikePrice) internal view returns (uint256 tokenId) {
        tokenId = getTokenId(TokenType.CALL, pidEthCollat, expiry, _strikePrice, 30 minutes);
    }

    function _putTokenId(uint256 _strikePrice) internal view returns (uint256 tokenId) {
        tokenId = getTokenId(TokenType.PUT, pidUsdcCollat, expiry, _strikePrice, 30 minutes);
    }

    // add a function prefixed with test here so forge coverage will ignore this file
    function testIgnore() public {}
}

contract PreviewCollateralReq_CMPM is PreviewCollateralReqBase_CMP {
    function setUp() public {
        expiry = block.timestamp + 14 days;
    }

    function testMarginRequirement1() public {
        OptionPosition[] memory positions = new OptionPosition[](6);
        positions[0] = _optionPosition(CALL, 21000, -1);
        positions[1] = _optionPosition(CALL, 22000, -8);
        positions[2] = _optionPosition(CALL, 25000, 16);
        positions[3] = _optionPosition(CALL, 26000, -6);
        positions[4] = _optionPosition(PUT, 17000, -1);
        positions[5] = _optionPosition(PUT, 18000, 1);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, usdcId);
        assertEq(balances[0].amount, 28000 * UNIT);
    }

    function testMarginRequirement2() public {
        OptionPosition[] memory positions = new OptionPosition[](6);
        positions[0] = OptionPosition(TokenType.CALL, 21000 * UNIT, -1 * sUNIT);
        positions[1] = OptionPosition(TokenType.CALL, 22000 * UNIT, -8 * sUNIT);
        positions[2] = OptionPosition(TokenType.CALL, 25000 * UNIT, 16 * sUNIT);
        positions[3] = OptionPosition(TokenType.CALL, 26000 * UNIT, -7 * sUNIT);
        positions[4] = OptionPosition(TokenType.PUT, 17000 * UNIT, -1 * sUNIT);
        positions[5] = OptionPosition(TokenType.PUT, 18000 * UNIT, 1 * sUNIT);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, usdcId);
        assertEq(balances[0].amount, 28000 * UNIT);
    }

    function testMarginRequirement3() public {
        OptionPosition[] memory positions = new OptionPosition[](6);
        positions[0] = OptionPosition(TokenType.CALL, 21000 * UNIT, -1 * sUNIT);
        positions[1] = OptionPosition(TokenType.CALL, 22000 * UNIT, -8 * sUNIT);
        positions[2] = OptionPosition(TokenType.CALL, 25000 * UNIT, 16 * sUNIT);
        positions[3] = OptionPosition(TokenType.CALL, 26000 * UNIT, -8 * sUNIT);
        positions[4] = OptionPosition(TokenType.PUT, 17000 * UNIT, -1 * sUNIT);
        positions[5] = OptionPosition(TokenType.PUT, 18000 * UNIT, 1 * sUNIT);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 2);
        assertEq(balances[0].collateralId, usdcId);
        assertEq(balances[0].amount, 28000 * UNIT);
        assertEq(balances[1].collateralId, wethId);
        assertEq(balances[1].amount, 1 * 1e18);
    }

    function testMarginRequirement4() public {
        OptionPosition[] memory positions = new OptionPosition[](6);
        positions[0] = OptionPosition(TokenType.CALL, 21000 * UNIT, -1 * sUNIT);
        positions[1] = OptionPosition(TokenType.CALL, 22000 * UNIT, -8 * sUNIT);
        positions[2] = OptionPosition(TokenType.CALL, 25000 * UNIT, 16 * sUNIT);
        positions[3] = OptionPosition(TokenType.CALL, 26000 * UNIT, -6 * sUNIT);
        positions[4] = OptionPosition(TokenType.PUT, 17000 * UNIT, -3 * sUNIT);
        positions[5] = OptionPosition(TokenType.PUT, 18000 * UNIT, 1 * sUNIT);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, usdcId);
        assertEq(balances[0].amount, 33000 * UNIT);
    }

    function testMarginUnsortedStrikes() public {
        OptionPosition[] memory positions = new OptionPosition[](6);
        positions[0] = OptionPosition(TokenType.CALL, 22000 * UNIT, -8 * sUNIT);
        positions[1] = OptionPosition(TokenType.CALL, 26000 * UNIT, -6 * sUNIT);
        positions[2] = OptionPosition(TokenType.CALL, 21000 * UNIT, -1 * sUNIT);
        positions[3] = OptionPosition(TokenType.CALL, 25000 * UNIT, 16 * sUNIT);
        positions[4] = OptionPosition(TokenType.PUT, 18000 * UNIT, 1 * sUNIT);
        positions[5] = OptionPosition(TokenType.PUT, 17000 * UNIT, -1 * sUNIT);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, usdcId);
        assertEq(balances[0].amount, 28000 * UNIT);
    }

    function testMarginSimplePut() public {
        OptionPosition[] memory positions = new OptionPosition[](1);
        positions[0] = OptionPosition(TokenType.PUT, 15000 * UNIT, -1 * sUNIT);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, usdcId);
        assertEq(balances[0].amount, 15000 * UNIT);
    }

    function testMarginSimpleCall() public {
        OptionPosition[] memory positions = new OptionPosition[](1);
        positions[0] = OptionPosition(TokenType.CALL, 22000 * UNIT, -1 * sUNIT);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, wethId);
        assertEq(balances[0].amount, 1 * 1e18);
    }

    function testMarginLongBinaryPut() public {
        OptionPosition[] memory positions = new OptionPosition[](2);
        positions[0] = OptionPosition(TokenType.PUT, 17999_999999, -1 * sUNIT);
        positions[1] = OptionPosition(TokenType.PUT, 18000 * UNIT, 1 * sUNIT);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 0);
    }

    function testMarginShortBinaryPut() public {
        OptionPosition[] memory positions = new OptionPosition[](2);
        positions[0] = OptionPosition(TokenType.PUT, 17999_999999, 1 * sUNIT);
        positions[1] = OptionPosition(TokenType.PUT, 18000 * UNIT, -1 * sUNIT);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, usdcId);
        assertEq(balances[0].amount, 1);
    }

    function testMarginCallSpreadSameUnderlyingCollateral() public {
        OptionPosition[] memory positions = new OptionPosition[](2);
        positions[0] = OptionPosition(TokenType.CALL, 21999 * UNIT, -1 * sUNIT);
        positions[1] = OptionPosition(TokenType.CALL, 22000 * UNIT, 1 * sUNIT);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, wethId);
        assertEq(balances[0].amount, ((1 * UNIT) / 22000) * (10 ** (18 - UNIT_DECIMALS)));
    }

    function testMarginCallSpreadSameUnderlyingCollateralBiggerNumbers() public {
        OptionPosition[] memory positions = new OptionPosition[](2);
        positions[0] = OptionPosition(TokenType.CALL, 21000 * UNIT, -100000 * sUNIT);
        positions[1] = OptionPosition(TokenType.CALL, 22000 * UNIT, 100000 * sUNIT);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, wethId);
        assertEq(balances[0].amount, ((100000 * 1000 * UNIT) / 22000) * (10 ** (18 - UNIT_DECIMALS)));
    }

    function testMarginBinaryCallOption() public {
        OptionPosition[] memory positions = new OptionPosition[](2);
        positions[0] = OptionPosition(TokenType.CALL, 21999_999999, 1 * sUNIT);
        positions[1] = OptionPosition(TokenType.CALL, 22000 * UNIT, -1 * sUNIT);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 0);
    }

    function testConversion() public {
        OptionPosition[] memory positions = new OptionPosition[](2);
        positions[0] = OptionPosition(TokenType.CALL, 17000 * UNIT, -1 * sUNIT);
        positions[1] = OptionPosition(TokenType.PUT, 17000 * UNIT, -1 * sUNIT);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 2);
        assertEq(balances[0].collateralId, usdcId);
        assertEq(balances[0].amount, 17000 * UNIT);
        assertEq(balances[1].collateralId, wethId);
        assertEq(balances[1].amount, 1 * 1e18);

        positions[0] = OptionPosition(TokenType.CALL, 17000 * UNIT, -314 * sUNIT);

        balances = _previewMinCollateral(positions);

        assertEq(balances.length, 2);
        assertEq(balances[0].collateralId, usdcId);
        assertEq(balances[0].amount, 17000 * UNIT);
        assertEq(balances[1].collateralId, wethId);
        assertEq(balances[1].amount, 314 * 1e18);
    }

    function testMarginRequirementsVanillaCall() public {
        OptionPosition[] memory positions = new OptionPosition[](1);
        positions[0] = OptionPosition(TokenType.CALL, 21000 * UNIT, -1 * sUNIT);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, wethId);
        assertEq(balances[0].amount, 1 * 1e18);
    }

    function testMarginRequirementsVanillaPut() public {
        OptionPosition[] memory positions = new OptionPosition[](1);
        positions[0] = OptionPosition(TokenType.PUT, 18000 * UNIT, -1 * sUNIT);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, usdcId);
        assertEq(balances[0].amount, 18000 * UNIT);
    }

    function testShortStrangles() public {
        OptionPosition[] memory positions = new OptionPosition[](2);

        positions[0] = OptionPosition(TokenType.CALL, 20000 * UNIT, -1 * sUNIT);
        positions[1] = OptionPosition(TokenType.PUT, 18000 * UNIT, -1 * sUNIT);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 2);
        assertEq(balances[0].collateralId, usdcId);
        assertEq(balances[0].amount, 18000 * UNIT);
        assertEq(balances[1].collateralId, wethId);
        assertEq(balances[1].amount, 1 * 1e18);
    }

    function testLongStrangles() public {
        OptionPosition[] memory positions = new OptionPosition[](2);
        positions[0] = OptionPosition(TokenType.CALL, 20000 * UNIT, 1 * sUNIT);
        positions[1] = OptionPosition(TokenType.PUT, 18000 * UNIT, 1 * sUNIT);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 0);
    }

    function testStrangleSpread() public {
        OptionPosition[] memory positions = new OptionPosition[](4);

        positions[0] = OptionPosition(TokenType.CALL, 20000 * UNIT, -1 * sUNIT);
        positions[1] = OptionPosition(TokenType.CALL, 21000 * UNIT, 1 * sUNIT);
        positions[2] = OptionPosition(TokenType.PUT, 17000 * UNIT, -1 * sUNIT);
        positions[3] = OptionPosition(TokenType.PUT, 18000 * UNIT, 1 * sUNIT);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, usdcId);
        assertEq(balances[0].amount, 1000 * UNIT);
    }

    function testStrangleSpread2() public {
        OptionPosition[] memory positions = new OptionPosition[](4);

        positions[0] = OptionPosition(TokenType.CALL, 20000 * UNIT, -1 * sUNIT);
        positions[1] = OptionPosition(TokenType.CALL, 21000 * UNIT, 1 * sUNIT);
        positions[2] = OptionPosition(TokenType.PUT, 17000 * UNIT, 1 * sUNIT);
        positions[3] = OptionPosition(TokenType.PUT, 18000 * UNIT, -1 * sUNIT);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, usdcId);
        assertEq(balances[0].amount, 1000 * UNIT);
    }

    function testOneByTwoCall() public {
        OptionPosition[] memory positions = new OptionPosition[](4);

        positions[0] = OptionPosition(TokenType.CALL, 20000 * UNIT, 1 * sUNIT);
        positions[1] = OptionPosition(TokenType.CALL, 21000 * UNIT, -2 * sUNIT);
        positions[2] = OptionPosition(TokenType.PUT, 0, 0);
        positions[3] = OptionPosition(TokenType.PUT, 0, 0);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 1);

        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, wethId);
        assertEq(balances[0].amount, 1 * 1e18);
    }

    function testOneByTwoPut() public {
        OptionPosition[] memory positions = new OptionPosition[](4);

        positions[0] = OptionPosition(TokenType.CALL, 0, 0);
        positions[1] = OptionPosition(TokenType.CALL, 0, 0);
        positions[2] = OptionPosition(TokenType.PUT, 17000 * UNIT, -2 * sUNIT);
        positions[3] = OptionPosition(TokenType.PUT, 18000 * UNIT, 1 * sUNIT);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 1);

        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, usdcId);
        assertEq(balances[0].amount, 16000 * UNIT);
    }

    function testIronCondor() public {
        OptionPosition[] memory positions = new OptionPosition[](4);

        positions[0] = OptionPosition(TokenType.CALL, 20000 * UNIT, 1 * sUNIT);
        positions[1] = OptionPosition(TokenType.CALL, 21000 * UNIT, -2 * sUNIT);
        positions[2] = OptionPosition(TokenType.PUT, 17000 * UNIT, -2 * sUNIT);
        positions[3] = OptionPosition(TokenType.PUT, 18000 * UNIT, 1 * sUNIT);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 2);
        assertEq(balances[0].collateralId, usdcId);
        assertEq(balances[0].amount, 16000 * UNIT);
        assertEq(balances[1].collateralId, wethId);
        assertEq(balances[1].amount, 1 * 1e18);
    }

    function testUpAndDown1() public {
        OptionPosition[] memory positions = new OptionPosition[](2);
        positions[0] = OptionPosition(TokenType.PUT, 17000 * UNIT, -18 * sUNIT);
        positions[1] = OptionPosition(TokenType.PUT, 18000 * UNIT, 17 * sUNIT);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 0);
    }

    function testLongPutSpread() public {
        OptionPosition[] memory positions = new OptionPosition[](2);
        positions[0] = OptionPosition(TokenType.PUT, 17000 * UNIT, -1 * sUNIT);
        positions[1] = OptionPosition(TokenType.PUT, 18000 * UNIT, 1 * sUNIT);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 0);
    }

    function testShortPutSpread() public {
        OptionPosition[] memory positions = new OptionPosition[](2);
        positions[0] = OptionPosition(TokenType.PUT, 17000 * UNIT, 1 * sUNIT);
        positions[1] = OptionPosition(TokenType.PUT, 18000 * UNIT, -1 * sUNIT);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, usdcId);
        assertEq(balances[0].amount, 1000 * UNIT);
    }

    function testUpAndDown2() public {
        OptionPosition[] memory positions = new OptionPosition[](2);
        positions[0] = OptionPosition(TokenType.PUT, 17000 * UNIT, -18 * sUNIT);
        positions[1] = OptionPosition(TokenType.PUT, 18000 * UNIT, 16 * sUNIT);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, usdcId);
        assertEq(balances[0].amount, 18000 * UNIT);
    }

    function testUpAndDown3() public {
        OptionPosition[] memory positions = new OptionPosition[](3);
        positions[0] = OptionPosition(TokenType.CALL, 20000 * UNIT, 1 * sUNIT);
        positions[1] = OptionPosition(TokenType.PUT, 17000 * UNIT, -18 * sUNIT);
        positions[2] = OptionPosition(TokenType.PUT, 18000 * UNIT, 17 * sUNIT);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 0);
    }

    function testUpAndDown4() public {
        OptionPosition[] memory positions = new OptionPosition[](4);
        positions[0] = OptionPosition(TokenType.CALL, 20000 * UNIT, 1 * sUNIT);
        positions[1] = OptionPosition(TokenType.CALL, 21000 * UNIT, -2 * sUNIT);
        positions[2] = OptionPosition(TokenType.PUT, 17000 * UNIT, -18 * sUNIT);
        positions[3] = OptionPosition(TokenType.PUT, 18000 * UNIT, 17 * sUNIT);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, wethId);
        assertEq(balances[0].amount, 1 * 1e18);
    }

    function testPutGreaterThanCalls() public {
        OptionPosition[] memory positions = new OptionPosition[](4);
        positions[0] = OptionPosition(TokenType.CALL, 23000 * UNIT, 1 * sUNIT);
        positions[1] = OptionPosition(TokenType.CALL, 22000 * UNIT, -1 * sUNIT);
        positions[2] = OptionPosition(TokenType.PUT, 25000 * UNIT, -1 * sUNIT);
        positions[3] = OptionPosition(TokenType.PUT, 10000 * UNIT, 1 * sUNIT);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, usdcId);
        assertEq(balances[0].amount, 15000 * UNIT);
    }
}
