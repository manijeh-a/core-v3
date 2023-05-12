// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.17;
//pragma abicoder v1;

import {IPriceOracleV2} from "@gearbox-protocol/core-v2/contracts/interfaces/IPriceOracle.sol";

// EXCEPTIONS

import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";

/// @title Disposable credit accounts factory
contract PriceOracleMock is Test, IPriceOracleV2 {
    uint256 public version;
    mapping(address => uint256) public priceInUSD;

    constructor() {
        vm.label(address(this), "PRICE_ORACLE");
    }

    function setPrice(address token, uint256 price) external {
        priceInUSD[token] = price;
    }

    /// @dev Converts a quantity of an asset to USD (decimals = 8).
    /// @param amount Amount to convert
    /// @param token Address of the token to be converted
    function convertToUSD(uint256 amount, address token) public view returns (uint256) {
        return amount * getPrice(token) / 10 ** 8;
    }

    /// @dev Converts a quantity of USD (decimals = 8) to an equivalent amount of an asset
    /// @param amount Amount to convert
    /// @param token Address of the token converted to
    function convertFromUSD(uint256 amount, address token) public view returns (uint256) {
        return amount * 10 ** 8 / getPrice(token);
    }

    /// @dev Converts one asset into another
    ///
    /// @param amount Amount to convert
    /// @param tokenFrom Address of the token to convert from
    /// @param tokenTo Address of the token to convert to
    function convert(uint256 amount, address tokenFrom, address tokenTo) external view returns (uint256) {
        return convertFromUSD(convertToUSD(amount, tokenFrom), tokenTo);
    }

    /// @dev Returns token's price in USD (8 decimals)
    /// @param token The token to compute the price for
    function getPrice(address token) public view returns (uint256 price) {
        price = priceInUSD[token];
        if (price == 0) revert("Price is not set");
    }

    /// @dev Returns the price feed address for the passed token
    /// @param token Token to get the price feed for
    function priceFeeds(address token) external view returns (address priceFeed) {}

    /// @dev Returns the price feed for the passed token,
    ///      with additional parameters
    /// @param token Token to get the price feed for
    function priceFeedsWithFlags(address token)
        external
        view
        returns (address priceFeed, bool skipCheck, uint256 decimals)
    {}

    /// OUTDATED!
    function fastCheck(uint256 amountFrom, address tokenFrom, uint256 amountTo, address tokenTo)
        external
        view
        returns (uint256 collateralFrom, uint256 collateralTo)
    {}
}
