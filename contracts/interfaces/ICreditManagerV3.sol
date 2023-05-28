// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.17;

import {IPriceOracleV2} from "@gearbox-protocol/core-v2/contracts/interfaces/IPriceOracle.sol";
import {IPoolQuotaKeeper} from "./IPoolQuotaKeeper.sol";
import {ClaimAction, IWithdrawalManager} from "./IWithdrawalManager.sol";
import {IVersion} from "@gearbox-protocol/core-v2/contracts/interfaces/IVersion.sol";

enum ClosureAction {
    CLOSE_ACCOUNT,
    LIQUIDATE_ACCOUNT,
    LIQUIDATE_EXPIRED_ACCOUNT
}

enum ManageDebtAction {
    INCREASE_DEBT,
    DECREASE_DEBT
}

uint8 constant WITHDRAWAL_FLAG = 1;
uint8 constant BOT_PERMISSIONS_SET_FLAG = 1 << 1;

struct CreditAccountInfo {
    uint256 debt;
    uint256 cumulativeIndexLastUpdate;
    uint256 cumulativeQuotaInterest;
    uint256 enabledTokensMask;
    uint16 flags;
    address borrower;
}

enum CollateralCalcTask {
    GENERIC_PARAMS,
    DEBT_ONLY,
    DEBT_COLLATERAL_WITHOUT_WITHDRAWALS,
    DEBT_COLLATERAL_CANCEL_WITHDRAWALS,
    DEBT_COLLATERAL_FORCE_CANCEL_WITHDRAWALS,
    ///
    FULL_COLLATERAL_CHECK_LAZY
}

struct CollateralDebtData {
    uint256 debt;
    uint256 cumulativeIndexNow;
    uint256 cumulativeIndexLastUpdate;
    uint256 cumulativeQuotaInterest;
    uint256 accruedInterest;
    uint256 accruedFees;
    uint256 totalDebtUSD;
    uint256 totalValue;
    uint256 totalValueUSD;
    uint256 twvUSD;
    uint256 enabledTokensMask;
    uint256 quotedTokensMask;
    address[] quotedTokens;
    uint16[] quotedLts;
    uint256[] quotas;
    ///
    address _poolQuotaKeeper;
}

struct CollateralTokenData {
    address token;
    uint16 ltInitial;
    uint16 ltFinal;
    uint40 timestampRampStart;
    uint24 rampDuration;
}

struct RevocationPair {
    address spender;
    address token;
}

interface ICreditManagerV3Events {
    /// @dev Emits when a call to an external contract is made through the Credit Manager
    event Execute(address indexed targetContract);

    /// @dev Emits when a configurator is upgraded
    event SetCreditConfigurator(address indexed newConfigurator);
}

/// @notice All Credit Manager functions are access-restricted and can only be called
///         by the Credit Facade or allowed adapters. Users are not allowed to
///         interact with the Credit Manager directly
interface ICreditManagerV3 is ICreditManagerV3Events, IVersion {
    //
    // CREDIT ACCOUNT MANAGEMENT
    //

    ///  @dev Opens credit account and borrows funds from the pool.
    /// @param debt Amount to be borrowed by the Credit Account
    /// @param onBehalfOf The owner of the newly opened Credit Account
    function openCreditAccount(uint256 debt, address onBehalfOf) external returns (address);

    ///  @dev Closes a Credit Account - covers both normal closure and liquidation
    /// - Checks whether the contract is paused, and, if so, if the payer is an emergency liquidator.
    ///   Only emergency liquidators are able to liquidate account while the CM is paused.
    ///   Emergency liquidations do not pay a liquidator premium or liquidation fees.
    /// - Calculates payments to various recipients on closure:
    ///    + Computes amountToPool, which is the amount to be sent back to the pool.
    ///      This includes the principal, interest and fees, but can't be more than
    ///      total position value
    ///    + Computes remainingFunds during liquidations - these are leftover funds
    ///      after paying the pool and the liquidator, and are sent to the borrower
    ///    + Computes protocol profit, which includes interest and liquidation fees
    ///    + Computes loss if the totalValue is less than borrow amount + interest
    /// - Checks the underlying token balance:
    ///    + if it is larger than amountToPool, then the pool is paid fully from funds on the Credit Account
    ///    + else tries to transfer the shortfall from the payer - either the borrower during closure, or liquidator during liquidation
    /// - Send assets to the "to" address, as long as they are not included into skipTokenMask
    /// - If convertToETH is true, the function converts WETH into ETH before sending
    /// - Returns the Credit Account back to factory
    ///
    /// @param creditAccount Credit account address
    /// @param closureAction Whether the account is closed, liquidated or liquidated due to expiry
    /// @param payer Address which would be charged if credit account has not enough funds to cover amountToPool
    /// @param to Address to which the leftover funds will be sent
    /// @param skipTokensMask Tokenmask contains 1 for tokens which needed to be skipped for sending
    /// @param convertToETH If true converts WETH to ETH
    function closeCreditAccount(
        address creditAccount,
        ClosureAction closureAction,
        CollateralDebtData memory collateralDebtData,
        address payer,
        address to,
        uint256 skipTokensMask,
        bool convertToETH
    ) external returns (uint256 remainingFunds, uint256 loss);

