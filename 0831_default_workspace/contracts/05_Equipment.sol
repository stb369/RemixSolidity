// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Equipment is ERC1155, Ownable {
    struct EquipmentInfo {
        string name;
        uint8 slot;        // "rightHand", "leftHand", etc.
        uint256 chargeTime;
        uint256 weight;
        uint256 range;
    }

    mapping(uint256 => EquipmentInfo) public equipmentData;

    // コンストラクタで initialOwner を明示
    constructor(address initialOwner) 
        ERC1155("https://game.example/api/item/{id}.json")
        Ownable(initialOwner) 
    {}

    function mint(address to, uint256 id, uint256 amount, bytes memory data) external onlyOwner {
        _mint(to, id, amount, data);
    }

    function setEquipmentData(
        uint256 id,
        string memory name,
        uint8 slot,
        uint256 chargeTime,
        uint256 weight,
        uint256 range
    ) external onlyOwner {
        equipmentData[id] = EquipmentInfo(name, slot, chargeTime, weight, range);
    }
}
