// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IGrappa} from "grappa/interfaces/IGrappa.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {UintArrayLib} from "array-lib/UintArrayLib.sol";

import "grappa/libraries/TokenIdUtil.sol";
import "grappa/libraries/BalanceUtil.sol";

import "../libraries/AccountUtil.sol";

// Cross Margin libraries and configs
import {CrossMarginAccount} from "./types.sol";
import "../config/errors.sol";

/**
 * @title CrossMarginCashLib
 * @dev   This library is in charge of updating the simple account struct and do validations
 */
library CrossMarginCashLib {
    using BalanceUtil for Balance[];
    using AccountUtil for Position[];
    using UintArrayLib for uint256[];
    using TokenIdUtil for uint256;

    /**
     * @dev return true if the account has no short,long positions nor collateral
     */
    function isEmpty(CrossMarginAccount storage account) external view returns (bool) {
        return account.shorts.isEmpty() && account.longs.isEmpty() && account.collaterals.isEmpty();
    }

    ///@dev Increase the collateral in the account
    ///@param account CrossMarginAccount storage that will be updated
    function addCollateral(CrossMarginAccount storage account, uint8 collateralId, uint80 amount) public {
        if (amount == 0) return;

        (bool found, uint256 index) = account.collaterals.indexOf(collateralId);

        if (!found) {
            account.collaterals.push(Balance(collateralId, amount));
        } else {
            account.collaterals[index].amount += amount;
        }
    }

    ///@dev Reduce the collateral in the account
    ///@param account CrossMarginAccount storage that will be updated
    function removeCollateral(CrossMarginAccount storage account, uint8 collateralId, uint80 amount) public {
        Balance[] memory collaterals = account.collaterals;

        (bool found, uint256 index) = collaterals.indexOf(collateralId);

        if (!found) revert CM_WrongCollateralId();

        uint80 newAmount = collaterals[index].amount - amount;

        if (newAmount == 0) {
            account.collaterals.remove(index);
        } else {
            account.collaterals[index].amount = newAmount;
        }
    }

    ///@dev Increase the amount of short call or put (debt) of the account
    ///@param account CrossMarginAccount storage that will be updated
    function mintOption(CrossMarginAccount storage account, uint256 tokenId, uint64 amount) external {
        if (amount == 0) return;

        TokenType optionType = tokenId.parseTokenType();

        // engine only supports calls and puts
        if (optionType != TokenType.CALL && optionType != TokenType.PUT) revert CM_UnsupportedTokenType();

        (bool found, uint256 index) = account.shorts.indexOf(tokenId);
        if (!found) {
            account.shorts.push(Position(tokenId, amount));
        } else {
            account.shorts[index].amount += amount;
        }
    }

    ///@dev Remove the amount of short call or put (debt) of the account
    ///@param account CrossMarginAccount storage that will be updated in-place
    function burnOption(CrossMarginAccount storage account, uint256 tokenId, uint64 amount) external {
        (bool found, Position memory position, uint256 index) = account.shorts.find(tokenId);

        if (!found) revert CM_InvalidToken();

        uint64 newShortAmount = position.amount - amount;
        if (newShortAmount == 0) {
            account.shorts.removeAt(index);
        } else {
            account.shorts[index].amount = newShortAmount;
        }
    }

    ///@dev Increase the amount of long call or put (debt) of the account
    ///@param account CrossMarginAccount storage that will be updated
    function addOption(CrossMarginAccount storage account, uint256 tokenId, uint64 amount) external {
        if (amount == 0) return;

        (bool found, uint256 index) = account.longs.indexOf(tokenId);

        if (!found) {
            account.longs.push(Position(tokenId, amount));
        } else {
            account.longs[index].amount += amount;
        }
    }

    ///@dev Remove the amount of long call or put held by the account
    ///@param account CrossMarginAccount storage that will be updated in-place
    function removeOption(CrossMarginAccount storage account, uint256 tokenId, uint64 amount) external {
        (bool found, Position memory position, uint256 index) = account.longs.find(tokenId);

        if (!found) revert CM_InvalidToken();

        uint64 newLongAmount = position.amount - amount;
        if (newLongAmount == 0) {
            account.longs.removeAt(index);
        } else {
            account.longs[index].amount = newLongAmount;
        }
    }

    ///@dev Settles the accounts longs and shorts
    ///@param account CrossMarginAccount storage that will be updated in-place
    function settleAtExpiry(CrossMarginAccount storage account, IGrappa grappa)
        external
        returns (Balance[] memory longPayouts, Balance[] memory shortPayouts)
    {
        // settling longs first as they can only increase collateral
        longPayouts = _settleLongs(grappa, account);
        // settling shorts last as they can only reduce collateral
        shortPayouts = _settleShorts(grappa, account);
    }

    ///@dev Settles the accounts longs, adding collateral to balances
    ///@param grappa interface to settle long options in a batch call
    ///@param account CrossMarginAccount memory that will be updated in-place
    function _settleLongs(IGrappa grappa, CrossMarginAccount storage account) public returns (Balance[] memory payouts) {
        uint256 i;
        uint256[] memory tokenIds;
        uint256[] memory amounts;

        while (i < account.longs.length) {
            uint256 tokenId = account.longs[i].tokenId;

            if (tokenId.isExpired()) {
                tokenIds = tokenIds.append(tokenId);
                amounts = amounts.append(account.longs[i].amount);

                account.longs.removeAt(i);
            } else {
                unchecked {
                    ++i;
                }
            }
        }

        if (tokenIds.length > 0) {
            payouts = grappa.batchSettleOptions(address(this), tokenIds, amounts);

            for (i = 0; i < payouts.length;) {
                // add the collateral in the account storage.
                addCollateral(account, payouts[i].collateralId, payouts[i].amount);

                unchecked {
                    ++i;
                }
            }
        }
    }

    ///@dev Settles the accounts shorts, reserving collateral for ITM options
    ///@param grappa interface to get short option payouts in a batch call
    ///@param account CrossMarginAccount memory that will be updated in-place
    function _settleShorts(IGrappa grappa, CrossMarginAccount storage account) public returns (Balance[] memory payouts) {
        uint256 i;
        uint256[] memory tokenIds;
        uint256[] memory amounts;

        while (i < account.shorts.length) {
            uint256 tokenId = account.shorts[i].tokenId;

            if (tokenId.isExpired()) {
                tokenIds = tokenIds.append(tokenId);
                amounts = amounts.append(account.shorts[i].amount);

                account.shorts.removeAt(i);
            } else {
                unchecked {
                    ++i;
                }
            }
        }

        if (tokenIds.length > 0) {
            payouts = grappa.batchGetPayouts(tokenIds, amounts);

            for (i = 0; i < payouts.length;) {
                // remove the collateral in the account storage.
                removeCollateral(account, payouts[i].collateralId, payouts[i].amount);

                unchecked {
                    ++i;
                }
            }
        }
    }
}
