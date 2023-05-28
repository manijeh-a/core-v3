// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.17;

import "../../../interfaces/IAddressProviderV3.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {
    ICreditManagerV3,
    ClosureAction,
    CollateralDebtData,
    CollateralCalcTask,
    ManageDebtAction,
    RevocationPair
} from "../../../interfaces/ICreditManagerV3.sol";
import {IPoolV3} from "../../../interfaces/IPoolV3.sol";
import {IPoolQuotaKeeper} from "../../../interfaces/IPoolQuotaKeeper.sol";
import {ClaimAction} from "../../../interfaces/IWithdrawalManager.sol";

import "../../../interfaces/IExceptions.sol";

import "../../lib/constants.sol";

contract CreditManagerMock {
    /// @dev Factory contract for Credit Accounts
    address public addressProvider;

    /// @dev Address of the underlying asset
    address public underlying;

    /// @dev Address of the connected pool
    address public poolService;
    address public pool;

    /// @dev Address of WETH
    address public weth;

    /// @dev Address of WETH Gateway
    address public wethGateway;

    mapping(address => uint256) public tokenMasksMap;

    address public creditFacade;

    address public creditConfigurator;
    address borrower;
    uint256 public quotedTokensMask;
    bool public supportsQuotas;

    CollateralDebtData return_collateralDebtData;

    CollateralDebtData _closeCollateralDebtData;
    uint256 internal _enabledTokensMask;

    address nextCreditAccount;
    uint256 cw_return_tokensToEnable;

    address activeCreditAccount;
    bool revertOnSetActiveAccount;

    uint16 flags;

    address public priceOracle;

    /// @notice Maps allowed adapters to their respective target contracts.
    mapping(address => address) public adapterToContract;

    /// @notice Maps 3rd party contracts to their respective adapters
    mapping(address => address) public contractToAdapter;

    uint256 return_remainingFunds;
    uint256 return_loss;

    uint256 return_newDebt;
    uint256 md_return_tokensToEnable;
    uint256 md_return_tokensToDisable;

    uint256 ad_tokenMask;

    uint256 qu_tokensToEnable;
    uint256 qu_tokensToDisable;

    constructor(address _addressProvider, address _pool) {
        addressProvider = _addressProvider;
        weth = IAddressProviderV3(addressProvider).getAddressOrRevert(AP_WETH_TOKEN, NO_VERSION_CONTROL); // U:[CM-1]
        wethGateway = IAddressProviderV3(addressProvider).getAddressOrRevert(AP_WETH_GATEWAY, 3_00); // U:[CM-1]
        setPoolService(_pool);
        creditConfigurator = CONFIGURATOR;
        supportsQuotas = true;
    }

    function setPriceOracle(address _priceOracle) external {
        priceOracle = _priceOracle;
    }

    function getTokenMaskOrRevert(address token) public view returns (uint256 tokenMask) {
        tokenMask = tokenMasksMap[token];
        if (tokenMask == 0) revert TokenNotAllowedException();
    }

    function setSupportsQuotas(bool _supportsQuotas) external {
        supportsQuotas = _supportsQuotas;
    }

    function setPoolService(address newPool) public {
        poolService = newPool;
        pool = newPool;
    }

    function setCreditFacade(address _creditFacade) external {
        creditFacade = _creditFacade;
    }

    /// @notice Outdated
    function lendCreditAccount(uint256 borrowedAmount, address ca) external {
        IPoolV3(poolService).lendCreditAccount(borrowedAmount, ca);
    }

    /// @notice Outdated
    function repayCreditAccount(uint256 borrowedAmount, uint256 profit, uint256 loss) external {
        IPoolV3(poolService).repayCreditAccount(borrowedAmount, profit, loss);
    }

    function setUpdateQuota(uint256 tokensToEnable, uint256 tokensToDisable) external {
        qu_tokensToEnable = tokensToEnable;
        qu_tokensToDisable = tokensToDisable;
    }

    function updateQuota(address _creditAccount, address token, int96 quotaChange)
        external
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        tokensToEnable = qu_tokensToEnable;
        tokensToDisable = qu_tokensToDisable;
    }

    function addToken(address token, uint256 mask) external {
        tokenMasksMap[token] = mask;
    }

    function setBorrower(address _borrower) external {
        borrower = _borrower;
    }

    function getBorrowerOrRevert(address creditAccount) external view returns (address) {
        if (borrower == address(0)) revert CreditAccountNotExistsException();
        return borrower;
    }

    function setReturnOpenCreditAccount(address _nextCreditAccount) external {
        nextCreditAccount = _nextCreditAccount;
    }

    function openCreditAccount(uint256 debt, address onBehalfOf) external returns (address creditAccount) {
        return nextCreditAccount;
    }

    function setCloseCreditAccountReturns(uint256 remainingFunds, uint256 loss) external {
        return_remainingFunds = remainingFunds;
        return_loss = loss;
    }

    function closeCreditAccount(
        address creditAccount,
        ClosureAction closureAction,
        CollateralDebtData memory collateralDebtData,
        address payer,
        address to,
        uint256 skipTokensMask,
        bool convertToETH
    ) external returns (uint256 remainingFunds, uint256 loss) {
        _closeCollateralDebtData = collateralDebtData;
        remainingFunds = return_remainingFunds;
        loss = return_loss;
    }

    function fullCollateralCheck(
        address creditAccount,
        uint256 enabledTokensMask,
        uint256[] memory collateralHints,
        uint16 minHealthFactor
    ) external {}

    function setRevertOnActiveAccount(bool _value) external {
        revertOnSetActiveAccount = _value;
    }

    function setActiveCreditAccount(address creditAccount) external {
        activeCreditAccount = creditAccount;
    }

    function setQuotedTokensMask(uint256 _quotedTokensMask) external {
        quotedTokensMask = _quotedTokensMask;
    }

    function calcDebtAndCollateral(address creditAccount, CollateralCalcTask task)
        external
        view
        returns (CollateralDebtData memory)
    {
        return return_collateralDebtData;
    }

    function setDebtAndCollateralData(CollateralDebtData calldata _collateralDebtData) external {
        return_collateralDebtData = _collateralDebtData;
    }

    function closeCollateralDebtData() external returns (CollateralDebtData memory) {
        return _closeCollateralDebtData;
    }

    function setClaimWithdrawals(uint256 tokensToEnable) external {
        cw_return_tokensToEnable = tokensToEnable;
    }

    function claimWithdrawals(address creditAccount, address to, ClaimAction action)
        external
        returns (uint256 tokensToEnable)
    {
        tokensToEnable = cw_return_tokensToEnable;
    }

    function enabledTokensMaskOf(address creditAccount) external view returns (uint256) {
        return _enabledTokensMask;
    }

    function setEnabledTokensMask(uint256 newEnabledTokensMask) external {
        _enabledTokensMask = newEnabledTokensMask;
    }

    function setContractAllowance(address adapter, address targetContract) external {
        adapterToContract[adapter] = targetContract; // U:[CM-45]
        contractToAdapter[targetContract] = adapter; // U:[CM-45]
    }

    function execute(bytes calldata data) external returns (bytes memory) {}

    /// FLAGS

    /// @notice Returns the mask containing miscellaneous account flags
    /// @dev Currently, the following flags are supported:
    ///      * 1 - WITHDRAWALS_FLAG - whether the account has pending withdrawals
    ///      * 2 - BOT_PERMISSIONS_FLAG - whether the account has non-zero permissions for at least one bot
    /// @param creditAccount Account to get the mask for
    function flagsOf(address creditAccount) external view returns (uint16) {
        return flags; // U:[CM-35]
    }

    /// @notice Sets a flag for a Credit Account
    /// @param creditAccount Account to set a flag for
    /// @param flag Flag to set
    /// @param value The new flag value
    function setFlagFor(address creditAccount, uint16 flag, bool value) external {
        if (value) {
            _enableFlag(creditAccount, flag); // U:[CM-36]
        } else {
            _disableFlag(creditAccount, flag); // U:[CM-36]
        }
    }

    /// @notice Sets the flag in the CA's flag mask to 1
    function _enableFlag(address creditAccount, uint16 flag) internal {
        flags |= flag; // U:[CM-36]
    }

    /// @notice Sets the flag in the CA's flag mask to 0
    function _disableFlag(address creditAccount, uint16 flag) internal {
        flags &= ~flag; // U:[CM-36]
    }

    function setAddCollateral(uint256 tokenMask) external {
        ad_tokenMask = tokenMask;
    }

    function addCollateral(address payer, address creditAccount, address token, uint256 amount)
        external
        returns (uint256 tokenMask)
    {
        tokenMask = ad_tokenMask;
    }

    function setManageDebt(uint256 newDebt, uint256 tokensToEnable, uint256 tokensToDisable) external {
        return_newDebt = newDebt;
        md_return_tokensToEnable = tokensToEnable;
        md_return_tokensToDisable = tokensToDisable;
    }

    function manageDebt(address creditAccount, uint256 amount, uint256 enabledTokensMask, ManageDebtAction action)
        external
        returns (uint256 newDebt, uint256 tokensToEnable, uint256 tokensToDisable)
    {
        newDebt = return_newDebt;
        tokensToEnable = md_return_tokensToEnable;
        tokensToDisable = md_return_tokensToDisable;
    }

    function scheduleWithdrawal(address creditAccount, address token, uint256 amount)
        external
        returns (uint256 tokensToDisable)
    {}

    function revokeAdapterAllowances(address creditAccount, RevocationPair[] calldata revocations) external {}
}