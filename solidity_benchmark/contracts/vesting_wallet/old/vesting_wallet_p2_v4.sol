// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (finance/VestingWallet.sol)
pragma solidity ^0.8.0;

import "lib/Address.sol";
import "lib/Context.sol";

contract VestingWallet is Context {
    event EtherReleased(uint256 amount);

    uint256 private _released;
    address private immutable _beneficiary;
    uint64 private immutable _start;
    uint64 private immutable _duration;

    // ghost variables
    uint private _balance;
    uint private _deposited;

    constructor(address beneficiaryAddress, uint64 startTimestamp, uint64 durationSeconds) payable {
        require(beneficiaryAddress != address(0), "VestingWallet: beneficiary is zero address");
        require(durationSeconds > 0);
        _beneficiary = beneficiaryAddress;
        _start = startTimestamp;
        _duration = durationSeconds;

        _balance += msg.value;
        _deposited += msg.value;
    }

    receive() external payable virtual {
        _balance += msg.value;
        _deposited += msg.value;
    }

    function beneficiary() public view virtual returns (address) {
        return _beneficiary;
    }

    function start() public view virtual returns (uint256) {
        return _start;
    }

    function duration() public view virtual returns (uint256) {
        return _duration;
    }

    function released() public view virtual returns (uint256) {
        return _released;
    }

    function releasable() public virtual returns (uint256) {
        return vestedAmount(uint64(block.timestamp)) - released();
    }

    function release() public virtual {
        uint256 amount = releasable();
        _released += amount;
        _balance -= amount;
        emit EtherReleased(amount);
        Address.sendValue(payable(beneficiary()), amount);
    }

    function vestedAmount(uint64 timestamp) public virtual returns (uint256) {
        return _vestingSchedule(_balance + released(), timestamp);
    }

    function _vestingSchedule(uint256 totalAllocation, uint64 timestamp) internal virtual returns (uint256) {
        if (timestamp < start()) {
            return 0;
        } else if (timestamp > start() + duration()) {
            return totalAllocation;
        } else {
            return (totalAllocation * (timestamp - start())) / duration();
        }
    }

    function invariant() public view {
        assert(_balance + released() == _deposited);
    }
}

// ====
// SMTEngine: CHC
// Time: 18:15.62
// Targets: assert
// ----
// Does not seem to terminate
// Warning: CHC: Assertion violation might happen here.
