// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract POATest_V2 is ERC721Enumerable, Ownable {

  using Strings for uint256;
  using Counters for Counters.Counter;

  Counters.Counter private tokenIdCounter;

  string public baseUri = "https://meta.hypercomic.io/nft/";
  uint256 public maxSupply = 1111;
  uint public mintingTimes = 0;

  bytes32 public oglistMerkleRoot;
  bytes32 public whitelistMerkleRoot;
  bytes32 public whitelist2MerkleRoot = 0xc4268e0b519d56c1f0c6a8c751c7c69dffdf3ac647c5ef15d4c8f2dab485125c;

  struct MintInfo {
    string mintTitle;
    uint256 cost;
    uint maxMintAmountPerTx;
    uint256 startTimestamp;
    uint256 endTimestamp;
  }

  mapping(uint => MintInfo) public mintGroups;
  mapping(address => uint) public LastTimeStamp;
  mapping(address => uint[10]) public listMinted;
 
  address public hubAddress = 0x4860E7Cc9902Eb06b73EeBd308fAa7d6588D526C; 
  address minter;
  
  constructor() ERC721("POA TEST", "P.O.A") {
    mintGroups[0] = MintInfo("OG", 0 ether, 2, 1676464200, 1676679461);
    mintGroups[1] = MintInfo("WL", 0 ether, 1, 1676464800, 1676679461);
    mintGroups[2] = MintInfo("WL2", 0 ether, 10, 1676516400, 1676679461);
    mintGroups[3] = MintInfo("PB", 0 ether, 1, 1676538000, 1676679461);
    minter = msg.sender;
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
    _;
  }

  function mint(uint256 _mintAmount, address _receiver) external payable 
    mintCompliance(3, _mintAmount) 
  {
      require(msg.sender == minter, "Only minter");
      require(msg.value >= mintGroups[3].cost * _mintAmount, "Insufficient funds!"); 

      _requesttMint(_receiver, _mintAmount);
  }

  function mintForPublic(uint256 _mintAmount) external payable 
    mintCompliance(3, _mintAmount) 
  {
      require(LastTimeStamp[msg.sender] + 15 < block.timestamp, "Bot is not allowed:");
      require(msg.sender == tx.origin, "Contract is not allowed.");
      require(msg.value >= mintGroups[3].cost * _mintAmount, "Insufficient funds!"); 

      _requesttMint(msg.sender, _mintAmount);
      LastTimeStamp[msg.sender] =  block.timestamp;
  }

  function mintForWhite2(bytes32[] calldata merkleProof, uint256 _mintAmount) external payable 
    isValidMerkleProof(merkleProof, whitelist2MerkleRoot) mintCompliance(2, _mintAmount) 
  {
      require(msg.value >= mintGroups[2].cost * _mintAmount, "Insufficient funds!"); 
      require(listMinted[msg.sender][mintingTimes] < mintGroups[2].maxMintAmountPerTx, "Aleady Minted!");
      
      _requesttMint(msg.sender, _mintAmount);
      listMinted[msg.sender][mintingTimes]++;
  }  

  function mintForWhite(bytes32[] calldata merkleProof, uint256 _mintAmount) external payable 
    isValidMerkleProof(merkleProof, whitelistMerkleRoot) mintCompliance(1, _mintAmount) 
  {
      require(msg.value >= mintGroups[1].cost * _mintAmount, "Insufficient funds!");
      require(listMinted[msg.sender][mintingTimes] < mintGroups[1].maxMintAmountPerTx, "Aleady Minted!");

      _requesttMint(msg.sender, _mintAmount);
      listMinted[msg.sender][mintingTimes]++;
  }  

  function mintForOg(bytes32[] calldata merkleProof, uint256 _mintAmount) external payable
    isValidMerkleProof(merkleProof,oglistMerkleRoot) mintCompliance(0, _mintAmount) 
  {
      require(msg.value >= mintGroups[0].cost * _mintAmount, "Insufficient funds!"); 
      require(listMinted[msg.sender][mintingTimes] < mintGroups[0].maxMintAmountPerTx, "Aleady Minted!");

      _requesttMint(msg.sender, _mintAmount);
      listMinted[msg.sender][mintingTimes]++;
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
  
  function setMintingTimes(uint _times) external onlyOwner {
    mintingTimes = _times;
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
