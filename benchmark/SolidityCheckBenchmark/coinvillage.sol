pragma solidity >=0.4.22 <0.6.0;

//0xe4b676c8af80cf9a27abcbfdd1f2504ac6528603.sol
contract Coinvillage {
    string public name;

    string public symbol;

    uint8 public decimals = 18;

    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;

    /**
     * Initializes contract with initial supply tokens to the creator of the contract
     */

    constructor(
        uint256 initialSupply,
        string memory tokenName,
        string memory tokenSymbol
    ) public {
        totalSupply = initialSupply * 10 ** uint256(decimals); // Update total supply with the decimal amount

        balanceOf[msg.sender] = totalSupply; // Give the creator all initial tokens

        name = tokenName; // Set the name for display purposes

        symbol = tokenSymbol; // Set the symbol for display purposes
    }

    /**
     * Internal transfer, only can be called by this contract
     */

    function _transfer(address _from, address _to, uint _value) internal {
        // Prevent transfer to 0x0 address. Use burn() instead
        require(_to != address(0x0));

        // Check if the sender has enough
        require(balanceOf[_from] >= _value);

        // Check for overflows
        require(balanceOf[_to] + _value >= balanceOf[_to]);

        // Save this for an assertion in the future
        uint previousBalances = balanceOf[_from] + balanceOf[_to];

        // Subtract from the sender
        balanceOf[_from] -= _value;

        // Add the same to the recipient
        balanceOf[_to] += _value;

        // Asserts are used to use static analysis to find bugs in your code. They should never fail
        assert(balanceOf[_from] + balanceOf[_to] == previousBalances);
    }

    /**
     * Send `_value` tokens to `_to` from your account
     * @param _to The address of the recipient

     * @param _value the amount to send

     */

    function transfer(
        address _to,
        uint256 _value
    ) public returns (bool success) {
        _transfer(msg.sender, _to, _value);

        return true;
    }

    /**
     * Transfer tokens from other address

     * Send `_value` tokens to `_to` on behalf of `_from`

     * @param _from The address of the sender

     * @param _to The address of the recipient

     * @param _value the amount to send

     */

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) public returns (bool success) {
        _transfer(_from, _to, _value);

        return true;
    }

    /**
     * Destroy tokens

     * Remove `_value` tokens from the system irreversibly

     * @param _value the amount of money to burn

     */

    function burn(uint256 _value) public returns (bool success) {
        require(balanceOf[msg.sender] >= _value); // Check if the sender has enough

        balanceOf[msg.sender] -= _value; // Subtract from the sender

        totalSupply -= _value; // Updates totalSupply

        return true;
    }

    /**
     * Destroy tokens from other account

     * Remove `_value` tokens from the system irreversibly on behalf of `_from`.

     * @param _from the address of the sender

     * @param _value the amount of money to burn

     */

    function burnFrom(
        address _from,
        uint256 _value
    ) public returns (bool success) {
        require(balanceOf[_from] >= _value); // Check if the targeted balance is enough

        balanceOf[_from] -= _value; // Subtract from the targeted balance

        totalSupply -= _value; // Update totalSupply

        return true;
    }
}
