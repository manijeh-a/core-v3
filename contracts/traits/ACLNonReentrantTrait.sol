// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.17;

import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {AddressProvider} from "@gearbox-protocol/core-v2/contracts/core/AddressProvider.sol";
import {IACL} from "@gearbox-protocol/core-v2/contracts/interfaces/IACL.sol";
import {
    ZeroAddressException,
    CallerNotConfiguratorException,
    CallerNotPausableAdminException,
    CallerNotUnpausableAdminException,
    CallerNotControllerException
} from "../interfaces/IExceptions.sol";

import {ACLTrait} from "./ACLTrait.sol";
import {NOT_ENTERED, ENTERED} from "./ReentrancyGuardTrait.sol";

/// @title ACL Trait
/// @notice Utility class for ACL consumers
abstract contract ACLNonReentrantTrait is ACLTrait, Pausable {
    /// @dev Emitted when new external controller is set
    event NewController(address indexed newController);

    uint8 internal _reentrancyStatus = NOT_ENTERED;

    address public controller;
    bool public externalController;

    /// @dev Prevents a contract from calling itself, directly or indirectly.
    /// Calling a `nonReentrant` function from another `nonReentrant`
    /// function is not supported. It is possible to prevent this from happening
    /// by making the `nonReentrant` function external, and making it call a
    /// `private` function that does the actual work.
    ///
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_reentrancyStatus != ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _reentrancyStatus = ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _reentrancyStatus = NOT_ENTERED;
    }

    /// @dev Ensures that caller is external controller (if it is set) or configurator
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

    /// @dev Ensures that caller is pausable admin
    modifier pausableAdminsOnly() {
        if (!_acl.isPausableAdmin(msg.sender)) {
            revert CallerNotPausableAdminException();
        }
        _;
    }

    /// @dev Ensures that caller is unpausable admin
    modifier unpausableAdminsOnly() {
        if (!_acl.isUnpausableAdmin(msg.sender)) {
            revert CallerNotUnpausableAdminException();
        }
        _;
    }

    /// @dev constructor
    /// @param addressProvider Address of address repository
    constructor(address addressProvider) ACLTrait(addressProvider) nonZeroAddress(addressProvider) {
        controller = IACL(AddressProvider(addressProvider).getACL()).owner();
    }

    ///@dev Pauses contract
    function pause() external virtual pausableAdminsOnly {
        _pause();
    }

    /// @dev Unpauses contract
    function unpause() external virtual unpausableAdminsOnly {
        _unpause();
    }

    /// @dev Sets new external controller
    function setController(address newController) external configuratorOnly {
        externalController = !_acl.isConfigurator(newController);
        controller = newController;
        emit NewController(newController);
    }
}