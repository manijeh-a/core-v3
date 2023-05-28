// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.17;
pragma abicoder v1;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {AddressProvider} from "@gearbox-protocol/core-v2/contracts/core/AddressProvider.sol";

/// LIBS & TRAITS
import {ACLNonReentrantTrait} from "../traits/ACLNonReentrantTrait.sol";
import {ContractsRegisterTrait} from "../traits/ContractsRegisterTrait.sol";
import {CreditLogic} from "../libraries/CreditLogic.sol";

import {QuotasLogic} from "../libraries/QuotasLogic.sol";

import {IPoolV3} from "../interfaces/IPoolV3.sol";
import {IPoolQuotaKeeper, TokenQuotaParams, AccountQuota} from "../interfaces/IPoolQuotaKeeper.sol";
import {IGauge} from "../interfaces/IGauge.sol";
import {ICreditManagerV3} from "../interfaces/ICreditManagerV3.sol";

import {RAY, SECONDS_PER_YEAR, MAX_WITHDRAW_FEE} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";
import {PERCENTAGE_FACTOR} from "@gearbox-protocol/core-v2/contracts/libraries/PercentageMath.sol";

// EXCEPTIONS
import "../interfaces/IExceptions.sol";

uint192 constant RAY_DIVIDED_BY_PERCENTAGE = uint192(RAY / PERCENTAGE_FACTOR);

