// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.17;

import {Balance} from "../libraries/BalancesLogic.sol";
import {RevocationPair} from "./ICreditManagerV3.sol";

uint192 constant ADD_COLLATERAL_PERMISSION = 1;
uint192 constant INCREASE_DEBT_PERMISSION = 2 ** 1;
uint192 constant DECREASE_DEBT_PERMISSION = 2 ** 2;
uint192 constant ENABLE_TOKEN_PERMISSION = 2 ** 3;
uint192 constant DISABLE_TOKEN_PERMISSION = 2 ** 4;
uint192 constant WITHDRAW_PERMISSION = 2 ** 5;
uint192 constant UPDATE_QUOTA_PERMISSION = 2 ** 6;
uint192 constant REVOKE_ALLOWANCES_PERMISSION = 2 ** 7;

uint192 constant EXTERNAL_CALLS_PERMISSION = 2 ** 16;

uint256 constant ALL_CREDIT_FACADE_CALLS_PERMISSION = ADD_COLLATERAL_PERMISSION | INCREASE_DEBT_PERMISSION
    | DECREASE_DEBT_PERMISSION | ENABLE_TOKEN_PERMISSION | DISABLE_TOKEN_PERMISSION | WITHDRAW_PERMISSION
    | UPDATE_QUOTA_PERMISSION | REVOKE_ALLOWANCES_PERMISSION;

uint256 constant ALL_PERMISSIONS = ALL_CREDIT_FACADE_CALLS_PERMISSION | EXTERNAL_CALLS_PERMISSION;

// All flags start from 193rd bit, because bot permissions is uint192
uint256 constant INCREASE_DEBT_WAS_CALLED = 2 ** 193;
uint256 constant EXTERNAL_CONTRACT_WAS_CALLED = 2 ** 194;

// pay bot is a flag which is enabled in botMulticall function only to allow one payment operation
uint256 constant PAY_BOT_CAN_BE_CALLED = 2 ** 195;

interface ICreditFacadeMulticall {
    /// @dev Instructs CreditFacadeV3 to check token balances at the end
    /// Used to control slippage after the entire sequence of operations, since tracking slippage
    /// On each operation is not ideal. Stores expected balances (computed as current balance + passed delta)
    /// and compare with actual balances at the end of a multicall, reverts
    /// if at least one is less than expected
    /// @param expected Array of expected balance changes
    /// @notice This is an extenstion function that does not exist in the Credit Facade
    ///         itself and can only be used within a multicall
    function revertIfReceivedLessThan(Balance[] memory expected) external;

    /// @dev Enables token in enabledTokensMask for the Credit Account of msg.sender
    /// @param token Address of token to enable
    function enableToken(address token) external;

    /// @dev Disables a token on the caller's Credit Account
    /// @param token Token to disable
    /// @notice This is an extenstion function that does not exist in the Credit Facade
    ///         itself and can only be used within a multicall
    function disableToken(address token) external;

    /// @dev Adds collateral to borrower's credit account
    /// @param token Address of a collateral token
    /// @param amount Amount to add
    function addCollateral(address token, uint256 amount) external;

    /// @dev Increases debt for msg.sender's Credit Account
    /// - Borrows the requested amount from the pool
    /// - Updates the CA's borrowAmount / cumulativeIndexOpen
    ///   to correctly compute interest going forward
    /// - Performs a full collateral check
    ///
    /// @param amount Amount to borrow
    function increaseDebt(uint256 amount) external;

    /// @dev Decrease debt
    /// - Decreases the debt by paying the requested amount + accrued interest + fees back to the pool
    /// - It's also include to this payment interest accrued at the moment and fees
    /// - Updates cunulativeIndex to cumulativeIndex now
    ///
    /// @param amount Amount to increase borrowed amount
    function decreaseDebt(uint256 amount) external;

    /// @dev Update msg.sender's Credit Account quota
    function updateQuota(address token, int96 quotaChange) external;

    /// @dev Set collateral hints for a full check
    /// @param collateralHints Array of token mask in the desired order of checking
    /// @param minHealthFactor Minimal HF threshold to pass the collateral check in PERCENTAGE format.
    ///                        Cannot be lower than PERCENTAGE_FACTOR.
    function setFullCheckParams(uint256[] memory collateralHints, uint16 minHealthFactor) external;

    function scheduleWithdrawal(address token, uint256 amount) external;

    function revokeAdapterAllowances(RevocationPair[] calldata revocations) external;

    function onDemandPriceUpdate(address token, bytes memory data) external;

    function payBot(uint72 paymentAmount) external;
}