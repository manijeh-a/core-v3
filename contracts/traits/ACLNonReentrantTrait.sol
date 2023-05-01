// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {AddressProvider} from "@gearbox-protocol/core-v2/contracts/core/AddressProvider.sol";
import {IACL} from "@gearbox-protocol/core-v2/contracts/interfaces/IACL.sol";
import {
    ZeroAddressException,
    CallerNotConfiguratorException,
    CallerNotPausableAdminException,
    CallerNotUnPausableAdminException,
    CallerNotControllerException
} from "../interfaces/IExceptions.sol";

import {ACLTrait} from "./ACLTrait.sol";

/// @title ACL Trait
/// @notice Utility class for ACL consumers
abstract contract ACLNonReentrantTrait is ACLTrait, Pausable {
    uint8 private constant _NOT_ENTERED = 1;
    uint8 private constant _ENTERED = 2;

    address public controller;
    bool public externalController;

    uint8 private _status = _NOT_ENTERED;

    /// @dev Modifier that allow pausable admin to call only
    modifier pausableAdminsOnly() {
        if (!_acl.isPausableAdmin(msg.sender)) {
            revert CallerNotPausableAdminException();
        }
        _;
    }

    /// @dev Prevents a contract from calling itself, directly or indirectly.
    /// Calling a `nonReentrant` function from another `nonReentrant`
    /// function is not supported. It is possible to prevent this from happening
    /// by making the `nonReentrant` function external, and making it call a
    /// `private` function that does the actual work.
    ///
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }

    event NewController(address indexed newController);

    /// @dev constructor
    /// @param addressProvider Address of address repository
    constructor(address addressProvider) ACLTrait(addressProvider) nonZeroAddress(addressProvider) {
        controller = IACL(AddressProvider(addressProvider).getACL()).owner();
    }

    /// @dev  Reverts if msg.sender is not configurator
    modifier controllerOnly() {
        if (externalController) {
            if (msg.sender != controller) {
                revert CallerNotControllerException();
            }
        } else {
            if (!_acl.isConfigurator(msg.sender)) {
                revert CallerNotControllerException();
            }
        }
        _;
    }

    ///@dev Pause contract
    function pause() external {
        if (!_acl.isPausableAdmin(msg.sender)) {
            revert CallerNotPausableAdminException();
        }
        _pause();
    }

    /// @dev Unpause contract
    function unpause() external {
        if (!_acl.isUnpausableAdmin(msg.sender)) {
            revert CallerNotUnPausableAdminException();
        }

        _unpause();
    }

    function setController(address newController) external configuratorOnly {
        externalController = !_acl.isConfigurator(newController);
        controller = newController;
        emit NewController(newController);
    }
}
