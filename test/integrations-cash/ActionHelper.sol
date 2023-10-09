// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../src/config/types.sol";

import {ActionType} from "../../src/settled-cash/enums.sol";
import {ActionArgs} from "../../src/settled-cash/types.sol";

import {TokenIdUtil} from "grappa/libraries/TokenIdUtil.sol";

import {TokenType} from "grappa/config/enums.sol";

abstract contract ActionHelper {
    function getTokenId(TokenType tokenType, uint40 productId, uint256 expiry, uint256 longStrike, uint256 shortStrike)
        internal
        pure
        returns (uint256 tokenId)
    {
        tokenId = TokenIdUtil.getTokenId(tokenType, productId, uint64(expiry), uint64(longStrike), uint64(shortStrike));
    }

    function createAddCollateralAction(uint8 collateralId, address from, uint256 amount)
        internal
        pure
        returns (ActionArgs memory action)
    {
        return ActionArgs({action: ActionType.AddCollateral, data: abi.encode(from, uint80(amount), collateralId)});
    }

    function createRemoveCollateralAction(uint256 amount, uint8 collateralId, address recipient)
        internal
        pure
        returns (ActionArgs memory action)
    {
        return ActionArgs({action: ActionType.RemoveCollateral, data: abi.encode(uint80(amount), recipient, collateralId)});
    }

    function createTransferCollateralAction(uint256 amount, uint8 collateralId, address recipient)
        internal
        pure
        returns (ActionArgs memory action)
    {
        return ActionArgs({action: ActionType.TransferCollateral, data: abi.encode(uint80(amount), recipient, collateralId)});
    }

    function createMintAction(uint256 tokenId, address recipient, uint256 amount)
        internal
        pure
        returns (ActionArgs memory action)
    {
        return ActionArgs({action: ActionType.MintShort, data: abi.encode(tokenId, recipient, uint64(amount))});
    }

    function createMintIntoAccountAction(uint256 tokenId, address recipient, uint256 amount)
        internal
        pure
        returns (ActionArgs memory action)
    {
        return ActionArgs({action: ActionType.MintShortIntoAccount, data: abi.encode(tokenId, recipient, uint64(amount))});
    }

    function createBurnAction(uint256 tokenId, address from, uint256 amount) internal pure returns (ActionArgs memory action) {
        return ActionArgs({action: ActionType.BurnShort, data: abi.encode(tokenId, from, uint64(amount))});
    }

    function createTransferLongAction(uint256 tokenId, address recipient, uint256 amount)
        internal
        pure
        returns (ActionArgs memory action)
    {
        return ActionArgs({action: ActionType.TransferLong, data: abi.encode(tokenId, recipient, uint64(amount))});
    }

    function createTransferShortAction(uint256 tokenId, address recipient, uint256 amount)
        internal
        pure
        returns (ActionArgs memory action)
    {
        return ActionArgs({action: ActionType.TransferShort, data: abi.encode(tokenId, recipient, uint64(amount))});
    }

    function createMergeAction(uint256 tokenId, uint256 shortId, address from, uint256 amount)
        internal
        pure
        returns (ActionArgs memory action)
    {
        return ActionArgs({action: ActionType.MergeOptionToken, data: abi.encode(tokenId, shortId, from, amount)});
    }

    function createSplitAction(uint256 spreadId, uint256 amount, address recipient)
        internal
        pure
        returns (ActionArgs memory action)
    {
        return ActionArgs({action: ActionType.SplitOptionToken, data: abi.encode(spreadId, uint64(amount), recipient)});
    }

    function createAddLongAction(uint256 tokenId, uint256 amount, address from)
        internal
        pure
        returns (ActionArgs memory action)
    {
        return ActionArgs({action: ActionType.AddLong, data: abi.encode(tokenId, uint64(amount), from)});
    }

    function createRemoveLongAction(uint256 tokenId, uint256 amount, address recipient)
        internal
        pure
        returns (ActionArgs memory action)
    {
        return ActionArgs({action: ActionType.RemoveLong, data: abi.encode(tokenId, uint64(amount), recipient)});
    }

    function createBurnShortInAccountAction(uint256 tokenId, address from, uint256 amount)
        internal
        pure
        returns (ActionArgs memory action)
    {
        return ActionArgs({action: ActionType.BurnShortInAccount, data: abi.encode(tokenId, from, uint64(amount))});
    }

    function createSettleAction() internal pure returns (ActionArgs memory action) {
        return ActionArgs({action: ActionType.SettleAccount, data: ""});
    }
}
