// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
contract Battle {
    
    struct StackStatus {
    uint256 evasion;       // 回避スタック
    uint256 accuracy;      // 命中スタック
    uint256 critical;      // 会心スタック
    uint256 breakPart;     // 部位破壊スタック
    uint256 statusInflict; // 状態異常発生スタック
    uint256 statusClear;   // 状態異常解除スタック
    uint256 dmgCut;        // ダメージカットスタック
    }

    mapping(address => StackStatus) public stacks;
    mapping(address => uint256) public positions; 

    // tokenId -> UniqueContract address
}