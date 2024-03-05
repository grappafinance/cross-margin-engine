// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {CrossMarginCashEngine} from "../../src/settled-cash/CrossMarginCashEngine.sol";
import "../../src/settled-cash/CrossMarginCashEngineProxy.sol";
import {Grappa} from "grappa/core/Grappa.sol";
import "grappa/core/GrappaProxy.sol";
import "grappa/core/CashOptionToken.sol";

import {RolesAuthority} from "entitlements/src/core/RolesAuthority.sol";
import {RolesAuthorityProxy} from "entitlements/src/core/RolesAuthorityProxy.sol";
import {Role} from "entitlements/src/config/enums.sol";
import {MockSanctions} from "entitlements/test/mocks/MockSanctions.sol";

// Mocks
import "../mocks/MockERC20.sol";
import "grappa-test/mocks/MockOracle.sol";

// Types
import "grappa/config/types.sol";
import "grappa/config/enums.sol";
import "../../src/config/types.sol";
import "../../src/config/errors.sol";

import "../utils/Utilities.sol";

import {ActionHelper} from "grappa-test/shared/ActionHelper.sol";

// solhint-disable max-states-count

/**
 * helper contract for full margin integration test to inherit.
 */
abstract contract CrossMarginCashFixture is Test, ActionHelper, Utilities {
    CrossMarginCashEngine internal engine;
    Grappa internal grappa;
    CashOptionToken internal option;

    RolesAuthority public rolesAuthority;
    MockSanctions internal sanctions;

    MockERC20 internal usdc;
    MockERC20 internal weth;

    MockOracle internal oracle;

    address internal alice;
    address internal charlie;
    address internal bob;

    // usdc collateralized call / put
    uint40 internal pidUsdcCollat;

    // eth collateralized call / put
    uint40 internal pidEthCollat;

    uint8 internal usdcId;
    uint8 internal wethId;

    uint8 internal engineId;
    uint8 internal oracleId;

    constructor() {
        usdc = new MockERC20("USDC", "USDC", 6); // nonce: 1
        vm.label(address(usdc), "USDC");

        weth = new MockERC20("WETH", "WETH", 18); // nonce: 2
        vm.label(address(weth), "WETH");

        oracle = new MockOracle(); // nonce: 3

        // predict address of margin account and use it here
        address grappaAddr = predictAddress(address(this), 6);
        option = new CashOptionToken(grappaAddr, address(0)); // nonce: 4
        address grappaImplementation = address(new Grappa(address(option))); // nonce: 5
        bytes memory grappaData = abi.encodeWithSelector(Grappa.initialize.selector, address(this));
        grappa = Grappa(address(new GrappaProxy(grappaImplementation, grappaData))); // 6

        sanctions = new MockSanctions();
        address implementation = address(new RolesAuthority(address(sanctions)));
        bytes memory initData = abi.encodeWithSelector(RolesAuthority.initialize.selector, address(this));
        address rolesAuthorityProxy = address(new RolesAuthorityProxy(implementation, initData));
        rolesAuthority = RolesAuthority(rolesAuthorityProxy);

        address engineImplementation =
            address(new CrossMarginCashEngine(address(grappa), address(option), address(oracle), address(rolesAuthority))); // nonce 7
        bytes memory engineData = abi.encodeWithSelector(CrossMarginCashEngine.initialize.selector, address(this));
        engine = CrossMarginCashEngine(address(new CrossMarginCashEngineProxy(engineImplementation, engineData))); // 8

        // register products
        usdcId = grappa.registerAsset(address(usdc));
        wethId = grappa.registerAsset(address(weth));

        engineId = grappa.registerEngine(address(engine));

        oracleId = grappa.registerOracle(address(oracle));

        pidUsdcCollat = grappa.getProductId(address(oracle), address(engine), address(weth), address(usdc), address(usdc));
        pidEthCollat = grappa.getProductId(address(oracle), address(engine), address(weth), address(usdc), address(weth));

        charlie = address(0xcccc);
        vm.label(charlie, "Charlie");

        bob = address(0xb00b);
        vm.label(bob, "Bob");

        alice = address(0xaaaa);
        vm.label(alice, "Alice");

        // make sure timestamp is not 0
        vm.warp(0xffff);

        usdc.mint(alice, 1000_000_000 * 1e6);
        usdc.mint(bob, 1000_000_000 * 1e6);
        usdc.mint(charlie, 1000_000_000 * 1e6);

        rolesAuthority.setUserRole(address(this), Role.Investor_MFFeederDomestic, true);
        rolesAuthority.setUserRole(alice, Role.Investor_MFFeederDomestic, true);
        rolesAuthority.setRoleCapability(Role.Investor_MFFeederDomestic, address(engine), engine.execute.selector, true);
        rolesAuthority.setRoleCapability(Role.Investor_MFFeederDomestic, address(engine), engine.batchExecute.selector, true);
        rolesAuthority.setRoleCapability(Role.Investor_MFFeederDomestic, address(engine), engine.payCashValue.selector, true);
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function mintOptionFor(address _recipient, uint256 _tokenId, uint40 _productId, uint256 _amount) internal {
        address anon = address(0x42424242);

        vm.startPrank(anon);

        uint256 lotOfCollateral = 1_000 * 1e18;

        usdc.mint(anon, lotOfCollateral);
        weth.mint(anon, lotOfCollateral);
        usdc.approve(address(engine), type(uint256).max);
        weth.approve(address(engine), type(uint256).max);

        ActionArgs[] memory actions = new ActionArgs[](2);

        uint8 collateralId = uint8(_productId);

        actions[0] = createAddCollateralAction(collateralId, address(anon), lotOfCollateral);
        actions[1] = createMintAction(_tokenId, address(_recipient), _amount);
        engine.execute(address(anon), actions);

        vm.stopPrank();
    }

    // place holder here so forge coverage won't pick it up
    function test() public {}
}
