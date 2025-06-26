pragma solidity ^0.4.11;

//0xe0f2b452761482da7862356366373817770bb58c.sol
contract AITToken {
    string public name = "AIT";

    string public symbol = "AIT";

    uint256 public decimals = 8;

    address public adminWallet;

    mapping(address => uint256) public balanceOf;

    uint256 public totalSupply = 0;

    bool public stopped = false;

    address owner = 0x0;

    modifier isOwner() {
        assert(owner == msg.sender);

        _;
    }

    modifier isRunning() {
        assert(!stopped);

        _;
    }

    modifier validAddress() {
        assert(0x0 != msg.sender);

        _;
    }

    function AITToken() public {
        owner = msg.sender;

        adminWallet = owner;

        totalSupply = 20000000000000000;

        balanceOf[owner] = 20000000000000000;
    }

    function transfer(
        address _to,
        uint256 _value
    ) public isRunning validAddress returns (bool success) {
        require(balanceOf[msg.sender] >= _value);

        require(balanceOf[_to] + _value >= balanceOf[_to]);

        balanceOf[msg.sender] -= _value;

        balanceOf[_to] += _value;

        return true;
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) public isRunning validAddress returns (bool success) {
        require(balanceOf[_from] >= _value);

        require(balanceOf[_to] + _value >= balanceOf[_to]);

        balanceOf[_to] += _value;

        balanceOf[_from] -= _value;

        return true;
    }

    function stop() public isOwner {
        stopped = true;
    }

    function start() public isOwner {
        stopped = false;
    }

    function setName(string _name) public isOwner {
        name = _name;
    }

    function setSymbol(string _symbol) public isOwner {
        symbol = _symbol;
    }

    function burn(uint256 _value) public {
        require(balanceOf[msg.sender] >= _value);

        balanceOf[msg.sender] -= _value;

        balanceOf[0x0] += _value;
    }
}
