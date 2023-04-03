// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
//import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract POAMinterTest is Ownable {

    event RequestMint(address indexed account, uint256 amount, uint256 cost);

    using Counters for Counters.Counter;

    Counters.Counter private mintIdCounter;

    uint256 public maxSupply = 30;
    uint256 public startSupply = 10;
    uint public mintingTimes = 0;

    bytes32 public oglistMerkleRoot;
    bytes32 public whitelistMerkleRoot;
    bytes32 public whitelist2MerkleRoot = 0xc4268e0b519d56c1f0c6a8c751c7c69dffdf3ac647c5ef15d4c8f2dab485125c;

    struct MintInfo {
    uint256 cost;
    uint maxMintAmountPerTx;
    uint256 startTimestamp;
    uint256 endTimestamp;
    }

    mapping(uint => MintInfo) public mintGroups;
    mapping(address => uint) public LastTimeStamp;
    mapping(address => uint[10]) public listMinted;

    address public hubAddress = 0x4860E7Cc9902Eb06b73EeBd308fAa7d6588D526C;
    address public fromAddress;

    IERC721 POANft = IERC721(0x75F509A4eDA030470272DfBAf99A47D587E76709);
    IERC20 HYCOToken = IERC20(0x35973aa36974eaEB162bddFB90B1581948c140C3);
  
    constructor(address _fromAddress) {
        mintGroups[0] = MintInfo(0 ether, 2, 1676464200, 1676679461);
        mintGroups[1] = MintInfo(0 ether, 1, 1676464800, 1676679461);
        mintGroups[2] = MintInfo(0 ether, 2, 1676516400, 1678405362);
        mintGroups[3] = MintInfo(0 ether, 5, 1676538000, 1678405362);
        fromAddress = _fromAddress;
        //maxSupply = POANft.totalSupply();
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

  function requestForPublic(uint256 _mintAmount) external payable 
    mintCompliance(3, _mintAmount) 
  {
        require(LastTimeStamp[msg.sender] + 15 < block.timestamp, "Bot is not allowed:");
        
        _requestTransfer(3, msg.sender, _mintAmount);

        emit RequestMint(msg.sender, _mintAmount, mintGroups[3].cost);
  }

  function requestForWhite2(bytes32[] calldata merkleProof, uint256 _mintAmount) external payable 
    isValidMerkleProof(merkleProof, whitelist2MerkleRoot) mintCompliance(2, _mintAmount) 
  {
        require(listMinted[msg.sender][mintingTimes] < mintGroups[2].maxMintAmountPerTx, "Aleady Minted!");

        _requestTransfer(2, msg.sender, _mintAmount);

        listMinted[msg.sender][mintingTimes]++;

        emit RequestMint(msg.sender, _mintAmount, mintGroups[3].cost);
  }  

  function requestForWhite(bytes32[] calldata merkleProof, uint256 _mintAmount) external payable 
    isValidMerkleProof(merkleProof, whitelistMerkleRoot) mintCompliance(1, _mintAmount) 
  {
        require(listMinted[msg.sender][mintingTimes] < mintGroups[1].maxMintAmountPerTx, "Aleady Minted!");

        _requestTransfer(1, msg.sender, _mintAmount);

        listMinted[msg.sender][mintingTimes]++;

        emit RequestMint(msg.sender, _mintAmount, mintGroups[1].cost);
  }  

  function requestForOg(bytes32[] calldata merkleProof, uint256 _mintAmount) external payable
    isValidMerkleProof(merkleProof,oglistMerkleRoot) mintCompliance(0, _mintAmount) 
  {
        require(listMinted[msg.sender][mintingTimes] < mintGroups[0].maxMintAmountPerTx, "Aleady Minted!");

        _requestTransfer(1, msg.sender, _mintAmount);

        listMinted[msg.sender][mintingTimes]++;

        emit RequestMint(msg.sender, _mintAmount, mintGroups[0].cost);
  }  

  function _requestTransfer (uint _mintGroupId, address _receiver, uint256 _mintAmount) internal {
        //require(msg.value >= mintGroups[3].cost * _mintAmount, "Insufficient funds!"); 
        if (mintGroups[_mintGroupId].cost > 0) {
            require(HYCOToken.balanceOf(_receiver) >= mintGroups[_mintGroupId].cost * _mintAmount, "Not enough balance to complete transaction.");
            require(HYCOToken.allowance(_receiver, address(this)) >= mintGroups[_mintGroupId].cost * _mintAmount, "Not enough allowance to complete transaction.");
        }

        for (uint i = 1; i <= _mintAmount; i++) {
            if (mintGroups[_mintGroupId].cost > 0) {
                HYCOToken.transferFrom(_receiver, address(this), mintGroups[_mintGroupId].cost);
            }
            mintIdCounter.increment();
            POANft.safeTransferFrom(fromAddress, _receiver, startSupply + mintIdCounter.current());
        }
  }

  function totalSupply() public view returns (uint256) {
    return mintIdCounter.current();
  }


  // Set Mint Infomation
  function setMintGroup(uint _mintGroupId, uint256 _mintCost, uint256 _maxMintAmountPerTx, uint256 _startTimestamp, uint256 _endTimestamp) external onlyOwner {
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

  function setStartSupply(uint256 _startSupply) external onlyOwner {
    startSupply = _startSupply;
  }
  // Set Mint Infomation End

  function setErc20Token(address _address) external onlyOwner {
    HYCOToken = IERC20(_address);
  }

  function setErc721Token(address _address) external onlyOwner {
     POANft = IERC721(_address);
  }

  function setHubAddress(address _address) external onlyOwner {
    hubAddress = _address;
  }

  function withdraw() external onlyOwner {
    (bool os, ) = payable(hubAddress).call{value: address(this).balance}("");
    require(os);
  }
 
}
