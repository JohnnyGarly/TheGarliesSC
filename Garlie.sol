// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Garlie is ERC721Enumerable, Ownable {
    //CONTRACT GENERAL INFOS VARIABLES
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    mapping(address => bool) public gameContracts;
    string baseURI;
    enum Generation {
        ORIGINAL,
        ENLIGHTENED,
        BRAVE,
        ORPHANS
    }
    mapping(Generation => uint256) public MAX_SUPPLIES;
    mapping(Generation => uint256) public GENERATION_PRICE;
    uint16 internal giveaways;
    uint8 public constant MAX_PER_SALE_PER_ADDRESS = 5;

    Generation public currentGeneration = Generation.ORIGINAL;

    //SALES RELATED VARIABLES
    bool public pause = false;

    bool public isPrivateSaleOpen = false;
    bool public isPublicSaleOpen = false;

    mapping(address => bool) internal whitelist;
    mapping(address => uint8) internal privateMints;
    mapping(address => uint8) internal publicMints;

    //CONTRACT GENERAL INFOS FUNCTIONS
    constructor(
        string memory _baseURI,
        uint16 _giveaways
    ) ERC721("TheGarlies", "GARLIE") {
        MAX_SUPPLIES[Generation.ORIGINAL] = 222;
        GENERATION_PRICE[Generation.ORIGINAL] = 1500 ether;
        baseURI = _baseURI;
        giveaways = _giveaways;
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
                ? string(abi.encodePacked(baseURI, Strings.toString(tokenId)))
                : "";
    }

    function tokensOfOwner() public view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(msg.sender);
        uint256[] memory tokenList = new uint256[](tokenCount);
        for (uint256 i = 0; i < tokenCount; i++) {
            tokenList[i] = tokenOfOwnerByIndex(msg.sender, i);
        }
        return tokenList;
    }

    function setGiveaways(uint16 count) public onlyOwner {
        giveaways = count;
    }

    function setGeneration(uint16 _generation) public onlyOwner {
        if(_generation == 0){
            currentGeneration = Generation.ORIGINAL;
        } else if (_generation == 1){
            currentGeneration = Generation.ENLIGHTENED;
        } else if (_generation == 2){
            currentGeneration = Generation.BRAVE;
        } else if(_generation == 3){
            currentGeneration = Generation.ORPHANS;
        }
    }

    function setGenerationSupply(uint16 _generation, uint supply) public onlyOwner {
        if(_generation == 0){
            require(MAX_SUPPLIES[Generation.ORIGINAL] >= totalSupply());
            MAX_SUPPLIES[Generation.ORIGINAL] = supply;
        } else if (_generation == 1){
            require(MAX_SUPPLIES[Generation.ENLIGHTENED] >= totalSupply());
            MAX_SUPPLIES[Generation.ENLIGHTENED] = supply;
        } else if (_generation == 2){
            require(MAX_SUPPLIES[Generation.BRAVE] >= totalSupply());
            MAX_SUPPLIES[Generation.BRAVE] = supply;
        } 
    }

    function setGenerationPrice(uint16 _generation, uint price) public onlyOwner {
        if(_generation == 0){
            GENERATION_PRICE[Generation.ORIGINAL] = price;
        } else if (_generation == 1){
            GENERATION_PRICE[Generation.ENLIGHTENED] = price;
        } else if (_generation == 2){
            GENERATION_PRICE[Generation.BRAVE] = price;
        } 
    }

    function isWhiteListed() public view returns (bool) {
        return whitelist[msg.sender];
    } 

    function getPrivateMints() public view returns (uint) {
        return privateMints[msg.sender];
    }

    function getPublicMints() public view returns (uint) {
        return publicMints[msg.sender];
    }

    function withdraw() public onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    //SALES RELATED FUNCTIONS
    function setWhitelist(address[] calldata addresses) public onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            whitelist[addresses[i]] = true;
        }
    }

    function isWhitelisted(address _address) public view onlyOwner returns (bool){
        return whitelist[_address];
    }

    function setPause(bool value) public onlyOwner {
        pause = value;
    }

    function openPrivateSale() public onlyOwner {
        isPublicSaleOpen = false;
        isPrivateSaleOpen = true;
        pause = false;
    }

    function openPublicSale() public onlyOwner {
        isPrivateSaleOpen = false;
        isPublicSaleOpen = true;
        pause = false;
    }

    function closeSale() public onlyOwner {
        isPrivateSaleOpen = false;
        isPublicSaleOpen = false;
        pause = false;
    }

    modifier saleOpen() {
        require(pause == false, "Sales not open");
        require(
            isPrivateSaleOpen == true || isPublicSaleOpen == true,
            "Sales not open"
        );
        _;
    }

    function mintGiveaways(address recipient, uint16 quantity)
        public
        onlyOwner
    {
        require(giveaways > 0, "No more giveaways available.");
        require(
            _tokenIds.current() + quantity <= MAX_SUPPLIES[currentGeneration],
            "Mint limit"
        );

        for (uint256 i = 0; i < quantity; i++) {
            _mintOne(recipient);
            giveaways = giveaways - 1;
        }
    }

    function mint(uint8 quantity) public payable saleOpen {
        require(currentGeneration != Generation.ORPHANS, "Incorrect generation");

        require(
            (_tokenIds.current() + quantity) <=
                (MAX_SUPPLIES[currentGeneration] - giveaways),
            "Mint limit"
        );
        require(quantity <= MAX_PER_SALE_PER_ADDRESS, "Incorrect quantity.");

        require(msg.value == quantity * GENERATION_PRICE[currentGeneration], "Incorrect price.");

        if (isPublicSaleOpen == true) {
            require(
                publicMints[msg.sender] + quantity <= MAX_PER_SALE_PER_ADDRESS,
                "Mint limit for address"
            );
            for (uint256 i = 0; i < quantity; i++) {
                _mintOne(msg.sender);
                publicMints[msg.sender] = publicMints[msg.sender] + 1;
            }
        } else if (isPrivateSaleOpen == true) {
            require(whitelist[msg.sender], "User not whitelisted.");
            require(
                privateMints[msg.sender] + quantity <= MAX_PER_SALE_PER_ADDRESS,
                "Mint limit for address"
            );
            for (uint256 i = 0; i < quantity; i++) {
                _mintOne(msg.sender);
                privateMints[msg.sender] = privateMints[msg.sender] + 1;
            }
        }
    }

    function _mintOne(address recipient) internal {
        _tokenIds.increment();

        uint256 newTokenId = _tokenIds.current();
        _safeMint(recipient, newTokenId);
    }

    modifier onlyGameContract(address from) {
        require(gameContracts[from], "Not authorized to mint.");
        _;
    }

    function setGameContract(address _contract, bool status) public onlyOwner {
        gameContracts[_contract] = status;
    }

    function mintOrphans(address recipient, uint8 quantity) public onlyGameContract(msg.sender){
        require(currentGeneration == Generation.ORPHANS, "Incorrect generation");

        for (uint256 i = 0; i < quantity; i++) {
                _mintOne(recipient);
        }
    }
}