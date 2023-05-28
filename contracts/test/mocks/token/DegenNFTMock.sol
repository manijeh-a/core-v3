// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.17;

// EXCEPTIONS
import "../../../interfaces/IExceptions.sol";

contract DegenNFTMock {
    bool revertOnBurn;

    function burn(address, uint256 balance) external view {
        if (revertOnBurn) revert InsufficientBalanceException();
    }

    function setRevertOnBurn(bool _revertOnBurn) external {
        revertOnBurn = _revertOnBurn;
    }
}