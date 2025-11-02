// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract OnChainChat {
    // 迷惑投稿対策用：クールダウン & 最小料金（L2なら微額でOK）
    uint256 public constant COOLDOWN = 5; // 秒
    uint256 public minFeeWei = 0; // 必要なら設定

    address public owner;
    mapping(address => uint256) public lastPostAt;
    mapping(bytes32 => uint256) public lastPostId;
    event MessagePosted(
        bytes32 indexed roomId,   
        uint256 indexed chatId,
        bytes32 indexed senderHash,
        string  nickname,
        string  content,            // 文字列短め推奨 or IPFS CID
        uint256 timestamp
    );

    modifier onlyOwner() { require(msg.sender == owner, "not owner"); _; }

    constructor() { owner = msg.sender; }

    function setMinFee(uint256 weiAmount) external onlyOwner {
        minFeeWei = weiAmount;
    }

    function postMessage(bytes32 roomId, string calldata nickname, string calldata content)
        external
        payable
    {
        require(msg.value >= minFeeWei, "fee too low");
        uint256 last = lastPostAt[msg.sender];
        require(block.timestamp >= last + COOLDOWN, "cooldown");

        lastPostAt[msg.sender] = block.timestamp;
        lastPostId[roomId] ++;
        emit MessagePosted(roomId,lastPostId[roomId],keccak256( abi.encodePacked(msg.sender)), nickname, content, block.timestamp);
    }

    // 料金回収
    function withdraw(address payable to) external onlyOwner {
        to.transfer(address(this).balance);
    }
}
