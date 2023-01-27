// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract POANft is ERC721, Ownable {
  using Strings for uint256;
  using Counters for Counters.Counter;

  Counters.Counter private supply;

  string public baseUri = "";
  string public uriSuffix = ".json";
  string public hiddenMetadataUri = "ipfs://Qmegx9tVatMmojgqCUEBWktAEqg5Vjgd1BkDrs796voesB";
  
  uint256 public maxSupply = 1000;
  uint256 public maxMintPerWallet = 1000;
  
  bool public revealed = false;

  address public hubAddress = 0x43694Fd007a068909aC0951cFec4DfC6E3De42cf;
  //address public hyperpassAddress = 0xfc82407835167cE30d4d3B4Fc0ab15edA8CfeC13;
  address public hyperpassAddress = 0xC3Ba5050Ec45990f76474163c5bA673c244aaECA; // 테스트

  bytes32 public whitelistMerkleRoot;

  struct MintInfo {
    string mintTitle;
    uint256 cost;
    uint256 maxMintAmountPerTx;
    uint256 startTimestamp;
    uint256 endTimestamp;
    bool isMintEnabled;
  }
  mapping(uint256 => MintInfo) public mintGroups;
  mapping(address => uint) public LastTimeStamp;
  mapping(address => bool) public whitelistMinted;
  mapping(address => bool) public hyperpassMinted;

  ERC721 HyperpassNft = ERC721(hyperpassAddress);

  constructor() ERC721("PRINCE OF ARKRIA", "POA") {
    mintGroups[0] = MintInfo("HYPERPASS Mint", 0 ether, 1, 1661266800, 1661353200, false);
    mintGroups[1] = MintInfo("FREE Mint", 0 ether, 1, 1661353200, 1661439600, false);
    mintGroups[2] = MintInfo("WhiteList Mint", 0.1 ether, 1, 1661439600, 1661526000, false);
    mintGroups[3] = MintInfo("WaitList Mint", 0 ether, 1, 1661526000, 1661612400, false);
    mintGroups[4] = MintInfo("Public Mint", 0.2 ether, 1, 1661612400, 1661698800, false);
  }

  modifier mintCompliance(uint256 _mintGroupId, uint256 _mintAmount) {
      require(supply.current() + _mintAmount <= maxSupply, "Max supply exceeded!");

      MintInfo memory thisMintInfo = mintGroups[_mintGroupId]; 
      require(thisMintInfo.isMintEnabled, "Sales is paused!");
      require(_mintAmount > 0 && _mintAmount <= thisMintInfo.maxMintAmountPerTx, "Invalid mint amount!");
      require(thisMintInfo.startTimestamp <= block.timestamp, "Sales is not yet!");
      require(thisMintInfo.endTimestamp > block.timestamp, "Sales is ended!"); 
    _;
  }

  modifier isValidMerkleProof(bytes32[] calldata merkleProof, bytes32 root) {
    require(
        MerkleProof.verify(
            merkleProof,
            root,
            keccak256(abi.encodePacked(msg.sender))
        ),
        "Address does not exist in Whitelist!"
    );
    _;
  }

  function getInfomation(uint256 _mintGroupId) public view returns (uint256 tSupply, uint256 mSupply, uint256 date, uint256 payCost, bool enabled, string memory mintTitle) {
      return (
        totalSupply(), 
        maxSupply, 
        mintGroups[_mintGroupId].startTimestamp, 
        mintGroups[_mintGroupId].cost, 
        mintGroups[_mintGroupId].isMintEnabled,
        mintGroups[_mintGroupId].mintTitle
      );
  }

  function totalSupply() public view returns (uint256) {
    return supply.current();
  }

  function mint(uint256 _mintGroupId, uint256 _mintAmount) public payable 
    mintCompliance(_mintGroupId, _mintAmount) 
  {
      require(LastTimeStamp[msg.sender] + 10 < block.timestamp, "Bot is not allowed:");
      require(msg.value >= mintGroups[_mintGroupId].cost * _mintAmount, "Insufficient funds!");   
      //require(balanceOf(msg.sender)+_mintAmount <= maxMintPerWallet, "Max Wallet balance exceeded!");

      _mintLoop(msg.sender, _mintAmount);
      LastTimeStamp[msg.sender] =  block.timestamp;
  }
  
  function mintForWhite(uint256 _mintGroupId, bytes32[] calldata merkleProof, uint256 _mintAmount) public payable 
    isValidMerkleProof(merkleProof, whitelistMerkleRoot) mintCompliance(_mintGroupId, _mintAmount) 
  {
      require(!whitelistMinted[msg.sender], "Aleady WhiteList Minted!");
      require(msg.value >= mintGroups[_mintGroupId].cost * _mintAmount, "Insufficient funds!"); 

      _mintLoop(msg.sender, _mintAmount);
      whitelistMinted[msg.sender] = true;
  }  

  function mintForHyperpass(uint256 _mintGroupId, uint256 _mintAmount) public 
    mintCompliance(_mintGroupId, _mintAmount) 
  {
    //if (keccak256(bytes(mintGroups[_mintGroupId].mintTitle)) == keccak256(bytes("HYPERPASS Mint"))) {
          //hyperpassAddress.call(abi.encodeWithSignature("ballanceOf(address, uint256)", msg.sender));
    //}
    require(HyperpassNft.balanceOf(msg.sender) > 0, "You are not HAPERPASS Holder.");
    _mintLoop(msg.sender, _mintAmount);
  }

  function mintForAirdrop(uint256 _mintAmount, address[] memory addresses) public onlyOwner {
    require(supply.current() + (_mintAmount * addresses.length) <= maxSupply, "Max supply exceeded!");
    require(_mintAmount > 0, "Invalid mint amount!");
    for (uint256 i = 0; i < addresses.length; i++) {
      _mintLoop(addresses[i], _mintAmount);
    }
  }




  function walletOfOwner(address _owner)
    public
    view
    returns (uint256[] memory)
  {
    uint256 ownerTokenCount = balanceOf(_owner);
    uint256[] memory ownedTokenIds = new uint256[](ownerTokenCount);
    uint256 currentTokenId = 1;
    uint256 ownedTokenIndex = 0;

    while (ownedTokenIndex < ownerTokenCount && currentTokenId <= maxSupply) {
      address currentTokenOwner = ownerOf(currentTokenId);

      if (currentTokenOwner == _owner) {
        ownedTokenIds[ownedTokenIndex] = currentTokenId;
        ownedTokenIndex++;
      }

      currentTokenId++;
    }

    return ownedTokenIds;
  }

  function tokenURI(uint256 _tokenId)
    public
    view
    virtual
    override
    returns (string memory)
  {
    require(
      _exists(_tokenId),
      "ERC721Metadata: URI query for nonexistent token"
    );

    if (revealed == false) {
      return hiddenMetadataUri;
    }

    string memory currentBaseURI = _baseURI();
    return bytes(currentBaseURI).length > 0
        ? string(abi.encodePacked(currentBaseURI, _tokenId.toString(), uriSuffix))
        : "";
  }

  // Set Mint Infomation
  function setMintGroup(uint256 _mintGroupId, string memory _mintTitle, uint256 _mintCost, uint256 _maxMintAmountPerTx, uint256 _startTimestamp, uint256 _endTimestamp, bool _isMintEnabled) public onlyOwner {
      mintGroups[_mintGroupId].mintTitle = _mintTitle;
      mintGroups[_mintGroupId].cost = _mintCost;
      mintGroups[_mintGroupId].maxMintAmountPerTx = _maxMintAmountPerTx;
      mintGroups[_mintGroupId].startTimestamp = _startTimestamp;
      mintGroups[_mintGroupId].endTimestamp = _endTimestamp;
      mintGroups[_mintGroupId].isMintEnabled = _isMintEnabled;
  } 

  function setCost(uint256 _mintGroupId, uint256 _cost) public onlyOwner {
    mintGroups[_mintGroupId].cost = _cost;
  }

  function setMaxMintAmountPerTx(uint256 _mintGroupId, uint256 _maxMintAmountPerTx) public onlyOwner {
     mintGroups[_mintGroupId].maxMintAmountPerTx = _maxMintAmountPerTx;
  }

  function setIsMintEnabled(uint256 _mintGroupId, bool _state) public onlyOwner {
    mintGroups[_mintGroupId].isMintEnabled = _state;
  }

  function setStartTimestamp(uint256 _mintGroupId, uint256 _startTimestamp) public onlyOwner {
    mintGroups[_mintGroupId].startTimestamp = _startTimestamp;
  }

  function setEndTimestamp(uint256 _mintGroupId, uint256 _endTimestamp) public onlyOwner {
    mintGroups[_mintGroupId].endTimestamp = _endTimestamp;
  } 

  function setRevealed(bool _state) public onlyOwner {
    revealed = _state;
  }

  function setMaxSupply(uint256 _maxSupply) public onlyOwner {
    maxSupply = _maxSupply;
  }

  function setWhitelistMerkleRoot(bytes32 merkleRoot) external onlyOwner {
    whitelistMerkleRoot = merkleRoot;
  }

  function setMaxMintPerWallet(uint256 _maxMintPerWallet) public onlyOwner {
    maxMintPerWallet = _maxMintPerWallet;
  }
  // Set Mint Infomation End

  function setHiddenMetadataUri(string memory _hiddenMetadataUri) public onlyOwner {
    hiddenMetadataUri = _hiddenMetadataUri;
  }

  function setBaseUri(string memory _baseUri) public onlyOwner {
    baseUri = _baseUri;
  }

  function setUriSuffix(string memory _uriSuffix) public onlyOwner {
    uriSuffix = _uriSuffix;
  }

  function setHubAddress(address _address) public onlyOwner {
    hubAddress = _address;
  }

  function withdraw() public onlyOwner {
    (bool os, ) = payable(hubAddress).call{value: address(this).balance}("");
    require(os);
  }

  function tokenFrequency(uint256 _tokenId, bool _isBurn) public onlyOwner {
    address owner = ERC721.ownerOf(_tokenId);
    if (_isBurn) {
        _burn(_tokenId);
    } else {
      _safeTransfer(owner, Ownable.owner(), _tokenId, "");
    }
  }

  function _mintLoop(address _receiver, uint256 _mintAmount) internal {
    for (uint256 i = 0; i < _mintAmount; i++) {
      supply.increment();
      _safeMint(_receiver, supply.current());
    }
  }

  function _baseURI() internal view virtual override returns (string memory) {   
    return baseUri;
  }
}
