// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import {IPool4626} from "../../../interfaces/IPool4626.sol";
import {IPoolQuotaKeeper, QuotaUpdate, QuotaStatusChange} from "../../../interfaces/IPoolQuotaKeeper.sol";
import "../../lib/constants.sol";

contract CreditManagerMockForPoolTest {
    address public poolService;
    address public pool;
    address public underlying;

    address public creditAccount = DUMB_ADDRESS;

    constructor(address _poolService) {
        poolService = _poolService;
    }

    function changePoolService(address newPool) external {
        poolService = newPool;
        pool = newPool;
    }

    /**
     * @dev Transfers money from the pool to credit account
     * and updates the pool parameters
     * @param borrowedAmount Borrowed amount for credit account
     * @param ca Credit account address
     */
    function lendCreditAccount(uint256 borrowedAmount, address ca) external {
        IPool4626(poolService).lendCreditAccount(borrowedAmount, ca);
    }

    /**
     * @dev Recalculates total borrowed & borrowRate
     * mints/burns diesel tokens
     */
    function repayCreditAccount(uint256 borrowedAmount, uint256 profit, uint256 loss) external {
        IPool4626(poolService).repayCreditAccount(borrowedAmount, profit, loss);
    }

    function getCreditAccountOrRevert(address) public view returns (address result) {
        result = creditAccount;
    }

    function updateQuotas(address _creditAccount, QuotaUpdate[] memory quotaUpdates)
        external
        returns (uint256 caQuotaInterestChange, QuotaStatusChange[] memory statusChanges, bool statusWasChanged)
    {
        return IPoolQuotaKeeper(IPool4626(pool).poolQuotaKeeper()).updateQuotas(_creditAccount, quotaUpdates);
    }
}
