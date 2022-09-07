// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./LootInterface.sol";

contract MiniGame is Ownable {
    //VARIABLES

    //General
    address lootAddress;
    LootInterface lootInterface;

    mapping(address => bool) internal gameMasters;

    //Item infos
    enum ItemRarity {
        COMMON,
        RARE,
        MYTHICAL,
        LEGENDARY
    }
    enum ItemSlot {
        WEAPON,
        ARTIFACT,
        POTION,
        INGREDIENT,
        SECONDARY,
        ARMOR
    }
    struct ItemInfos {
        string name;
        ItemRarity rarity;
        ItemSlot slot;
        uint8 dropMode;
    }
    mapping(uint256 => ItemInfos) internal items;

    //Stak
    struct Mode {
        bool valid;
        uint256 duration;
        uint8 itemRate;
    }
    mapping(uint8 => Mode) internal modes;
    mapping(uint8 => ItemSlot) internal classBonus;
    uint256 internal classBonusRate;

    struct StakeInfos {
        bool staking;
        uint8 mode;
        uint8 class;
        uint256 time;
    }
    mapping(address => StakeInfos) internal stakeInfos;

    //Claim
    mapping(ItemRarity => uint8) internal rarityRates;

    struct ClaimedReward {
        bool rewardAvailable;
        uint256 itemId;
        uint256 expirationTime;
    }
    mapping(address => ClaimedReward) internal claimedRewards;
    uint256 nonce = 0;

    //FUNCTIONS

    //General
    constructor(
        address _lootAddress,
        uint8[] memory _rarityRates,
        uint256[] memory _durations,
        uint8[] memory _rates,
        ItemSlot[] memory _classBonus,
        uint256 _classBonusRate
    ) {
        require(
            _durations.length == _rates.length,
            "Incorrect constructor parameters."
        );
        require(_rarityRates.length == 4, "Incorrect constructor parameters.");
        require(_classBonus.length == 6, "Incorrect constructor parameters.");
        gameMasters[address(this)] = true;
        gameMasters[owner()] = true;

        lootAddress = _lootAddress;
        lootInterface = LootInterface(lootAddress);
        for (uint8 i = 0; i < _durations.length; i++) {
            modes[i] = Mode(true, _durations[i] * 1 hours, _rates[i]);
        }
        for (uint8 i = 0; i < _classBonus.length; i++) {
            classBonus[i] = _classBonus[i];
        }
        classBonusRate = _classBonusRate;
        rarityRates[ItemRarity.COMMON] = _rarityRates[0];
        rarityRates[ItemRarity.RARE] = _rarityRates[1];
        rarityRates[ItemRarity.MYTHICAL] = _rarityRates[2];
        rarityRates[ItemRarity.LEGENDARY] = _rarityRates[3];
    }

    function setLootAddress(address _lootAddress) public onlyOwner {
        lootAddress = _lootAddress;
        lootInterface = LootInterface(lootAddress);
    }

    function setGameMaster(address _address, bool status) public onlyOwner {
        gameMasters[_address] = status;
    }

    //Items
    modifier onlyGameMaster(address from) {
        require(gameMasters[from], "Require to be game master.");
        _;
    }

    function getAllItems()
        public
        view
        onlyGameMaster(msg.sender)
        returns (
            uint256[] memory,
            uint256[] memory,
            uint256[] memory,
            string[] memory,
            ItemRarity[] memory,
            ItemSlot[] memory,
            uint8[] memory
        )
    {
        return getAllItemsInternal();
    }

    function getAllItemsInternal()
        internal
        view
        returns (
            uint256[] memory,
            uint256[] memory,
            uint256[] memory,
            string[] memory,
            ItemRarity[] memory,
            ItemSlot[] memory,
            uint8[] memory
        )
    {
        (
            uint256[] memory idList,
            uint256[] memory supplyList,
            uint256[] memory maxSupplyList
        ) = lootInterface.getAllItems();
        uint256 itemCount = idList.length;
        string[] memory nameList = new string[](itemCount);
        ItemRarity[] memory rarityList = new ItemRarity[](itemCount);
        ItemSlot[] memory slotList = new ItemSlot[](itemCount);
        uint8[] memory dropModeList = new uint8[](itemCount);
        for (uint256 i = 0; i < itemCount; i++) {
            nameList[i] = items[idList[i]].name;
            rarityList[i] = items[idList[i]].rarity;
            slotList[i] = items[idList[i]].slot;
            dropModeList[i] = items[idList[i]].dropMode;
        }
        return (
            idList,
            supplyList,
            maxSupplyList,
            nameList,
            rarityList,
            slotList,
            dropModeList
        );
    }

    function createItem(
        uint256 maxSupply,
        string memory name,
        ItemRarity rarity,
        ItemSlot slot,
        uint8 dropMode
    ) public onlyGameMaster(msg.sender) {
        require(modes[dropMode].valid, "Non-existent mode.");

        uint256 itemId = lootInterface.createItem(maxSupply);
        items[itemId] = ItemInfos(name, rarity, slot, dropMode);
    }

    function setItem(
        uint256 _itemId,
        uint256 maxSupply,
        string memory name,
        ItemRarity rarity,
        ItemSlot slot,
        uint8 mode
    ) public onlyGameMaster(msg.sender) {
        require(modes[mode].valid, "Non-existent mode.");

        lootInterface.setItem(_itemId, maxSupply);
        items[_itemId].name = name;
        items[_itemId].rarity = rarity;
        items[_itemId].slot = slot;
        items[_itemId].dropMode = mode;
    }

    //Stak
    function getMode(uint8 index)
        public
        view
        onlyGameMaster(msg.sender)
        returns (uint256, uint8)
    {
        require(modes[index].valid, "Non-existent mode.");
        return (modes[index].duration, modes[index].itemRate);
    }

    function setMode(
        uint8 index,
        bool valid,
        uint256 durationHours,
        uint8 itemRate
    ) public onlyGameMaster(msg.sender) {
        modes[index] = Mode(valid, durationHours * 1 hours, itemRate);
    }

    function getClassBonus()
        public
        view
        onlyGameMaster(msg.sender)
        returns (ItemSlot[6] memory)
    {
        return [
            classBonus[0],
            classBonus[1],
            classBonus[2],
            classBonus[3],
            classBonus[4],
            classBonus[5]
        ];
    }

    function setClassBonus(ItemSlot[] calldata _classBonus)
        public
        onlyGameMaster(msg.sender)
    {
        require(_classBonus.length == 6, "Incorrect parameters.");
        for (uint8 i = 0; i < _classBonus.length; i++) {
            classBonus[i] = _classBonus[i];
        }
    }

    function getClassBonusRate()
        public
        view
        onlyGameMaster(msg.sender)
        returns (uint256)
    {
        return classBonusRate;
    }

    function setClassBonusRate(uint256 _rate)
        public
        onlyGameMaster(msg.sender)
    {
        require(_rate >= 0 && _rate <= 100, "Incorrect rate");
        classBonusRate = _rate;
    }

    function getRarityRates()
        public
        view
        onlyGameMaster(msg.sender)
        returns (uint8[4] memory)
    {
        return [
            rarityRates[ItemRarity.COMMON],
            rarityRates[ItemRarity.RARE],
            rarityRates[ItemRarity.MYTHICAL],
            rarityRates[ItemRarity.LEGENDARY]
        ];
    }

    function setRarityRates(uint8[] calldata _rarityRates)
        public
        onlyGameMaster(msg.sender)
    {
        require(_rarityRates.length == 4, "Incorrect parameters.");
        rarityRates[ItemRarity.COMMON] = _rarityRates[0];
        rarityRates[ItemRarity.RARE] = _rarityRates[1];
        rarityRates[ItemRarity.MYTHICAL] = _rarityRates[2];
        rarityRates[ItemRarity.LEGENDARY] = _rarityRates[3];
    }

    function stake(uint8 mode, uint8 class) public {
        require(modes[mode].valid, "Non-existent mode.");
        require(class >= 0 && class <= 5, "Non-existent class");
        require(
            stakeInfos[msg.sender].staking == false,
            "Address already staked."
        );
        stakeInfos[msg.sender] = StakeInfos(
            true,
            mode,
            class,
            block.timestamp + modes[mode].duration
        );
    }

    function getStakeInfos()
        public
        view
        returns (
            bool,
            uint8,
            uint8,
            uint256
        )
    {
        return (
            stakeInfos[msg.sender].staking,
            stakeInfos[msg.sender].mode,
            stakeInfos[msg.sender].class,
            stakeInfos[msg.sender].time
        );
    }

    //Claim
    modifier isReadyToClaim(address _address) {
        require(stakeInfos[_address].staking, "No record for this address.");
        require(
            stakeInfos[_address].time <= block.timestamp,
            "Staking time not up yet."
        );
        _;
    }

    function getClaimInfos()
        public
        view
        returns (
            bool,
            uint256,
            uint256
        )
    {
        return (
            claimedRewards[msg.sender].rewardAvailable,
            claimedRewards[msg.sender].itemId,
            claimedRewards[msg.sender].expirationTime
        );
    }

    function claim() public isReadyToClaim(msg.sender) {
        stakeInfos[msg.sender].staking = false;

        uint256 rewardId = computeReward(msg.sender);

        claimedRewards[msg.sender] = ClaimedReward(
            true,
            rewardId,
            block.timestamp + 1 hours
        );
    }

    function getReward() public view mintReady(msg.sender) returns (uint256) {
        return claimedRewards[msg.sender].itemId;
    }

    //Return the id of the item won and 0 if no item was won
    function computeReward(address _address) internal returns (uint256) {
        uint8 rate = modes[stakeInfos[_address].mode].itemRate;

        uint256 randomNumber = random(100);

        if (randomNumber + 1 <= rate) {
            //An item is won

            randomNumber = random(100);

            if (randomNumber + 1 <= rarityRates[ItemRarity.COMMON]) {
                return
                    pickReward(
                        ItemRarity.COMMON,
                        stakeInfos[_address].mode,
                        stakeInfos[_address].class
                    );
            }
            randomNumber = randomNumber - rarityRates[ItemRarity.COMMON];
            if (randomNumber + 1 <= rarityRates[ItemRarity.RARE]) {
                return
                    pickReward(
                        ItemRarity.RARE,
                        stakeInfos[_address].mode,
                        stakeInfos[_address].class
                    );
            }
            randomNumber = randomNumber - rarityRates[ItemRarity.RARE];
            if (randomNumber + 1 <= rarityRates[ItemRarity.MYTHICAL]) {
                return
                    pickReward(
                        ItemRarity.MYTHICAL,
                        stakeInfos[_address].mode,
                        stakeInfos[_address].class
                    );
            }
            randomNumber = randomNumber - rarityRates[ItemRarity.MYTHICAL];
            if (randomNumber + 1 <= rarityRates[ItemRarity.LEGENDARY]) {
                return
                    pickReward(
                        ItemRarity.LEGENDARY,
                        stakeInfos[_address].mode,
                        stakeInfos[_address].class
                    );
            }
        }
        return 0;
    }

    function pickReward(
        ItemRarity rarity,
        uint8 mode,
        uint8 class
    ) internal returns (uint256) {
        (
            uint256[] memory idList,
            uint256[] memory supplyList,
            uint256[] memory maxSupplyList,
            ,
            ItemRarity[] memory rarityList,
            ItemSlot[] memory slotList,
            uint8[] memory dropModeList
        ) = getAllItemsInternal();

        uint256 randomNumber = random(100);

        if (randomNumber + 1 < classBonusRate) {
            //Class bonus activated
            uint256[] memory classCandidates = new uint256[](idList.length);
            uint256 classCandidatesCount = 0;

            for (uint256 i = 0; i < idList.length; i++) {
                if (
                    rarityList[i] == rarity &&
                    supplyList[i] < maxSupplyList[i] &&
                    dropModeList[i] == mode &&
                    slotList[i] == classBonus[class]
                ) {
                    classCandidates[classCandidatesCount] = idList[i];
                    classCandidatesCount += 1;
                }
            }

            if (classCandidatesCount != 0) {
                randomNumber = random(classCandidatesCount);
                return classCandidates[randomNumber];
            }
        }

        uint256[] memory candidates = new uint256[](idList.length);
        uint256 candidatesCount = 0;

        for (uint256 i = 0; i < idList.length; i++) {
            if (
                rarityList[i] == rarity &&
                supplyList[i] < maxSupplyList[i] &&
                dropModeList[i] == mode
            ) {
                candidates[candidatesCount] = idList[i];
                candidatesCount += 1;
            }
        }
        //Return 0 if all items have reached their max supply
        if (candidatesCount == 0) {
            return 0;
        }

        randomNumber = random(candidatesCount);
        return candidates[randomNumber];
    }

    //Generate a random number between 0 and max
    function random(uint256 max) internal returns (uint256) {
        uint256 randomNumber = uint256(
            keccak256(abi.encodePacked(block.timestamp, msg.sender, nonce))
        ) % max;
        nonce++;
        return randomNumber;
    }

    //Mint
    modifier mintReady(address from) {
        require(claimedRewards[from].rewardAvailable, "Unauthorized mint.");
        require(
            claimedRewards[from].expirationTime >= block.timestamp,
            "Unauthorized mint."
        );
        _;
    }

    function mintReward() public mintReady(msg.sender) {
        lootInterface.mint(msg.sender, claimedRewards[msg.sender].itemId);
        claimedRewards[msg.sender].rewardAvailable = false;
    }
}
