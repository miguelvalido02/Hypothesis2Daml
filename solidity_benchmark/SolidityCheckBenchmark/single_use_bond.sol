pragma solidity ^0.5.1;

//0x2577fd5ca8cafad8e2fdad6b16004f8e1cb4e380.sol
contract OneTimesBondContract {
    // This is a single use bond contract that allows owner issue locked funds

    bool public has_initialized = false;

    address public creator = msg.sender;

    uint256 public expires_on;

    uint256 public cur_bond_val;

    address public bond_owner;

    modifier onlyOwner() {
        require(msg.sender == bond_owner);

        _;
    }

    constructor(address _for) public {
        bond_owner = _for;
    }

    function initializeBond(uint256 _expires_on) public payable {
        require(has_initialized == false);
        require(msg.sender == creator);
        expires_on = _expires_on;

        cur_bond_val = msg.value;

        has_initialized = true;
    }

    function redeemBond() public {
        require(msg.sender == creator);
        if (block.timestamp < expires_on) {
            msg.sender.transfer(cur_bond_val);
        }
    }

    function liquidateBond() public payable onlyOwner {
        if (block.timestamp >= expires_on) {
            msg.sender.transfer(cur_bond_val);
        }
    }
}
