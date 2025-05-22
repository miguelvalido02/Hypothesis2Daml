>
 * @dev If you mark a function `nonReentrant`, you should also
 * mark it `external`.
 */
contract ReentrancyGuard {
    /// @dev counter to allow mutex lock with only one SSTORE operation
    uint256 private _guardCounter;

    constructor () internal {
        // The counter starts at one to prevent changing it from zero to a non-zero
        // value, which is a more expensive operation.
        _guardCounter = 1;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _guardCounter += 1;
        uint256 localCounter = _guardCounter;
        _;
        require(localCounter == _guardCounter);
    }
}

// File: contracts/lib/github.com/contract-library/contract-library-0.0.4/contracts/DJTBase.sol

contract DJTBase is Withdrawable, Pausable, ReentrancyGuard {
    using SafeMath for uint256;
}

// File: contracts/ExtensionGatewayV2.sol

contract ExtensionGatewayV2 is OperatorRole, DJTBase {

  ExtensionAsset public extensionAsset;

  event InComingEvent(
    address indexed locker,
    uint256 tokenId,
    uint256 at
  );

  event OutgoingEvent(
      address indexed assetOwner,
      uint256 tokenId,
      uint256 at,
      bytes32 indexed eventHash,
      uint8 eventType
  );

  uint public constant LIMIT = 10;

  mapping(bytes32 => bool) private isPastEvent;

  function transferAllTokensOfGateway(address _newAddress) external onlyOwner {
    uint256 balance = extensionAsset.balanceOf(address(this));

    for (uint256 i=balance; i > 0; i--) {
      uint256 tokenId = extensionAsset.tokenOfOwnerByIndex(address(this), i-1);
      _transferExtensionAsset(address(this), _newAddress, tokenId);
    }
  }

  function setPastEventHash(bytes32 _eventHash, bool _desired) external onlyOperator {
    isPastEvent[_eventHash] = _desired;
  }

  function setExtensionAssetAddress(address _extensionAssetAddress) external onlyOwner {
    extensionAsset = ExtensionAsset(_extensionAssetAddress);
  }

  function depositExtension(uint256 _tokenId) public whenNotPaused() {
    _transferExtensionAsset(msg.sender, address(this), _tokenId);
    emit InComingEvent(msg.sender, _tokenId, block.timestamp);
  }

  function withdrawExtensionWithMint(address _assetOwner, uint256 _tokenId, bytes32 _eventHash) external onlyOperator {
    require(!checkIsPastEvent(_eventHash));
    if (extensionAsset.isAlreadyMinted(_tokenId)) {
      _withdrawExtension(_assetOwner, _tokenId, _eventHash);
    } else {
      _mintExtension(_assetOwner, _tokenId, _eventHash);
    }
    isPastEvent[_eventHash] = true;
  }

  function mintExtension(address _assetOwner, uint256 _tokenId, bytes32 _eventHash) public onlyOperator {
    require(!checkIsPastEvent(_eventHash));
    _mintExtension(_assetOwner, _tokenId, _eventHash);
    isPastEvent[_eventHash] = true;
  }

  function onERC721Received(
    address operator,
    address from,
    uint256 tokenId,
    bytes memory data
  )
  public
  returns(bytes4) { 
    return 0x150b7a02;
  }

  function checkIsPastEvent(bytes32 _eventHash) public view returns (bool) {
    return isPastEvent[_eventHash];
  }
  
  function _transferExtensionAsset(address _from, address _to, uint256 _tokenId) private {
    extensionAsset.safeTransferFrom(
      _from,
      _to,
      _tokenId
    );
  }

  function _withdrawExtension(address _assetOwner, uint256 _tokenId, bytes32 _eventHash) private {
    _transferExtensionAsset(address(this), _assetOwner, _tokenId);
    emit OutgoingEvent(_assetOwner, _tokenId, block.timestamp, _eventHash, 1);
  }

  function _mintExtension(address _assetOwner, uint256 _tokenId, bytes32 _eventHash) private {
    extensionAsset.mintExtensionAsset(_assetOwner, _tokenId);
    emit OutgoingEvent(_assetOwner, _tokenId, block.timestamp, _eventHash, 0);
  }
}