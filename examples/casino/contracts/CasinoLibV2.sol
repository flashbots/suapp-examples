// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {Random} from "suave-std/Random.sol";
import {console2} from "forge-std/console2.sol";
import {LibString} from "solady/src/utils/LibString.sol";

library CasinoLib {
    using LibString for uint256;

    uint8 public constant NUM_COLS_ROWS = 3;
    uint8 public constant NUM_VALUES = 10;
    uint256 public constant BASE_MULTIPLIER = 5;

    struct SlotMachine {
        /// counter for the number of pulls done on this machine
        uint256 nonce;
        /// minimum bet amount
        uint256 minBet;
        /// running balance of this machine
        uint256 pot;
    }

    /**
     * @dev Calculate the payout for a slot pull.
     * @param betAmount The amount of Rigil-ETH to bet.
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
     *   1.  board:          0 4 9  . . .
     *                       1 3 0  . . .
     *                       2 2 1  . . .
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
     *   6.  board:          9 2 1   . . /
     *                       0 1 2   . / .
     *                       1 0 3   / . .
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
    function calculateSlotPull(uint256 betAmount, uint8[NUM_COLS_ROWS] memory randomNums)
        internal
        pure
        returns (uint256 payout, uint256 rollValue)
    {
        require(NUM_COLS_ROWS % 2 == 1, "NUM_COLS_ROWS must be odd because the middle row is special.");

        /* ...calculate payout conditions... */

        // base win multiplier is x10. set optimistically, then check @ end; if it's still 10, set to 0.
        uint256 multiplier = BASE_MULTIPLIER;
        uint8 middleRowIndex = _getMiddleRowIndex();
        rollValue = _extractRowNumber(randomNums, 0);

        // diagonal wins just use first row as base
        uint256 diagonalDownValue = _extractNumberDiagonalDown(rollValue);
        uint256 diagonalUpValue = _extractNumberDiagonalUp(rollValue);
        if (_isNumberRepeating(diagonalDownValue)) {
            multiplier = _applyDiagonalMultiplier(multiplier);
        }
        // haven't bothered to check whether hitting both is possible
        if (_isNumberRepeating(diagonalUpValue)) {
            multiplier = _applyDiagonalMultiplier(multiplier);
        }
        // check for jackpot; only one of the conditionals is possible at a time
        if (isJackpot(rollValue) || isJackpot(diagonalDownValue) || isJackpot(diagonalUpValue)) {
            multiplier = _applyJackpot(multiplier);
        }

        // check each row for a horizontal win
        for (uint8 i = 0; i < NUM_COLS_ROWS; i++) {
            uint256 rowValue = _extractRowNumber(randomNums, i);
            if (_isNumberRepeating(rowValue)) {
                if (i == middleRowIndex) {
                    // x3 payout if found on middle row
                    multiplier = _applyMiddleRowMultiplier(multiplier);
                } else {
                    multiplier = _applyHorizontalMultiplier(multiplier);
                }
                if (i > 0 && isJackpot(rowValue)) {
                    multiplier = _applyJackpot(multiplier);
                }
            }
        }

        if (multiplier == BASE_MULTIPLIER) {
            // multiplier was never changed; no win. wins will always be >10x
            multiplier = 0;
        }

        payout = (betAmount * multiplier);
    }

    /// Generate random numbers for a slot pull. Note: only runs in MEVM.
    function generateSlotNumbers() internal returns (uint8[] memory) {
        uint8[] memory randomNums = new uint8[](NUM_COLS_ROWS);
        for (uint8 i = 0; i < NUM_COLS_ROWS; i++) {
            randomNums[i] = Random.randomUint8() % NUM_VALUES;
        }
        return randomNums;
    }

    function _oneMask(uint8 numDigits) internal pure returns (uint256 mask) {
        require(numDigits > 0, "numDigits must be > 0");
        for (uint8 i = 0; i < numDigits; i++) {
            mask += (10 ** i);
        }
    }

    function _isNumberRepeating(uint256 value) internal pure returns (bool) {
        return value % _oneMask(NUM_COLS_ROWS) == 0;
    }

    /// A jackpot is all 7s.
    function isJackpot(uint256 value) internal pure returns (bool) {
        return value > 0 && value % (_oneMask(NUM_COLS_ROWS) * 7) == 0;
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

    function _extractNumberDiagonalDown(uint256 baseNumber) internal pure returns (uint256 number) {
        for (uint8 i = 0; i < NUM_COLS_ROWS; i++) {
            uint256 factor = NUM_VALUES ** (NUM_COLS_ROWS - i - 1);
            number += _shiftDigits((baseNumber - (baseNumber % factor)) / factor, i, i);
        }
    }

    function _extractNumberDiagonalUp(uint256 baseNumber) internal pure returns (uint256 number) {
        for (uint8 i = 0; i < NUM_COLS_ROWS; i++) {
            uint256 factor = NUM_VALUES ** (NUM_COLS_ROWS - i - 1);
            number += _shiftDigits((baseNumber - (baseNumber % factor)) / factor, NUM_COLS_ROWS - i - 1, i);
        }
    }

    function _getMiddleRowIndex() internal pure returns (uint8 middleRowIndex) {
        for (uint8 idx = 0; idx < NUM_COLS_ROWS; idx++) {
            if (NUM_COLS_ROWS - idx - 1 == idx) {
                middleRowIndex = idx;
            }
        }
    }

    function _applyJackpot(uint256 multiplier) internal pure returns (uint256) {
        return multiplier * 10;
    }

    function _applyHorizontalMultiplier(uint256 multiplier) internal pure returns (uint256) {
        return multiplier * 2;
    }

    function _applyMiddleRowMultiplier(uint256 multiplier) internal pure returns (uint256) {
        return multiplier * 3;
    }

    function _applyDiagonalMultiplier(uint256 multiplier) internal pure returns (uint256) {
        return multiplier * 2;
    }

    function boardToString(uint8[NUM_COLS_ROWS] memory randomNums) internal pure returns (string memory result) {
        for (uint8 i = 0; i < NUM_COLS_ROWS; i++) {
            result = string(abi.encodePacked(result, _extractRowNumber(randomNums, i).toString(), "\n"));
        }
    }
}
