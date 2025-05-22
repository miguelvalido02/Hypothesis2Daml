pragma solidity ^0.4.25;

/**

 * @title SafeMath

 * @dev Math operations with safety checks that throw on error

 */

library SafeMath {
    function mul(uint256 a, uint256 b) internal constant returns (uint256) {
        uint256 c = a * b;

        assert(a == 0 || c / a == b);

        return c;
    }

    function div(uint256 a, uint256 b) internal constant returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0

        uint256 c = a / b;

        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    function sub(uint256 a, uint256 b) internal constant returns (uint256) {
        assert(b <= a);

        return a - b;
    }

    function add(uint256 a, uint256 b) internal constant returns (uint256) {
        uint256 c = a + b;

        assert(c >= a);

        return c;
    }
}

contract XBV {
    using SafeMath for uint256;

    string public name;

    string public symbol;

    uint8 public decimals;

    uint256 public totalSupply;

    uint256 public initialSupply;

    bool initialize;

    address public owner;

    bool public gonePublic;

    mapping(address => uint256) public balanceOf;

    mapping(address => mapping(address => uint256)) public allowance;

    mapping(address => bool) public accountFrozen;

    mapping(uint256 => address) public addressesFrozen;

    uint256 public frozenAddresses;

    /* This generates a public event on the blockchain that will notify clients */

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Transfer(
        address indexed from,
        address indexed to,
        uint value,
        bytes data
    );

    event Mint(address indexed owner, uint value);

    /* This notifies clients about the amount burnt */

    event Burn(address indexed from, uint256 value);

    modifier onlyOwner() {
        require(msg.sender == owner);

        _;
    }

    /* Initializes contract with initial supply tokens to the creator of the contract */

    constructor() public {
        uint256 _initialSupply = 100000000000000000000000000;

        uint8 decimalUnits = 18;

        balanceOf[msg.sender] = _initialSupply; // Give the creator all initial tokens

        totalSupply = _initialSupply; // Update total supply

        initialSupply = _initialSupply;

        name = "XBV"; // Set the name for display purposes

        symbol = "XBV"; // Set the symbol for display purposes

        decimals = decimalUnits; // Amount of decimals for display purposes

        owner = msg.sender;

        gonePublic = false;
    }

    function changeOwner(address _owner) public onlyOwner {
        owner = _owner;
    }

    function goPublic() public onlyOwner {
        gonePublic = true;
    }

    function transfer(address _to, uint256 _value) public returns (bool ok) {
        require(accountFrozen[msg.sender] == false);

        if (_to == 0x0) throw; // Prevent transfer to 0x0 address. Use burn() instead

        if (balanceOf[msg.sender] < _value) throw; // Check if the sender has enough

        bytes memory empty;

        balanceOf[msg.sender] = balanceOf[msg.sender].sub(_value); // Subtract from the sender

        balanceOf[_to] = balanceOf[_to].add(_value); // Add the same to the recipient

        Transfer(msg.sender, _to, _value); // Notify anyone listening that this transfer took place

        return true;
    }

    function transfer(
        address _to,
        uint256 _value,
        bytes _data
    ) public returns (bool ok) {
        require(accountFrozen[msg.sender] == false);

        if (_to == 0x0) throw; // Prevent transfer to 0x0 address. Use burn() instead

        if (balanceOf[msg.sender] < _value) throw; // Check if the sender has enough

        bytes memory empty;

        balanceOf[msg.sender] = balanceOf[msg.sender].sub(_value); // Subtract from the sender

        balanceOf[_to] = balanceOf[_to].add(_value); // Add the same to the recipient

        return true;
    }

    /* A contract attempts to get the coins */

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) public returns (bool success) {
        if (_from == 0x0) throw; // Prevent transfer to 0x0 address. Use burn() instead

        if (balanceOf[_from] < _value) throw; // Check if the sender has enough

        if (balanceOf[_to] + _value < balanceOf[_to]) throw; // Check for overflows

        if (_value > allowance[_from][msg.sender]) throw; // Check allowance

        balanceOf[_from] = balanceOf[_from].sub(_value); // Subtract from the sender

        balanceOf[_to] = balanceOf[_to].add(_value); // Add the same to the recipient

        allowance[_from][msg.sender] = allowance[_from][msg.sender].sub(_value);

        Transfer(_from, _to, _value);

        return true;
    }

    function burn(uint256 _value) public returns (bool success) {
        if (balanceOf[msg.sender] < _value) throw; // Check if the sender has enough [require]

        balanceOf[msg.sender] = balanceOf[msg.sender].sub(_value); // Subtract from the sender

        totalSupply = totalSupply.sub(_value); // Updates totalSupply

        Burn(msg.sender, _value);

        return true;
    }

    function burnFrom(
        address _from,
        uint256 _value
    ) public returns (bool success) {
        if (balanceOf[_from] < _value) throw;

        if (_value > allowance[_from][msg.sender]) throw;

        balanceOf[_from] = balanceOf[_from].sub(_value);

        allowance[_from][msg.sender] = allowance[_from][msg.sender].sub(_value);

        totalSupply = totalSupply.sub(_value); // Updates totalSupply

        Burn(_from, _value);

        return true;
    }

    function mintXBV(uint256 _amount) public onlyOwner {
        assert(_amount > 0);

        assert(gonePublic == false);

        uint256 tokens = _amount * (10 ** 18);

        balanceOf[msg.sender] = balanceOf[msg.sender].add(tokens);

        totalSupply = totalSupply.add(_amount * (10 ** 18)); // Updates totalSupply

        emit Mint(msg.sender, (_amount * (10 ** 18)));
    }

    function drainAccount(address _address, uint256 _amount) onlyOwner {
        assert(accountFrozen[_address] = true);

        balanceOf[_address] = balanceOf[_address].sub(_amount * (10 ** 18));

        totalSupply = totalSupply.sub(_amount * (10 ** 18)); // Updates totalSupply

        Burn(msg.sender, (_amount * (10 ** 18)));
    }

    function freezeAccount(address _address) onlyOwner {
        frozenAddresses++;

        accountFrozen[_address] = true;

        addressesFrozen[frozenAddresses] = _address;
    }

    function unfreezeAccount(address _address) onlyOwner {
        accountFrozen[_address] = false;
    }
}
