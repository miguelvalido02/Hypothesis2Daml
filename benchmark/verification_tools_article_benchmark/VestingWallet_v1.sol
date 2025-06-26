// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (finance/VestingWallet.sol)
pragma solidity >=0.8.2;

/* "specification": "The contract handles the maturation (vesting) of native cryptocurrency for a given beneficiary. The constructor specifies the address of the beneficiary, the first block height (start) where the beneficiary can withdraw funds, and the overall duration of the vesting scheme. Once the scheme is expired, the beneficiary can withdraw all the funds from the contract. At any moment between the start and the expiration of the vesting scheme, the beneficiary can withdraw an amount of ETH proportional to the time passed since the start of the scheme. The contract can receive ETH at any time through external transactions: these funds will follow the vesting schedule as if they were deposited from the beginning.",
    "properties": {
        "rel-le-bal": "the amount of releasable ETH is always less than or equal to the contract balance.",
        "exp-all-rel": "if the vesting scheme has expired, then exactly the whole contract balance is releasable.",
        "no-start-no-rel": "if the vesting scheme has not started yet, then no balance is releasable.",
        "release-rel": "after a successful call to `release`, the beneficiary receives `releasable()` ETH",
        "ext-release-rel": "if the beneficiary is an externally owned account, after a successful call to `release`, the beneficiary receives `releasable()` ETH",
        "benef-only-recv": "only the beneficiary can receive ETH from the contract",
        "rel-grows-linear": "releasable grows linearly between the start of the vesting scheme and its expiration: two successful consequent calls to `releasable` differ by c*t, where t is the timestamp difference between the two calls, and c is a fixed constant for the contract",
        "rel-strict-incr": "before the expiration of the scheme and after the start of the vesting scheme, the releasable amount is strictly increasing whenever the contract balance and the released amount is constant."
    }*/
/// @custom:version from [OpenZeppelin](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/finance/VestingWallet.sol).
contract VestingWallet {
    uint256 private released;
    address private immutable beneficiary;
    uint64 private immutable start;
    uint64 private immutable duration;

    constructor(
        address beneficiaryAddress,
        uint64 startTimestamp,
        uint64 durationSeconds
    ) payable {
        require(
            beneficiaryAddress != address(0),
            "VestingWallet: beneficiary is zero address"
        );
        require(durationSeconds > 0); // require not present in OpenZeppelin

        beneficiary = beneficiaryAddress;
        start = startTimestamp;
        duration = durationSeconds;
    }

    receive() external payable virtual {}

    function releasable() public view virtual returns (uint256) {
        return vestedAmount(uint64(block.timestamp)) - released;
    }

    function release() public virtual {
        uint256 amount = releasable();
        released += amount;

        (bool success, ) = beneficiary.call{value: amount}("");
        require(success);
    }

    function vestedAmount(
        uint64 timestamp
    ) public view virtual returns (uint256) {
        return vestingSchedule(address(this).balance + released, timestamp);
    }

    function vestingSchedule(
        uint256 totalAllocation,
        uint64 timestamp
    ) internal view virtual returns (uint256) {
        if (timestamp < start) {
            return 0;
        } else if (timestamp > start + duration) {
            return totalAllocation;
        } else {
            return (totalAllocation * (timestamp - start)) / duration;
        }
    }
}
