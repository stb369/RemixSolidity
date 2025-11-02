// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./10_EnvironmentCore.sol";

/// @title EnvironmentDAO (AMM-integrated)
/// @notice DAO要素と流動性プール（a*b=k）を持つ集落を管理
contract EnvironmentDAO is EnvironmentCore {
    uint256 public constant BASEYIELD   = 3;

    struct Pool {
        uint256 tokenIdA;
        uint256 tokenIdB;
        uint256 tokenReserveA;
        uint256 tokenReserveB;
        uint256 k; // 定積（a*b）
        uint256 baseYield;
        bool exists;
    }

    mapping(uint256 => Pool) public pools;  //keyには座標コードが入る。EnvironmentCoreの値と対応させる

    event PoolInitialized(uint256 indexed coordCode, uint256 gavar, uint256 energy);
    event LiquidityAdded(address indexed user, uint256 indexed coordCode, uint256 gavar, uint256 energy);
    event SwapTokens(address indexed user, uint256 indexed coordCode, uint256 poolType, uint256 tokenIn, uint256 tokenOut);

    constructor(string memory baseURI,  address godTicketAddress) EnvironmentCore(baseURI, godTicketAddress) {}

    // ===== 定積AMMの初期化 =====
    function initPool(//指定した座標にspotsがまだない想定
        int256 _x,
        int256 _y,
        uint256 _tokenIdA,
        uint256 _tokenIdB,
        uint256 _tokenAmountA,
        uint256 _tokenAmountB
    ) external {
        uint256 key = encodeCoord(_x, _y);
        require(!pools[key].exists, "Pool exists");
        uint256 poolType = _tokenIdA * 1000 + _tokenIdB;
        uint256 _k = _tokenAmountA * _tokenAmountB;
        createSpot(_x, _y, poolType, _k);
        // 入力資産の移動
        resource.burn(msg.sender, _tokenIdA, _tokenAmountA); //tokenA
        resource.burn(msg.sender, _tokenIdB, _tokenAmountB); //tokenB

        pools[key] = Pool({
            tokenIdA : _tokenIdA,
            tokenIdB : _tokenIdB,
            tokenReserveA: _tokenAmountA,
            tokenReserveB: _tokenAmountB,
            k : _k,
            baseYield : BASEYIELD,
            exists: true
        });
        

        emit PoolInitialized(key, _tokenAmountA, _tokenAmountB);
    }

    // ===== 流動性追加 =====
    function addLiquidity(
        int256 _x,
        int256 _y,
        uint256 _tokenAmountA,
        uint256 _tokenAmountB
    ) external {
        uint256 key = encodeCoord(_x, _y);
        Pool storage p = pools[key];
        require(p.exists, "Pool not found");
        uint256 poolType = spots[key].spotType;
        if(p.tokenReserveA > p.tokenReserveB){//低価値はA
            _tokenAmountB = (p.tokenReserveB * _tokenAmountA) / p.tokenReserveA;
        } else{
            _tokenAmountA = (p.tokenReserveA * _tokenAmountB) / p.tokenReserveB;
        }
        // 比率チェック：既存比率と近い値でないとズレる
        require(
            (p.tokenReserveA * _tokenAmountB) / p.tokenReserveB == _tokenAmountA,
            "Unbalanced liquidity ratio"
        );
        // 入力資産を焼却（LPトークン化は簡略化）
        resource.burn(msg.sender, poolType / 1000, _tokenAmountA);
        resource.burn(msg.sender, poolType % 1000, _tokenAmountB);


        p.tokenReserveA += _tokenAmountA;
        p.tokenReserveB += _tokenAmountB;
        p.k = p.tokenReserveA * p.tokenReserveB;


        emit LiquidityAdded(msg.sender, key, _tokenAmountA, _tokenAmountB);
    }

    // ===== Gavar → Energy スワップ → 汎用に変更==   ===
    function swapTokens(
        int256 x,
        int256 y,
        uint256 tokenId,
        uint256 inTokenAmount
    ) external {
        uint256 key = encodeCoord(x, y);
        Pool storage p = pools[key];
        require(p.exists, "Pool not found");
        require((p.tokenIdA == tokenId)||(p.tokenIdB == tokenId), "Invalid TokenID");
        uint256 inTokenId = 0;
        uint256 outTokenId = 0;
        if (p.tokenIdA == tokenId){
            inTokenId = p.tokenIdA;
            outTokenId = p.tokenIdB;
        }else{
            inTokenId = p.tokenIdB;
            outTokenId = p.tokenIdA;
        }
        uint256 inputAmount = (inTokenAmount * (1000 - p.baseYield)) / 1000; // 手数料0.3%を引いたプールに入れるトークン量
        uint256 newTokenReserveA = p.tokenReserveA + inputAmount; //取引料を含めた新しい貯蔵量
        uint256 newTokenReserveB = p.k / newTokenReserveA; //k一定の法則で、新しいBの貯蔵量を算出
        uint256 outAmount = p.tokenReserveB - newTokenReserveB; //貯蔵量の増減分が出力量

        require(outAmount > 0, "Insufficient output");

        // バーン/ミント address from, uint256 id, uint256 amount
        resource.burn(msg.sender, inTokenId, inputAmount);
        resource.mint(msg.sender, outTokenId , outAmount);

        p.tokenReserveA = newTokenReserveA;
        p.tokenReserveB = newTokenReserveB;

        emit SwapTokens(msg.sender, key, p.tokenIdA * 10 + p.tokenIdB, inputAmount, outAmount);
        //address indexed user, uint256 indexed coordCode, uint256 poolType, uint256 tokenIn, uint256 tokenOut
    }

    function getSpot (int256 x, int256 y) view override public returns(string memory){
        uint256 key = encodeCoord(x, y);
        Pool memory p = pools[key];
        require(p.exists, "Pool does not exist");

        string memory json = string.concat(
            "{",
                "\"key\": ", Strings.toString(key), ",",
                "\"tokenIdA\": ", Strings.toString(p.tokenIdA), ",",
                "\"tokenIdB\": ", Strings.toString(p.tokenIdB), ",",
                "\"tokenReserveA\": ", Strings.toString(p.tokenReserveA), ",",
                "\"tokenReserveB\": ", Strings.toString(p.tokenReserveB), ",",
                "\"k\": ", Strings.toString(p.k), ",",
                "\"exists\": ", p.exists ? "true" : "false",
            "}"
        );

        return json;
    }

    /// @notice GodTicketを1枚burnしないと実行できないmint
    function resetPool(int x, int y) external {
        // --- 1️⃣ GodTicketを持っているかチェック ---
        require(godTicket.balanceOf(msg.sender) >= 1, "Need at least 1 GodTicket");

        // --- 2️⃣ GodTicketをburn ---
        // GodTicketコントラクト側にburnFromの権限を与えておく必要あり
        godTicket.burnFrom(msg.sender, 1);

        // --- 3️⃣ 指定されたプールの資源トークン量を平らにならす(合計値を二等分して分配する) ---
        uint256 key = encodeCoord(x, y);
        Pool storage p = pools[key];
        uint256 tokenAverage = (p.tokenReserveA + p.tokenReserveB) / 2;
        p.tokenReserveA = tokenAverage;
        p.tokenReserveB = tokenAverage;
        p.k = p.tokenReserveA * p.tokenReserveB;
    }
    
}
