// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./CasinoLib.sol";
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
    event PulledSlot(uint256 slotId, uint256 betAmount, uint256 latestPot);
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

    function initSlotMachine(uint256 minBet, uint8 winChancePercent) public payable returns (uint256 slotId) {
        require(winChancePercent <= 50, "unreasonable odds");
        CasinoLib.SlotMachine memory machine = CasinoLib.SlotMachine({
            winChancePercent: winChancePercent,
            nonce: 0,
            minBet: minBet,
            // should be economically safe hardcoded values for now
            // but these should be configurable within reasonable params
            jackpotFactor: 10000,
            standardPayoutPercent: 200,
            jackpotPayoutPercent: 9001,
            pot: msg.value
        });
        slotMachines[numMachines] = machine;
        slotId = numMachines++;
        emit InitializedSlotMachine(slotId, msg.value, minBet);
    }

    function pullSlot(uint256 slotId, uint256 betAmount) public returns (bytes memory suave_call_data) {
        require(Suave.isConfidential(), "must call via confidential compute request");
        require(chipsBalance[msg.sender] >= betAmount, "insufficient funds deposited");
        CasinoLib.SlotMachine memory machine = slotMachines[slotId];
        require(betAmount >= machine.minBet, "must place at least minimum bet");
        uint256 randomNum = Random.randomUint256();
        suave_call_data = encodeOnSlotPulled(betAmount, slotId, randomNum);
    }

    function encodeOnSlotPulled(uint256 betAmount, uint256 slotId, uint256 randomNum)
        private
        pure
        returns (bytes memory)
    {
        return bytes.concat(this.onSlotPulled.selector, abi.encode(betAmount, slotId, randomNum));
    }

    function onSlotPulled(uint256 betAmount, uint256 slotId, uint256 randomNum) external {
        chipsBalance[msg.sender] -= betAmount;
        CasinoLib.SlotMachine memory machine = slotMachines[slotId];
        machine.pot += betAmount;
        machine.nonce++;
        slotMachines[slotId] = machine;
        emit PulledSlot(slotId, betAmount, machine.pot);
        uint256 payout = CasinoLib.calculateSlotPull(betAmount, randomNum, machine);
        if (payout == 0) {
            // return early; player lost
            emit Bust(slotId, msg.sender);
            return;
        }
        if (machine.pot < payout) {
            // slots couldn't pay out the winnings; refund bet
            emit EcononicCrisis(slotId, machine.pot, payout);
            chipsBalance[msg.sender] += betAmount;
            return;
        }
        if (payout >= ((machine.jackpotPayoutPercent * machine.standardPayoutPercent * betAmount) / 10000)) {
            emit Jackpot(slotId, msg.sender, payout);
        }
        // disburse winnings
        chipsBalance[msg.sender] += payout;
        emit Winner(slotId, msg.sender, payout);
    }
}
