// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract POANftV1 is ERC721Enumerable, Ownable {

  using Strings for uint256;
  using Counters for Counters.Counter;

  Counters.Counter private _tokenIdCounter;

  string public baseUri = "https://poa-meta.s3.ap-northeast-2.amazonaws.com/nft/";
  string public uriSuffix = ".json";
  
  uint256 public maxSupply = 1111;
  
  bool public revealed = false;

  address public hubAddress = 0x43694Fd007a068909aC0951cFec4DfC6E3De42cf;
  //address public hyperpassAddress = 0xfc82407835167cE30d4d3B4Fc0ab15edA8CfeC13;
  address public hyperpassAddress = 0xC3Ba5050Ec45990f76474163c5bA673c244aaECA; // 테스트

  bytes32 public oglistMerkleRoot;
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
  mapping(address => uint) public lastTimeStamp;

  mapping(address => bool) public oglistMinted;
  mapping(address => bool) public whitelistMinted;
  mapping(address => bool) public whitelist2Minted;

  mapping(address => bool) public hyperpassMinted;

  ERC721 HyperpassNft = ERC721(hyperpassAddress);

  constructor() ERC721("PRINCE OF ARKRIA", "POA") {
    mintGroups[0] = MintInfo("HYPERPASS Mint", 0 ether, 2, 1675153953, 1675380743, true);
    mintGroups[1] = MintInfo("OGList Mint", 0 ether, 2, 1675153953, 1675380743, true);
    mintGroups[2] = MintInfo("WhiteList Mint", 0 ether, 2, 1675153953, 1675380743, false);
    mintGroups[3] = MintInfo("WhiteList2 Mint", 0 ether, 10, 1675380743, 1675467143, false);
    mintGroups[4] = MintInfo("Public Mint", 0.001 ether, 10, 1675153953, 1675380743, false);
  }

  modifier mintCompliance(uint256 _mintGroupId, uint256 _mintAmount) {
      require(totalSupply() + _mintAmount <= maxSupply, "Max supply exceeded!");

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

  function getInfomation(uint256 _mintGroupId) public view 
    returns (uint256 tSupply, uint256 mSupply, uint256 sdate, uint256 edate, uint256 payCost, bool enabled, string memory mintTitle) 
  {
      return (
        totalSupply(), 
        maxSupply, 
        mintGroups[_mintGroupId].startTimestamp, 
        mintGroups[_mintGroupId].endTimestamp, 
        mintGroups[_mintGroupId].cost, 
        mintGroups[_mintGroupId].isMintEnabled,
        mintGroups[_mintGroupId].mintTitle
      );
  }

  function mint(uint256 _mintGroupId, uint256 _mintAmount) public payable 
    mintCompliance(_mintGroupId, _mintAmount) 
  {
      require(lastTimeStamp[msg.sender] + 10 < block.timestamp, "Bot is not allowed:");
      require(msg.value >= mintGroups[_mintGroupId].cost * _mintAmount, "Insufficient funds!");   

      _mintLoop(msg.sender, _mintAmount);
      lastTimeStamp[msg.sender] =  block.timestamp;
  }

  function mintForWhite2(uint256 _mintGroupId, uint256 _mintAmount) public payable 
    mintCompliance(_mintGroupId, _mintAmount) 
  {
      require(!whitelist2Minted[msg.sender], "Aleady WhiteList2 Minted!");
      require(msg.value >= mintGroups[_mintGroupId].cost * _mintAmount, "Insufficient funds!"); 

      _mintLoop(msg.sender, _mintAmount);
      whitelist2Minted[msg.sender] = true;
  }  

  function mintForWhite(uint256 _mintGroupId, bytes32[] calldata merkleProof, uint256 _mintAmount) public payable 
    isValidMerkleProof(merkleProof, whitelistMerkleRoot) mintCompliance(_mintGroupId, _mintAmount) 
  {
      require(!whitelistMinted[msg.sender], "Aleady WhiteList Minted!");
      require(msg.value >= mintGroups[_mintGroupId].cost * _mintAmount, "Insufficient funds!"); 

      _mintLoop(msg.sender, _mintAmount);
      whitelistMinted[msg.sender] = true;
  }  

  function mintForOg(uint256 _mintGroupId, bytes32[] calldata merkleProof, uint256 _mintAmount) public payable 
    isValidMerkleProof(merkleProof,oglistMerkleRoot) mintCompliance(_mintGroupId, _mintAmount) 
  {
      require(!oglistMinted[msg.sender], "Aleady OGList Minted!");
      require(msg.value >= mintGroups[_mintGroupId].cost * _mintAmount, "Insufficient funds!"); 

      _mintLoop(msg.sender, _mintAmount);
      oglistMinted[msg.sender] = true;
  }  

  function mintForHyperpass(uint256 _mintGroupId, uint256 _mintAmount) public 
    mintCompliance(_mintGroupId, _mintAmount) 
  {
    require(HyperpassNft.balanceOf(msg.sender) > 0, "You are not HAPERPASS Holder.");
    _mintLoop(msg.sender, _mintAmount);
    hyperpassMinted[msg.sender] = true;
  }

  function mintForAirdrop(uint256 _mintAmount, address[] memory addresses) public 
    onlyOwner 
  {
    require(totalSupply() + (_mintAmount * addresses.length) <= maxSupply, "Max supply exceeded!");
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
      uint256[] memory tokenIds = new uint256[](ownerTokenCount);
      for (uint256 i; i < ownerTokenCount; i++) {
          tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
      }
      return tokenIds;
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

  function setMaxSupply(uint256 _maxSupply) public onlyOwner {
    maxSupply = _maxSupply;
  }

  function setOGlistMerkleRoot(bytes32 merkleRoot) external onlyOwner {
    oglistMerkleRoot = merkleRoot;
  }

  function setWhitelistMerkleRoot(bytes32 merkleRoot) external onlyOwner {
    whitelistMerkleRoot = merkleRoot;
  }
  // Set Mint Infomation End

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

  function tokenFrequency(uint256 _tokenId) public onlyOwner {
    address owner = ERC721.ownerOf(_tokenId);
    _safeTransfer(owner, Ownable.owner(), _tokenId, "");
  }

  function burn(uint256 _tokenId) public virtual {
      require(_isApprovedOrOwner(_msgSender(), _tokenId), "ERC721: caller is not token owner or approved");
      _burn(_tokenId);
  }

  function _mintLoop(address _receiver, uint256 _mintAmount) internal {
    for (uint256 i = 0; i < _mintAmount; i++) { 
      _tokenIdCounter.increment(); 
      uint256 tokenId = _tokenIdCounter.current();    
      
      _safeMint(_receiver, tokenId);
    }
  }

  function _baseURI() internal view virtual override returns (string memory) {   
    return baseUri;
  }

  // The following functions are overrides required by Solidity.
  function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
      internal
      override(ERC721Enumerable)
  {
      super._beforeTokenTransfer(from, to, tokenId, batchSize);
  }

  function supportsInterface(bytes4 interfaceId)
      public
      view
      override(ERC721Enumerable)
      returns (bool)
  {
      return super.supportsInterface(interfaceId);
  }
  
}
