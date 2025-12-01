// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibAppStorage, AppStorage} from "./14_DiamondInterfaces.sol";

contract DiamondInit {
    // Diamond初期設定関数
    function init(
        address _energyToken,
        address _damageToken,
        address _attackSoulToken,
        address _blockSoulToken
    ) public {
        AppStorage storage s = LibAppStorage.appStorage();

        // トークンアドレスをストレージに保存
        s.energyToken = _energyToken;
        s.damageToken = _damageToken;
        s.attackSoulToken = _attackSoulToken;
        s.blockSoulToken = _blockSoulToken;

        // 初期防御コストの設定
        s.baseDefenseCost = 100;

        // ここに他の初期設定（例：攻撃/防御ファセットの初期設定値）を追加可能
    }
}