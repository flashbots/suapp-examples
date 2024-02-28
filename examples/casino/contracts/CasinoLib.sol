// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

library CasinoLib {
    uint256 constant max_uint = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    struct SlotMachine {
        /// 0-100; chance of winning
        uint8 winChancePercent;
        uint256 nonce;
        uint256 minBet;
        /// higher number => rarer jackpot (jackpotOdds = winChancePercent/jackpotFactor)
        uint32 jackpotFactor;
        /// how much a standard win pays out (multiply this by bet/100 for win payout) (// TODO: add several win tiers)
        /// encoded in percent; i.e. if payout is 2:1, standardPayoutPercent = 200
        uint32 standardPayoutPercent;
        /// how much a jackpot win pays out (multiply this by standard payout for jackpot payout)
        /// encoded in percent; i.e. if jackpot is 10x standard payout, then jackpotPayoutPercent = 1000
        uint32 jackpotPayoutPercent;
        /// running balance of this machine
        uint256 pot;
    }

    function calculateSlotPull(uint256 betAmount, uint256 _randomNum, CasinoLib.SlotMachine memory machine)
        internal
        pure
        returns (uint256 payout)
    {
        // the nonce should be incremented by the SlotMachine controller every pull.
        uint256 randomNum = _randomNum + machine.nonce;
        /*
            random number must be greater than the cutoff to win
            "cutoff size" will be subtracted from the max uint to determine the cutoff
        */
        // scale winChancePercent to u256
        uint256 standardCutoffSize = (max_uint / 100) * machine.winChancePercent;
        uint256 jackpotCutoffSize = standardCutoffSize / machine.jackpotFactor;
        uint256 standardCutoff = max_uint - standardCutoffSize;
        uint256 jackpotCutoff = max_uint - jackpotCutoffSize;
        if (randomNum >= standardCutoff) {
            if (randomNum >= jackpotCutoff) {
                // jackpot payout
                return (machine.jackpotPayoutPercent * machine.standardPayoutPercent * betAmount) / 10000; // account for two multiplied percents
            }
            // standard payout
            return (machine.standardPayoutPercent * betAmount) / 100; // account for single percent
        }
        // better luck next time
        payout = 0;
    }
}