    /// @dev Manages debt size for borrower:
    ///
    /// - Increase debt:
    ///   + Increases debt by transferring funds from the pool to the credit account
    ///   + Updates the cumulative index to keep interest the same. Since interest
    ///     is always computed dynamically as debt * (cumulativeIndexNew / cumulativeIndexOpen - 1),
    ///     cumulativeIndexOpen needs to be updated, as the borrow amount has changed
    ///
    /// - Decrease debt:
    ///   + Repays debt partially + all interest and fees accrued thus far
    ///   + Updates cunulativeIndex to cumulativeIndex now
    ///
    /// @param creditAccount Address of the Credit Account to change debt for
    /// @param amount Amount to increase / decrease the principal by
    /// @param action Increase/decrease
    // @return newdebt The new debt principal
    function manageDebt(address creditAccount, uint256 amount, uint256 enabledTokensMask, ManageDebtAction action)
        external
        returns (uint256 newDebt, uint256 tokensToEnable, uint256 tokensToDisable);

    /// @dev Adds collateral to borrower's credit account
    /// @param payer Address of the account which will be charged to provide additional collateral
    /// @param creditAccount Address of the Credit Account
    /// @param token Collateral token to add
    /// @param amount Amount to add
    function addCollateral(address payer, address creditAccount, address token, uint256 amount)
        external
        returns (uint256);

    /// @dev Requests the Credit Account to approve a collateral token to another contract.\
    /// @param token Collateral token to approve
    /// @param amount New allowance amount
    function approveCreditAccount(address token, uint256 amount) external;

    /// @dev Requests a Credit Account to make a low-level call with provided data
    /// This is the intended pathway for state-changing interactions with 3rd-party protocols
    /// @param callData Data to pass with the call
    function execute(bytes memory callData) external returns (bytes memory);

    //
    // COLLATERAL VALIDITY AND ACCOUNT HEALTH CHECKS
    //

    /// @dev Performs a full health check on an account with a custom order of evaluated tokens and
    ///      a custom minimal health factor
    /// @param creditAccount Address of the Credit Account to check
    /// @param collateralHints Array of token masks in the desired order of evaluation
    /// @param minHealthFactor Minimal health factor of the account, in PERCENTAGE format
    function fullCollateralCheck(
        address creditAccount,
        uint256 enabledTokensMaskBefore,
        uint256[] memory collateralHints,
        uint16 minHealthFactor
    ) external;

    //
    // QUOTAS MANAGEMENT
    //

    /// @dev Updates credit account's quotas
    /// @param creditAccount Address of credit account
    function updateQuota(address creditAccount, address token, int96 quotaChange)
        external
        returns (uint256 tokensToEnable, uint256 tokensToDisable);

    //
    // GETTERS
    //

    /// @dev Returns the address of a borrower's Credit Account, or reverts if there is none.
    /// @param creditAccount credit account address
    /// @return borrower Borrower's address
    function getBorrowerOrRevert(address creditAccount) external view returns (address borrower);

    /// @dev Maps Credit Accounts to bit masks encoding their enabled token sets
    /// Only enabled tokens are counted as collateral for the Credit Account
    /// @notice An enabled token mask encodes an enabled token by setting
    ///         the bit at the position equal to token's index to 1
    function enabledTokensMaskOf(address creditAccount) external view returns (uint256);

    /// @dev Returns the collateral token with requested mask and its liquidationThreshold
    /// @param tokenMask Token mask corresponding to the token
    function collateralTokenByMask(uint256 tokenMask)
        external
        view
        returns (address token, uint16 liquidationThreshold);

