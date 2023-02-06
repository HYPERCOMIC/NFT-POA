// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract POANft is ERC721Enumerable, Ownable {

  using Strings for uint256;
  using Counters for Counters.Counter;

  Counters.Counter private tokenIdCounter;

  string public baseUri = "https://poa-meta.s3.ap-northeast-2.amazonaws.com/nft/";
  uint256 public maxSupply = 1111;
  bytes32 public oglistMerkleRoot;
  bytes32 public whitelistMerkleRoot;

  struct MintInfo {
    string mintTitle;
    uint256 cost;
    uint maxMintAmountPerTx;
    uint256 startTimestamp;
    uint256 endTimestamp;
  }

  mapping(uint => MintInfo) public mintGroups;
 
  address public hubAddress = 0x43694Fd007a068909aC0951cFec4DfC6E3De42cf; 
  address[] public ogMinted;
  address[] public whiteMinted;
  address[] public white2Minted;

  constructor() ERC721("PRINCE OF ARKRIA", "POA") {
    mintGroups[0] = MintInfo("OG", 0 ether, 2, 1675153953, 1675799447);
    mintGroups[1] = MintInfo("WL", 0 ether, 2, 1675153953, 1675799447);
    mintGroups[2] = MintInfo("WL2", 0 ether, 2, 1675380743, 1675799447);
    mintGroups[3] = MintInfo("PB", 0.001 ether, 10, 1675153953, 1675799447);
  }

  modifier mintCompliance(uint _mintGroupId, uint256 _mintAmount) {
    require(totalSupply() + _mintAmount <= maxSupply, "Max supply exceeded!");

    require(_mintAmount > 0 && _mintAmount <= mintGroups[_mintGroupId].maxMintAmountPerTx, "Invalid mint amount!");
    require(mintGroups[_mintGroupId].startTimestamp <= block.timestamp && mintGroups[_mintGroupId].endTimestamp > block.timestamp, "Sales is not yet!");
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

  function getInfomation(uint _mintGroupId) public view 
    returns (uint256 tSupply, uint256 mSupply, uint256 sdate, uint256 edate, uint256 payCost, string memory mintTitle) 
  {
      return (
        totalSupply(), 
        maxSupply, 
        mintGroups[_mintGroupId].startTimestamp, 
        mintGroups[_mintGroupId].endTimestamp, 
        mintGroups[_mintGroupId].cost, 
        mintGroups[_mintGroupId].mintTitle
      );
  }

  function mint(uint _mintGroupId, uint256 _mintAmount) public payable 
    mintCompliance(_mintGroupId, _mintAmount) 
  {
      require(msg.value >= mintGroups[_mintGroupId].cost * _mintAmount, "Insufficient funds!");   

      _mintLoop(msg.sender, _mintAmount);
  }

  function mintForWhite2(uint _mintGroupId, uint256 _mintAmount) public payable 
    mintCompliance(_mintGroupId, _mintAmount) 
  {
      require(!checkMinted(msg.sender, white2Minted), "Aleady WhiteList2 Minted!");
      require(msg.value >= mintGroups[_mintGroupId].cost * _mintAmount, "Insufficient funds!"); 

      _mintLoop(msg.sender, _mintAmount);
      white2Minted.push(msg.sender);
  }  

  function mintForWhite(uint _mintGroupId, bytes32[] calldata merkleProof, uint256 _mintAmount) public payable 
    isValidMerkleProof(merkleProof, whitelistMerkleRoot) mintCompliance(_mintGroupId, _mintAmount) 
  {
      require(!checkMinted(msg.sender, whiteMinted), "Aleady WhiteList Minted!");
      require(msg.value >= mintGroups[_mintGroupId].cost * _mintAmount, "Insufficient funds!"); 

      _mintLoop(msg.sender, _mintAmount);
      whiteMinted.push(msg.sender);
  }  

  function mintForOg(uint _mintGroupId, bytes32[] calldata merkleProof, uint256 _mintAmount) public payable
    isValidMerkleProof(merkleProof,oglistMerkleRoot) mintCompliance(_mintGroupId, _mintAmount) 
  {
      require(!checkMinted(msg.sender, ogMinted), "Aleady OGList Minted!");
      require(msg.value >= mintGroups[_mintGroupId].cost * _mintAmount, "Insufficient funds!"); 

      _mintLoop(msg.sender, _mintAmount);
      ogMinted.push(msg.sender);
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

  function checkMinted(address _address, address[] memory _mintedList) internal pure
    returns (bool)
  {
    for (uint256 i; i < _mintedList.length; i++) {
      if (_mintedList[i] == _address) return true;
    }
    return false;
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
  function setMintGroup(uint _mintGroupId, string memory _mintTitle, uint256 _mintCost, uint256 _maxMintAmountPerTx, uint256 _startTimestamp, uint256 _endTimestamp) external onlyOwner {
      mintGroups[_mintGroupId].mintTitle = _mintTitle;
      mintGroups[_mintGroupId].cost = _mintCost;
      mintGroups[_mintGroupId].maxMintAmountPerTx = _maxMintAmountPerTx;
      mintGroups[_mintGroupId].startTimestamp = _startTimestamp;
      mintGroups[_mintGroupId].endTimestamp = _endTimestamp;
  } 

  function setCost(uint _mintGroupId, uint256 _cost) external onlyOwner {
    mintGroups[_mintGroupId].cost = _cost;
  }

  function setMaxMintAmountPerTx(uint _mintGroupId, uint _maxMintAmountPerTx) external onlyOwner {
     mintGroups[_mintGroupId].maxMintAmountPerTx = _maxMintAmountPerTx;
  }

  function setStartTimestamp(uint _mintGroupId, uint256 _startTimestamp) external onlyOwner {
    mintGroups[_mintGroupId].startTimestamp = _startTimestamp;
  }

  function setEndTimestamp(uint _mintGroupId, uint256 _endTimestamp) external onlyOwner {
    mintGroups[_mintGroupId].endTimestamp = _endTimestamp;
  } 

  function setOGlistMerkleRoot(bytes32 merkleRoot) external onlyOwner {
    oglistMerkleRoot = merkleRoot;
  }

  function setWhitelistMerkleRoot(bytes32 merkleRoot) external onlyOwner {
    whitelistMerkleRoot = merkleRoot;
  }

  function resetMintedList() external onlyOwner {
    delete ogMinted;
    delete whiteMinted;
    delete white2Minted;
  }

  function setMaxSupply(uint256 _maxSupply) external onlyOwner {
    maxSupply = _maxSupply;
  }
  // Set Mint Infomation End

  function setBaseUri(string memory _baseUri) external onlyOwner {
    baseUri = _baseUri;
  }

  function setHubAddress(address _address) external onlyOwner {
    hubAddress = _address;
  }

  function withdraw() public onlyOwner {
    (bool os, ) = payable(hubAddress).call{value: address(this).balance}("");
    require(os);
  }

  function burn(uint256 _tokenId) public virtual {
      require(_isApprovedOrOwner(_msgSender(), _tokenId), "ERC721: caller is not token owner or approved");
      _burn(_tokenId);
  }

  function _mintLoop(address _receiver, uint256 _mintAmount) internal {
    for (uint256 i = 0; i < _mintAmount; i++) { 
      tokenIdCounter.increment(); 
      _safeMint(_receiver, tokenIdCounter.current());
    }
  }

  function _baseURI() internal view virtual override returns (string memory) {   
    return baseUri;
  }

  // The following functions are overrides required by Solidity.
  function supportsInterface(bytes4 interfaceId)
      public
      view
      override(ERC721Enumerable)
      returns (bool)
  {
      return super.supportsInterface(interfaceId);
  }
  
}
