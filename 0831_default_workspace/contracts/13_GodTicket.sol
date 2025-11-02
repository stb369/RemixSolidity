// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title ResourceManager
/// @notice ERC1155形式でガバー、スタミナ、各資源を一元管理する
contract GodTicket is ERC20, ERC20Permit , Ownable{

    constructor() ERC20("GodTicket", "GTCK") ERC20Permit("GodTicket") Ownable(msg.sender) {
        //_mint(msg.sender, 1000 * 10 ** decimals());
    }

    event eventMint(address indexed player, uint256 amount);
    event eventBurn(address indexed player, uint256 amount);

    /// @notice 運営のみが発行可能
    function mint(address to, uint256 amount) external onlyOwner {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
        _mint(to, amount);
        emit eventMint(to,amount);
    }

    /// @notice 所有者が自分のトークンをburn
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
        emit eventBurn(msg.sender,amount);
    }

    /// @notice 他者のトークンをburn（approveが必要）
    function burnFrom(address account, uint256 amount) external {
        _approve(account, msg.sender, amount);//ウォレットアドレスのチケットをEnvironmentが処理する
        //uint256 currentAllowance = allowance(account, msg.sender);
        //require(currentAllowance >= amount, "ERC20: burn amount exceeds allowance");
        _burn(account, amount);
    }       
}
