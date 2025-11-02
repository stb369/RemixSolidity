// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./02_Receipt.sol";

interface IBaseContract {
    function id() external view returns (uint);
    function uniconAddress() external view returns (address);
}

// EIP-165インターフェース。is-a関係を間接的にチェックするために使用。
interface IERC165BimboGummy {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

contract BimboGummy is ERC20, ERC20Permit {

    Receipt private receipt;

    mapping(address => mapping (address => uint8)) private _blackList;

    event ReceiptIssued(
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 receiptTokenId,
        bytes32 txHash
    );


    constructor(address _receiptNFT) ERC20("BimboGummy", "BBGM") ERC20Permit("BimboGummy") {
        //_mint(msg.sender, 1000 * 10 ** decimals());
        require(_receiptNFT != address(0), "Invalid NFT address");
        receipt = Receipt(_receiptNFT);
    }

    event MintBimboGummy(uint256 count);

    event DebugEvent(string text);    


    //function allowance(address owner, address spender) public virtual override returns (uint256){}
    


    function Mint (uint256 count) public payable {
        _mint(msg.sender, count);
        emit MintBimboGummy(count);
    }

    //used for DirectAttack
    function transfer (address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        uint256 _amount = amount;
        if (_amount < 1 ){
            _amount = 1;
        }
        //足りなかったら送れない
        require(balanceOf(owner) >= _amount, "Insufficient balance.");
        //相手のブラックリストに自分が入っている場合も失敗
        require(_blackList[owner][to] == 0, "the tartget address is blacklisted.;");
        require(_blackList[to][owner] == 0, "the owner address is blacklisted.;");
        
        //Burn禁止
        require(to != address(0), "Burn is forbidden.;");
        
        bool success = super.transfer(to,_amount);
        if (success) {
            _mintReceipt(owner,to,1,true);//攻撃者に青レシートを付与
            _mintReceipt(owner,to,1,false);//標的に赤レシートを付与
            _blackList[owner][to] = 1;
            _blackList[to][owner] = 2;
        }
        return success;
    }
    
    

    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        //_;
        bool success = super.transferFrom(from, to, amount);
        if (success) {
            _mintReceipt(from, to, 1,true);
            _mintReceipt(from,to,1,false);
        }
        return success;
    }

    function getBlackList(address from , address to) public view returns (uint8,uint8) {
        
        return (_blackList[from][to],_blackList[to][from]);

    }
    
    function _mintReceipt(address from, address to, uint256 amount,bool isBlueReceipt) internal {

        bytes32 pseudoTxHash = keccak256(
            abi.encodePacked(from, to, amount, block.timestamp, isBlueReceipt)
        );//各項目をつなげた文字列をbytesに変換してさらにそれを元に256ビットのハッシュ値を作る
        address recipient = from;
        bytes4 BIMBO_GUMMY_INTERFACE_ID = type(IERC165BimboGummy).interfaceId;
        if (IERC165BimboGummy(from).supportsInterface(BIMBO_GUMMY_INTERFACE_ID)) {// fromがユニコンだった場合。青レシートの発行先を持ち主のウォレットアドレスにする
            
            //IBaseContract baseContract = IBaseContract(from);
            //recipient = baseContract.baseContract.id();
        }

        if(!isBlueReceipt){
            recipient = to;
        }
        emit ReceiptIssued(from, to, amount, 0, pseudoTxHash);

        receipt.mint(//ここでReceiptを発行
            recipient,  // NFT を受け取るのはトークン送信者
            from,
            to,
            amount,
            balanceOf(from),//balanceOfFrom,
            balanceOf(to),//balanceOfTo,
            pseudoTxHash,
            isBlueReceipt
        );
    }

    //指定したユーザーが持ってるレシートの量を取得する
    function receiptBalanceOf(address user) public view returns (uint256) {
        return receipt.balanceOf(user); // ✅ 問題なく動作する
    }
    
    //指定したユーザーが持っているレシートの中から、{tokenId}番目の情報を取得する
    function receiptTokenOfOwnerByIndex(address owner, uint256 tokenId) public view returns (uint256) {
        return receipt.tokenOfOwnerByIndex(owner,tokenId); // ✅ 問題なく動作する
    }


}
