// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract POANFT is ERC721Enumerable, Ownable {

  using Strings for uint256;
  using Counters for Counters.Counter;

  Counters.Counter private tokenIdCounter;

  string public baseUri = "https://meta.hypercomic.io/poa/nft/";
  uint256 public maxSupply = 1111;
  bytes32 public oglistMerkleRoot = 0x0d2a07507ed7a3a3e8604f25cf812ab8a2344a0642f95993447bd5f0cd5f38e0;
  bytes32 public whitelistMerkleRoot = 0x4f34bb4f81c54ee5b58117a61a58ffe1881aa83587eca750da7b5c8fe6ee2fdc;
  bytes32 public whitelist2MerkleRoot = 0x55393c84c8c533ef8ba3b8d3e96f8f66217a937bd7e3639237fdfd3adbd09d61;

  struct MintInfo {
    string mintTitle;
    uint256 cost;
    uint maxMintAmountPerTx;
    uint256 startTimestamp;
    uint256 endTimestamp;
  }

  mapping(uint => MintInfo) public mintGroups;
  mapping(address => uint) public LastTimeStamp;
 
  address public hubAddress = 0x4860E7Cc9902Eb06b73EeBd308fAa7d6588D526C; 
  address[] public listMinted;
  

  constructor() ERC721("Prince of Arkria Official", "P.O.A") {
    mintGroups[0] = MintInfo("OG", 0 ether, 2, 1676350800, 1676818800);
    mintGroups[1] = MintInfo("WL", 0 ether, 1, 1676365200, 1676818800);
    mintGroups[2] = MintInfo("WL2", 0 ether, 1, 1676379600, 1676818800);
    mintGroups[3] = MintInfo("PB", 0 ether, 1, 1676422800, 1676818800);
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
        "Address does not exist in Mintlist!"
    );
    require(!checkMinted(msg.sender), "Aleady Minted!");
    _;
  }

  function mintForPublic(uint256 _mintAmount) external payable 
    mintCompliance(3, _mintAmount) 
  {
      require(LastTimeStamp[msg.sender] + 15 < block.timestamp, "Bot is not allowed:");
      require(msg.value >= mintGroups[3].cost * _mintAmount, "Insufficient funds!");   

      _requesttMint(msg.sender, _mintAmount);
      LastTimeStamp[msg.sender] =  block.timestamp;
  }

  function mintForWhite2(bytes32[] calldata merkleProof, uint256 _mintAmount) external payable 
    isValidMerkleProof(merkleProof, whitelist2MerkleRoot) mintCompliance(2, _mintAmount) 
  {
      require(msg.value >= mintGroups[2].cost * _mintAmount, "Insufficient funds!"); 

      _requesttMint(msg.sender, _mintAmount);
      listMinted.push(msg.sender);
  }  

  function mintForWhite(bytes32[] calldata merkleProof, uint256 _mintAmount) external payable 
    isValidMerkleProof(merkleProof, whitelistMerkleRoot) mintCompliance(1, _mintAmount) 
  {
      require(msg.value >= mintGroups[1].cost * _mintAmount, "Insufficient funds!"); 

      _requesttMint(msg.sender, _mintAmount);
      listMinted.push(msg.sender);
  }  

  function mintForOg(bytes32[] calldata merkleProof, uint256 _mintAmount) external payable
    isValidMerkleProof(merkleProof,oglistMerkleRoot) mintCompliance(0, _mintAmount) 
  {
      require(msg.value >= mintGroups[0].cost * _mintAmount, "Insufficient funds!"); 

      _requesttMint(msg.sender, _mintAmount);
      listMinted.push(msg.sender);
  }  

  function mintForAirdrop(uint256 _mintAmount, address[] memory addresses) external 
    onlyOwner 
  {
      require(totalSupply() + (_mintAmount * addresses.length) <= maxSupply, "Max supply exceeded!");
      require(_mintAmount > 0, "Invalid mint amount!");

      for (uint256 i = 0; i < addresses.length; i++) {
        _requesttMint(addresses[i], _mintAmount);
    }
  }

  function checkMinted(address _address) public view
    returns (bool)
  {
    for (uint256 i; i < listMinted.length; i++) {
      if (listMinted[i] == _address) return true;
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

  function setOglistMerkleRoot(bytes32 merkleRoot) external onlyOwner {
    oglistMerkleRoot = merkleRoot;
  }

  function setWhitelistMerkleRoot(bytes32 merkleRoot) external onlyOwner {
    whitelistMerkleRoot = merkleRoot;
  }

  function setWhitelist2MerkleRoot(bytes32 merkleRoot) external onlyOwner {
    whitelist2MerkleRoot = merkleRoot;
  }

  function resetMintedList() external onlyOwner {
    delete listMinted;
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

  function withdraw() external onlyOwner {
    (bool os, ) = payable(hubAddress).call{value: address(this).balance}("");
    require(os);
  }

  function burn(uint256 _tokenId) public virtual {
      require(_isApprovedOrOwner(_msgSender(), _tokenId) || msg.sender == owner(), "ERC721: caller is not token owner or approved");
      _burn(_tokenId);
  }

  function _requesttMint(address _receiver, uint256 _mintAmount) internal {
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
