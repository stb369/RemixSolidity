// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.20;


contract Ranking {

    mapping ( address => PlayerRank ) public playerList;
    mapping ( address => BattleResult) public battleResults;

    //こちらは半永久的に残される情報を保存する
    struct PlayerRank {
        uint256 maxRankScore;//これまでのプレイで最も高いランクスコアを出した時の値を保存する
        uint256 rankNumber;//0~4でD~S
        uint256 playerCurrentWeek;//レシートを発行した時にゲームのCWとこの値が違っていたら、BattleResultをまとめ処理した後リセットする。その後この値をゲームのCWと等しくする
    }

    //こちらはCWの更新のタイミングでリセットされる情報を保存する
    struct BattleResult {
        uint256 rankScore;
        uint256 chainCode; //現CW中に発行されたレシートの種類と価値を記録する。最大78枚
        uint256 lastBlueUpdate;//最後に青レシートを発行した日時
        
    }

    uint256 currentWeek = 1;

    constructor() {
    }

    event e_ResetBattleResult(uint256 count);
    event e_UpdateBattleResult(uint256 count);
    
    function setPlayerList (address _walletAddress , uint256 _maxRankScore, uint256 _rankNumber) private{
        PlayerRank memory player = PlayerRank ({
            maxRankScore : _maxRankScore,
            rankNumber : _rankNumber,
            playerCurrentWeek : block.timestamp / 1 weeks
        });
        playerList[_walletAddress] = player;
    }

    function getPlayerRank (address _walletAddress) public view returns (uint256) {
        uint256 rankNumber = playerList[_walletAddress].rankNumber;
        return rankNumber;
    }

    //receiptのmintからこれを呼び、↓にある関数をここから実行する
    //各関数でいちいちbattleResults[_walletAddress]して値を取得するより、ここでまずstructごと取得してそれを各関数の引数に入れた方がガス安いんじゃね？
    //第２引数は青レシートなら標的のランクが、赤レシートなら攻撃者のランク+5が入る
    function updateBattleResult (address _walletAddress, uint256 _code) external{
        PlayerRank storage _playerRank = playerList[_walletAddress];
        BattleResult storage _battleResult = battleResults[_walletAddress];
        uint256 code = _code;
        if (code < 1){
            code = 1;
        }
        if (code < 5){//青レシートの場合、かつCWリセットがされていない場合
            bool isReset = checkReset(_playerRank, _battleResult);
            if (!isReset){
                checkGreenReceipt(_battleResult);
                
            }
        }
        addRankScore(_battleResult,code,1);
        addChainCode(_battleResult, code);
        updateRankNumber(_playerRank, _battleResult);
    }

    function checkReset (PlayerRank storage _playerRank, BattleResult storage _battleResult) private returns (bool) {
        uint currentRankScore = _battleResult.rankScore;
        uint256 playerCurrentWeek = _playerRank.playerCurrentWeek;
        bool isReset = ((block.timestamp /1 weeks) - playerCurrentWeek > 0);
        if(isReset){//CWが更新されているため、BattleResultはリセット。現在の予想だと最初の攻撃成功(登録を伴う)の時もtrueになるはず
            
            emit e_ResetBattleResult(currentRankScore);
            _battleResult.rankScore = 0;
            _battleResult.chainCode = 0;
            _battleResult.lastBlueUpdate = block.timestamp;
            _playerRank.playerCurrentWeek = block.timestamp / 1 weeks;
        }
        return isReset;
    }

    //返り値は反映後のchainCode。青レシート発行の時かつリセットされてない時のみ呼ばれる
    function checkGreenReceipt (BattleResult storage _battleResult) private{
        uint256 lastBlueUpdate = _battleResult.lastBlueUpdate;
        uint256 currentTime = block.timestamp;
        uint256 diffTime = (currentTime - lastBlueUpdate)/ 1 days;//何日分の空きがあるかを取得
        uint256 chainCode = _battleResult.chainCode;
        _battleResult.lastBlueUpdate = currentTime;
        if (diffTime < 1 || lastBlueUpdate < 1) {
            return;
        }
        uint256 shift = 10 ** diffTime; 
        uint greenCode = 5*(shift - 1)/9;
        chainCode = chainCode * shift + greenCode;
        _battleResult.chainCode = chainCode;
        addRankScore(_battleResult, 5, diffTime);//diffTimeには1以上の数値が入る
        
        return;

    }

    //02_Receipt.solから呼び出される想定。青と赤だけ
    function addChainCode (BattleResult storage _battleResult , uint256 _code) private returns (uint256){
        uint256 chainCode = _battleResult.chainCode;
        chainCode = chainCode * 10 +_code;
        _battleResult.chainCode = chainCode;
        return chainCode;
    }

    function updateRankNumber(PlayerRank storage _playerRank, BattleResult storage _battleResult)private{
        uint currentRankScore = _battleResult.rankScore;
        if(_playerRank.maxRankScore < currentRankScore){
                
            _playerRank.maxRankScore = currentRankScore;
            _playerRank.rankNumber = getRankNumber(_playerRank.maxRankScore);
        }
    }
    //02_Receipt.solから呼び出される想定
    //新しくreceiptが発行され、その影響で変動する
    function addRankScore (BattleResult storage _battleResult,uint256 _code, uint256 times) private returns (uint256) {
        uint256 rankScore = _battleResult.rankScore;
        if(_code < 5){//青
            rankScore += _code;

        }else if(_code > 5){//赤
            if(rankScore >= _code){
                rankScore -= _code;
            }else{
                rankScore = 0;
            }
        }else{//緑
            require(times != 0, "times is zero");
            rankScore = rankScore / times;
        }  
        emit e_UpdateBattleResult(rankScore);
        _battleResult.rankScore = rankScore;
        return rankScore;
    }
    //後日このくだらないハードコーディングをやめる方法を考える
    function getRankNumber(uint256 rankScore)public pure returns(uint256){
        if(rankScore >= 25){
            return 4;
        }else if (rankScore >= 15){
            return 3;
        }else if (rankScore >= 5){
            return 2;
        }else if (rankScore >= 1){
            return 1;
        }else{
            return 0;
        }
    }

}