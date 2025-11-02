// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.20;
import "./07_UniqueContract.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract UniqueFactory is Ownable {

    uint dnaDigits = 16;
    uint dnaModulus = 10 ** dnaDigits;
    uint cooldownTime = 1 days;
    
    constructor(address initialOwner) 
        Ownable(initialOwner) 
    {}
    //Unicon[] public unicons;
    UniqueContract[] public uniqueContracts;
    mapping(address => address[]) public userContracts; // owner => list of unique contracts
    //UniqueNFT public nft; // optional registry

    //event UniqueContractCreated(address indexed owner, address indexed contractAddress, bytes32 salt, uint256 tokenId);
    event UniqueContractCreated(
        bytes32 indexed roomId,     //ユニコンのアドレスの値。だが、ここにsaltが入る？
        uint256 indexed chatId,     //レス番。不要そうだがユーザーがバージョンを確認する際に使うのかも
        bytes32 indexed senderHash, //keccak256(ownerAddress)を入れる。chatIdやsenderHashでフィルタリングすると他者のここの値が見られてしまうため。
        string  nickname,           //ユニコンの名前
        string  content,            //ユニコンのコントラクトアドレス
        uint256 timestamp           //そのまま、発行時刻
    );
    //emit MessagePosted(roomId,lastPostId[roomId],keccak256( abi.encodePacked(msg.sender)), nickname, content, block.timestamp);


    function createUnicon(string memory _name, bytes32 salt) public returns(address) {
        
        uint _id = uniqueContracts.length;
        UniqueContract newUnicon = new UniqueContract{salt : salt}(_id, msg.sender);//Unicon(_name,  _dna, 0, 0, 0, 0, 0, 0, 0,0);
        //address(newUnicon)の値がsaltと同値になるってことなのか？要検証。
        address uniconAddress = address(newUnicon);//uniconAddress = salt なのか？
        newUnicon.setStatus(_name,0,0);
        uniqueContracts.push( newUnicon );
        userContracts[msg.sender].push(uniconAddress);
        bytes32 pseudoTxHash = keccak256(
            abi.encodePacked(msg.sender)
        );
        uint256 _version = userContracts[msg.sender].length;
        emit UniqueContractCreated(salt,_version,pseudoTxHash,_name,"new Unicon created.",block.timestamp);

        return uniconAddress;
    }

    function _generateRandomDna(string memory _str) private view returns (uint) {
        uint rand = uint(keccak256(bytes(_str)));
        return rand % dnaModulus;
    }

    function predictAddress(bytes32 salt, address ownerAddr) external view returns (address) {
        bytes memory bytecode = type(UniqueContract).creationCode;
        bytes memory initCode = abi.encodePacked(bytecode, abi.encode(ownerAddr));
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(initCode)));
        return address(uint160(uint256(hash)));
    }

}