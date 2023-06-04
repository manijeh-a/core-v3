// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.17;
pragma abicoder v1;

// INTERFACES
import {GaugeV3, QuotaRateParams, UserVotes} from "../../../pool/GaugeV3.sol";

contract GaugeV3Harness is GaugeV3 {
    constructor(address _pool, address _gearStaking) GaugeV3(_pool, _gearStaking) {}

    function setQuotaRateParams(
        address token,
        uint16 minRate,
        uint16 maxRate,
        uint96 totalVotesLpSide,
        uint96 totalVotesCaSide
    ) external {
        quotaRateParams[token] = QuotaRateParams({
            minRate: minRate,
            maxRate: maxRate,
            totalVotesLpSide: totalVotesLpSide,
            totalVotesCaSide: totalVotesCaSide
        });
    }

    function setUserTokenVotes(address user, address token, uint96 votesLpSide, uint96 votesCaSide) external {
        userTokenVotes[user][token] = UserVotes({votesLpSide: votesLpSide, votesCaSide: votesCaSide});
    }
}
