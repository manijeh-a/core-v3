// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {ControllerTimelockV3} from "../../../governance/ControllerTimelockV3.sol";
import {Policy} from "../../../governance/PolicyManagerV3.sol";
import {GeneralMock} from "../../mocks/GeneralMock.sol";

import {ICreditManagerV3} from "../../../interfaces/ICreditManagerV3.sol";
import {ICreditFacadeV3} from "../../../interfaces/ICreditFacadeV3.sol";
import {ICreditConfiguratorV3} from "../../../interfaces/ICreditConfiguratorV3.sol";
import {IPoolV3} from "../../../interfaces/IPoolV3.sol";
import {IPoolQuotaKeeperV3} from "../../../interfaces/IPoolQuotaKeeperV3.sol";
import {IGaugeV3} from "../../../interfaces/IGaugeV3.sol";
import {PoolV3} from "../../../pool/PoolV3.sol";
import {PoolQuotaKeeperV3} from "../../../pool/PoolQuotaKeeperV3.sol";
import {GaugeV3} from "../../../governance/GaugeV3.sol";
import {ILPPriceFeedV2} from "@gearbox-protocol/core-v2/contracts/interfaces/ILPPriceFeedV2.sol";
import {IControllerTimelockV3Events, IControllerTimelockV3Errors} from "../../../interfaces/IControllerTimelockV3.sol";

// TEST
import "../../lib/constants.sol";

// MOCKS
import {AddressProviderV3ACLMock} from "../../mocks/core/AddressProviderV3ACLMock.sol";

// EXCEPTIONS
import "../../../interfaces/IExceptions.sol";

