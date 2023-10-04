// SPDX-License-Identifier: MIT
// solhint-disable no-empty-blocks
pragma solidity ^0.8.0;

// inheriting contracts
import {BaseEngine} from "grappa/core/engines/BaseEngine.sol";

// constants and types
import "grappa/config/enums.sol";
import "grappa/config/errors.sol";

/**
 * @title   AccountCashEngine
 * @author  @dsshap
 * @notice  util functions to transfer positions between accounts "without" moving tokens externally
 */
abstract contract AccountCashEngine is BaseEngine {
    event CollateralTransferred(address from, address to, uint8 collateralId, uint256 amount);

    event CashOptionTokenTransferred(address from, address to, uint256 tokenId, uint64 amount);

    /**
     * @dev Transfers collateral to another account.
     * @param _subAccount subaccount that will be update in place
     */
    function _transferCollateral(address _subAccount, bytes calldata _data) internal virtual {
        // decode parameters
        (uint80 amount, address to, uint8 collateralId) = abi.decode(_data, (uint80, address, uint8));

        // update the account in state
        _removeCollateralFromAccount(_subAccount, collateralId, amount);
        _addCollateralToAccount(to, collateralId, amount);

        emit CollateralTransferred(_subAccount, to, collateralId, amount);
    }

    /**
     * @dev Transfers short tokens to another account.
     * @param _subAccount subaccount that will be update in place
     */
    function _transferShort(address _subAccount, bytes calldata _data) internal virtual {
        // decode parameters
        (uint256 tokenId, address to, uint64 amount) = abi.decode(_data, (uint256, address, uint64));

        _assertCallerHasAccess(to);

        // update the account in state
        _decreaseShortInAccount(_subAccount, tokenId, amount);
        _increaseShortInAccount(to, tokenId, amount);

        emit CashOptionTokenTransferred(_subAccount, to, tokenId, amount);

        if (!_isAccountAboveWater(to)) revert BM_AccountUnderwater();
    }

    /**
     * @dev Transfers long tokens to another account.
     * @param _subAccount subaccount that will be update in place
     */
    function _transferLong(address _subAccount, bytes calldata _data) internal virtual {
        // decode parameters
        (uint256 tokenId, address to, uint64 amount) = abi.decode(_data, (uint256, address, uint64));

        // update the account in state
        _decreaseLongInAccount(_subAccount, tokenId, amount);
        _increaseLongInAccount(to, tokenId, amount);

        emit CashOptionTokenTransferred(_subAccount, to, tokenId, amount);
    }

    /**
     * @dev mint option token into another account
     * @dev increase short position (debt) in the current account
     * @dev increase long position another account's storage
     * @param _data bytes data to decode
     */
    function _mintOptionIntoAccount(address _subAccount, bytes calldata _data) internal virtual {
        // decode parameters
        (uint256 tokenId, address recipientSubAccount, uint64 amount) = abi.decode(_data, (uint256, address, uint64));

        _verifyLongTokenIdToAdd(tokenId);

        // update the account in state
        _increaseShortInAccount(_subAccount, tokenId, amount);

        emit CashOptionTokenMinted(_subAccount, tokenId, amount);

        // update the account in state
        _increaseLongInAccount(recipientSubAccount, tokenId, amount);

        emit CashOptionTokenAdded(recipientSubAccount, tokenId, amount);

        // mint option token
        optionToken.mint(address(this), tokenId, amount);
    }

    /**
     * @dev burn option token from account
     * @dev decrease short position (debt) in the current account
     * @dev decrease long position another account's storage
     * @param _data bytes data to decode
     */
    function _burnOptionFromAccount(address _subAccount, bytes calldata _data) internal virtual {
        // decode parameters
        // decode parameters
        (uint256 tokenId, address from, uint64 amount) = abi.decode(_data, (uint256, address, uint64));

        // token being burn must come from caller or the primary account for this subAccount
        if (from != msg.sender && !_isPrimaryAccountFor(from, _subAccount)) revert BM_InvalidFromAddress();

        // update the account in state
        _decreaseLongInAccount(from, tokenId, amount);

        // update the account in state
        _decreaseShortInAccount(_subAccount, tokenId, amount);

        emit CashOptionTokenBurned(_subAccount, tokenId, amount);

        // burn option token
        optionToken.burn(address(this), tokenId, amount);
    }
}
