pragma solidity ^0.5.3;

interface Token {
  function transfer( address to, uint amount ) external;
  function transferFrom( address from, address to, uint amount ) external;
}

interface Membership {
  function isMember( address pusher ) external returns (bool);
}

contract Owned
{
  address payable public owner;
  constructor() public { owner = msg.sender; }

  function changeOwner( address payable newOwner ) isOwner public {
    owner = newOwner;
  }

  modifier isOwner {
    require( msg.sender == owner );
    _;
  }
}

contract Publisher is Owned
{
  event Published( string indexed receiverpubkey,
                   string ipfshash,
                   string redmeta );

  Membership public membership;

  address payable public treasury;
  uint256 public fee;
  uint256 dao;

  uint256 public tokenFee;
  Token   public token;

  constructor() public {
    dao = uint256(100);
  }

  function setFee( uint256 _fee ) isOwner public {
    fee = _fee;
  }

  function setDao( uint256 _dao ) isOwner public {
    dao = _dao;
  }

  function setTreasury( address payable _treasury ) isOwner public {
    treasury = _treasury;
  }

  function setMembership( address _contract ) isOwner public {
    membership = Membership(_contract);
  }

  function setTokenFee( uint256 _fee ) isOwner public {
    tokenFee = _fee;
  }

  function setToken( address _token ) isOwner public {
    token = Token(_token);
  }

  function publish( string memory receiverpubkey,
                    string memory ipfshash,
                    string memory redmeta ) payable public {

    require(    msg.value >= fee
             && membership.isMember(msg.sender) );

    if (treasury != address(0))
      treasury.transfer( msg.value - msg.value / dao );

    emit Published( receiverpubkey, ipfshash, redmeta );
  }

  function publish_t( string memory receiverpubkey,
                      string memory ipfshash,
                      string memory redmeta ) public {

    require( membership.isMember(msg.sender) );

    token.transferFrom( msg.sender, address(this), tokenFee );

    if (treasury != address(0)) {
      token.transfer( treasury, tokenFee - tokenFee/dao );
    }

    emit Published( receiverpubkey, ipfshash, redmeta );
  }

  function withdraw( uint256 amount ) isOwner public {
    owner.transfer( amount );
  }

  function sendTok( address _tok, address _to, uint256 _qty ) isOwner public {
    Token(_tok).transfer( _to, _qty );
  }
}[{"constant":false,"inputs":[{"name":"_token","type":"address"}],"name":"setToken","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"name":"amount","type":"uint256"}],"name":"withdraw","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"name":"_fee","type":"uint256"}],"name":"setTokenFee","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"tokenFee","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_contract","type":"address"}],"name":"setMembership","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"name":"_tok","type":"address"},{"name":"_to","type":"address"},{"name":"_qty","type":"uint256"}],"name":"sendTok","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"treasury","outputs":[{"name":"","type":"address"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_fee","type":"uint256"}],"name":"setFee","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"name":"receiverpubkey","type":"string"},{"name":"ipfshash","type":"string"},{"name":"redmeta","type":"string"}],"name":"publish","outputs":[],"payable":true,"stateMutability":"payable","type":"function"},{"constant":false,"inputs":[{"name":"_dao","type":"uint256"}],"name":"setDao","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"owner","outputs":[{"name":"","type":"address"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"membership","outputs":[{"name":"","type":"address"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"newOwner","type":"address"}],"name":"changeOwner","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"name":"receiverpubkey","type":"string"},{"name":"ipfshash","type":"string"},{"name":"redmeta","type":"string"}],"name":"publish_t","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"fee","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_treasury","type":"address"}],"name":"setTreasury","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"token","outputs":[{"name":"","type":"address"}],"payable":false,"stateMutability":"view","type":"function"},{"inputs":[],"payable":false,"stateMutability":"nonpayable","type":"constructor"},{"anonymous":false,"inputs":[{"indexed":true,"name":"receiverpubkey","type":"string"},{"indexed":false,"name":"ipfshash","type":"string"},{"indexed":false,"name":"redmeta","type":"string"}],"name":"Published","type":"event"}]