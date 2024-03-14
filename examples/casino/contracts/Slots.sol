// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./CasinoLibV2.sol";
import "suave-std/suavelib/Suave.sol";
import {Random} from "suave-std/Random.sol";

contract SlotMachines {
    mapping(uint256 => CasinoLib.SlotMachine) public slotMachines;
    uint256 numMachines;
    mapping(address => uint256) public chipsBalance;

    event Test(uint256 debugCode);
    event Test(address debugCode);
    event BoughtChips(address gamer, uint256 amount);
    event EcononicCrisis(uint256 slotId, uint256 pot, uint256 requestedPayout);
    event InitializedSlotMachine(uint256 slotId, uint256 pot, uint256 minBet);
    event PulledSlot(uint256 slotId, uint256 betAmount, uint256 latestPot, string board);
    event Winner(uint256 slotId, address winner, uint256 amount);
    event Jackpot(uint256 slotId, address winner, uint256 amount);
    event Bust(uint256 slotId, address gamer);
    event Fail(uint256 errCode);

    fallback() external {
        emit Fail(11);
    }

    receive() external payable {
        emit Fail(21);
    }

    function buyChips() public payable returns (bool success) {
        require(msg.value > 0, "deposit must be greater than 0");
        chipsBalance[msg.sender] += msg.value;
        emit BoughtChips(msg.sender, msg.value);
        success = true;
    }

    function cashChips(uint256 amount) public {
        require(chipsBalance[msg.sender] >= amount, "insufficient balance");
        chipsBalance[msg.sender] -= amount;
        (bool success,) = payable(msg.sender).call{value: amount}("");
        require(success, "ETH transfer failed");
    }

    function initSlotMachine(uint256 minBet) public payable returns (uint256 slotId) {
        CasinoLib.SlotMachine memory machine = CasinoLib.SlotMachine({nonce: 0, minBet: minBet, pot: msg.value});
        slotMachines[numMachines] = machine;
        slotId = numMachines++;
        emit InitializedSlotMachine(slotId, msg.value, minBet);
    }

    function pullSlot(uint256 slotId, uint256 betAmount) public returns (bytes memory suave_call_data) {
        require(Suave.isConfidential(), "must call via confidential compute request");
        require(chipsBalance[msg.sender] >= betAmount, "insufficient funds deposited");
        CasinoLib.SlotMachine memory machine = slotMachines[slotId];
        require(betAmount >= machine.minBet, "must place at least minimum bet");
        uint8[] memory randomNums = CasinoLib.generateSlotNumbers();
        suave_call_data = encodeOnSlotPulled(betAmount, slotId, randomNums);
    }

    function encodeOnSlotPulled(uint256 betAmount, uint256 slotId, uint8[] memory randomNums)
        private
        pure
        returns (bytes memory)
    {
        return bytes.concat(this.onSlotPulled.selector, abi.encode(betAmount, slotId, randomNums));
    }

    function onSlotPulled(uint256 betAmount, uint256 slotId, uint8[] memory randomNums) external {
        chipsBalance[msg.sender] -= betAmount;
        CasinoLib.SlotMachine memory machine = slotMachines[slotId];
        machine.pot += betAmount;
        machine.nonce++;
        uint8[3] memory roll = [randomNums[0], randomNums[1], randomNums[2]];
        (uint256 payout, uint256 rollValue) = CasinoLib.calculateSlotPull(betAmount, roll);

        if (payout == 0) {
            // return early; player lost
            emit Bust(slotId, msg.sender);
        } else if (payout > machine.pot) {
            // slots couldn't pay out the winnings; refund bet
            emit EcononicCrisis(slotId, machine.pot, payout);
            chipsBalance[msg.sender] += betAmount;
            machine.pot -= betAmount;
        } else {
            machine.pot -= payout;
            if (CasinoLib.isJackpot(rollValue)) {
                emit Jackpot(slotId, msg.sender, payout);
            } else {
                emit Winner(slotId, msg.sender, payout);
            }
        }

        machine.pot -= payout;
        slotMachines[slotId] = machine;
        string memory board = CasinoLib.boardToString(roll);
        emit PulledSlot(slotId, betAmount, machine.pot, board);

        // disburse winnings
        chipsBalance[msg.sender] += payout;
    }
}
