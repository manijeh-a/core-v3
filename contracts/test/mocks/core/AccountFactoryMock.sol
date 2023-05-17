// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.17;
//pragma abicoder v1;

import {IAccountFactory} from "../../../interfaces/IAccountFactory.sol";
import {CreditAccountMock} from "../credit/CreditAccountMock.sol";

// EXCEPTIONS

import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";

/// @title Disposable credit accounts factory
contract AccountFactoryMock is Test, IAccountFactory {
    /// @dev Contract version
    uint256 public version;

    address public usedAccount;

    address public returnedAccount;

    constructor(uint256 _version) {
        usedAccount = address(new CreditAccountMock());

        version = _version;

        vm.label(usedAccount, "CREDIT_ACCOUNT");
    }

    /// @dev Provides a new credit account to a Credit Manager
    /// @return creditAccount Address of credit account
    function takeCreditAccount(uint256, uint256) external override returns (address creditAccount) {
        return usedAccount;
    }

    function returnCreditAccount(address _usedAccount) external override {
        returnedAccount = _usedAccount;
    }
}
