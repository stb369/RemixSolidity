// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibAppStorage, AppStorage, IGameToken, ISoulToken} from "./14_DiamondInterfaces.sol";

contract AttackingFacet {
    function attackPlayer(
        address target,
        uint256 damageAmount,
        uint256 energyCost,
        bytes calldata attackData // 防御側が予想する情報
    ) external {
        AppStorage storage s = LibAppStorage.appStorage();
        address player = msg.sender;

        // 1. ダメージトークン保有チェック (自身が貧乏神トークンを持っていたら攻撃不可)
        IGameToken damageToken = IGameToken(s.damageToken);
        require(damageToken.balanceOf(player) == 0, "Attacking: Cannot attack while holding Damage Token.");

        // 2. エネルギー消費
        IGameToken energyToken = IGameToken(s.energyToken);
        require(energyToken.balanceOf(player) >= energyCost, "Attacking: Insufficient Energy Token.");
        
        // Energy Tokenを攻撃元からDiamondコントラクトへ送金し消費
        require(
            energyToken.transferFrom(player, address(this), energyCost), 
            "Attacking: Energy transfer failed."
        );

        // 3. ダメージトークンの送付 (防御側でフックが発動)
        // ERC-777の send 関数を使用
        (bool success, bytes memory returndata) = s.damageToken.call(
            abi.encodeWithSignature(
                "send(address,uint256,bytes)", 
                target, 
                damageAmount, 
                attackData
            )
        );

        // 4. AttackSoulの発行
        // 防御側で transferがrevertされなかった（防御が失敗した）場合、AttackSoulを発行
        // ERC-777のsendが成功しても、防御側でrevertされる可能性があるため、トランザクション全体が失敗しないかを確認する必要があるが、
        // ここではsendコールが成功した（防御側でrevertされなかった）と仮定してSoulを発行する。
        if (success) {
            ISoulToken attackSoul = ISoulToken(s.attackSoulToken);
            uint256 soulAmount = damageAmount / 10; // 例: ダメージ量に応じたSoul量
            attackSoul.mint(player, soulAmount);
        } else {
            // 防御側で revert された場合（防御成功）は Soul 発行なし。
            // 実際にはERC-777のフックでのrevertはトランザクション全体を失敗させるため、
            // 成功・失敗の判定はイベントログの監視や、フックの設計を工夫して行う必要があります。
            // ここでは、`send`が実行されたが内部で失敗した、というケースとして扱う。
            revert("Attacking: Damage Token transfer failed (defense success/other error).");
        }
    }
}