/// @title Pool quota keeper
/// @dev The PQK works as an intermediary between the Credit Manager and the pool with regards to quotas and quota interest.
///      The PQK stores all of the quotas and related parameters, and computes and updates the quota revenue value used by
///      the pool to include quota interest in its liquidity.
/// @dev Account quotas are user-set values that limit the exposure of an account to a particular asset. The USD value of an asset
///      counted towards account's collateral cannot exceed the USD calue of the respective quota. Users pay interest on their quotas,
///      both as an anti-spam measure and a way to price-discriminate based on asset's risk
contract PoolQuotaKeeper is IPoolQuotaKeeper, ACLNonReentrantTrait, ContractsRegisterTrait {
    using EnumerableSet for EnumerableSet.AddressSet;
    using QuotasLogic for TokenQuotaParams;

    /// @notice Address of the underlying token
    address public immutable underlying;

    /// @notice Address of the liquidity pool
    address public immutable override pool;

    /// @notice The list of all connected Credit Managers
    EnumerableSet.AddressSet internal creditManagerSet;

    /// @notice The list of all quoted tokens
    EnumerableSet.AddressSet internal quotaTokensSet;

    /// @notice Mapping from token address to global per-token params
    mapping(address => TokenQuotaParams) public totalQuotaParams;

    /// @notice Mapping from creditAccount => token => per-account quota params
    mapping(address => mapping(address => AccountQuota)) internal accountQuotas;

    /// @notice Address of the Gauge
    address public gauge;

    /// @notice Timestamp of the last time quota rates were batch-updated
    uint40 public lastQuotaRateUpdate;

    /// @notice Contract version
    uint256 public constant override version = 3_00;

    /// @dev Reverts if the function is called by non-gauge
    modifier gaugeOnly() {
        if (msg.sender != gauge) revert CallerNotGaugeException(); // F:[PQK-3]
        _;
    }

    /// @dev Reverts if the function is called by non-Credit Manager
    modifier creditManagerOnly() {
        if (!creditManagerSet.contains(msg.sender)) {
            revert CallerNotCreditManagerException(); // F:[PQK-4]
        }
        _;
    }

    //
    // CONSTRUCTOR
    //

    /// @dev Constructor
    /// @param _pool Pool address
    constructor(address _pool)
        ACLNonReentrantTrait(IPoolV3(_pool).addressProvider())
        ContractsRegisterTrait(IPoolV3(_pool).addressProvider())
    {
        pool = _pool; // F:[PQK-1]
        underlying = IPoolV3(_pool).asset(); // F:[PQK-1]
    }

    /// @notice Updates a Credit Account's quota amount for a token
    /// @param creditAccount Address of credit account
    /// @param token Address of the token
    /// @param quotaChange Signed quota change amount
    /// @return caQuotaInterestChange Accrued quota interest since last interest update.
    ///                               It is expected that this value is stored/used by the caller,
    ///                               as PQK will update the interest index, which will set local accrued interest to 0
    /// @return enableToken Whether the token needs to be enabled
    /// @return disableToken Whether the token needs to be disabled
    function updateQuota(address creditAccount, address token, int96 quotaChange)
        external
        override
        creditManagerOnly // F:[PQK-4]
        returns (uint256 caQuotaInterestChange, bool enableToken, bool disableToken)
    {
        int256 quotaRevenueChange;

        AccountQuota storage accountQuota = accountQuotas[creditAccount][token];
        TokenQuotaParams storage tokenQuotaParams = totalQuotaParams[token];
        /// On quota update:
        /// FOR ANY CHANGE
        /// * Computes the accrued quota interest since last update and updates the interest index,
        ///   so that
        /// INCREASE
        /// * Computes the current capacity until quota limit and checks the amount against it
        /// * Computes whether the token should be enabled (quota changed from zero to non-zero)
        /// * Increases the account quota and total quota by the amount (or remaining capacity, if the amount exceeds it)
        /// * Adds a one-time quota increase fee (if enabled)
        /// * Computes the total quota revenue change
        /// DECREASE
        /// * Decreases the account quota and total quota by the amount
        /// * Computes whether the token should be disabled (quota changed from non-zero to zero)
        /// * Computes the total quota revenue change
        (caQuotaInterestChange, quotaRevenueChange, enableToken, disableToken) = QuotasLogic.changeQuota({
            tokenQuotaParams: tokenQuotaParams,
            accountQuota: accountQuota,
            lastQuotaRateUpdate: lastQuotaRateUpdate,
            quotaChange: quotaChange
        });

        /// Quota revenue must be changed on each quota updated, so that the
        /// pool can correctly compute its liquidity metrics in the future
        if (quotaRevenueChange != 0) {
            IPoolV3(pool).updateQuotaRevenue(quotaRevenueChange);
        }
    }

    /// @notice Updates all Credit Account quotas to zero
    /// @param creditAccount Address of the Credit Account to remove quotas from
    /// @param tokens Array of all active quoted tokens on the account
    /// @param setLimitsToZero Whether limits for affected tokens should be set to zero
    function removeQuotas(address creditAccount, address[] memory tokens, bool setLimitsToZero)
        external
        override
        creditManagerOnly // F:[PQK-4]
    {
        int256 quotaRevenueChange;

        uint256 len = tokens.length;

        for (uint256 i; i < len;) {
            address token = tokens[i];
            if (token == address(0)) break;

            AccountQuota storage accountQuota = accountQuotas[creditAccount][token];
            TokenQuotaParams storage tokenQuotaParams = totalQuotaParams[token];

            /// On quota removal:
            /// * Decreases the total token quota by the account's quota
            /// * Sets account quota to zero
            /// * Computes quota revenue change

            quotaRevenueChange +=
                QuotasLogic.removeQuota({tokenQuotaParams: tokenQuotaParams, accountQuota: accountQuota}); // F:[CMQ-06]

            /// On some critical triggers (such as account liquidating with a loss), the Credit Manager
            /// may request the PQK to set quota limits to 0, effectively preventing any further exposure
            /// to the token until the limit is raised again
            if (setLimitsToZero) {
                _setTokenLimit({tokenQuotaParams: tokenQuotaParams, token: token, limit: 1});
            }

            unchecked {
                ++i;
            }
        }

        if (quotaRevenueChange != 0) {
            IPoolV3(pool).updateQuotaRevenue(quotaRevenueChange);
        }
    }

    /// @notice Updates interest indexes for all Credit Account's quotas to current index
    /// @dev This effectively sets accrued interest to 0 locally - the function assumes
    ///      that the calling Credit Manager has computed and stored pending interest
    ///      beforehand
    /// @param creditAccount Address of the Credit Account to accrue interest for
    /// @param tokens Array of all active quoted tokens on the account
    function accrueQuotaInterest(address creditAccount, address[] memory tokens)
        external
        override
        creditManagerOnly // F:[PQK-4]
    {
        uint256 len = tokens.length;
        uint40 _lastQuotaRateUpdate = lastQuotaRateUpdate;
        unchecked {
            for (uint256 i; i < len; ++i) {
                address token = tokens[i];
                if (token == address(0)) break;

                QuotasLogic.accrueAccountQuotaInterest({
                    tokenQuotaParams: totalQuotaParams[token],
                    accountQuota: accountQuotas[creditAccount][token],
                    lastQuotaRateUpdate: _lastQuotaRateUpdate
                });
            }
        }
    }

    //
    // GETTERS
    //

    /// @notice Returns the account's quota and accrued interest since last update
    /// @param creditAccount Credit Account to compute values for
    /// @param token Token to compute values for
    /// @return quoted Account's quota amount
    /// @return interest Interest accrued since last interest update
    function getQuotaAndOutstandingInterest(address creditAccount, address token)
        external
        view
        override
        returns (uint256 quoted, uint256 interest)
    {
        AccountQuota storage accountQuota = accountQuotas[creditAccount][token];

        quoted = accountQuota.quota;

        if (quoted > 1) {
            interest = CreditLogic.calcAccruedInterest({
                amount: quoted,
                cumulativeIndexLastUpdate: accountQuota.cumulativeIndexLU,
                cumulativeIndexNow: cumulativeIndex(token)
            }); // F:[CMQ-8]
        }
    }

    /// @notice Returns current interest index in RAY for a quoted token. Returns 0 for non-quoted tokens.
    function cumulativeIndex(address token) public view override returns (uint192) {
        return totalQuotaParams[token].cumulativeIndexSince(lastQuotaRateUpdate);
    }

    /// @notice Returns quota interest rate for a token in PERCENTAGE FORMAT
    function getQuotaRate(address token) external view override returns (uint16) {
        return totalQuotaParams[token].rate;
    }

    /// @notice Returns an array of all quoted tokens
    function quotedTokens() external view override returns (address[] memory) {
        return quotaTokensSet.values();
    }

    /// @notice Returns whether a token is quoted
    function isQuotedToken(address token) external view override returns (bool) {
        return quotaTokensSet.contains(token);
    }

    /// @notice Returns quota parameters for a single (account, token) pair
    function getQuota(address creditAccount, address token)
        external
        view
        returns (uint96 quota, uint192 cumulativeIndexLU)
    {
        AccountQuota storage aq = accountQuotas[creditAccount][token];
        return (aq.quota, aq.cumulativeIndexLU);
    }

    /// @notice Returns list of connected credit managers
    function creditManagers() external view returns (address[] memory) {
        return creditManagerSet.values(); // F:[PQK-10]
    }

    //
    // GAUGE-ONLY FUNCTIONS
    //

    /// @notice Registers a new quoted token
    /// @param token Address of the token
    function addQuotaToken(address token)
        external
        gaugeOnly // F:[PQK-3]
    {
        if (quotaTokensSet.contains(token)) {
            revert TokenAlreadyAddedException(); // F:[PQK-6]
        }

        /// The interest rate is not set immediately on adding a quoted token,
        /// since all rates are updated during a general epoch update in the Gauge
        quotaTokensSet.add(token); // F:[PQK-5]
        totalQuotaParams[token].initialise(); // F:[PQK-5]

        emit NewQuotaTokenAdded(token); // F:[PQK-5]
    }

    /// @notice Batch updates the quota rates and changes the combined quota revenue
    function updateRates()
        external
        override
        gaugeOnly // F:[PQK-3]
    {
        address[] memory tokens = quotaTokensSet.values();
        uint16[] memory rates = IGauge(gauge).getRates(tokens); // F:[PQK-7]

        uint256 quotaRevenue;
        uint256 timeFromLastUpdate = block.timestamp - lastQuotaRateUpdate;
        uint256 len = tokens.length;

        for (uint256 i; i < len;) {
            address token = tokens[i];
            uint16 rate = rates[i];

            /// Before writing a new rate, the token's interest index current value is also
            /// saved, to ensure that further calculations with the new rates are correct
            TokenQuotaParams storage tokenQuotaParams = totalQuotaParams[token];
            quotaRevenue += tokenQuotaParams.updateRate(timeFromLastUpdate, rate);

            emit UpdateTokenQuotaRate(token, rate); // F:[PQK-7]

            unchecked {
                ++i;
            }
        }

        IPoolV3(pool).setQuotaRevenue(quotaRevenue); // F:[PQK-7]
        lastQuotaRateUpdate = uint40(block.timestamp); // F:[PQK-7]
    }

    //
    // CONFIGURATION
    //

    /// @notice Sets a new gauge contract to compute quota rates
    /// @param _gauge The new contract's address
    function setGauge(address _gauge)
        external
        configuratorOnly // F:[PQK-2]
    {
        if (gauge != _gauge) {
            gauge = _gauge; // F:[PQK-8]
            lastQuotaRateUpdate = uint40(block.timestamp); // F:[PQK-8]
            emit SetGauge(_gauge); // F:[PQK-8]
        }
    }

    /// @notice Adds a new Credit Manager to the set of allowed CM's
    /// @param _creditManager Address of the new Credit Manager
    function addCreditManager(address _creditManager)
        external
        configuratorOnly // F:[PQK-2]
        nonZeroAddress(_creditManager)
        registeredCreditManagerOnly(_creditManager) // F:[PQK-9]
    {
        if (ICreditManagerV3(_creditManager).pool() != address(pool)) {
            revert IncompatibleCreditManagerException(); // F:[PQK-9]
        }

        /// Checks if creditManager is already in list
        if (!creditManagerSet.contains(_creditManager)) {
            creditManagerSet.add(_creditManager); // F:[PQK-10]
            emit AddCreditManager(_creditManager); // F:[PQK-10]
        }
    }

    /// @notice Sets an upper limit for total quotas across all accounts for a token
    /// @param token Address of token to set the limit for
    /// @param limit The limit to set
    function setTokenLimit(address token, uint96 limit)
        external
        controllerOnly // F:[PQK-2]
    {
        TokenQuotaParams storage tokenQuotaParams = totalQuotaParams[token];
        _setTokenLimit(tokenQuotaParams, token, limit);
    }

    /// @dev IMPLEMENTATION: setTokenLimit
    function _setTokenLimit(TokenQuotaParams storage tokenQuotaParams, address token, uint96 limit) internal {
        if (tokenQuotaParams.setLimit(limit)) {
            emit SetTokenLimit(token, limit);
        } // F:[PQK-12]
    }

    /// @notice Sets the one-time fee paid on each quota increase
    /// @param token Token to set the fee for
    /// @param fee The new fee value in PERCENTAGE_FACTOR format
    function setTokenQuotaIncreaseFee(address token, uint16 fee) external controllerOnly {
        TokenQuotaParams storage tokenQuotaParams = totalQuotaParams[token];
        if (tokenQuotaParams.setQuotaIncreaseFee(fee)) {
            emit SetQuotaIncreaseFee(token, fee);
        }
    }
}
