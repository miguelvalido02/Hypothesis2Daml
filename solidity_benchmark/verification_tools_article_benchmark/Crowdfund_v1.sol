// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.2;

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
