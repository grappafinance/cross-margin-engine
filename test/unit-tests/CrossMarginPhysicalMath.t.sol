// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {CrossMarginPhysicalMath} from "../../src/settled-physical/CrossMarginPhysicalMath.sol";
import "pomace/config/constants.sol";
import "../../src/config/errors.sol";

import "../../src/config/types.sol";
import "forge-std/console2.sol";

/**
 * test full margin calculation for complicated structure
 */
// solhint-disable-next-line contract-name-camelcase
contract TestStructures_CMPM is Test {
    using CrossMarginPhysicalMath for CrossMarginDetail;

    int256[] private putWeights;
    uint256[] private putStrikes;

    int256[] private callWeights;
    uint256[] private callStrikes;

    function setUp() public {
        putWeights = new int256[](2);
        putWeights[0] = -1 * sUNIT;
        putWeights[1] = 1 * sUNIT;

        putStrikes = new uint256[](2);
        putStrikes[0] = 17000 * UNIT;
        putStrikes[1] = 18000 * UNIT;

        callWeights = new int256[](4);
        callWeights[0] = -1 * sUNIT;
        callWeights[1] = -8 * sUNIT;
        callWeights[2] = 16 * sUNIT;
        callWeights[3] = -6 * sUNIT;

        callStrikes = new uint256[](4);
        callStrikes[0] = 21000 * UNIT;
        callStrikes[1] = 22000 * UNIT;
        callStrikes[2] = 25000 * UNIT;
        callStrikes[3] = 26000 * UNIT;
    }

    function testVerifyInputs2() public {
        callWeights[2] = 0;

        CrossMarginDetail memory detail = CrossMarginDetail({
            putWeights: putWeights,
            putStrikes: putStrikes,
            callWeights: callWeights,
            callStrikes: callStrikes,
            underlyingId: 0,
            underlyingDecimals: UNIT_DECIMALS,
            numeraireId: 1,
            numeraireDecimals: UNIT_DECIMALS,
            expiry: 0
        });
        vm.expectRevert(CMM_InvalidCallWeight.selector);
        detail.getMinCollateral();
    }

    function testVerifyInputs3() public {
        putWeights = new int256[](3);
        putWeights[0] = -1 * sUNIT;
        putWeights[1] = 1 * sUNIT;
        putWeights[2] = 1 * sUNIT;

        CrossMarginDetail memory detail = CrossMarginDetail({
            putWeights: putWeights,
            putStrikes: putStrikes,
            callWeights: callWeights,
            callStrikes: callStrikes,
            underlyingId: 0,
            underlyingDecimals: UNIT_DECIMALS,
            numeraireId: 1,
            numeraireDecimals: UNIT_DECIMALS,
            expiry: 0
        });

        vm.expectRevert(CMM_InvalidPutLengths.selector);
        detail.getMinCollateral();
    }

    function testVerifyInputs4() public {
        callWeights = new int256[](3);
        callWeights[0] = -1 * sUNIT;
        callWeights[1] = 1 * sUNIT;
        callWeights[2] = 1 * sUNIT;

        CrossMarginDetail memory detail = CrossMarginDetail({
            putWeights: putWeights,
            putStrikes: putStrikes,
            callWeights: callWeights,
            callStrikes: callStrikes,
            underlyingId: 0,
            underlyingDecimals: UNIT_DECIMALS,
            numeraireId: 1,
            numeraireDecimals: UNIT_DECIMALS,
            expiry: 0
        });
        vm.expectRevert(CMM_InvalidCallLengths.selector);
        detail.getMinCollateral();
    }

    function testMarginRequirement1() public {
        CrossMarginDetail memory detail = CrossMarginDetail({
            putWeights: putWeights,
            putStrikes: putStrikes,
            callWeights: callWeights,
            callStrikes: callStrikes,
            underlyingId: 0,
            underlyingDecimals: UNIT_DECIMALS,
            numeraireId: 1,
            numeraireDecimals: UNIT_DECIMALS,
            expiry: 0
        });

        (uint256 numeraireNeeded, uint256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(numeraireNeeded, 28000 * UNIT);
        assertEq(underlyingNeeded, 0);
    }

    function testMarginRequirement2() public {
        callWeights[3] = -7 * sUNIT;
        console2.log("entered, set call weights", callWeights[3]);

        CrossMarginDetail memory detail = CrossMarginDetail({
            putWeights: putWeights,
            putStrikes: putStrikes,
            callWeights: callWeights,
            callStrikes: callStrikes,
            underlyingId: 0,
            underlyingDecimals: UNIT_DECIMALS,
            numeraireId: 1,
            numeraireDecimals: UNIT_DECIMALS,
            expiry: 0
        });

        console2.log("set detail", callWeights[3]);

        (uint256 numeraireNeeded, uint256 underlyingNeeded) = detail.getMinCollateral();
        console2.log("get min collat", numeraireNeeded, underlyingNeeded);

        assertEq(numeraireNeeded, 28000 * UNIT);
        assertEq(underlyingNeeded, 0);
    }

    function testMarginRequirement3() public {
        callWeights[3] = -8 * sUNIT;

        CrossMarginDetail memory detail = CrossMarginDetail({
            putWeights: putWeights,
            putStrikes: putStrikes,
            callWeights: callWeights,
            callStrikes: callStrikes,
            underlyingId: 0,
            underlyingDecimals: UNIT_DECIMALS,
            numeraireId: 1,
            numeraireDecimals: UNIT_DECIMALS,
            expiry: 0
        });

        (uint256 numeraireNeeded, uint256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(numeraireNeeded, 28000 * UNIT);
        assertEq(underlyingNeeded, 1 * UNIT);
    }

    function testMarginRequirement4() public {
        putWeights[0] = -3 * sUNIT;
        putWeights[1] = 1 * sUNIT;

        CrossMarginDetail memory detail = CrossMarginDetail({
            putWeights: putWeights,
            putStrikes: putStrikes,
            callWeights: callWeights,
            callStrikes: callStrikes,
            underlyingId: 0,
            underlyingDecimals: UNIT_DECIMALS,
            numeraireId: 1,
            numeraireDecimals: UNIT_DECIMALS,
            expiry: 0
        });

        (uint256 numeraireNeeded, uint256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(numeraireNeeded, 33000 * UNIT);
        assertEq(underlyingNeeded, 0);
    }

    function testMarginUnsortedStrikes() public {
        putWeights[0] = 1 * sUNIT;
        putWeights[1] = -1 * sUNIT;

        putStrikes[0] = 18000 * UNIT;
        putStrikes[1] = 17000 * UNIT;

        callWeights[0] = -8 * sUNIT;
        callWeights[1] = -6 * sUNIT;
        callWeights[2] = -1 * sUNIT;
        callWeights[3] = 16 * sUNIT;

        callStrikes[0] = 22000 * UNIT;
        callStrikes[1] = 26000 * UNIT;
        callStrikes[2] = 21000 * UNIT;
        callStrikes[3] = 25000 * UNIT;

        CrossMarginDetail memory detail = CrossMarginDetail({
            putWeights: putWeights,
            putStrikes: putStrikes,
            callWeights: callWeights,
            callStrikes: callStrikes,
            underlyingId: 0,
            underlyingDecimals: UNIT_DECIMALS,
            numeraireId: 1,
            numeraireDecimals: UNIT_DECIMALS,
            expiry: 0
        });

        (uint256 numeraireNeeded, uint256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(numeraireNeeded, 28000 * UNIT);
        assertEq(underlyingNeeded, 0);
    }

    function testMarginSimplePut() public {
        putWeights = new int256[](1);
        putWeights[0] = -1 * sUNIT;

        putStrikes = new uint256[](1);
        putStrikes[0] = 15000 * UNIT;

        callWeights = new int256[](0);
        callStrikes = new uint256[](0);

        CrossMarginDetail memory detail = CrossMarginDetail({
            putWeights: putWeights,
            putStrikes: putStrikes,
            callWeights: callWeights,
            callStrikes: callStrikes,
            underlyingId: 0,
            underlyingDecimals: UNIT_DECIMALS,
            numeraireId: 1,
            numeraireDecimals: UNIT_DECIMALS,
            expiry: 0
        });

        (uint256 numeraireNeeded, uint256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(numeraireNeeded, putStrikes[0]);
        assertEq(underlyingNeeded, 0);
    }

    function testMarginSimpleCall() public {
        putWeights = new int256[](0);
        putStrikes = new uint256[](0);

        callWeights = new int256[](1);
        callWeights[0] = -1 * sUNIT;

        callStrikes = new uint256[](1);
        callStrikes[0] = 22000 * UNIT;

        CrossMarginDetail memory detail = CrossMarginDetail({
            putWeights: putWeights,
            putStrikes: putStrikes,
            callWeights: callWeights,
            callStrikes: callStrikes,
            underlyingId: 0,
            underlyingDecimals: UNIT_DECIMALS,
            numeraireId: 1,
            numeraireDecimals: UNIT_DECIMALS,
            expiry: 0
        });

        (uint256 numeraireNeeded, uint256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(numeraireNeeded, 0);
        assertEq(underlyingNeeded, 1 * UNIT);
    }

    function testMarginPutSpread1() public {
        putWeights = new int256[](2);
        putWeights[0] = 1 * sUNIT;
        putWeights[1] = -1 * sUNIT;

        putStrikes = new uint256[](2);
        putStrikes[0] = 17999_999999;
        putStrikes[1] = 18000 * UNIT;

        callWeights = new int256[](0);
        callStrikes = new uint256[](0);

        CrossMarginDetail memory detail = CrossMarginDetail({
            putWeights: putWeights,
            putStrikes: putStrikes,
            callWeights: callWeights,
            callStrikes: callStrikes,
            underlyingId: 0,
            underlyingDecimals: UNIT_DECIMALS,
            numeraireId: 1,
            numeraireDecimals: UNIT_DECIMALS,
            expiry: 0
        });

        (uint256 numeraireNeeded, uint256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(numeraireNeeded, 1);
        assertEq(underlyingNeeded, 0);
    }

    function testMarginLongBinaryPut() public {
        putWeights = new int256[](2);
        putWeights[0] = -1 * sUNIT;
        putWeights[1] = 1 * sUNIT;

        putStrikes = new uint256[](2);
        putStrikes[0] = 17999_999999;
        putStrikes[1] = 18000 * UNIT;

        callWeights = new int256[](0);
        callStrikes = new uint256[](0);

        CrossMarginDetail memory detail = CrossMarginDetail({
            putWeights: putWeights,
            putStrikes: putStrikes,
            callWeights: callWeights,
            callStrikes: callStrikes,
            underlyingId: 0,
            underlyingDecimals: UNIT_DECIMALS,
            numeraireId: 0,
            numeraireDecimals: UNIT_DECIMALS,
            expiry: 0
        });

        (uint256 numeraireNeeded, uint256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(numeraireNeeded, 0);
        assertEq(underlyingNeeded, 0);
    }

    function testMarginShortBinaryPut() public {
        putWeights = new int256[](2);
        putWeights[0] = 1 * sUNIT;
        putWeights[1] = -1 * sUNIT;

        putStrikes = new uint256[](2);
        putStrikes[0] = 17999_999999;
        putStrikes[1] = 18000 * UNIT;

        callWeights = new int256[](0);
        callStrikes = new uint256[](0);

        CrossMarginDetail memory detail = CrossMarginDetail({
            putWeights: putWeights,
            putStrikes: putStrikes,
            callWeights: callWeights,
            callStrikes: callStrikes,
            underlyingId: 0,
            underlyingDecimals: UNIT_DECIMALS,
            numeraireId: 1,
            numeraireDecimals: UNIT_DECIMALS,
            expiry: 0
        });

        (uint256 numeraireNeeded, uint256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(numeraireNeeded, 1);
        assertEq(underlyingNeeded, 0);
    }

    function testMarginCallSpreadSameUnderlyingCollateral() public {
        callWeights = new int256[](2);
        callWeights[0] = -1 * sUNIT;
        callWeights[1] = 1 * sUNIT;

        callStrikes = new uint256[](2);
        callStrikes[0] = 21999 * UNIT;
        callStrikes[1] = 22000 * UNIT;

        putWeights = new int256[](0);
        putStrikes = new uint256[](0);

        CrossMarginDetail memory detail = CrossMarginDetail({
            putWeights: putWeights,
            putStrikes: putStrikes,
            callWeights: callWeights,
            callStrikes: callStrikes,
            underlyingId: 0,
            underlyingDecimals: UNIT_DECIMALS,
            numeraireId: 0,
            numeraireDecimals: UNIT_DECIMALS,
            expiry: 0
        });

        (uint256 numeraireNeeded, uint256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(numeraireNeeded, 0);
        assertEq(underlyingNeeded, (1 * UNIT) / 22000);
    }

    function testMarginCallSpreadSameUnderlyingCollateralBiggerNumbers() public {
        callWeights = new int256[](2);
        callWeights[0] = -100000 * sUNIT;
        callWeights[1] = 100000 * sUNIT;

        callStrikes = new uint256[](2);
        callStrikes[0] = 21000 * UNIT;
        callStrikes[1] = 22000 * UNIT;

        putWeights = new int256[](0);
        putStrikes = new uint256[](0);

        CrossMarginDetail memory detail = CrossMarginDetail({
            putWeights: putWeights,
            putStrikes: putStrikes,
            callWeights: callWeights,
            callStrikes: callStrikes,
            underlyingId: 0,
            underlyingDecimals: UNIT_DECIMALS,
            numeraireId: 0,
            numeraireDecimals: UNIT_DECIMALS,
            expiry: 0
        });

        (uint256 numeraireNeeded, uint256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(numeraireNeeded, 0);
        assertEq(underlyingNeeded, (1000_00000 * UNIT) / 22000);
    }

    function testMarginBinaryCallOption() public {
        callWeights = new int256[](2);
        callWeights[0] = 1 * sUNIT;
        callWeights[1] = -1 * sUNIT;

        callStrikes = new uint256[](2);
        callStrikes[0] = 21999_999999;
        callStrikes[1] = 22000 * UNIT;

        putWeights = new int256[](0);
        putStrikes = new uint256[](0);

        CrossMarginDetail memory detail = CrossMarginDetail({
            putWeights: putWeights,
            putStrikes: putStrikes,
            callWeights: callWeights,
            callStrikes: callStrikes,
            underlyingId: 0,
            underlyingDecimals: UNIT_DECIMALS,
            numeraireId: 0,
            numeraireDecimals: UNIT_DECIMALS,
            expiry: 0
        });

        (uint256 numeraireNeeded, uint256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(numeraireNeeded, 0);
        assertEq(underlyingNeeded, 0);
    }

    // not possible to mint calls with with anything other than underlying
    // function testMarginCallSpreadWithCash() public {
    //     callWeights = new int256[](2);
    //     callWeights[0] = -1 * sUNIT;
    //     callWeights[1] = 1 * sUNIT;

    //     callStrikes = new uint256[](2);
    //     callStrikes[0] = 21000 * UNIT;
    //     callStrikes[1] = 22000 * UNIT;

    //     putWeights = new int256[](0);
    //     putStrikes = new uint256[](0);

    //     CrossMarginDetail memory detail = CrossMarginDetail({
    //         putWeights: putWeights,
    //         putStrikes: putStrikes,
    //         callWeights: callWeights,
    //         callStrikes: callStrikes,
    //         underlyingId: 0,
    //         underlyingDecimals: UNIT_DECIMALS,
    //         numeraireId: 1,
    //         numeraireDecimals: UNIT_DECIMALS,
    //         expiry: 0
    //     });

    //     (uint256 numeraireNeeded, uint256 underlyingNeeded) = detail.getMinCollateral();
    //     assertEq(numeraireNeeded, 1000 * UNIT);
    //     assertEq(underlyingNeeded, 0);
    // }

    function testConversion() public {
        callWeights = new int256[](1);
        callWeights[0] = -1 * sUNIT;

        callStrikes = new uint256[](1);
        callStrikes[0] = 17000 * UNIT;

        putWeights = new int256[](1);
        putWeights[0] = -1 * sUNIT;

        putStrikes = new uint256[](1);
        putStrikes[0] = callStrikes[0];

        CrossMarginDetail memory detail = CrossMarginDetail({
            putWeights: putWeights,
            putStrikes: putStrikes,
            callWeights: callWeights,
            callStrikes: callStrikes,
            underlyingId: 0,
            underlyingDecimals: UNIT_DECIMALS,
            numeraireId: 1,
            numeraireDecimals: UNIT_DECIMALS,
            expiry: 0
        });

        (uint256 numeraireNeeded1, uint256 underlyingNeeded1) = detail.getMinCollateral();
        assertEq(numeraireNeeded1, 17000 * UNIT);
        assertEq(underlyingNeeded1, 1 * UNIT);

        callWeights[0] = 314 * callWeights[0];
        detail = CrossMarginDetail({
            putWeights: putWeights,
            putStrikes: putStrikes,
            callWeights: callWeights,
            callStrikes: callStrikes,
            underlyingId: 0,
            underlyingDecimals: UNIT_DECIMALS,
            numeraireId: 1,
            numeraireDecimals: UNIT_DECIMALS,
            expiry: 0
        });

        (uint256 numeraireNeeded2, uint256 underlyingNeeded2) = detail.getMinCollateral();
        assertEq(numeraireNeeded1, numeraireNeeded2);
        assertEq(underlyingNeeded2, 314 * underlyingNeeded1);
    }
}

// solhint-disable-next-line contract-name-camelcase
contract TestVanillaCall_CMPM is Test {
    using CrossMarginPhysicalMath for CrossMarginDetail;

    int256[] private putWeights;
    uint256[] private putStrikes;

    int256[] private callWeights;
    uint256[] private callStrikes;

    function setUp() public {
        putWeights = new int256[](0);
        putStrikes = new uint256[](0);

        callWeights = new int256[](1);
        callWeights[0] = -1 * sUNIT;

        callStrikes = new uint256[](1);
        callStrikes[0] = 21000 * UNIT;
    }

    function testMarginRequirementVanillaCall1() public {
        CrossMarginDetail memory detail = CrossMarginDetail({
            putWeights: putWeights,
            putStrikes: putStrikes,
            callWeights: callWeights,
            callStrikes: callStrikes,
            underlyingId: 0,
            underlyingDecimals: UNIT_DECIMALS,
            numeraireId: 0,
            numeraireDecimals: UNIT_DECIMALS,
            expiry: 0
        });

        (uint256 numeraireNeeded, uint256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(numeraireNeeded, 0);
        assertEq(underlyingNeeded, 1 * UNIT);
    }
}

// solhint-disable-next-line contract-name-camelcase
contract TestVanillaPut_CMPM is Test {
    using CrossMarginPhysicalMath for CrossMarginDetail;

    int256[] private putWeights;
    uint256[] private putStrikes;

    int256[] private callWeights;
    uint256[] private callStrikes;

    function setUp() public {
        putWeights = new int256[](1);
        putWeights[0] = -1 * sUNIT;

        putStrikes = new uint256[](1);
        putStrikes[0] = 18000 * UNIT;

        callWeights = new int256[](0);
        callStrikes = new uint256[](0);
    }

    function testMarginRequirement1() public {
        CrossMarginDetail memory detail = CrossMarginDetail({
            putWeights: putWeights,
            putStrikes: putStrikes,
            callWeights: callWeights,
            callStrikes: callStrikes,
            underlyingId: 0,
            underlyingDecimals: UNIT_DECIMALS,
            numeraireId: 1,
            numeraireDecimals: UNIT_DECIMALS,
            expiry: 0
        });

        (uint256 numeraireNeeded, uint256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(numeraireNeeded, 18000 * UNIT);
        assertEq(underlyingNeeded, 0);
    }
}

contract TestStrangles_CMPM is Test {
    using CrossMarginPhysicalMath for CrossMarginDetail;

    int256[] private putWeights;
    uint256[] private putStrikes;

    int256[] private callWeights;
    uint256[] private callStrikes;

    function setUp() public {
        putWeights = new int256[](1);
        putWeights[0] = -1 * sUNIT;

        putStrikes = new uint256[](1);
        putStrikes[0] = 18000 * UNIT;

        callWeights = new int256[](1);
        callWeights[0] = -1 * sUNIT;

        callStrikes = new uint256[](1);
        callStrikes[0] = 20000 * UNIT;
    }

    function testShortStrangles() public {
        CrossMarginDetail memory detail = CrossMarginDetail({
            putWeights: putWeights,
            putStrikes: putStrikes,
            callWeights: callWeights,
            callStrikes: callStrikes,
            underlyingId: 0,
            underlyingDecimals: UNIT_DECIMALS,
            numeraireId: 1,
            numeraireDecimals: UNIT_DECIMALS,
            expiry: 0
        });

        (uint256 numeraireNeeded, uint256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(numeraireNeeded, putStrikes[0]);
        assertEq(underlyingNeeded, uint256(-callWeights[0]));
    }

    function testLongStrangle() public {
        putWeights[0] = 1 * sUNIT;
        callWeights[0] = 1 * sUNIT;
        CrossMarginDetail memory detail = CrossMarginDetail({
            putWeights: putWeights,
            putStrikes: putStrikes,
            callWeights: callWeights,
            callStrikes: callStrikes,
            underlyingId: 0,
            underlyingDecimals: UNIT_DECIMALS,
            numeraireId: 1,
            numeraireDecimals: UNIT_DECIMALS,
            expiry: 0
        });

        (uint256 numeraireNeeded, uint256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(numeraireNeeded, 0);
        assertEq(underlyingNeeded, 0);
    }

    function testStrangleSpread() public {
        putWeights = new int256[](2);
        putWeights[0] = -1 * sUNIT;
        putWeights[1] = 1 * sUNIT;

        callWeights = new int256[](2);
        callWeights[0] = -1 * sUNIT;
        callWeights[1] = 1 * sUNIT;

        putStrikes = new uint256[](2);
        putStrikes[0] = 18000 * UNIT;
        putStrikes[1] = 17000 * UNIT;

        callStrikes = new uint256[](2);
        callStrikes[0] = 20000 * UNIT;
        callStrikes[1] = 21000 * UNIT;

        CrossMarginDetail memory detail = CrossMarginDetail({
            putWeights: putWeights,
            putStrikes: putStrikes,
            callWeights: callWeights,
            callStrikes: callStrikes,
            underlyingId: 0,
            underlyingDecimals: UNIT_DECIMALS,
            numeraireId: 1,
            numeraireDecimals: UNIT_DECIMALS,
            expiry: 0
        });

        (uint256 numeraireNeeded, uint256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(numeraireNeeded, putStrikes[0] - putStrikes[1]);
        assertEq(underlyingNeeded, 0);
    }
}

// solhint-disable-next-line contract-name-camelcase
contract TestCornerCases_CMPM is Test {
    using CrossMarginPhysicalMath for CrossMarginDetail;

    int256[] private putWeights;
    uint256[] private putStrikes;

    int256[] private callWeights;
    uint256[] private callStrikes;

    function setUp() public {
        putWeights = new int256[](2);
        putWeights[0] = 1 * sUNIT;
        putWeights[1] = -2 * sUNIT;

        putStrikes = new uint256[](2);
        putStrikes[0] = 18000 * UNIT;
        putStrikes[1] = 17000 * UNIT;

        callWeights = new int256[](2);
        callWeights[0] = 1 * sUNIT;
        callWeights[1] = -2 * sUNIT;

        callStrikes = new uint256[](2);
        callStrikes[0] = 20000 * UNIT;
        callStrikes[1] = 21000 * UNIT;
    }

    function testOneByTwoCall() public {
        putWeights = new int256[](0);
        putStrikes = new uint256[](0);
        CrossMarginDetail memory detail = CrossMarginDetail({
            putWeights: putWeights,
            putStrikes: putStrikes,
            callWeights: callWeights,
            callStrikes: callStrikes,
            underlyingId: 0,
            underlyingDecimals: UNIT_DECIMALS,
            numeraireId: 0,
            numeraireDecimals: UNIT_DECIMALS,
            expiry: 0
        });

        (uint256 numeraireNeeded, uint256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(numeraireNeeded, 0);
        assertEq(underlyingNeeded, 1 * UNIT);
    }

    function testOneByTwoCall2() public {
        putStrikes = new uint256[](0);
        putWeights = new int256[](0);
        CrossMarginDetail memory detail = CrossMarginDetail({
            putWeights: putWeights,
            putStrikes: putStrikes,
            callWeights: callWeights,
            callStrikes: callStrikes,
            underlyingId: 0,
            underlyingDecimals: UNIT_DECIMALS,
            numeraireId: 1,
            numeraireDecimals: UNIT_DECIMALS,
            expiry: 0
        });

        (uint256 numeraireNeeded, uint256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(underlyingNeeded, 1 * UNIT);
        assertEq(numeraireNeeded, 0);
    }

    function testPotentialBreakOnZeroWeight() public {
        putWeights[0] = 0;
        putWeights[1] = 0;
        CrossMarginDetail memory detail = CrossMarginDetail({
            putWeights: putWeights,
            putStrikes: putStrikes,
            callWeights: callWeights,
            callStrikes: callStrikes,
            underlyingId: 0,
            underlyingDecimals: UNIT_DECIMALS,
            numeraireId: 1,
            numeraireDecimals: UNIT_DECIMALS,
            expiry: 0
        });
        vm.expectRevert(CMM_InvalidPutWeight.selector);
        detail.getMinCollateral();
    }

    function testOneByTwoPut() public {
        callStrikes = new uint256[](0);
        callWeights = new int256[](0);
        CrossMarginDetail memory detail = CrossMarginDetail({
            putWeights: putWeights,
            putStrikes: putStrikes,
            callWeights: callWeights,
            callStrikes: callStrikes,
            underlyingId: 0,
            underlyingDecimals: UNIT_DECIMALS,
            numeraireId: 1,
            numeraireDecimals: UNIT_DECIMALS,
            expiry: 0
        });

        (uint256 numeraireNeeded, uint256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(numeraireNeeded, putStrikes[1] - 1000 * UNIT);
        assertEq(underlyingNeeded, 0);
    }

    function testIronCondor() public {
        CrossMarginDetail memory detail = CrossMarginDetail({
            putWeights: putWeights,
            putStrikes: putStrikes,
            callWeights: callWeights,
            callStrikes: callStrikes,
            underlyingId: 0,
            underlyingDecimals: UNIT_DECIMALS,
            numeraireId: 1,
            numeraireDecimals: UNIT_DECIMALS,
            expiry: 0
        });

        (uint256 numeraireNeeded, uint256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(numeraireNeeded, putStrikes[1] - 1000 * UNIT);
        assertEq(underlyingNeeded, 1 * UNIT);
    }

    function testUpAndDown1() public {
        putWeights[0] = 17 * sUNIT;
        putWeights[1] = -18 * sUNIT;
        callWeights = new int256[](0);
        callStrikes = new uint256[](0);

        CrossMarginDetail memory detail = CrossMarginDetail({
            putWeights: putWeights,
            putStrikes: putStrikes,
            callWeights: callWeights,
            callStrikes: callStrikes,
            underlyingId: 0,
            underlyingDecimals: UNIT_DECIMALS,
            numeraireId: 1,
            numeraireDecimals: UNIT_DECIMALS,
            expiry: 0
        });

        (uint256 numeraireNeeded, uint256 underlyingNeeded) = detail.getMinCollateral();
        uint256 cashRequired = uint256(-putWeights[1]) * putStrikes[1] - uint256(putWeights[0]) * putStrikes[0];
        assertEq(numeraireNeeded, cashRequired);
        assertEq(underlyingNeeded, 0);
    }

    function testUpAndDown2() public {
        putWeights[0] = 16 * sUNIT;
        putWeights[1] = -18 * sUNIT;
        callWeights = new int256[](0);
        callStrikes = new uint256[](0);
        CrossMarginDetail memory detail = CrossMarginDetail({
            putWeights: putWeights,
            putStrikes: putStrikes,
            callWeights: callWeights,
            callStrikes: callStrikes,
            underlyingId: 0,
            underlyingDecimals: UNIT_DECIMALS,
            numeraireId: 1,
            numeraireDecimals: UNIT_DECIMALS,
            expiry: 0
        });

        (uint256 numeraireNeeded, uint256 underlyingNeeded) = detail.getMinCollateral();
        uint256 cashRequired = uint256(-putWeights[1]) * putStrikes[1] - uint256(putWeights[0]) * putStrikes[0];
        assertEq(numeraireNeeded, cashRequired / UNIT);
        assertEq(underlyingNeeded, 0);
    }

    function testUpAndDown3() public {
        putWeights[0] = 17 * sUNIT;
        putWeights[1] = -18 * sUNIT;
        callWeights = new int256[](1);
        callWeights[0] = 1 * sUNIT;
        callStrikes = new uint256[](1);
        callStrikes[0] = 20000 * UNIT;

        CrossMarginDetail memory detail = CrossMarginDetail({
            putWeights: putWeights,
            putStrikes: putStrikes,
            callWeights: callWeights,
            callStrikes: callStrikes,
            underlyingId: 0,
            underlyingDecimals: UNIT_DECIMALS,
            numeraireId: 1,
            numeraireDecimals: UNIT_DECIMALS,
            expiry: 0
        });

        (uint256 numeraireNeeded, uint256 underlyingNeeded) = detail.getMinCollateral();
        uint256 cashRequired = uint256(-putWeights[1]) * putStrikes[1] - uint256(putWeights[0]) * putStrikes[0];
        assertEq(numeraireNeeded, cashRequired / UNIT);
        assertEq(underlyingNeeded, 0);
    }

    function testUpAndDown4() public {
        putWeights[0] = 17 * sUNIT;
        putWeights[1] = -18 * sUNIT;
        CrossMarginDetail memory detail = CrossMarginDetail({
            putWeights: putWeights,
            putStrikes: putStrikes,
            callWeights: callWeights,
            callStrikes: callStrikes,
            underlyingId: 0,
            underlyingDecimals: UNIT_DECIMALS,
            numeraireId: 1,
            numeraireDecimals: UNIT_DECIMALS,
            expiry: 0
        });

        (uint256 numeraireNeeded, uint256 underlyingNeeded) = detail.getMinCollateral();
        uint256 cashRequired = uint256(-putWeights[1]) * putStrikes[1] - uint256(putWeights[0]) * putStrikes[0];
        assertEq(numeraireNeeded, cashRequired / UNIT);
        assertEq(underlyingNeeded, uint256(-callWeights[1]) - uint256(callWeights[0]));
    }

    function testPutGreaterThanCalls() public {
        putWeights[0] = -1 * sUNIT;
        putWeights[1] = 1 * sUNIT;

        putStrikes[0] = 2500 * UNIT;
        putStrikes[1] = 100 * UNIT;

        callWeights[0] = 1 * sUNIT;
        callWeights[1] = -1 * sUNIT;

        callStrikes[0] = 300 * UNIT;
        callStrikes[1] = 200 * UNIT;
        CrossMarginDetail memory detail = CrossMarginDetail({
            putWeights: putWeights,
            putStrikes: putStrikes,
            callWeights: callWeights,
            callStrikes: callStrikes,
            underlyingId: 0,
            underlyingDecimals: UNIT_DECIMALS,
            numeraireId: 1,
            numeraireDecimals: UNIT_DECIMALS,
            expiry: 0
        });

        (uint256 numeraireNeeded, uint256 underlyingNeeded) = detail.getMinCollateral();
        uint256 cashRequired = uint256(-putWeights[0]) * putStrikes[0] - uint256(putWeights[1]) * putStrikes[1];
        assertEq(numeraireNeeded, cashRequired / UNIT);
        assertEq(underlyingNeeded, uint256(callWeights[0] + callWeights[1]));
    }
}
