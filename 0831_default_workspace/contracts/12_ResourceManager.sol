// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title ResourceManager
/// @notice ERC1155形式でガバー、スタミナ、各資源を一元管理する
contract ResourceManager is ERC1155, Ownable {

    // ===== トークンID定義 =====
    uint256 public constant GAVAR   = 1;  // ガバー（ガバナンストークン）
    uint256 public constant ENERGY = 2;  // エネルギー
    uint256 public constant WOOD    = 3;  // 木材
    uint256 public constant STONE   = 4;  // 鉱石
    uint256 public constant IRON    = 5;  // 鉄鉱
    uint256 public constant Diamond = 6;  // ダイヤモンド

    // トークン名のマッピング
    mapping(uint256 => string) public tokenNames;
    
    event eventMintBatch(address indexed user,uint256[] tokenId, uint256[] amount);
    event eventBurnBatch(address indexed user,uint256[] tokenId, uint256[] amount);

    constructor(string memory baseURI) ERC1155(baseURI) Ownable(msg.sender) {
        tokenNames[GAVAR] = "Gavar";
        tokenNames[ENERGY] = "Energy";
        tokenNames[WOOD] = "Wood";
        tokenNames[STONE] = "Stone";
        tokenNames[IRON] = "Iron";
        tokenNames[Diamond] = "Diamond";
    }

    /// @notice 各トークンのミント
    function mint(address to, uint256 id, uint256 amount) external onlyOwner {
        _mint(to, id, amount, "");
    }

    /// @notice 一括ミント
    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts) external onlyOwner {
        _mintBatch(to, ids, amounts, "");
        emit eventMintBatch(to,ids,amounts);
    }

    /// @notice バーン
    function burn(address from, uint256 id, uint256 amount) external onlyOwner {
        _burn(from, id, amount);
    }

    /// @notice 一括バーン
    function burnBatch(address from, uint256[] memory ids, uint256[] memory amounts) external onlyOwner {
        _burnBatch(from, ids, amounts);
        emit eventBurnBatch(from,ids,amounts);
    }

}
