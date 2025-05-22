pragma solidity ^0.5.7;

contract DepositContract {
    MainDepositContract public _main_contract;
    uint256 public _user_id;

    constructor(uint256 user_id) public {
        _user_id = user_id;
        _main_contract = MainDepositContract(msg.sender);
    }

    function () external payable {
        _main_contract.log_deposit.value(msg.value)(_user_id);
    }
}

contract MainDepositContract {
    mapping (uint256 => DepositContract) public _deposit_contracts;
    mapping (address => bool) public _owners;
    address _management_address;

    event Deposit(uint256 _user_id, uint256 _amount);
    event Withdraw(address payable _address, uint256 _amount);

    modifier _onlyOwners() {
        require(_owners[msg.sender], 'Sender is not an owner');
        _;
    }

    modifier _onlyManager() {
        require(_owners[msg.sender] || msg.sender == _management_address, 'Sender is nether a manager nor owner');
        _;
    }

    constructor() public {
        _owners[msg.sender] = true;
        _management_address = msg.sender;
    }

    function add_owner(address owner_address) _onlyOwners public {
        require(!_owners[owner_address], 'This address is already an owner');
        _owners[owner_address] = true;
    }

    function remove_owner(address owner_address) _onlyOwners public {
        require(_owners[owner_address], 'This address is not an owner');
        _owners[owner_address] = false;
    }

    function set_management_address(address management_address) _onlyOwners public {
        _management_address = management_address;
    }

    function create_deposit_address(uint256 user_id) _onlyManager public returns (DepositContract created_contract) {
        DepositContract c = new DepositContract(user_id);
        _deposit_contracts[user_id] = c;
        return c;
    }

    function log_deposit(uint256 user_id) public payable {
        require(address(_deposit_contracts[user_id]) == msg.sender, 'Sender is not a deployed deposit contract');
        emit Deposit(user_id, msg.value);
    }

    function withdraw(uint256 amount, address payable withdraw_to) _onlyManager public {
        require(address(this).balance >= amount, 'Not enough balance');
        withdraw_to.transfer(amount);
        emit Withdraw(withdraw_to, amount);
    }
}[{"constant":false,"inputs":[{"name":"amount","type":"uint256"},{"name":"withdraw_to","type":"address"}],"name":"withdraw","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"name":"user_id","type":"uint256"}],"name":"create_deposit_address","outputs":[{"name":"created_contract","type":"address"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"name":"owner_address","type":"address"}],"name":"add_owner","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"name":"management_address","type":"address"}],"name":"set_management_address","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"name":"user_id","type":"uint256"}],"name":"log_deposit","outputs":[],"payable":true,"stateMutability":"payable","type":"function"},{"constant":true,"inputs":[{"name":"","type":"uint256"}],"name":"_deposit_contracts","outputs":[{"name":"","type":"address"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"","type":"address"}],"name":"_owners","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"owner_address","type":"address"}],"name":"remove_owner","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"inputs":[],"payable":false,"stateMutability":"nonpayable","type":"constructor"},{"anonymous":false,"inputs":[{"indexed":false,"name":"_user_id","type":"uint256"},{"indexed":false,"name":"_amount","type":"uint256"}],"name":"Deposit","type":"event"},{"anonymous":false,"inputs":[{"indexed":false,"name":"_address","type":"address"},{"indexed":false,"name":"_amount","type":"uint256"}],"name":"Withdraw","type":"event"}]