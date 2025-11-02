// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "./03_Ranking.sol";

contract Receipt is ERC721Enumerable {

  //本当の通信記録はこっちに残す
  struct TransferRecord {
    address from;
    address to;
    uint256 amount;
    uint256 timestamp;
    bytes32 txHash;
  }

  //レシートの価値計算に使われる要素はこっちに残す
  struct Parameter {
    uint256 fromReceipt;
    uint256 toReceipt;
    uint256 fromBimboGummy;
    uint256 toBimboGummy;
    uint256 fromRank;
    uint256 toRank;
    uint256 amountBimboGummy;
    bool isBlueReceipt;
  }

  Ranking private ranking;
  //トークンID=>各記録
  mapping (uint256 => TransferRecord) private transferRecords;
  mapping(uint256 => Parameter) private parameters;
  //TransferRecord public transferRecord;

  event DebugEvent(string _text, address _address, bytes32 _txHash);  

  constructor( address _rankingAddress ) ERC721("Receipt", "RCPT") {
    
    require(_rankingAddress != address(0), "Invalid ranking address");
    ranking = Ranking(_rankingAddress);
  }

  function mint (
        address recipient,
        address _from,
        address _to,
        uint256 _amount,
        uint256 _bimboBalanceOfFrom,
        uint256 _bimboBalanceOfTo,
        bytes32 _txHash,
        bool _isBlueReceipt
        
    ) external returns ( uint256 ) {
        uint256 newTokenId = uint256(_txHash);
        emit DebugEvent("recipient address:", recipient, _txHash);
        _mint(recipient, newTokenId);//青レシートの場合はrecipientにfromアドレスが、赤レシートの場合はrecipientにtoアドレスが格納される
        uint256 _fromRank = ranking.getPlayerRank(_from);
        uint256 _toRank = ranking.getPlayerRank(_to);
        transferRecords[newTokenId] = TransferRecord({
            from: _from,
            to: _to,
            amount: _amount,
            timestamp: block.timestamp,
            txHash: _txHash
        });

        parameters[newTokenId] = Parameter({
            fromReceipt: balanceOf(_from),//ここを一週間という期間内に発行されたチケットに限定する
            toReceipt: balanceOf(_to),//ここを一週間という期間内に発行されたチケットに限定する
            fromBimboGummy: _bimboBalanceOfFrom,
            toBimboGummy: _bimboBalanceOfTo,
            fromRank: _fromRank,
            toRank: _toRank,
            amountBimboGummy: 0,
            isBlueReceipt : _isBlueReceipt
        });
        //青レシートか赤レシートかで入る値が変わる
        //青レシートの時…from→toの攻撃でfromに発行されてる。recipient(from)に0~4(toRank)
        //赤レシートの時…from→toの攻撃でtoに発行されている。recipient(to)に6~9(fromRank+5)
        if (_isBlueReceipt){
          ranking.updateBattleResult(recipient,_toRank);//ここの_toRankに
        }else{
          ranking.updateBattleResult(recipient,_fromRank + 5);
        }
        //ここで緑レシートの概念的発行とrecipientのランクスコアの更新を行う

        return newTokenId;
  }

}
