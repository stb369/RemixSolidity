// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.20;
//import "./06_UniqueFactory.sol";

interface IUniqueContract {//UniqueContractからBimboGummyとchatを呼ぶ用
    function mint(uint256 amount) external;
    function transfer(address to, uint256 amount) external;
    function postMessage(bytes32 roomId, string calldata nickname, string calldata content)external;
}

interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

struct Status {
        string name;
        uint8 job;//装備できるアイテムのレパートリーが変わる
        uint8 rightHand;//アクティブorリアクションスキル1→攻撃を行ったときのスキルor攻撃を受けた時のスキル
        uint8 leftHand;//アクティブorリアクションスキル2→攻撃を行ったときのスキルor攻撃を受けた時のスキル
        uint8 head;//状態異常耐久→状況判断
        uint8 body;//ダメージ耐久
        uint8 foot;//移動力
        uint8 accessory;//全般補助
        uint256 equipCode;
    }

contract UniqueContract {

    IUniqueContract public iUniqueContract;
    uint public id;
    address public owner;
    Status private status;

    event Executed (address indexed caller, address indexed target, bytes data) ;

    constructor(uint _id, address _owner) { 
        id = _id; 
        owner = _owner;
    }

    modifier onlyOwner() {
        require(msg.sender == owner,"Error");
        _;
    }

    function setStatus(string memory _name, uint8 _job, uint256 _equipCode)external{
        
    }

    function proxyMint(address _tokenAddress, uint256 _amount) internal onlyOwner {
        //ここで01_BimboGummyのアドレスが要る
        IUniqueContract token = IUniqueContract(_tokenAddress);
        
        
        // mint関数はERC20標準には含まれないため、この例ではコメントアウト
        // ERC20コントラクトがminting機能を実装している場合は、このように呼び出す
        token.mint( _amount);
    } 

    function proxyTransfer(address _tokenAddress, address _to, uint256 _amount) internal {
        //ここで01_BimboGummyのアドレスが要る
        require(_to != owner,"not allow to send to owner");
        IUniqueContract token = IUniqueContract(_tokenAddress);
        token.transfer(_to,_amount);
    }

    function proxyChat (address _contractAddress, string memory _roomName, string memory _name, string memory _content)internal{
        //ここで04_OnChainChatのアドレスが要る

        IUniqueContract chat = IUniqueContract(_contractAddress);
        bytes32 roomId = keccak256(abi.encodePacked(_roomName));
        chat.postMessage(roomId, _name, _content);
    }

    function execute(address target, uint256 value, bytes calldata data) external onlyOwner returns (bytes memory) {
        (bool success, bytes memory ret) = target.call{value: value}(data);
        require(success, "call failed");
        emit Executed(msg.sender, target, data);
        return ret;
    }

}