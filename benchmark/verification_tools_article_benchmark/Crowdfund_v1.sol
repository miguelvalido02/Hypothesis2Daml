// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.2;

/*Spec:
The Crowdfund contract implements a crowdfunding campaign.

The constructor specifies the owner of the campaign, the last block height where it is possible to receive donations (end_donate), and the goal in ETH that must be reached for the campaign to be successful.

The contract implements the following methods:

donate, which allows anyone to deposit any amount of ETH in the contract. Donations are only possible before the donation period has ended;
withdraw, which allows the owner to redeem all the funds deposited in the contract. This is only possible if the campaign goal has been reached;
reclaim, which all allows donors to reclaim their donations after the donation period has ended. This is only possible if the campaign goal has not been reached.

"properties": {
        "bal-decr-onlyif-wd-reclaim": "after the donation phase, if the contract balance decreases then either a successful `withdraw` or `reclaim` have been performed.",
        "donate-not-revert": "a transaction `donate` is not reverted if the donation phase has not ended.",
        "donate-not-revert-overflow": "a transaction `donate` is not reverted if the donation phase has not ended and sum between the old and the current donation does not overflow.",
        "no-donate-after-deadline": "calls to `donate` will revert if the donation phase has ended.",
        "no-receive-after-deadline": "the contract balance does not increase after the end of the donation phase.",
        "no-wd-if-no-goal": "calls to `withdraw` will revert if the contract balance is less than the `goal`.",
        "owner-only-recv": "only the owner can receive ETH from the contract.",
        "reclaim-not-revert": "a transaction `reclaim` is not reverted if the goal amount is not reached and the deposit phase has ended, and the sender has donated funds that they have not reclaimed yet.",
        "wd-not-revert": "a transaction `withdraw` is not reverted if the contract balance is greater than or equal to the goal and the donation phase has ended.",
        "wd-not-revert-EOA": "a transaction `withdraw` is not reverted if the contract balance is greater than or equal to the goal, the donation phase has ended, and the `receiver` is an EOA."
    }
*/
/// @custom:version conforming to specification.
contract Crowdfund {
    uint immutable goal; // amount that must be donated for the crowdfunding to be succesfull
    address immutable owner; // receiver of the donated funds
    mapping(address => uint) public donors;

    constructor(address payable owner_, uint256 goal_) {
        owner = owner_;
        goal = goal_;
    }

    function donate() public payable {
        donors[msg.sender] += msg.value;
    }

    function withdraw() public {
        require(address(this).balance >= goal);

        (bool succ, ) = owner.call{value: address(this).balance}("");
        require(succ);
    }

    function reclaim() public {
        require(address(this).balance < goal);
        require(donors[msg.sender] > 0);

        uint amount = donors[msg.sender];
        donors[msg.sender] = 0;

        (bool succ, ) = msg.sender.call{value: amount}("");
        require(succ);
    }
}