    // /// @dev Returns the array of quoted tokens that are enabled on the account
    // function getQuotedTokens(address creditAccount) external view returns (address[] memory tokens);

    /// @dev Total number of known collateral tokens.
    function collateralTokensCount() external view returns (uint8);

    /// @dev Returns the mask for the provided token
    /// @param token Token to returns the mask for
    function getTokenMaskOrRevert(address token) external view returns (uint256);

    /// @dev Mask of tokens to apply quotas for
    function quotedTokensMask() external view returns (uint256);

    /// @dev Maps allowed adapters to their respective target contracts.
    function adapterToContract(address adapter) external view returns (address);

    /// @dev Maps 3rd party contracts to their respective adapters
    function contractToAdapter(address targetContract) external view returns (address);

    /// @dev Address of the underlying asset
    function underlying() external view returns (address);

    /// @dev Address of the connected pool
    function pool() external view returns (address);

    /// @dev Address of the connected pool
    /// @notice [DEPRECATED]: use pool() instead.
    function poolService() external view returns (address);

    /// @dev Returns the current pool quota keeper connected to the pool
    function poolQuotaKeeper() external view returns (address);

    /// @dev Whether the Credit Manager supports quotas
    function supportsQuotas() external view returns (bool);

    /// @dev Address of the connected Credit Configurator
    function creditConfigurator() external view returns (address);

    /// @dev Address of WETH
    function weth() external view returns (address);

    /// @dev Address of WETHGateway
    function wethGateway() external view returns (address);

    /// @dev Returns the liquidation threshold for the provided token
    /// @param token Token to retrieve the LT for
    function liquidationThresholds(address token) external view returns (uint16);

    /// @dev The maximal number of enabled tokens on a single Credit Account
    function maxEnabledTokens() external view returns (uint8);

    /// @dev Returns the fee parameters of the Credit Manager
    /// @return feeInterest Percentage of interest taken by the protocol as profit
    /// @return feeLiquidation Percentage of account value taken by the protocol as profit
    ///         during unhealthy account liquidations
    /// @return liquidationDiscount Multiplier that reduces the effective totalValue during unhealthy account liquidations,
    ///         allowing the liquidator to take the unaccounted for remainder as premium. Equal to (1 - liquidationPremium)
    /// @return feeLiquidationExpired Percentage of account value taken by the protocol as profit
    ///         during expired account liquidations
    /// @return liquidationDiscountExpired Multiplier that reduces the effective totalValue during expired account liquidations,
    ///         allowing the liquidator to take the unaccounted for remainder as premium. Equal to (1 - liquidationPremiumExpired)
    function fees()
        external
        view
        returns (
            uint16 feeInterest,
            uint16 feeLiquidation,
            uint16 liquidationDiscount,
            uint16 feeLiquidationExpired,
            uint16 liquidationDiscountExpired
        );

    /// @dev Address of address provider
    function addressProvider() external view returns (address);

    /// @dev Address of the connected Credit Facade
    function creditFacade() external view returns (address);

    /// @dev Address of the connected Price Oracle
    function priceOracle() external view returns (address);

    /// @notice Returns the full set of currently active Credit Accounts
    function creditAccounts() external view returns (address[] memory);

    function calcDebtAndCollateral(address creditAccount, CollateralCalcTask task)
        external
        view
        returns (CollateralDebtData memory collateralDebtData);

    function isLiquidatable(address creditAccount, uint16 minHealthFactor) external view returns (bool);

    /// @dev Withdrawal manager
    function withdrawalManager() external view returns (address);

    function scheduleWithdrawal(address creditAccount, address token, uint256 amount)
        external
        returns (uint256 tokensToDisable);

    function claimWithdrawals(address creditAccount, address to, ClaimAction action)
        external
        returns (uint256 tokensToEnable);

    /// @notice Revokes allowances for specified spender/token pairs
    /// @param revocations Spender/token pairs to revoke allowances for
    function revokeAdapterAllowances(address creditAccount, RevocationPair[] calldata revocations) external;

    function setActiveCreditAccount(address creditAccount) external;

    function getActiveCreditAccountOrRevert() external view returns (address creditAccount);

    function getTokenByMask(uint256 tokenMask) external view returns (address token);

    function flagsOf(address creditAccount) external view returns (uint16);

    function setFlagFor(address creditAccount, uint16 flag, bool value) external;
}