pragma solidity ^0.5.6;

//0x7671db0a70fa0196071d634f26971b9371627dc0.sol
contract Registry {
    event LogWhitelisted(address addr, bool isWhitelisted);

    event LogChangedOwner(address oldOwner, address newOwner);

    mapping(address => bool) public whitelisted;

    // The owner will be changed to a SC that bridges into a polkadot praachain,

    // once the full AdEx Registry is running
    address public owner;

    constructor() public {
        owner = msg.sender;
    }

    function changeOwner(address newOwner) public {
        require(msg.sender == owner, "ONLY_OWNER");

        emit LogChangedOwner(owner, newOwner);

        owner = newOwner;
    }

    function setWhitelisted(address addr, bool isWhitelisted) public {
        require(msg.sender == owner, "ONLY_OWNER");

        whitelisted[addr] = isWhitelisted;

        emit LogWhitelisted(addr, isWhitelisted);
    }

    function isWhitelisted(address addr) public view returns (bool) {
        return whitelisted[addr];
    }
}
