// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (finance/PaymentSplitter.sol)

pragma solidity ^0.8.0;

/*
"specification": "This contract allows to split Ether payments among a group of accounts. 
The sender does not need to be aware that the Ether will be split in this way, since it is handled transparently by the contract.
The split can be in equal parts or in any other arbitrary proportion. The way this is specified is by assigning each account to a number of shares. 
Of all the Ether that this contract receives, each account will then be able to claim an amount proportional to the percentage of total shares they were assigned. 
The distribution of shares is set at the time of contract deployment and can't be updated thereafter.\n\n `PaymentSplitter` follows a pull payment model. 
This means that payments are not automatically forwarded to the accounts but kept in this contract, and the actual transfer is triggered as a separate step by calling the release() function.",
    "properties": [
        " for all accounts `a` in `payees`, `a != address(0)`.",
        " if `payees[0] == addr` then `shares[addr] == 0` (should fail).",
        " for all addresses `addr` in `payees`, `shares[addr] > 0`.",
        " for all addresses `addr` in `payees`, `releasable(addr)` is less than or equal to the balance of the contract.",
        " the sum of the releasable funds for every accounts is equal to the balance of the contract."
    ]
*/
/// @custom:version conformant to specification

contract PaymentSplitter {
    uint256 private totalShares;
    uint256 private totalReleased;

    mapping(address => uint256) private shares;
    mapping(address => uint256) private released;
    address[] private payees;

    // ghost variables
    uint _total_releasable;

    constructor(address[] memory payees_, uint256[] memory shares_) payable {
        require(
            payees_.length == shares_.length,
            "PaymentSplitter: payees and shares length mismatch"
        );
        require(payees_.length > 0, "PaymentSplitter: no payees");

        for (uint256 i = 0; i < payees_.length; i++) {
            addPayee(payees_[i], shares_[i]);
        }
    }

    function releasable(address account) public view returns (uint256) {
        uint256 totalReceived = address(this).balance + totalReleased;
        return pendingPayment(account, totalReceived, released[account]);
    }

    function release(address payable account) public virtual {
        require(shares[account] > 0, "PaymentSplitter: account has no shares");

        uint256 payment = releasable(account);

        require(payment != 0, "PaymentSplitter: account is not due payment");

        // totalReleased is the sum of all values in released.
        // If "totalReleased += payment" does not overflow, then "released[account] += payment" cannot overflow.
        totalReleased += payment;
        unchecked {
            released[account] += payment;
        }

        (bool success, ) = account.call{value: payment}("");
        require(success);
    }

    function pendingPayment(
        address account,
        uint256 totalReceived,
        uint256 alreadyReleased
    ) private view returns (uint256) {
        return
            (totalReceived * shares[account]) / totalShares - alreadyReleased;
    }

    function addPayee(address account, uint256 shares_) private {
        require(
            account != address(0),
            "PaymentSplitter: account is the zero address"
        );
        require(shares_ > 0, "PaymentSplitter: shares are 0");
        require(
            shares[account] == 0,
            "PaymentSplitter: account already has shares"
        );

        payees.push(account);
        shares[account] = shares_;
        totalShares = totalShares + shares_;
    }
}
