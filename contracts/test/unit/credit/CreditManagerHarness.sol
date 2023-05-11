import {CreditManagerV3, CreditAccountInfo} from "../../../credit/CreditManagerV3.sol";
import {IPriceOracleV2} from "@gearbox-protocol/core-v2/contracts/interfaces/IPriceOracle.sol";
import {CollateralDebtData} from "../../../interfaces/ICreditManagerV3.sol";

contract CreditManagerV3Harness is CreditManagerV3 {
    constructor(address _pool, address _withdrawalManager) CreditManagerV3(_pool, _withdrawalManager) {}

    function setDebt(address creditAccount, CreditAccountInfo memory _creditAccountInfo) external {
        creditAccountInfo[creditAccount] = _creditAccountInfo;
    }

    function approveSpender(address token, address targetContract, address creditAccount, uint256 amount) external {
        _approveSpender(token, targetContract, creditAccount, amount);
    }

    function getTargetContractOrRevert() external view returns (address targetContract) {
        return _getTargetContractOrRevert();
    }

    function calcFullCollateral(
        address creditAccount,
        uint256 enabledTokensMask,
        uint16 minHealthFactor,
        uint256[] memory collateralHints,
        IPriceOracleV2 _priceOracle,
        bool lazy
    ) external view returns (CollateralDebtData memory collateralDebtData) {
        return
            _calcFullCollateral(creditAccount, enabledTokensMask, minHealthFactor, collateralHints, _priceOracle, lazy);
    }

    function calcQuotedCollateral(address creditAccount, uint256 enabledTokensMask, IPriceOracleV2 _priceOracle)
        internal
        view
        returns (uint256 totalValueUSD, uint256 twvUSD, uint256 quotaInterest, address[] memory tokens)
    {
        return _calcQuotedCollateral(creditAccount, enabledTokensMask, _priceOracle);
    }

    function calcNotQuotedCollateral(
        address creditAccount,
        uint256 enabledTokensMask,
        uint256 enoughCollateralUSD,
        uint256[] memory collateralHints,
        IPriceOracleV2 _priceOracle
    ) internal view returns (uint256 tokensToDisable, uint256 totalValueUSD, uint256 twvUSD) {
        return _calcNotQuotedCollateral(
            creditAccount, enabledTokensMask, enoughCollateralUSD, collateralHints, _priceOracle
        );
    }

    function calcOneNonQuotedTokenCollateral(
        IPriceOracleV2 _priceOracle,
        uint256 tokenMask,
        address creditAccount,
        uint256 _totalValueUSD,
        uint256 _twvUSDx10K
    ) internal view returns (uint256 totalValueUSD, uint256 twvUSDx10K, bool nonZeroBalance) {
        return _calcOneNonQuotedTokenCollateral(_priceOracle, tokenMask, creditAccount, _totalValueUSD, _twvUSDx10K);
    }

    function _getQuotedTokensLT(uint256 enabledTokensMask, bool withLTs)
        internal
        view
        returns (address[] memory tokens, uint256[] memory lts)
    {
        return _getQuotedTokens(enabledTokensMask, withLTs);
    }

    function transferAssetsTo(address creditAccount, address to, bool convertWETH, uint256 enabledTokensMask)
        external
    {
        _transferAssetsTo(creditAccount, to, convertWETH, enabledTokensMask);
    }

    function safeTokenTransfer(address creditAccount, address token, address to, uint256 amount, bool convertToETH)
        internal
    {
        _safeTokenTransfer(creditAccount, token, to, amount, convertToETH);
    }

    function checkEnabledTokenLength(uint256 enabledTokensMask) internal view {
        _checkEnabledTokenLength(enabledTokensMask);
    }

    function collateralTokensByMaskCalcLT(uint256 tokenMask, bool calcLT)
        internal
        view
        returns (address token, uint16 liquidationThreshold)
    {
        return _collateralTokensByMask(tokenMask, calcLT);
    }

    function calcCreditAccountAccruedInterest(address creditAccount, uint256 quotaInterest)
        internal
        view
        returns (uint256 debt, uint256 accruedInterest, uint256 accruedFees)
    {
        return _calcCreditAccountAccruedInterest(creditAccount, quotaInterest);
    }

    function getCreditAccountParameters(address creditAccount)
        internal
        view
        returns (uint256 debt, uint256 cumulativeIndexLastUpdate, uint256 cumulativeIndexNow)
    {
        return _getCreditAccountParameters(creditAccount);
    }

    function hasWithdrawals(address creditAccount) internal view returns (bool) {
        return hasWithdrawals(creditAccount);
    }

    function calcCancellableWithdrawalsValue(IPriceOracleV2 _priceOracle, address creditAccount, bool isForceCancel)
        external
    {
        _calcCancellableWithdrawalsValue(_priceOracle, creditAccount, isForceCancel);
    }

    function saveEnabledTokensMask(address creditAccount, uint256 enabledTokensMask) internal {
        _saveEnabledTokensMask(creditAccount, enabledTokensMask);
    }

    function convertToUSD(IPriceOracleV2 _priceOracle, uint256 amountInToken, address token)
        external
        returns (uint256 amountInUSD)
    {
        return _convertToUSD(_priceOracle, amountInToken, token);
    }
}
