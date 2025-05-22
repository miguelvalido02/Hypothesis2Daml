pragma solidity ^0.4.23;

//0xbfd4c175606ab6e8d1e32d029d8c010a9bf4bd36.sol

// Lucre vesting contract for team members

contract LucreVesting {
    struct Vesting {
        uint256 amount;
        uint256 endTime;
    }

    mapping(address => Vesting) internal vestings;

    function addVesting(
        address _user,
        uint256 _amount,
        uint256 _endTime
    ) public;

    function getVestedAmount(
        address _user
    ) public view returns (uint256 _amount);

    function getVestingEndTime(
        address _user
    ) public view returns (uint256 _endTime);

    function vestingEnded(address _user) public view returns (bool);

    function endVesting(address _user) public;
}

//LucreToken implements the ERC20, ERC223 standard methods

contract LucreToken is LucreVesting {
    string _name = "LUCRE TOKEN";

    uint256 _totalSupply;

    address public contractOwner;

    mapping(address => uint256) balances;

    constructor(uint256 _supply) public {
        contractOwner = msg.sender;
        _totalSupply = _supply * (10 ** 18);
        balances[contractOwner] = _totalSupply;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address _user) public view returns (uint256 balance) {
        return balances[_user];
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) public returns (bool success) {
        require(_value <= balances[_from]);

        require(validateTransferAmount(_from, _value));

        balances[_from] = balances[_from] - _value;

        balances[_to] = balances[_to] + _value;

        return true;
    }

    // Create a vesting entry for the specified user

    function addVesting(
        address _user,
        uint256 _amount,
        uint256 _endTime
    ) public {
        require(contractOwner == _user);
        vestings[_user].amount = _amount;
        vestings[_user].endTime = _endTime;
    }

    // Returns the vested amount for a specified user

    function getVestedAmount(
        address _user
    ) public view returns (uint256 _amount) {
        _amount = vestings[_user].amount;

        return _amount;
    }

    // Returns the vested end time for a specified user

    function getVestingEndTime(
        address _user
    ) public view returns (uint256 _endTime) {
        _endTime = vestings[_user].endTime;

        return _endTime;
    }

    // Checks if the venting period is over for a specified user

    function vestingEnded(address _user) public view returns (bool) {
        if (vestings[_user].endTime <= now) {
            return true;
        } else {
            return false;
        }
    }

    // This function checks the transfer amount against the current balance and vested amount

    // Returns true if transfer amount is smaller than the difference between the balance and vested amount

    function validateTransferAmount(
        address _user,
        uint256 _amount
    ) internal view returns (bool) {
        if (vestingEnded(_user)) {
            return true;
        } else {
            uint256 _vestedAmount = getVestedAmount(_user);

            uint256 _currentBalance = balanceOf(_user);

            uint256 _availableBalance = _currentBalance - _vestedAmount;

            if (_amount <= _availableBalance) {
                return true;
            } else {
                return false;
            }
        }
    }
}
//[{"constant":true,"inputs":[],"name":"name","outputs":[{"name":"","type":"string"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_spender","type":"address"},{"name":"_value","type":"uint256"}],"name":"approve","outputs":[{"name":"success","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[{"name":"_user","type":"address"}],"name":"getVestingEndTime","outputs":[{"name":"_endTime","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"totalSupply","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_from","type":"address"},{"name":"_to","type":"address"},{"name":"_value","type":"uint256"}],"name":"transferFrom","outputs":[{"name":"success","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"decimals","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_value","type":"uint256"}],"name":"burn","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"name":"_user","type":"address"},{"name":"_amount","type":"uint256"},{"name":"_endTime","type":"uint256"}],"name":"addVesting","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"standard","outputs":[{"name":"","type":"string"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_user","type":"address"}],"name":"balanceOf","outputs":[{"name":"balance","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"symbol","outputs":[{"name":"","type":"string"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_to","type":"address"},{"name":"_value","type":"uint256"}],"name":"transfer","outputs":[{"name":"success","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"name":"_to","type":"address"},{"name":"_value","type":"uint256"},{"name":"_data","type":"bytes"}],"name":"transfer","outputs":[{"name":"success","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"name":"_user","type":"address"}],"name":"endVesting","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"contractOwner","outputs":[{"name":"","type":"address"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_user","type":"address"}],"name":"getVestedAmount","outputs":[{"name":"_amount","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_owner","type":"address"},{"name":"_spender","type":"address"}],"name":"allowance","outputs":[{"name":"remaining","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_user","type":"address"}],"name":"vestingEnded","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"view","type":"function"},{"inputs":[{"name":"_supply","type":"uint256"}],"payable":false,"stateMutability":"nonpayable","type":"constructor"},{"payable":false,"stateMutability":"nonpayable","type":"fallback"},{"anonymous":false,"inputs":[{"indexed":true,"name":"_user","type":"address"},{"indexed":false,"name":"_value","type":"uint256"}],"name":"Burn","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"name":"_previousOwner","type":"address"},{"indexed":true,"name":"_newOwner","type":"address"}],"name":"TransferredOwnership","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"name":"_from","type":"address"},{"indexed":true,"name":"_to","type":"address"},{"indexed":false,"name":"_value","type":"uint256"},{"indexed":false,"name":"_data","type":"bytes"}],"name":"Transfer","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"name":"_from","type":"address"},{"indexed":true,"name":"_to","type":"address"},{"indexed":false,"name":"_value","type":"uint256"}],"name":"Transfer","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"name":"_owner","type":"address"},{"indexed":true,"name":"_spender","type":"address"},{"indexed":false,"name":"_value","type":"uint256"}],"name":"Approval","type":"event"}]
