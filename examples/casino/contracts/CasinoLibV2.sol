// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {Random} from "suave-std/Random.sol";
import {console2} from "forge-std/console2.sol";

library CasinoLib2 {
    uint8 constant NUM_COLS_ROWS = 3;
    uint8 constant NUM_VALUES = 10;

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

    function generateSlotNumbers() internal returns (uint8[] memory) {
        uint8[] memory randomNums = new uint8[](NUM_COLS_ROWS);
        for (uint8 i = 0; i < NUM_COLS_ROWS; i++) {
            randomNums[i] = Random.randomUint8() % NUM_VALUES;
        }
        return randomNums;
    }

    function calculateHorizontalWin(uint8[NUM_COLS_ROWS] memory randomNums)
        internal
        pure
        returns (uint256 multiplier)
    {
        multiplier = 1;
        // TODO
    }

    /// Convert
    function _extractRowNumber(uint8[NUM_COLS_ROWS] memory randomNums, uint8 rowIndex)
        internal
        pure
        returns (uint256 number)
    {
        // each column shifts +- 1 per rowIndex
        for (uint8 j = 0; j < NUM_COLS_ROWS; j++) {
            number += _shiftDigits(randomNums[j], rowIndex, j);
        }
    }

    /// Shift a single digit in a number by an amount specified by rowIndex, in a direction specified by (columnIndex % 2)
    function _shiftDigits(uint256 baseNumber, uint8 rowIndex, uint8 columnIndex)
        internal
        pure
        returns (uint256 number)
    {
        if (columnIndex % 2 == 0) {
            number += ((baseNumber + rowIndex) % NUM_VALUES) * (NUM_VALUES ** (NUM_COLS_ROWS - columnIndex - 1));
        } else {
            // odd columns decrement per row
            if (baseNumber < (NUM_COLS_ROWS - 1)) {
                // protect from underflow
                baseNumber += NUM_VALUES;
            }
            number += ((baseNumber - rowIndex) % NUM_VALUES) * (NUM_VALUES ** (NUM_COLS_ROWS - columnIndex - 1));
        }
    }

    function extractNumberDiagonalDown(uint256 baseNumber) internal pure returns (uint256 number) {
        for (uint8 i = 0; i < NUM_COLS_ROWS; i++) {
            uint256 factor = NUM_VALUES ** (NUM_COLS_ROWS - i - 1);
            number += _shiftDigits((baseNumber - (baseNumber % factor)) / factor, i, i);
        }
    }

    function extractNumberDiagonalUp(uint256 baseNumber) internal pure returns (uint256 number) {
        for (uint8 i = 0; i < NUM_COLS_ROWS; i++) {
            uint256 factor = NUM_VALUES ** (NUM_COLS_ROWS - i - 1);
            number += _shiftDigits((baseNumber - (baseNumber % factor)) / factor, NUM_COLS_ROWS - i - 1, i);
        }
    }

    /**
     * @dev Calculate the payout for a slot pull.
     * @param machine The SlotMachine struct.
     * @param betAmount The amount of rigil ETH to bet.
     * @param randomNums The random numbers to use for the slot pull.
     *
     * winning conditions:
     *   - 3 in a row
     *   - diagonal 3
     *   - (TODO: 0 as a wild card)
     *
     * payout definitions:
     *   |-------------------|-----------|
     *   | condition         | payout    |
     *   |-------------------|-----------|
     *   | BASE WIN          | +  10*bet |
     *   | MIDDLE ROW WIN    | +   3*bet |
     *   | DIAGONAL WIN      | +   2*bet |
     *   | 7s                | +  10*bet |
     *   |-------------------|-----------|
     *
     * board definition:
     *   0 4 9
     *   1 3 0
     *   2 2 1
     *
     *   NxN board
     *   V possible values in {0, 1, 2, ..., V-1}
     *   numbers change in a column by 1 per row
     *   odd columns are reversed
     *
     * examples:
     *   1.  board:          0 4 9
     *                       1 3 0
     *                       2 2 1
     *       payout:         0
     *
     *   2.  board:          0 0 0   = = =
     *                       1 9 1   . . .
     *                       2 8 2   . . .
     *       payout:         (10) * bet
     *
     *   3.  board:          6 8 6   . . .
     *                       7 7 7   = = =
     *                       8 6 8   . . .
     *       payout:         (10 * 10 * 3) * bet
     *
     *   4.  board:          7 7 7   = = =
     *                       8 6 8   . . .
     *                       9 4 9   . . .
     *       payout:         (10 * 10) * bet
     *
     *   5.  board:          9 1 9   . . .
     *                       0 0 0   = = =
     *                       1 9 1   . . .
     *       payout:         (10 * 3) * bet
     *
     *   6.  board:          1 2 9   \ . .
     *                       2 1 0   . \ .
     *                       3 0 1   . . \
     *       payout:         (10 * 2) * bet
     *
     *   7.  board:          1 1 9   \ . .
     *                       2 0 0   = \ =
     *                       3 9 1   . . \
     *       payout:         (10 * 3 * 2) * bet
     *
     *   8.  board:          0 1 0   \ = /
     *                       1 0 1   = X =
     *                       2 9 2   / . \
     *       payout:         (10 * 2 * 2 * 2 * 3) * bet
     *
     *   9.  board:          7 8 5   \ . .
     *                       8 7 6   . \ .
     *                       9 6 7   . . \
     *       payout:         (10 * 10 * 2) * bet
     */
    function calculateSlotPull(SlotMachine memory machine, uint256 betAmount, uint8[NUM_COLS_ROWS] memory randomNums)
        internal
        pure
        returns (uint256 payout)
    {
        require(NUM_COLS_ROWS % 2 == 1, "NUM_COLS_ROWS must be odd; the middle row is special.");
        /* calculate payout */
        uint256 multiplier = 10; // base win is x10

        /*
            TODO: replace NUM_COLS_ROWS, NUM_COLS_ROWS, NUM_VALUES constants with properties from SlotMachine
        */

        // scan for 3 in a row, per row
        // for (uint8 i = 0; i < NUM_COLS_ROWS; i++) {
        //     // assemble a single row value in base(NUM_VALUES) given the random numbers
        //     uint256 rowValue;
        //     for (uint8 j = 0; j < NUM_COLS_ROWS; j++) {
        //         if (j % 2 == 0) {
        //             rowValue += ((randomNums[j] + i) % NUM_VALUES) * (NUM_VALUES ** (NUM_COLS_ROWS - j - 1));
        //         } else {
        //             // odd columns decrement per row
        //             if (randomNums[j] < (NUM_COLS_ROWS - 1)) {
        //                 // protect from underflow
        //                 randomNums[j] += NUM_VALUES;
        //             }
        //             rowValue += ((randomNums[j] - i) % NUM_VALUES) * (NUM_VALUES ** (NUM_COLS_ROWS - j - 1));
        //         }

        //         // calculate middle row index
        //         uint8 middleRowIndex;
        //         for (uint8 idx = 0; idx < NUM_COLS_ROWS; idx++) {
        //             if ((NUM_COLS_ROWS - 1) - idx == idx) {
        //                 middleRowIndex = idx;
        //             }
        //         }

        //         // detect horizontal wins
        //         if (rowValue % 111 == 0) {
        //             if (i == middleRowIndex) {
        //                 // x3 payout if found on middle row
        //                 multiplier *= 3;
        //             } else {
        //                 // x2 payout if found on non-middle row
        //                 multiplier *= 2;
        //             }
        //         }
        //         if (rowValue == 777) {
        //             // x10 payout if found 777
        //             multiplier *= 10;
        //         }
        //     }
        //     // detect diagonal wins: shift each column +i, then re-apply horizontal algorithm
        //     // ex: 1 2 9 -> 1 2 9 -> 1 1 1
        //     //     2 1 0     -1
        //     //     3 0 1       +2
        //     //              all rows % NUM_VALUES
        // }
    }
}
