// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "./LootInterface.sol";

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LootMinter is Ownable{
    //General
    address internal APIAddress;
    address lootAddress;
    LootInterface lootInterface;

    mapping(bytes32 => bool) public executed;

    constructor(address _lootAddress, address _APIAddress) {
        APIAddress = _APIAddress;
        lootAddress = _lootAddress;
        lootInterface = LootInterface(lootAddress);
    }

    function setAPIAddress(address _APIAddress) public onlyOwner {
        APIAddress = _APIAddress;
    }

    function getTxHash(
        address _to,
        uint256 _itemId,
        uint256 _nonce
    ) public view returns (bytes32) {
        return keccak256(abi.encodePacked(address(this), _to, _itemId, _nonce));
    }

    function claimLoot(
        address _to,
        uint256 _itemId,
        uint256 _nonce,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) public {
        bytes32 txHash = getTxHash(_to, _itemId, _nonce);

        require(!executed[txHash], "tx executed");
        require(_checkSigs(txHash, _v, _r, _s));

        lootInterface.mint(_to, _itemId);
        executed[txHash] = true;
    }

    function getEthSignedMessageHash(bytes32 _messageHash)
        public
        pure
        returns (bytes32)
    {
        /*
        Signature is produced by signing a keccak256 hash with the following format:
        "\x19Ethereum Signed Message\n" + len(msg) + msg
        */
        return
            keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", _messageHash)
            );
    }

    function _checkSigs(
        bytes32 _txHash,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) private view returns (bool) {
        bytes32 ethSignedHash = getEthSignedMessageHash(_txHash);

        address signer = ecrecover(ethSignedHash, _v, _r, _s);

        if (signer == APIAddress) {
            return true;
        }

        return false;
    }
}