contract ControllerTimelockTest is Test, IControllerTimelockV3Events, IControllerTimelockV3Errors {
    AddressProviderV3ACLMock public addressProvider;

    ControllerTimelockV3 public controllerTimelock;

    address admin;
    address vetoAdmin;

    function setUp() public {
        admin = makeAddr("ADMIN");
        vetoAdmin = makeAddr("VETO_ADMIN");

        vm.prank(CONFIGURATOR);
        addressProvider = new AddressProviderV3ACLMock();
        controllerTimelock = new ControllerTimelockV3(address(addressProvider), vetoAdmin);
    }

    function _makeMocks()
        internal
        returns (
            address creditManager,
            address creditFacade,
            address creditConfigurator,
            address pool,
            address poolQuotaKeeper
        )
    {
        creditManager = address(new GeneralMock());
        creditFacade = address(new GeneralMock());
        creditConfigurator = address(new GeneralMock());
        pool = address(new GeneralMock());
        poolQuotaKeeper = address(new GeneralMock());

        vm.mockCall(
            creditManager, abi.encodeWithSelector(ICreditManagerV3.creditFacade.selector), abi.encode(creditFacade)
        );

        vm.mockCall(
            creditManager,
            abi.encodeWithSelector(ICreditManagerV3.creditConfigurator.selector),
            abi.encode(creditConfigurator)
        );

        vm.mockCall(creditManager, abi.encodeWithSelector(ICreditManagerV3.pool.selector), abi.encode(pool));

        vm.mockCall(pool, abi.encodeCall(IPoolV3.poolQuotaKeeper, ()), abi.encode(poolQuotaKeeper));

        vm.prank(CONFIGURATOR);
        controllerTimelock.setGroup(creditManager, "CM");

        vm.prank(CONFIGURATOR);
        controllerTimelock.setGroup(pool, "POOL");

        vm.label(creditManager, "CREDIT_MANAGER");
        vm.label(creditFacade, "CREDIT_FACADE");
        vm.label(creditConfigurator, "CREDIT_CONFIGURATOR");
        vm.label(pool, "POOL");
        vm.label(poolQuotaKeeper, "PQK");
    }

    ///
    ///
    ///  TESTS
    ///
    ///

    /// @dev U:[CT-1]: setExpirationDate works correctly
    function test_U_CT_01_setExpirationDate_works_correctly() public {
        (address creditManager, address creditFacade, address creditConfigurator, address pool,) = _makeMocks();

        bytes32 POLICY_CODE = keccak256(abi.encode("CM", "EXPIRATION_DATE"));

        vm.mockCall(
            creditFacade, abi.encodeWithSelector(ICreditFacadeV3.expirationDate.selector), abi.encode(block.timestamp)
        );

        vm.mockCall(
            pool, abi.encodeWithSelector(IPoolV3.creditManagerBorrowed.selector, creditManager), abi.encode(1234)
        );

        Policy memory policy = Policy({
            enabled: false,
            admin: admin,
            flags: 1,
            exactValue: block.timestamp + 5,
            minValue: 0,
            maxValue: 0,
            referencePoint: 0,
            referencePointUpdatePeriod: 0,
            referencePointTimestampLU: 0,
            minPctChange: 0,
            maxPctChange: 0,
            minChange: 0,
            maxChange: 0
        });

        // VERIFY THAT THE FUNCTION CANNOT BE CALLED WITHOUT RESPECTIVE POLICY
        vm.expectRevert(ParameterChecksFailedException.selector);
        vm.prank(admin);
        controllerTimelock.setExpirationDate(creditManager, uint40(block.timestamp + 5));

        vm.prank(CONFIGURATOR);
        controllerTimelock.setPolicy(POLICY_CODE, policy);

        // VERIFY THAT THE FUNCTION IS ONLY CALLABLE BY ADMIN
        vm.expectRevert(ParameterChecksFailedException.selector);
        vm.prank(USER);
        controllerTimelock.setExpirationDate(creditManager, uint40(block.timestamp + 5));

        // VERIFY THAT POLICY CHECKS ARE PERFORMED
        vm.expectRevert(ParameterChecksFailedException.selector);
        vm.prank(admin);
        controllerTimelock.setExpirationDate(creditManager, uint40(block.timestamp + 4));

        // VERIFY THAT EXTRA CHECKS ARE PERFORMED
        vm.expectRevert(ParameterChecksFailedException.selector);
        vm.prank(admin);
        controllerTimelock.setExpirationDate(creditManager, uint40(block.timestamp + 5));

        vm.mockCall(pool, abi.encodeWithSelector(IPoolV3.creditManagerBorrowed.selector, creditManager), abi.encode(0));

        // VERIFY THAT THE FUNCTION IS QUEUED AND EXECUTED CORRECTLY
        bytes32 txHash = keccak256(
            abi.encode(
                admin,
                creditConfigurator,
                "setExpirationDate(uint40)",
                abi.encode(block.timestamp + 5),
                block.timestamp + 1 days
            )
        );

        vm.expectEmit(true, false, false, true);
        emit QueueTransaction(
            txHash,
            admin,
            creditConfigurator,
            "setExpirationDate(uint40)",
            abi.encode(block.timestamp + 5),
            uint40(block.timestamp + 1 days)
        );

        vm.prank(admin);
        controllerTimelock.setExpirationDate(creditManager, uint40(block.timestamp + 5));

        vm.expectCall(
            creditConfigurator,
            abi.encodeWithSelector(ICreditConfiguratorV3.setExpirationDate.selector, block.timestamp + 5)
        );

        vm.warp(block.timestamp + 1 days);

        vm.prank(admin);
        controllerTimelock.executeTransaction(txHash);

        (bool queued,,,,,) = controllerTimelock.queuedTransactions(txHash);

        assertTrue(!queued, "Transaction is still queued after execution");
    }

    /// @dev U:[CT-2]: setLPPriceFeedLimiter works correctly
    function test_U_CT_02_setLPPriceFeedLimiter_works_correctly() public {
        address lpPriceFeed = address(new GeneralMock());

        vm.prank(CONFIGURATOR);
        controllerTimelock.setGroup(lpPriceFeed, "LP_PRICE_FEED");

        vm.mockCall(lpPriceFeed, abi.encodeWithSelector(ILPPriceFeedV2.lowerBound.selector), abi.encode(5));

        bytes32 POLICY_CODE = keccak256(abi.encode("LP_PRICE_FEED", "LP_PRICE_FEED_LIMITER"));

        Policy memory policy = Policy({
            enabled: false,
            admin: admin,
            flags: 1,
            exactValue: 7,
            minValue: 0,
            maxValue: 0,
            referencePoint: 0,
            referencePointUpdatePeriod: 0,
            referencePointTimestampLU: 0,
            minPctChange: 0,
            maxPctChange: 0,
            minChange: 0,
            maxChange: 0
        });

        // VERIFY THAT THE FUNCTION CANNOT BE CALLED WITHOUT RESPECTIVE POLICY
        vm.expectRevert(ParameterChecksFailedException.selector);
        vm.prank(admin);
        controllerTimelock.setLPPriceFeedLimiter(lpPriceFeed, 7);

        vm.prank(CONFIGURATOR);
        controllerTimelock.setPolicy(POLICY_CODE, policy);

        // VERIFY THAT THE FUNCTION IS ONLY CALLABLE BY ADMIN
        vm.expectRevert(ParameterChecksFailedException.selector);
        vm.prank(USER);
        controllerTimelock.setLPPriceFeedLimiter(lpPriceFeed, 7);

        // VERIFY THAT POLICY CHECKS ARE PERFORMED
        vm.expectRevert(ParameterChecksFailedException.selector);
        vm.prank(admin);
        controllerTimelock.setLPPriceFeedLimiter(lpPriceFeed, 8);

        // VERIFY THAT THE FUNCTION IS QUEUED AND EXECUTED CORRECTLY
        bytes32 txHash =
            keccak256(abi.encode(admin, lpPriceFeed, "setLimiter(uint256)", abi.encode(7), block.timestamp + 1 days));

        vm.expectEmit(true, false, false, true);
        emit QueueTransaction(
            txHash, admin, lpPriceFeed, "setLimiter(uint256)", abi.encode(7), uint40(block.timestamp + 1 days)
        );

        vm.prank(admin);
        controllerTimelock.setLPPriceFeedLimiter(lpPriceFeed, 7);

        vm.expectCall(lpPriceFeed, abi.encodeWithSelector(ILPPriceFeedV2.setLimiter.selector, 7));

        vm.warp(block.timestamp + 1 days);

        vm.prank(admin);
        controllerTimelock.executeTransaction(txHash);

        (bool queued,,,,,) = controllerTimelock.queuedTransactions(txHash);

        assertTrue(!queued, "Transaction is still queued after execution");
    }

    /// @dev U:[CT-3]: setMaxDebtPerBlockMultiplier works correctly
    function test_U_CT_03_setMaxDebtPerBlockMultiplier_works_correctly() public {
        (address creditManager, address creditFacade, address creditConfigurator,,) = _makeMocks();

        bytes32 POLICY_CODE = keccak256(abi.encode("CM", "MAX_DEBT_PER_BLOCK_MULTIPLIER"));

        vm.mockCall(
            creditFacade, abi.encodeWithSelector(ICreditFacadeV3.maxDebtPerBlockMultiplier.selector), abi.encode(3)
        );

        Policy memory policy = Policy({
            enabled: false,
            admin: admin,
            flags: 1,
            exactValue: 4,
            minValue: 0,
            maxValue: 0,
            referencePoint: 0,
            referencePointUpdatePeriod: 0,
            referencePointTimestampLU: 0,
            minPctChange: 0,
            maxPctChange: 0,
            minChange: 0,
            maxChange: 0
        });

        // VERIFY THAT THE FUNCTION CANNOT BE CALLED WITHOUT RESPECTIVE POLICY
        vm.expectRevert(ParameterChecksFailedException.selector);
        vm.prank(admin);
        controllerTimelock.setMaxDebtPerBlockMultiplier(creditManager, 4);

        vm.prank(CONFIGURATOR);
        controllerTimelock.setPolicy(POLICY_CODE, policy);

        // VERIFY THAT THE FUNCTION IS ONLY CALLABLE BY ADMIN
        vm.expectRevert(ParameterChecksFailedException.selector);
        vm.prank(USER);
        controllerTimelock.setMaxDebtPerBlockMultiplier(creditManager, 4);

        // VERIFY THAT POLICY CHECKS ARE PERFORMED
        vm.expectRevert(ParameterChecksFailedException.selector);
        vm.prank(admin);
        controllerTimelock.setMaxDebtPerBlockMultiplier(creditManager, 5);

        // VERIFY THAT THE FUNCTION IS QUEUED AND EXECUTED CORRECTLY
        bytes32 txHash = keccak256(
            abi.encode(
                admin,
                creditConfigurator,
                "setMaxDebtPerBlockMultiplier(uint8)",
                abi.encode(4),
                block.timestamp + 1 days
            )
        );

        vm.expectEmit(true, false, false, true);
        emit QueueTransaction(
            txHash,
            admin,
            creditConfigurator,
            "setMaxDebtPerBlockMultiplier(uint8)",
            abi.encode(4),
            uint40(block.timestamp + 1 days)
        );

        vm.prank(admin);
        controllerTimelock.setMaxDebtPerBlockMultiplier(creditManager, 4);

        vm.expectCall(
            creditConfigurator, abi.encodeWithSelector(ICreditConfiguratorV3.setMaxDebtPerBlockMultiplier.selector, 4)
        );

        vm.warp(block.timestamp + 1 days);

        vm.prank(admin);
        controllerTimelock.executeTransaction(txHash);

        (bool queued,,,,,) = controllerTimelock.queuedTransactions(txHash);

        assertTrue(!queued, "Transaction is still queued after execution");
    }

    /// @dev U:[CT-4A]: setMinDebtLimit works correctly
    function test_U_CT_04A_setMinDebtLimit_works_correctly() public {
        (address creditManager, address creditFacade, address creditConfigurator,,) = _makeMocks();

        bytes32 POLICY_CODE = keccak256(abi.encode("CM", "MIN_DEBT"));

        vm.mockCall(creditFacade, abi.encodeWithSelector(ICreditFacadeV3.debtLimits.selector), abi.encode(10, 20));

        Policy memory policy = Policy({
            enabled: false,
            admin: admin,
            flags: 1,
            exactValue: 15,
            minValue: 0,
            maxValue: 0,
            referencePoint: 0,
            referencePointUpdatePeriod: 0,
            referencePointTimestampLU: 0,
            minPctChange: 0,
            maxPctChange: 0,
            minChange: 0,
            maxChange: 0
        });

        // VERIFY THAT THE FUNCTION CANNOT BE CALLED WITHOUT RESPECTIVE POLICY
        vm.expectRevert(ParameterChecksFailedException.selector);
        vm.prank(admin);
        controllerTimelock.setMinDebtLimit(creditManager, 15);

        vm.prank(CONFIGURATOR);
        controllerTimelock.setPolicy(POLICY_CODE, policy);

        // VERIFY THAT THE FUNCTION IS ONLY CALLABLE BY ADMIN
        vm.expectRevert(ParameterChecksFailedException.selector);
        vm.prank(USER);
        controllerTimelock.setMinDebtLimit(creditManager, 15);

        // VERIFY THAT POLICY CHECKS ARE PERFORMED
        vm.expectRevert(ParameterChecksFailedException.selector);
        vm.prank(admin);
        controllerTimelock.setMinDebtLimit(creditManager, 5);

        // VERIFY THAT THE FUNCTION IS QUEUED AND EXECUTED CORRECTLY
        bytes32 txHash = keccak256(
            abi.encode(
                admin, creditConfigurator, "setLimits(uint128,uint128)", abi.encode(15, 20), block.timestamp + 1 days
            )
        );

        vm.expectEmit(true, false, false, true);
        emit QueueTransaction(
            txHash,
            admin,
            creditConfigurator,
            "setLimits(uint128,uint128)",
            abi.encode(15, 20),
            uint40(block.timestamp + 1 days)
        );

        vm.prank(admin);
        controllerTimelock.setMinDebtLimit(creditManager, 15);

        vm.expectCall(creditConfigurator, abi.encodeWithSelector(ICreditConfiguratorV3.setLimits.selector, 15, 20));

        vm.warp(block.timestamp + 1 days);

        vm.prank(admin);
        controllerTimelock.executeTransaction(txHash);

        (bool queued,,,,,) = controllerTimelock.queuedTransactions(txHash);

        assertTrue(!queued, "Transaction is still queued after execution");
    }

    /// @dev U:[CT-4B]: setMaxDebtLimit works correctly
    function test_U_CT_04B_setMaxDebtLimit_works_correctly() public {
        (address creditManager, address creditFacade, address creditConfigurator,,) = _makeMocks();

        bytes32 POLICY_CODE = keccak256(abi.encode("CM", "MAX_DEBT"));

        vm.mockCall(creditFacade, abi.encodeWithSelector(ICreditFacadeV3.debtLimits.selector), abi.encode(10, 20));

        Policy memory policy = Policy({
            enabled: false,
            admin: admin,
            flags: 1,
            exactValue: 25,
            minValue: 0,
            maxValue: 0,
            referencePoint: 0,
            referencePointUpdatePeriod: 0,
            referencePointTimestampLU: 0,
            minPctChange: 0,
            maxPctChange: 0,
            minChange: 0,
            maxChange: 0
        });

        // VERIFY THAT THE FUNCTION CANNOT BE CALLED WITHOUT RESPECTIVE POLICY
        vm.expectRevert(ParameterChecksFailedException.selector);
        vm.prank(admin);
        controllerTimelock.setMaxDebtLimit(creditManager, 25);

        vm.prank(CONFIGURATOR);
        controllerTimelock.setPolicy(POLICY_CODE, policy);

        // VERIFY THAT THE FUNCTION IS ONLY CALLABLE BY ADMIN
        vm.expectRevert(ParameterChecksFailedException.selector);
        vm.prank(USER);
        controllerTimelock.setMaxDebtLimit(creditManager, 25);

        // VERIFY THAT POLICY CHECKS ARE PERFORMED
        vm.expectRevert(ParameterChecksFailedException.selector);
        vm.prank(admin);
        controllerTimelock.setMaxDebtLimit(creditManager, 5);

        // VERIFY THAT THE FUNCTION IS QUEUED AND EXECUTED CORRECTLY
        bytes32 txHash = keccak256(
            abi.encode(
                admin, creditConfigurator, "setLimits(uint128,uint128)", abi.encode(10, 25), block.timestamp + 1 days
            )
        );

        vm.expectEmit(true, false, false, true);
        emit QueueTransaction(
            txHash,
            admin,
            creditConfigurator,
            "setLimits(uint128,uint128)",
            abi.encode(10, 25),
            uint40(block.timestamp + 1 days)
        );

        vm.prank(admin);
        controllerTimelock.setMaxDebtLimit(creditManager, 25);

        vm.expectCall(creditConfigurator, abi.encodeWithSelector(ICreditConfiguratorV3.setLimits.selector, 10, 25));

        vm.warp(block.timestamp + 1 days);

        vm.prank(admin);
        controllerTimelock.executeTransaction(txHash);

        (bool queued,,,,,) = controllerTimelock.queuedTransactions(txHash);

        assertTrue(!queued, "Transaction is still queued after execution");
    }

    /// @dev U:[CT-5]: setCreditManagerDebtLimit works correctly
    function test_U_CT_05_setCreditManagerDebtLimit_works_correctly() public {
        (address creditManager, address creditFacade,, address pool,) = _makeMocks();

        vm.mockCall(creditFacade, abi.encodeCall(ICreditFacadeV3.trackTotalDebt, ()), abi.encode(false));

        bytes32 POLICY_CODE = keccak256(abi.encode("CM", "CREDIT_MANAGER_DEBT_LIMIT"));

        vm.mockCall(
            pool, abi.encodeWithSelector(IPoolV3.creditManagerDebtLimit.selector, creditManager), abi.encode(1e18)
        );

        Policy memory policy = Policy({
            enabled: false,
            admin: admin,
            flags: 1,
            exactValue: 2e18,
            minValue: 0,
            maxValue: 0,
            referencePoint: 0,
            referencePointUpdatePeriod: 0,
            referencePointTimestampLU: 0,
            minPctChange: 0,
            maxPctChange: 0,
            minChange: 0,
            maxChange: 0
        });

        // VERIFY THAT THE FUNCTION CANNOT BE CALLED WITHOUT RESPECTIVE POLICY
        vm.expectRevert(ParameterChecksFailedException.selector);
        vm.prank(admin);
        controllerTimelock.setCreditManagerDebtLimit(creditManager, 2e18);

        vm.prank(CONFIGURATOR);
        controllerTimelock.setPolicy(POLICY_CODE, policy);

        // VERIFY THAT THE FUNCTION IS ONLY CALLABLE BY ADMIN
        vm.expectRevert(ParameterChecksFailedException.selector);
        vm.prank(USER);
        controllerTimelock.setCreditManagerDebtLimit(creditManager, 2e18);

        // VERIFY THAT POLICY CHECKS ARE PERFORMED
        vm.expectRevert(ParameterChecksFailedException.selector);
        vm.prank(admin);
        controllerTimelock.setCreditManagerDebtLimit(creditManager, 1e18);

        // VERIFY THAT THE FUNCTION IS QUEUED AND EXECUTED CORRECTLY
        bytes32 txHash = keccak256(
            abi.encode(
                admin,
                pool,
                "setCreditManagerDebtLimit(address,uint256)",
                abi.encode(creditManager, 2e18),
                block.timestamp + 1 days
            )
        );

        vm.expectEmit(true, false, false, true);
        emit QueueTransaction(
            txHash,
            admin,
            pool,
            "setCreditManagerDebtLimit(address,uint256)",
            abi.encode(creditManager, 2e18),
            uint40(block.timestamp + 1 days)
        );

        vm.prank(admin);
        controllerTimelock.setCreditManagerDebtLimit(creditManager, 2e18);

        vm.expectCall(pool, abi.encodeWithSelector(PoolV3.setCreditManagerDebtLimit.selector, creditManager, 2e18));

        vm.warp(block.timestamp + 1 days);

        vm.prank(admin);
        controllerTimelock.executeTransaction(txHash);

        (bool queued,,,,,) = controllerTimelock.queuedTransactions(txHash);

        assertTrue(!queued, "Transaction is still queued after execution");
    }

    /// @dev U:[CT-5A]: setCreditManagerDebtLimit works correctly, Credit Facade tracks debt
    function test_U_CT_05A_setCreditManagerDebtLimit_works_correctly_CF_totalDebt() public {
        (address creditManager, address creditFacade, address creditConfigurator,,) = _makeMocks();

        vm.mockCall(creditFacade, abi.encodeCall(ICreditFacadeV3.trackTotalDebt, ()), abi.encode(true));

        bytes32 POLICY_CODE = keccak256(abi.encode("CM", "CREDIT_MANAGER_DEBT_LIMIT"));

        vm.mockCall(creditFacade, abi.encodeCall(ICreditFacadeV3.totalDebt, ()), abi.encode(uint128(0), uint128(1e18)));

        Policy memory policy = Policy({
            enabled: false,
            admin: admin,
            flags: 1,
            exactValue: 2e18,
            minValue: 0,
            maxValue: 0,
            referencePoint: 0,
            referencePointUpdatePeriod: 0,
            referencePointTimestampLU: 0,
            minPctChange: 0,
            maxPctChange: 0,
            minChange: 0,
            maxChange: 0
        });

        // VERIFY THAT THE FUNCTION CANNOT BE CALLED WITHOUT RESPECTIVE POLICY
        vm.expectRevert(ParameterChecksFailedException.selector);
        vm.prank(admin);
        controllerTimelock.setCreditManagerDebtLimit(creditManager, 2e18);

        vm.prank(CONFIGURATOR);
        controllerTimelock.setPolicy(POLICY_CODE, policy);

        // VERIFY THAT THE FUNCTION IS ONLY CALLABLE BY ADMIN
        vm.expectRevert(ParameterChecksFailedException.selector);
        vm.prank(USER);
        controllerTimelock.setCreditManagerDebtLimit(creditManager, 2e18);

        // VERIFY THAT POLICY CHECKS ARE PERFORMED
        vm.expectRevert(ParameterChecksFailedException.selector);
        vm.prank(admin);
        controllerTimelock.setCreditManagerDebtLimit(creditManager, 1e18);

        // VERIFY THAT THE FUNCTION IS QUEUED AND EXECUTED CORRECTLY
        bytes32 txHash = keccak256(
            abi.encode(
                admin,
                creditConfigurator,
                "setTotalDebtLimit(uint128)",
                abi.encode(uint128(2e18)),
                block.timestamp + 1 days
            )
        );

        vm.expectEmit(true, false, false, true);
        emit QueueTransaction(
            txHash,
            admin,
            creditConfigurator,
            "setTotalDebtLimit(uint128)",
            abi.encode(uint128(2e18)),
            uint40(block.timestamp + 1 days)
        );

        vm.prank(admin);
        controllerTimelock.setCreditManagerDebtLimit(creditManager, 2e18);

        vm.expectCall(creditConfigurator, abi.encodeCall(ICreditConfiguratorV3.setTotalDebtLimit, (2e18)));

        vm.warp(block.timestamp + 1 days);

        vm.prank(admin);
        controllerTimelock.executeTransaction(txHash);

        (bool queued,,,,,) = controllerTimelock.queuedTransactions(txHash);

        assertTrue(!queued, "Transaction is still queued after execution");
    }

    /// @dev U:[CT-6]: rampLiquidationThreshold works correctly
    function test_U_CT_06_rampLiquidationThreshold_works_correctly() public {
        (address creditManager,, address creditConfigurator,,) = _makeMocks();

        address token = makeAddr("TOKEN");

        vm.prank(CONFIGURATOR);
        controllerTimelock.setGroup(token, "TOKEN");

        bytes32 POLICY_CODE = keccak256(abi.encode("CM", "TOKEN", "TOKEN_LT"));

        vm.mockCall(
            creditManager, abi.encodeWithSelector(ICreditManagerV3.liquidationThresholds.selector), abi.encode(5000)
        );

        Policy memory policy = Policy({
            enabled: false,
            admin: admin,
            flags: 1,
            exactValue: 6000,
            minValue: 0,
            maxValue: 0,
            referencePoint: 0,
            referencePointUpdatePeriod: 0,
            referencePointTimestampLU: 0,
            minPctChange: 0,
            maxPctChange: 0,
            minChange: 0,
            maxChange: 0
        });

        // VERIFY THAT THE FUNCTION CANNOT BE CALLED WITHOUT RESPECTIVE POLICY
        vm.expectRevert(ParameterChecksFailedException.selector);
        vm.prank(admin);
        controllerTimelock.rampLiquidationThreshold(
            creditManager, token, 6000, uint40(block.timestamp + 14 days), 7 days
        );

        vm.prank(CONFIGURATOR);
        controllerTimelock.setPolicy(POLICY_CODE, policy);

        // VERIFY THAT THE FUNCTION IS ONLY CALLABLE BY ADMIN
        vm.expectRevert(ParameterChecksFailedException.selector);
        vm.prank(USER);
        controllerTimelock.rampLiquidationThreshold(
            creditManager, token, 6000, uint40(block.timestamp + 14 days), 7 days
        );

        // VERIFY THAT POLICY CHECKS ARE PERFORMED
        vm.expectRevert(ParameterChecksFailedException.selector);
        vm.prank(admin);
        controllerTimelock.rampLiquidationThreshold(
            creditManager, token, 5000, uint40(block.timestamp + 14 days), 7 days
        );

        // VERIFY THAT EXTRA CHECKS ARE PERFORMED
        vm.expectRevert(ParameterChecksFailedException.selector);
        vm.prank(admin);
        controllerTimelock.rampLiquidationThreshold(
            creditManager, token, 6000, uint40(block.timestamp + 14 days), 1 days
        );

        vm.expectRevert(ParameterChecksFailedException.selector);
        vm.prank(admin);
        controllerTimelock.rampLiquidationThreshold(
            creditManager, token, 6000, uint40(block.timestamp + 1 days / 2), 7 days
        );

        // VERIFY THAT THE FUNCTION IS QUEUED AND EXECUTED CORRECTLY
        bytes32 txHash = keccak256(
            abi.encode(
                admin,
                creditConfigurator,
                "rampLiquidationThreshold(address,uint16,uint40,uint24)",
                abi.encode(token, 6000, block.timestamp + 14 days, 7 days),
                block.timestamp + 1 days
            )
        );

        vm.expectEmit(true, false, false, true);
        emit QueueTransaction(
            txHash,
            admin,
            creditConfigurator,
            "rampLiquidationThreshold(address,uint16,uint40,uint24)",
            abi.encode(token, 6000, block.timestamp + 14 days, 7 days),
            uint40(block.timestamp + 1 days)
        );

        vm.prank(admin);
        controllerTimelock.rampLiquidationThreshold(
            creditManager, token, 6000, uint40(block.timestamp + 14 days), 7 days
        );

        vm.expectCall(
            creditConfigurator,
            abi.encodeWithSelector(
                ICreditConfiguratorV3.rampLiquidationThreshold.selector,
                token,
                6000,
                uint40(block.timestamp + 14 days),
                7 days
            )
        );

        vm.warp(block.timestamp + 1 days);

        vm.prank(admin);
        controllerTimelock.executeTransaction(txHash);

        (bool queued,,,,,) = controllerTimelock.queuedTransactions(txHash);

        assertTrue(!queued, "Transaction is still queued after execution");
    }

    /// @dev U:[CT-7]: cancelTransaction works correctly
    function test_U_CT_07_cancelTransaction_works_correctly() public {
        (address creditManager, address creditFacade, address creditConfigurator, address pool,) = _makeMocks();

        bytes32 POLICY_CODE = keccak256(abi.encode("CM", "EXPIRATION_DATE"));

        vm.mockCall(
            creditFacade, abi.encodeWithSelector(ICreditFacadeV3.expirationDate.selector), abi.encode(block.timestamp)
        );

        vm.mockCall(pool, abi.encodeWithSelector(IPoolV3.creditManagerBorrowed.selector, creditManager), abi.encode(0));

        Policy memory policy = Policy({
            enabled: false,
            admin: admin,
            flags: 1,
            exactValue: block.timestamp + 5,
            minValue: 0,
            maxValue: 0,
            referencePoint: 0,
            referencePointUpdatePeriod: 0,
            referencePointTimestampLU: 0,
            minPctChange: 0,
            maxPctChange: 0,
            minChange: 0,
            maxChange: 0
        });

        vm.prank(CONFIGURATOR);
        controllerTimelock.setPolicy(POLICY_CODE, policy);

        // VERIFY THAT THE FUNCTION IS QUEUED AND EXECUTED CORRECTLY
        bytes32 txHash = keccak256(
            abi.encode(
                admin,
                creditConfigurator,
                "setExpirationDate(uint40)",
                abi.encode(block.timestamp + 5),
                block.timestamp + 1 days
            )
        );

        vm.prank(admin);
        controllerTimelock.setExpirationDate(creditManager, uint40(block.timestamp + 5));

        vm.expectRevert(CallerNotVetoAdminException.selector);

        vm.prank(admin);
        controllerTimelock.cancelTransaction(txHash);

        vm.expectEmit(true, false, false, false);
        emit CancelTransaction(txHash);

        vm.prank(vetoAdmin);
        controllerTimelock.cancelTransaction(txHash);

        (bool queued,,,,,) = controllerTimelock.queuedTransactions(txHash);

        assertTrue(!queued, "Transaction is still queued after cancelling");

        vm.expectRevert(TxNotQueuedException.selector);
        vm.prank(admin);
        controllerTimelock.executeTransaction(txHash);
    }

    /// @dev U:[CT-8]: configuration functions work correctly
    function test_U_CT_08_configuration_works_correctly() public {
        vm.expectRevert(CallerNotConfiguratorException.selector);
        vm.prank(USER);
        controllerTimelock.setVetoAdmin(DUMB_ADDRESS);

        vm.expectRevert(CallerNotConfiguratorException.selector);
        vm.prank(USER);
        controllerTimelock.setDelay(5);

        vm.expectEmit(true, false, false, false);
        emit SetVetoAdmin(DUMB_ADDRESS);

        vm.prank(CONFIGURATOR);
        controllerTimelock.setVetoAdmin(DUMB_ADDRESS);

        assertEq(controllerTimelock.vetoAdmin(), DUMB_ADDRESS, "Veto admin address was not set");

        vm.expectEmit(false, false, false, true);
        emit SetDelay(5);

        vm.prank(CONFIGURATOR);
        controllerTimelock.setDelay(5);

        assertEq(controllerTimelock.delay(), 5, "Delay was not set");
    }

    /// @dev U:[CT-9]: executeTransaction works correctly
    function test_U_CT_09_executeTransaction_works_correctly() public {
        (address creditManager, address creditFacade, address creditConfigurator, address pool,) = _makeMocks();

        bytes32 POLICY_CODE = keccak256(abi.encode("CM", "EXPIRATION_DATE"));

        vm.mockCall(
            creditFacade, abi.encodeWithSelector(ICreditFacadeV3.expirationDate.selector), abi.encode(block.timestamp)
        );

        vm.mockCall(pool, abi.encodeWithSelector(IPoolV3.creditManagerBorrowed.selector, creditManager), abi.encode(0));

        uint40 expirationDate = uint40(block.timestamp + 2 days);

        Policy memory policy = Policy({
            enabled: false,
            admin: FRIEND,
            flags: 1,
            exactValue: expirationDate,
            minValue: 0,
            maxValue: 0,
            referencePoint: 0,
            referencePointUpdatePeriod: 0,
            referencePointTimestampLU: 0,
            minPctChange: 0,
            maxPctChange: 0,
            minChange: 0,
            maxChange: 0
        });

        vm.prank(CONFIGURATOR);
        controllerTimelock.setPolicy(POLICY_CODE, policy);

        // VERIFY THAT THE FUNCTION IS QUEUED AND EXECUTED CORRECTLY
        bytes32 txHash = keccak256(
            abi.encode(
                FRIEND,
                creditConfigurator,
                "setExpirationDate(uint40)",
                abi.encode(expirationDate),
                block.timestamp + 1 days
            )
        );

        vm.prank(FRIEND);
        controllerTimelock.setExpirationDate(creditManager, expirationDate);

        vm.expectRevert(CallerNotExecutorException.selector);
        vm.prank(USER);
        controllerTimelock.executeTransaction(txHash);

        vm.expectRevert(TxExecutedOutsideTimeWindowException.selector);
        vm.prank(FRIEND);
        controllerTimelock.executeTransaction(txHash);

        vm.warp(block.timestamp + 20 days);

        vm.expectRevert(TxExecutedOutsideTimeWindowException.selector);
        vm.prank(FRIEND);
        controllerTimelock.executeTransaction(txHash);

        vm.warp(block.timestamp - 10 days);

        vm.mockCallRevert(
            creditConfigurator,
            abi.encodeWithSelector(ICreditConfiguratorV3.setExpirationDate.selector, expirationDate),
            abi.encode("error")
        );

        vm.expectRevert(TxExecutionRevertedException.selector);
        vm.prank(FRIEND);
        controllerTimelock.executeTransaction(txHash);

        vm.clearMockedCalls();

        vm.expectEmit(true, false, false, false);
        emit ExecuteTransaction(txHash);

        vm.prank(FRIEND);
        controllerTimelock.executeTransaction(txHash);
    }

    /// @dev U:[CT-10]: forbidAdapter works correctly
    function test_U_CT_10_forbidAdapter_works_correctly() public {
        (address creditManager,, address creditConfigurator,,) = _makeMocks();

        bytes32 POLICY_CODE = keccak256(abi.encode("CM", "FORBID_ADAPTER"));

        Policy memory policy = Policy({
            enabled: false,
            admin: admin,
            flags: 0,
            exactValue: 0,
            minValue: 0,
            maxValue: 0,
            referencePoint: 0,
            referencePointUpdatePeriod: 0,
            referencePointTimestampLU: 0,
            minPctChange: 0,
            maxPctChange: 0,
            minChange: 0,
            maxChange: 0
        });

        // VERIFY THAT THE FUNCTION CANNOT BE CALLED WITHOUT RESPECTIVE POLICY
        vm.expectRevert(ParameterChecksFailedException.selector);
        vm.prank(admin);
        controllerTimelock.forbidAdapter(creditManager, DUMB_ADDRESS);

        vm.prank(CONFIGURATOR);
        controllerTimelock.setPolicy(POLICY_CODE, policy);

        // VERIFY THAT THE FUNCTION IS ONLY CALLABLE BY ADMIN
        vm.expectRevert(ParameterChecksFailedException.selector);
        vm.prank(USER);
        controllerTimelock.forbidAdapter(creditManager, DUMB_ADDRESS);

        // VERIFY THAT THE FUNCTION IS QUEUED AND EXECUTED CORRECTLY
        bytes32 txHash = keccak256(
            abi.encode(
                admin, creditConfigurator, "forbidAdapter(address)", abi.encode(DUMB_ADDRESS), block.timestamp + 1 days
            )
        );

        vm.expectEmit(true, false, false, true);
        emit QueueTransaction(
            txHash,
            admin,
            creditConfigurator,
            "forbidAdapter(address)",
            abi.encode(DUMB_ADDRESS),
            uint40(block.timestamp + 1 days)
        );

        vm.prank(admin);
        controllerTimelock.forbidAdapter(creditManager, DUMB_ADDRESS);

        vm.expectCall(
            creditConfigurator, abi.encodeWithSelector(ICreditConfiguratorV3.forbidAdapter.selector, DUMB_ADDRESS)
        );

        vm.warp(block.timestamp + 1 days);

        vm.prank(admin);
        controllerTimelock.executeTransaction(txHash);

        (bool queued,,,,,) = controllerTimelock.queuedTransactions(txHash);

        assertTrue(!queued, "Transaction is still queued after execution");
    }

    /// @dev U:[CT-12]: setQuotaIncreaseFee works correctly
    function test_U_CT_12_setQuotaIncreaseFee_works_correctly() public {
        (,,, address pool, address poolQuotaKeeper) = _makeMocks();

        address token = makeAddr("TOKEN");

        vm.prank(CONFIGURATOR);
        controllerTimelock.setGroup(token, "TOKEN");

        vm.mockCall(
            poolQuotaKeeper,
            abi.encodeCall(IPoolQuotaKeeperV3.getTokenQuotaParams, (token)),
            abi.encode(uint16(10), uint192(1e27), uint16(15), uint96(1e17), uint96(1e18))
        );

        bytes32 POLICY_CODE = keccak256(abi.encode("POOL", "TOKEN", "TOKEN_QUOTA_INCREASE_FEE"));

        Policy memory policy = Policy({
            enabled: false,
            admin: admin,
            flags: 1,
            exactValue: 20,
            minValue: 0,
            maxValue: 0,
            referencePoint: 0,
            referencePointUpdatePeriod: 0,
            referencePointTimestampLU: 0,
            minPctChange: 0,
            maxPctChange: 0,
            minChange: 0,
            maxChange: 0
        });

        // VERIFY THAT THE FUNCTION CANNOT BE CALLED WITHOUT RESPECTIVE POLICY
        vm.expectRevert(ParameterChecksFailedException.selector);
        vm.prank(admin);
        controllerTimelock.setTokenQuotaIncreaseFee(pool, token, 20);

        vm.prank(CONFIGURATOR);
        controllerTimelock.setPolicy(POLICY_CODE, policy);

        // VERIFY THAT THE FUNCTION IS ONLY CALLABLE BY ADMIN
        vm.expectRevert(ParameterChecksFailedException.selector);
        vm.prank(USER);
        controllerTimelock.setTokenQuotaIncreaseFee(pool, token, 20);

        // VERIFY THAT THE FUNCTION PERFORMS POLICY CHECKS
        vm.expectRevert(ParameterChecksFailedException.selector);
        vm.prank(admin);
        controllerTimelock.setTokenQuotaIncreaseFee(pool, token, 30);

        // VERIFY THAT THE FUNCTION IS QUEUED AND EXECUTED CORRECTLY
        bytes32 txHash = keccak256(
            abi.encode(
                admin,
                poolQuotaKeeper,
                "setTokenQuotaIncreaseFee(address,uint16)",
                abi.encode(token, uint16(20)),
                block.timestamp + 1 days
            )
        );

        vm.expectEmit(true, false, false, true);
        emit QueueTransaction(
            txHash,
            admin,
            poolQuotaKeeper,
            "setTokenQuotaIncreaseFee(address,uint16)",
            abi.encode(token, uint16(20)),
            uint40(block.timestamp + 1 days)
        );

        vm.prank(admin);
        controllerTimelock.setTokenQuotaIncreaseFee(pool, token, 20);

        vm.expectCall(poolQuotaKeeper, abi.encodeCall(PoolQuotaKeeperV3.setTokenQuotaIncreaseFee, (token, 20)));

        vm.warp(block.timestamp + 1 days);

        vm.prank(admin);
        controllerTimelock.executeTransaction(txHash);

        (bool queued,,,,,) = controllerTimelock.queuedTransactions(txHash);

        assertTrue(!queued, "Transaction is still queued after execution");
    }

    /// @dev U:[CT-13]: setTotalDebt works correctly
    function test_U_CT_13_setTotalDebt_works_correctly() public {
        (,,, address pool,) = _makeMocks();

        vm.mockCall(pool, abi.encodeCall(IPoolV3.totalDebtLimit, ()), abi.encode(1e18));

        bytes32 POLICY_CODE = keccak256(abi.encode("POOL", "TOTAL_DEBT_LIMIT"));

        Policy memory policy = Policy({
            enabled: false,
            admin: admin,
            flags: 1,
            exactValue: 2e18,
            minValue: 0,
            maxValue: 0,
            referencePoint: 0,
            referencePointUpdatePeriod: 0,
            referencePointTimestampLU: 0,
            minPctChange: 0,
            maxPctChange: 0,
            minChange: 0,
            maxChange: 0
        });

        // VERIFY THAT THE FUNCTION CANNOT BE CALLED WITHOUT RESPECTIVE POLICY
        vm.expectRevert(ParameterChecksFailedException.selector);
        vm.prank(admin);
        controllerTimelock.setTotalDebtLimit(pool, 2e18);

        vm.prank(CONFIGURATOR);
        controllerTimelock.setPolicy(POLICY_CODE, policy);

        // VERIFY THAT THE FUNCTION IS ONLY CALLABLE BY ADMIN
        vm.expectRevert(ParameterChecksFailedException.selector);
        vm.prank(USER);
        controllerTimelock.setTotalDebtLimit(pool, 2e18);

        // VERIFY THAT THE FUNCTION PERFORMS POLICY CHECKS
        vm.expectRevert(ParameterChecksFailedException.selector);
        vm.prank(admin);
        controllerTimelock.setTotalDebtLimit(pool, 3e18);

        // VERIFY THAT THE FUNCTION IS QUEUED AND EXECUTED CORRECTLY
        bytes32 txHash =
            keccak256(abi.encode(admin, pool, "setTotalDebtLimit(uint256)", abi.encode(2e18), block.timestamp + 1 days));

        vm.expectEmit(true, false, false, true);
        emit QueueTransaction(
            txHash, admin, pool, "setTotalDebtLimit(uint256)", abi.encode(2e18), uint40(block.timestamp + 1 days)
        );

        vm.prank(admin);
        controllerTimelock.setTotalDebtLimit(pool, 2e18);

        vm.expectCall(pool, abi.encodeCall(PoolV3.setTotalDebtLimit, (2e18)));

        vm.warp(block.timestamp + 1 days);

        vm.prank(admin);
        controllerTimelock.executeTransaction(txHash);

        (bool queued,,,,,) = controllerTimelock.queuedTransactions(txHash);

        assertTrue(!queued, "Transaction is still queued after execution");
    }

    /// @dev U:[CT-14]: setWithdrawFee works correctly
    function test_U_CT_14_setWithdrawFee_works_correctly() public {
        (,,, address pool,) = _makeMocks();

        vm.mockCall(pool, abi.encodeCall(IPoolV3.withdrawFee, ()), abi.encode(10));

        bytes32 POLICY_CODE = keccak256(abi.encode("POOL", "WITHDRAW_FEE"));

        Policy memory policy = Policy({
            enabled: false,
            admin: admin,
            flags: 1,
            exactValue: 20,
            minValue: 0,
            maxValue: 0,
            referencePoint: 0,
            referencePointUpdatePeriod: 0,
            referencePointTimestampLU: 0,
            minPctChange: 0,
            maxPctChange: 0,
            minChange: 0,
            maxChange: 0
        });

        // VERIFY THAT THE FUNCTION CANNOT BE CALLED WITHOUT RESPECTIVE POLICY
        vm.expectRevert(ParameterChecksFailedException.selector);
        vm.prank(admin);
        controllerTimelock.setWithdrawFee(pool, 20);

        vm.prank(CONFIGURATOR);
        controllerTimelock.setPolicy(POLICY_CODE, policy);

        // VERIFY THAT THE FUNCTION IS ONLY CALLABLE BY ADMIN
        vm.expectRevert(ParameterChecksFailedException.selector);
        vm.prank(USER);
        controllerTimelock.setWithdrawFee(pool, 20);

        // VERIFY THAT THE FUNCTION PERFORMS POLICY CHECKS
        vm.expectRevert(ParameterChecksFailedException.selector);
        vm.prank(admin);
        controllerTimelock.setWithdrawFee(pool, 30);

        // VERIFY THAT THE FUNCTION IS QUEUED AND EXECUTED CORRECTLY
        bytes32 txHash =
            keccak256(abi.encode(admin, pool, "setWithdrawFee(uint256)", abi.encode(20), block.timestamp + 1 days));

        vm.expectEmit(true, false, false, true);
        emit QueueTransaction(
            txHash, admin, pool, "setWithdrawFee(uint256)", abi.encode(20), uint40(block.timestamp + 1 days)
        );

        vm.prank(admin);
        controllerTimelock.setWithdrawFee(pool, 20);

        vm.expectCall(pool, abi.encodeCall(PoolV3.setWithdrawFee, (20)));

        vm.warp(block.timestamp + 1 days);

        vm.prank(admin);
        controllerTimelock.executeTransaction(txHash);

        (bool queued,,,,,) = controllerTimelock.queuedTransactions(txHash);

        assertTrue(!queued, "Transaction is still queued after execution");
    }

    /// @dev U:[CT-15A]: setMinQuotaRate works correctly
    function test_U_CT_15A_setMinQuotaRate_works_correctly() public {
        (,,, address pool, address poolQuotaKeeper) = _makeMocks();

        address gauge = address(new GeneralMock());

        vm.mockCall(poolQuotaKeeper, abi.encodeCall(IPoolQuotaKeeperV3.gauge, ()), abi.encode(gauge));

        address token = makeAddr("TOKEN");

        vm.prank(CONFIGURATOR);
        controllerTimelock.setGroup(token, "TOKEN");

        vm.mockCall(
            gauge,
            abi.encodeCall(IGaugeV3.quotaRateParams, (token)),
            abi.encode(uint16(10), uint16(20), uint96(100), uint96(200))
        );

        bytes32 POLICY_CODE = keccak256(abi.encode("POOL", "TOKEN", "TOKEN_QUOTA_MIN_RATE"));

        Policy memory policy = Policy({
            enabled: false,
            admin: admin,
            flags: 1,
            exactValue: 15,
            minValue: 0,
            maxValue: 0,
            referencePoint: 0,
            referencePointUpdatePeriod: 0,
            referencePointTimestampLU: 0,
            minPctChange: 0,
            maxPctChange: 0,
            minChange: 0,
            maxChange: 0
        });

        // VERIFY THAT THE FUNCTION CANNOT BE CALLED WITHOUT RESPECTIVE POLICY
        vm.expectRevert(ParameterChecksFailedException.selector);
        vm.prank(admin);
        controllerTimelock.setMinQuotaRate(pool, token, 15);

        vm.prank(CONFIGURATOR);
        controllerTimelock.setPolicy(POLICY_CODE, policy);

        // VERIFY THAT THE FUNCTION IS ONLY CALLABLE BY ADMIN
        vm.expectRevert(ParameterChecksFailedException.selector);
        vm.prank(USER);
        controllerTimelock.setMinQuotaRate(pool, token, 15);

        // VERIFY THAT THE FUNCTION PERFORMS POLICY CHECKS
        vm.expectRevert(ParameterChecksFailedException.selector);
        vm.prank(admin);
        controllerTimelock.setMinQuotaRate(pool, token, 25);

        // VERIFY THAT THE FUNCTION IS QUEUED AND EXECUTED CORRECTLY
        bytes32 txHash = keccak256(
            abi.encode(
                admin,
                gauge,
                "changeQuotaTokenRateParams(address,uint16,uint16)",
                abi.encode(token, uint16(15), uint16(20)),
                block.timestamp + 1 days
            )
        );

        vm.expectEmit(true, false, false, true);
        emit QueueTransaction(
            txHash,
            admin,
            gauge,
            "changeQuotaTokenRateParams(address,uint16,uint16)",
            abi.encode(token, uint16(15), uint16(20)),
            uint40(block.timestamp + 1 days)
        );

        vm.prank(admin);
        controllerTimelock.setMinQuotaRate(pool, token, 15);

        vm.expectCall(gauge, abi.encodeCall(GaugeV3.changeQuotaTokenRateParams, (token, 15, 20)));

        vm.warp(block.timestamp + 1 days);

        vm.prank(admin);
        controllerTimelock.executeTransaction(txHash);

        (bool queued,,,,,) = controllerTimelock.queuedTransactions(txHash);

        assertTrue(!queued, "Transaction is still queued after execution");
    }

    /// @dev U:[CT-15B]: setMaxQuotaRate works correctly
    function test_U_CT_15B_setMaxQuotaRate_works_correctly() public {
        (,,, address pool, address poolQuotaKeeper) = _makeMocks();

        address gauge = address(new GeneralMock());

        vm.mockCall(poolQuotaKeeper, abi.encodeCall(IPoolQuotaKeeperV3.gauge, ()), abi.encode(gauge));

        address token = makeAddr("TOKEN");

        vm.prank(CONFIGURATOR);
        controllerTimelock.setGroup(token, "TOKEN");

        vm.mockCall(
            gauge,
            abi.encodeCall(IGaugeV3.quotaRateParams, (token)),
            abi.encode(uint16(10), uint16(20), uint96(100), uint96(200))
        );

        bytes32 POLICY_CODE = keccak256(abi.encode("POOL", "TOKEN", "TOKEN_QUOTA_MAX_RATE"));

        Policy memory policy = Policy({
            enabled: false,
            admin: admin,
            flags: 1,
            exactValue: 25,
            minValue: 0,
            maxValue: 0,
            referencePoint: 0,
            referencePointUpdatePeriod: 0,
            referencePointTimestampLU: 0,
            minPctChange: 0,
            maxPctChange: 0,
            minChange: 0,
            maxChange: 0
        });

        // VERIFY THAT THE FUNCTION CANNOT BE CALLED WITHOUT RESPECTIVE POLICY
        vm.expectRevert(ParameterChecksFailedException.selector);
        vm.prank(admin);
        controllerTimelock.setMaxQuotaRate(pool, token, 25);

        vm.prank(CONFIGURATOR);
        controllerTimelock.setPolicy(POLICY_CODE, policy);

        // VERIFY THAT THE FUNCTION IS ONLY CALLABLE BY ADMIN
        vm.expectRevert(ParameterChecksFailedException.selector);
        vm.prank(USER);
        controllerTimelock.setMaxQuotaRate(pool, token, 25);

        // VERIFY THAT THE FUNCTION PERFORMS POLICY CHECKS
        vm.expectRevert(ParameterChecksFailedException.selector);
        vm.prank(admin);
        controllerTimelock.setMaxQuotaRate(pool, token, 35);

        // VERIFY THAT THE FUNCTION IS QUEUED AND EXECUTED CORRECTLY
        bytes32 txHash = keccak256(
            abi.encode(
                admin,
                gauge,
                "changeQuotaTokenRateParams(address,uint16,uint16)",
                abi.encode(token, uint16(10), uint16(25)),
                block.timestamp + 1 days
            )
        );

        vm.expectEmit(true, false, false, true);
        emit QueueTransaction(
            txHash,
            admin,
            gauge,
            "changeQuotaTokenRateParams(address,uint16,uint16)",
            abi.encode(token, uint16(10), uint16(25)),
            uint40(block.timestamp + 1 days)
        );

        vm.prank(admin);
        controllerTimelock.setMaxQuotaRate(pool, token, 25);

        vm.expectCall(gauge, abi.encodeCall(GaugeV3.changeQuotaTokenRateParams, (token, 10, 25)));

        vm.warp(block.timestamp + 1 days);

        vm.prank(admin);
        controllerTimelock.executeTransaction(txHash);

        (bool queued,,,,,) = controllerTimelock.queuedTransactions(txHash);

        assertTrue(!queued, "Transaction is still queued after execution");
    }
}
