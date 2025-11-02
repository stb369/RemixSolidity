// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
contract UniqueNFT is ERC721, Ownable {
    // tokenId -> UniqueContract address
    mapping(uint256 => address) public contractOf;

    uint256 private _nextToken;

    constructor(address initialOwner) ERC721("UniqueContractToken", "UCT") Ownable(initialOwner)  {}

    function mintFor(address to, address uniqueContract) external onlyOwner returns (uint256) {
        uint256 tid = _nextToken++;
        _safeMint(to, tid);
        contractOf[tid] = uniqueContract;
        return tid;
    }
}