pragma solidity ^0.4.22;

//0xa8dbd8beab9a664fc5a74920bd47411e56966997
library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a * b;

        assert(a == 0 || c / a == b);

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a / b;

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);

        return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;

        assert(c >= a);

        return c;
    }
}

contract ForeignToken {
    function balanceOf(address _owner) public constant returns (uint256);

    function transfer(address _to, uint256 _value) public returns (bool);
}

contract ERC20Basic {
    uint256 public totalSupply;

    function balanceOf(address who) public constant returns (uint256);

    function transfer(address to, uint256 value) public returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
}

contract ERC20 is ERC20Basic {
    function allowance(
        address owner,
        address spender
    ) public constant returns (uint256);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public returns (bool);

    function approve(address spender, uint256 value) public returns (bool);

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

interface Token {
    function distr(address _to, uint256 _value) external returns (bool);

    function totalSupply() external constant returns (uint256 supply);

    function balanceOf(
        address _owner
    ) external constant returns (uint256 balance);
}

contract Predatex is ERC20 {
    using SafeMath for uint256;

    address owner = msg.sender;

    mapping(address => uint256) balances;

    mapping(address => bool) public blacklist;

    string public constant name = "Predatex";

    string public constant symbol = "PDTX";

    uint public constant decimals = 8;

    uint256 public totalSupply = 21000000000e8;

    uint256 public totalDistributed = 10000000000e8;

    uint256 public totalRemaining = totalSupply.sub(totalDistributed);

    uint256 public value = 100000e8;

    bool public distributionFinished = false;

    modifier canDistr() {
        require(!distributionFinished);

        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);

        _;
    }

    modifier onlyWhitelist() {
        require(blacklist[msg.sender] == false);

        _;
    }

    constructor() public {
        owner = msg.sender;

        balances[owner] = totalDistributed;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        if (newOwner != address(0)) {
            owner = newOwner;
        }
    }

    function finishDistribution() public onlyOwner canDistr returns (bool) {
        distributionFinished = true;

        return true;
    }

    function distr(
        address _to,
        uint256 _amount
    ) private canDistr returns (bool) {
        totalDistributed = totalDistributed.add(_amount);

        totalRemaining = totalRemaining.sub(_amount);

        balances[_to] = balances[_to].add(_amount);

        emit Transfer(address(0), _to, _amount);

        return true;

        if (totalDistributed >= totalSupply) {
            distributionFinished = true;
        }
    }

    function getTokens() public payable canDistr onlyWhitelist {
        if (value > totalRemaining) {
            value = totalRemaining;
        }

        require(value <= totalRemaining);

        address investor = msg.sender;

        uint256 toGive = value;

        distr(investor, toGive);

        if (toGive > 0) {
            blacklist[investor] = true;
        }

        if (totalDistributed >= totalSupply) {
            distributionFinished = true;
        }

        value = value.div(100000).mul(99999);
    }

    function balanceOf(address _owner) public constant returns (uint256) {
        return balances[_owner];
    }

    function transfer(
        address _to,
        uint256 _amount
    ) public returns (bool success) {
        require(_to != address(0));

        require(_amount <= balances[msg.sender]);

        balances[msg.sender] = balances[msg.sender].sub(_amount);

        balances[_to] = balances[_to].add(_amount);

        return true;
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _amount
    ) public returns (bool success) {
        require(_to != address(0));

        require(_amount <= balances[_from]);

        balances[_from] = balances[_from].sub(_amount);

        balances[_to] = balances[_to].add(_amount);

        return true;
    }

    function getTokenBalance(
        address tokenAddress,
        address who
    ) public constant returns (uint) {
        ForeignToken t = ForeignToken(tokenAddress);

        uint bal = t.balanceOf(who);

        return bal;
    }

    function withdraw() public onlyOwner {
        uint256 etherBalance = address(this).balance;

        owner.transfer(etherBalance);
    }

    function burn(uint256 _value) public onlyOwner {
        require(_value <= balances[msg.sender]);

        address burner = msg.sender;

        balances[burner] = balances[burner].sub(_value);

        totalSupply = totalSupply.sub(_value);

        totalDistributed = totalDistributed.sub(_value);
    }

    function withdrawForeignTokens(
        address _tokenContract
    ) public onlyOwner returns (bool) {
        ForeignToken token = ForeignToken(_tokenContract);

        uint256 amount = token.balanceOf(address(this));

        return token.transfer(owner, amount);
    }
}
