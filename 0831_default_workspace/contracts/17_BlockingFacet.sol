// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibAppStorage, AppStorage, IGameToken, ISoulToken,  ITokensRecipient} from "./14_DiamondInterfaces.sol";

// CoreBlockingFacetは、DamageTokenがDiamondに送付される際のフックITokensRecipientを実装
contract CoreBlockingFacet is ITokensRecipient {
    
    // (省略: getFacetAddresses の実装。実際はDiamond本体の機能)
    //address constant DIAMOND_ADDRESS = 0xDiamondAddress; // Diamond本体のアドレス

    // ERC-777のフックコールバック関数
    // ダメージトークンが 'to' (defender) に届く直前に呼び出される
    function tokensReceived(
        address operator,
        address from, // attacker
        address to, // defender
        uint256 amount,
        bytes calldata userData, // attackDataとして使用
        bytes calldata operatorData
    ) external override {
        AppStorage storage s = LibAppStorage.appStorage();
        require(msg.sender == s.damageToken, "TokensReceived: Must be called by Damage Token.");
        require(to == address(this), "TokensReceived: Only applies to Diamond storage.");
        
        // 実際の防御対象は 'from' から Damage Token を受け取った 'to' ではなく、
        // Diamond のロジック上で管理されているプレイヤーアドレス（ここでは 'to' を防御対象とする）
        
        // ここで 'to' を防御側のプレイヤーアドレスとして処理を続行
        // ... (省略: attemptBlock のロジックをここに移植または呼び出し)
        
        // 便宜上、外部から呼び出せる attemptBlock 関数を呼び出す形とする
        if (attemptBlock(to, from, userData)) {
            // 防御成功時、attemptBlock 内で revert が実行される
            // ここに到達した場合、何らかの問題が発生
            revert("Block check failed."); 
        }
        
        // revert されなかった場合、transferは続行され、ダメージトークンは to (防御側プレイヤー) に付与される
    }

    // attemptBlock は前回の回答の内容に基づき、ロジックを実行する関数
    function attemptBlock(
        address defender,
        address attacker,
        bytes calldata attackData
    ) internal returns (bool) {
        AppStorage storage s = LibAppStorage.appStorage();

        // 1. コスト計算と防御成功判定の初期化
        int256 totalCost = int256(s.baseDefenseCost);
        bool defenseSuccess = true;

        // 2. Diamondにアタッチされた全ファセットを巡回 (簡略化のため、この部分は省略し、ロジックのみ記載)
        // ... ファセットリスト取得と巡回ロジック ...
        
        // (ここではすべてのファセットの canBlock/getEnergyModifier を呼び出す処理が実行されると仮定)
        defenseSuccess = false;
        totalCost += 100; // 例: ファセットによるコスト増加

        // 3. 最終的な防御処理の実行
        if (defenseSuccess && totalCost > 0) {
            uint256 cost = uint256(totalCost);
            IGameToken energyToken = IGameToken(s.energyToken);
            
            // エネルギー残量チェック
            if (energyToken.balanceOf(defender) >= cost) {
                // エネルギー消費
                require(
                    energyToken.transferFrom(defender, address(this), cost),
                    "Energy consumption failed."
                );
                
                // BlockSoul発行
                ISoulToken blockSoul = ISoulToken(s.blockSoulToken);
                blockSoul.mint(defender, cost / 5); // 例: 消費コストに応じたSoul量
                
                // 防御成功。ERC-777の transfer を阻止するために revert
                revert("Blocked: Energy consumed and transfer reverted.");
            } else {
                // エネルギー不足で防御失敗
                return false;
            }
        }

        // 4. 防御失敗 (抜け穴を突かれた or エネルギー不足以外)
        return false;
    }
}