// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract Loot is ERC721Burnable, ERC721Enumerable, ERC2981, Ownable {
    //VARIABLES

    //General infos
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    string baseURI;
    mapping(address => bool) public gameContracts;

    //Items infos
    struct ItemInfos {
        uint256 supply;
        uint256 maxSupply;
    }
    Counters.Counter private _itemIds;
    mapping(uint256 => ItemInfos) internal items;
    mapping(uint256 => uint256) public tokenToItemId;

    //FUNCTIONS

    //General Infos
    constructor(string memory _baseURI, uint96 _feeNumerator)
        ERC721("TheGarliesLoot", "LOOT")
    {
        baseURI = _baseURI;
        setRoyaltyInfo(owner(), _feeNumerator);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC2981, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function setBaseURI(string calldata _baseURI) public onlyOwner {
        baseURI = _baseURI;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {

        return
            bytes(baseURI).length > 0
                ? string(abi.encodePacked(baseURI,Strings.toString(tokenToItemId[tokenId]),"/",Strings.toString(tokenId)))
                : "";
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        return ERC721Enumerable._beforeTokenTransfer(from,to,tokenId);
    }

    //Royalties

    function setRoyaltyInfo(address _receiver, uint96 _feeNumerator)
        public
        onlyOwner
    {
        _setDefaultRoyalty(_receiver, _feeNumerator);
    }

    //Tokens
    function tokensOfOwner() public view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(msg.sender);
        uint256[] memory tokenList = new uint256[](tokenCount);
        for (uint256 i = 0; i < tokenCount; i++) {
            tokenList[i] = tokenOfOwnerByIndex(msg.sender, i);
        }
        return tokenList;
    }

    //Items
    function getAllItems()
        public
        view
        returns (
            uint256[] memory,
            uint256[] memory,
            uint256[] memory
        )
    {
        uint256 maxItemId = _itemIds.current();
        uint256[] memory idList = new uint256[](maxItemId);
        uint256[] memory supplyList = new uint256[](maxItemId);
        uint256[] memory maxSupplyList = new uint256[](maxItemId);
        for (uint256 i = 0; i < maxItemId; i++) {
            idList[i] = i + 1;
            supplyList[i] = items[i + 1].supply;
            maxSupplyList[i] = items[i + 1].maxSupply;
        }

        return (idList, supplyList, maxSupplyList);
    }

    modifier itemExists(uint256 _itemId) {
        require(_itemId >= 1 && _itemId <= _itemIds.current());
        _;
    }

    function createItem(uint256 maxSupply)
        public
        onlyGameContract(msg.sender)
        returns (uint256)
    {
        _itemIds.increment();

        uint256 newItemId = _itemIds.current();
        items[newItemId] = ItemInfos(0, maxSupply);

        return _itemIds.current();
    }

    function setItem(uint256 _itemId, uint256 _maxSupply)
        public
        onlyGameContract(msg.sender)
        itemExists(_itemId)
    {
        require(_maxSupply >= items[_itemId].supply, "Incorrect max supply.");
        items[_itemId].maxSupply = _maxSupply;
    }

    //Mint
    modifier onlyGameContract(address from) {
        require(gameContracts[from], "Not authorized to mint.");
        _;
    }

    function setGameContract(address _contract, bool status) public onlyOwner {
        gameContracts[_contract] = status;
    }

    function mint(address recipient, uint256 _itemId)
        public
        itemExists(_itemId)
        onlyGameContract(msg.sender)
    {
        require(
            items[_itemId].supply + 1 <= items[_itemId].maxSupply,
            "Maximal supply reached."
        );

        _tokenIds.increment();

        uint256 newTokenId = _tokenIds.current();
        _safeMint(recipient, newTokenId);
        tokenToItemId[newTokenId] = _itemId;
        items[_itemId].supply = items[_itemId].supply + 1;
    }
}
