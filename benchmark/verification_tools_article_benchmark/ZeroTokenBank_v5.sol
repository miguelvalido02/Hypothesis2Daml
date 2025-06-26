/// @custom:version flat caps on deposits and withdraw.
//SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.2;

/*
 "specification": "The ZeroTokenBank contract accepts deposits and withdrawals from any address. 
 When a deposit is made, the corresponding amount is added to the account balance of the depositing address. 
 These balances are maintained using a mapping within the contract. 
 To withdraw funds, a user can call the withdraw function of the Bank contract with a specified amount. 
 The contract verifies that the depositor has sufficient funds in their account and then initiates a transfer of the specified amount to the depositor's address.",
    "properties": {
        "dep-inc-snd-bal": "after a successful `deposit(amount)`, the balance entry of `msg.sender` is increased by `amount`.",
        "wd-dec-snd-bal": "after a successful `withdraw(amount)`, the balance entry of `msg.sender` is decreased by `amount`.",
        "dep-not-revert": "a `deposit(amount)` call never reverts.",
        "wd-not-revert": "a `withdraw(amount)` call does not revert if `amount` is bigger than zero and less or equal to the balance entry of `msg.sender`.",
        "bal-inc-onlyif-dep": "the only way to increase the balance entry of a user `a` is by calling `deposit` with `msg.sender = a`.",
        "bal-dec-onlyif-wd": "the only way to decrease the balance entry of a user `a` is by calling `withdraw` with `msg.sender = a`.",
        "cbal-nonneg": "`contract_balance` is always non-negative.",
        "bal-nonneg": "every balance entry is always non-negative.",
        "always-bal-to-max": "any user can always increase their balance up to its maximum value with a single transaction.",
        "always-bal-inc": "any user can always increase their balance.",
        "cbal-ge-bal": "`contract_balance` is always greater or equal to any balance entry.",
        "cbal-eq-sum-bal": "`contract_balance` is always equal to the sum of the balance entries.",
        "bal-sum-dep-wd": "for every user `a`, their balance entry is equal to the sum of all `amount`s in successful `deposit(amount)` with `msg.sender = a` minus those in successful `withdraw(amount)` with `msg.sender = a`.",
        "always-wd-all-one": "any user can always withdraw their whole balance entry in a single transaction.",
        "always-wd-all-many": "any user can always withdraw their whole balance entry in a finite sequence of transaction.",
        "sum-wd-le-sum-dep": "for every user `a`, the sum of all `amount`s withdrawn by `a` is less or equal to the sum of all `amount`s deposited by `a`.",
        "frontrun-one": "any transaction made by a user will have the same effect when frontrun by a single transaction made by a different user.",
        "frontrun-many": "any transaction made by a user will have the same effect when frontrun by a finite sequence of transactions made by different users."
    }
*/
contract ZeroTokenBank {
    uint contract_balance;
    mapping(address => uint) balances;

    function balanceOf(address addr) public view returns (uint) {
        return balances[addr];
    }

    function totalBalance() public view returns (uint) {
        return contract_balance;
    }

    function deposit(uint amount) public {
        require(amount < 200);
        balances[msg.sender] += amount;
        contract_balance += amount;
    }

    function withdraw(uint amount) public {
        require(amount <= 100);
        require(amount > 0);
        require(amount <= balances[msg.sender]);

        balances[msg.sender] -= amount;

        contract_balance -= amount;
    }
}
