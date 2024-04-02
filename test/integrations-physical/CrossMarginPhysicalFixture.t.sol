// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../../src/settled-physical/CrossMarginPhysicalEngine.sol";
import "../../src/settled-physical/CrossMarginPhysicalEngineProxy.sol";
import {Pomace} from "pomace/core/Pomace.sol";
import "pomace/core/PomaceProxy.sol";
import "pomace/core/PhysicalOptionToken.sol";

import {RolesAuthority} from "entitlements/src/core/RolesAuthority.sol";
import {RolesAuthorityProxy} from "entitlements/src/core/RolesAuthorityProxy.sol";
import {Role} from "entitlements/src/config/enums.sol";
import {MockSanctions} from "entitlements/test/mocks/MockSanctions.sol";

// Mocks
import "../mocks/MockERC20.sol";
import "pomace-test/mocks/MockOracle.sol";

import {ActionArgs} from "pomace/config/types.sol";
import "pomace/config/enums.sol";
import "../../src/config/types.sol";
import "../../src/config/errors.sol";

import "../utils/Utilities.sol";

import {ActionHelper} from "pomace-test/shared/ActionHelper.sol";

// solhint-disable max-states-count

/**
 * helper contract for full margin integration test to inherit.
 */
abstract contract CrossMarginPhysicalFixture is Test, ActionHelper, Utilities {
    CrossMarginPhysicalEngine internal engine;
    Pomace internal pomace;
    PhysicalOptionToken internal option;

    RolesAuthority public rolesAuthority;
    MockSanctions internal sanctions;

    MockERC20 internal usdc;
    MockERC20 internal weth;

    MockOracle internal oracle;

    address internal alice;
    address internal charlie;
    address internal bob;

    // usdc collateralized call / put
    uint32 internal pidUsdcCollat;

    // eth collateralized call / put
    uint32 internal pidEthCollat;

    uint8 internal usdcId;
    uint8 internal wethId;

    uint8 internal engineId;

    constructor() {
        usdc = new MockERC20("USDC", "USDC", 6); // nonce: 1
        vm.label(address(usdc), "USDC");

        weth = new MockERC20("WETH", "WETH", 18); // nonce: 2
        vm.label(address(weth), "WETH");

        oracle = new MockOracle(); // nonce: 3

        // predict address of margin account and use it here
        address pomaceAddr = predictAddress(address(this), 6);
        option = new PhysicalOptionToken(pomaceAddr, address(0)); // nonce: 4
        vm.label(address(option), "PhysicalOptionToken");
        address pomaceImplementation = address(new Pomace(address(option), address(oracle))); // nonce: 5
        bytes memory pomaceData = abi.encodeWithSelector(Pomace.initialize.selector, address(this));
        pomace = Pomace(address(new PomaceProxy(pomaceImplementation, pomaceData))); // 6
        vm.label(address(pomace), "Pomace");

        sanctions = new MockSanctions();
        address implementation = address(new RolesAuthority(address(sanctions)));
        bytes memory initData = abi.encodeWithSelector(RolesAuthority.initialize.selector, address(this));
        address rolesAuthorityProxy = address(new RolesAuthorityProxy(implementation, initData));
        rolesAuthority = RolesAuthority(rolesAuthorityProxy);

        address engineImplementation =
            address(new CrossMarginPhysicalEngine(address(pomace), address(option), address(rolesAuthority))); // nonce 7
        bytes memory engineData = abi.encodeWithSelector(CrossMarginPhysicalEngine.initialize.selector, address(this));
        engine = CrossMarginPhysicalEngine(address(new CrossMarginPhysicalEngineProxy(engineImplementation, engineData))); // 8
        vm.label(address(engine), "CrossMarginPhysicalEngine");

        // register products
        usdcId = pomace.registerAsset(address(usdc));
        wethId = pomace.registerAsset(address(weth));

        engineId = pomace.registerEngine(address(engine));

        pidUsdcCollat = pomace.getProductId(address(engine), address(weth), address(usdc), address(usdc));
        pidEthCollat = pomace.getProductId(address(engine), address(weth), address(usdc), address(weth));

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
        rolesAuthority.setUserRole(bob, Role.Investor_MFFeederDomestic, true);
        rolesAuthority.setRoleCapability(Role.Investor_MFFeederDomestic, address(engine), engine.execute.selector, true);
        rolesAuthority.setRoleCapability(Role.Investor_MFFeederDomestic, address(engine), engine.batchExecute.selector, true);
        rolesAuthority.setRoleCapability(Role.Investor_MFFeederDomestic, address(engine), engine.receiveDebtValue.selector, true);
        rolesAuthority.setRoleCapability(Role.Investor_MFFeederDomestic, address(engine), engine.sendPayoutValue.selector, true);
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function mintOptionFor(address _recipient, uint256 _tokenId, uint32 _productId, uint256 _amount) internal {
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
