pragma solidity ^0.5.2;

//////////////////////////////////////////

//                                      //

//              SafeMath                //

//                                      //

//                                      //

//////////////////////////////////////////

/**

 * @title SafeMath

 * @dev Unsigned math operations with safety checks that revert on error

 */

library SafeMath {
    /**

     * @dev Subtracts two unsigned integers, reverts on overflow (i.e. if subtrahend is greater than minuend).

     */

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);

        uint256 c = a - b;

        return c;
    }

    /**

     * @dev Adds two unsigned integers, reverts on overflow.

     */

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;

        require(c >= a);

        return c;
    }
}

//////////////////////////////////////////

//                                      //

//          Token interface             //

//                                      //

//                                      //

//////////////////////////////////////////

/**

 * @title ERC20 interface

 * @dev see https://github.com/ethereum/EIPs/issues/20

 */

interface IERC20 {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function totalSupply() external view returns (uint256);

    function balanceOf(address who) external view returns (uint256);

    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);

    function approve(address spender, uint256 value) external returns (bool);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

/**

 * @title Standard ERC20 token

 *

 * @dev Implementation of the basic standard token.

 */

contract LEOcoin is IERC20 {
    using SafeMath for uint256;

    string private _name;

    string private _symbol;

    uint8 private _decimals;

    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowed;

    uint256 private _totalSupply;

    address private _isMinter;

    uint256 private _cap;

    constructor(
        address masterAccount,
        uint256 premined,
        address minterAccount
    ) public {
        _name = "LEOcoin";

        _symbol = "LEO";

        _decimals = 18;

        _cap = 4000000000 * 1E18;

        _isMinter = minterAccount;

        _totalSupply = _totalSupply.add(premined);

        _balances[masterAccount] = _balances[masterAccount].add(premined);

        emit Transfer(address(0), masterAccount, premined);
    }

    /**
     * @return the name of the token.
     */

    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @return the symbol of the token.
     */

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /**
     * @return the number of decimals of the token.
     */

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    /**
     * @dev Total number of tokens in existence
     */

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev Gets the balance of the specified address.
     * @param owner The address to query the balance of.
     * @return An uint256 representing the amount owned by the passed address.
     */

    function balanceOf(address owner) public view returns (uint256) {
        return _balances[owner];
    }

    /**
     * @dev Transfer token for a specified address
     * @param to The address to transfer to.
     * @param value The amount to be transferred.
     */

    function transfer(address to, uint256 value) public returns (bool) {
        _transfer(msg.sender, to, value);

        return true;
    }

    /**
     * @dev Transfer tokens from one address to another.
     * Note that while this function emits an Approval event, this is not required as per the specification,
     * and other compliant implementations may not emit the event.
     * @param from address The address which you want to send tokens from
     * @param to address The address which you want to transfer to
     * @param value uint256 the amount of tokens to be transferred
     */

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public returns (bool) {
        _transfer(from, to, value);

        return true;
    }

    /**
     * @dev Transfer token for a specified addresses
     * @param from The address to transfer from.
     * @param to The address to transfer to.
     * @param value The amount to be transferred.
     */

    function _transfer(address from, address to, uint256 value) internal {
        require(to != address(0));

        _balances[from] = _balances[from].sub(value);

        _balances[to] = _balances[to].add(value);

        emit Transfer(from, to, value);
    }

    /**
     * @dev Function to mint tokens
     * @param account The address that will receive the minted tokens.
     * @param value The amount of tokens to mint.
     * @return A boolean that indicates if the operation was successful.
     */

    function mint(address account, uint256 value) public onlyMinter {
        require(account != address(0));

        require(totalSupply().add(value) <= _cap);

        _totalSupply = _totalSupply.add(value);

        _balances[account] = _balances[account].add(value);

        emit Transfer(address(0), account, value);
    }

    /**
     * @return the cap for the token minting.
     */

    function cap() external view returns (uint256) {
        return _cap;
    }

    /**
     * @return the address that can mint tokens.
     */

    function currentMinter() external view returns (address) {
        return _isMinter;
    }

    /**
     * @dev Function to change minter address
     * @param newMinter The address that will be able to mint tokens from now on
     */

    function changeMinter(address newMinter) external onlyMinter {
        _isMinter = newMinter;
    }

    modifier onlyMinter() {
        require(msg.sender == _isMinter);
        _;
    }
}
