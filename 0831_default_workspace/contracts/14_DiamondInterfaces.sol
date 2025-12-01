// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// ERC-20/ERC-777の共通インターフェース（ここでは簡略化）
interface IGameToken {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

// Soulトークン（AttackSoul/BlockSoul）のミント機能
interface ISoulToken is IGameToken {
    function mint(address to, uint256 amount) external;
}

// ERC-777 DamageToken フックコールバックインターフェース（CoreBlockingFacetが実装）
interface ITokensRecipient {
    function tokensReceived(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes calldata userData,
        bytes calldata operatorData
    ) external;
}

// Diamondの共有ストレージ構造体
struct AppStorage {
    address energyToken;
    address damageToken;
    address attackSoulToken;
    address blockSoulToken;
    // CoreBlockingFacetが使用する、防御に必要な基本コストなどの設定
    uint256 baseDefenseCost;
    // DiamondCutFacetなどに必要なEIP-2535関連のストレージはここでは省略
}

// AppStorageへのポインタを取得するための関数
library LibAppStorage {
    function appStorage() internal pure returns (AppStorage storage s) {
        assembly {
            // EIP-2535の標準的なストレージスロット（ここでは0x0）
            s.slot := 0x0 
        }
    }
}