// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./12_ResourceManager.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

interface IGodTicket is IERC20 {
    function burnFrom(address account, uint256 amount) external;
}
/// @title EnvironmentCore
/// @notice 森・鉱山での作業、エネルギー回復、資源収穫のロジックを担う
contract EnvironmentCore is Ownable {

    uint256 SCALE = 1_000_000; // X,Yをまとめる係数（座標範囲に応じて設定）。デプロイ時に決めた値から変えてはいけない
    uint256 MovementCost = 1; // １マス移動するのに必要なエネルギー消費量。単位はWeiであることに注意

    uint256 public constant INN     = 1002;  // 宿屋（ガバー↔︎エネルギー）
    uint256 public constant FOREST  = 2003;  // 森(エネルギー↔︎木材)
    uint256 public constant QUARRY  = 2004;  // 採石場(エネルギー↔︎石材)
    uint256 public constant MINE    = 2005;  // 鉱山(エネルギー↔︎鉄鉱石)
    uint256 public constant DIAMINE = 2006;  // ダイア鉱山(エネルギー↔︎ダイアモンド)
    uint256 public constant TIMBEREXC  = 1003;  // 木材取引所(ガバー↔︎木材)
    uint256 public constant STONEEXC   = 1004;  // 石材取引所(ガバー↔︎石材)
    uint256 public constant IRONEXC    = 1005;  // 鉄材取引所(ガバー↔︎鉄鉱石)
    uint256 public constant DIAMONDEXC = 1006;  // ダイアモンド取引所(ガバー↔︎ダイアモンド)

    uint256 public constant ENERGY_MAX = 100;
    uint256 public constant ENERGY_RECOVERY_INTERVAL = 1 hours;
    uint256 public constant ENERGY_RECOVERY_AMOUNT = 10;

    IGodTicket public immutable godTicket;

    ResourceManager public resource;

    struct ResourceSpot {
        uint256 spotType;
        uint256 level;
        bool exists;
    }


    mapping(uint256 => ResourceSpot) internal spots; //keyは座標コード
    mapping(address => uint256)  internal lastRecovery; //keyはプレイヤーのアドレス
    mapping(address => uint256) internal playerEnergyMax; //keyはプレイヤーのアドレス。valueは各プレイヤーの現在のエネルギー所持量
    mapping(address => uint256) internal playerPosition; //keyはプレイヤーのアドレス、valueがCoordCode


    event SpotCreated(uint256 indexed area, int256 x, int256 y, uint256 spotType);
    event SpotInteracted(address indexed user, int256 x, int256 y, uint256 spotType, string result);
    event ResourceDeployed(address resourceAddress);
    event PositionUpdated(address indexed user, int256 x, int256 y);

    constructor(string memory baseURI, uint256 coordScale,uint256 movementCost ,address godTicketAddress) Ownable(msg.sender) {
        resource = new ResourceManager(baseURI);
        godTicket = IGodTicket(godTicketAddress);
        SCALE = coordScale;
        MovementCost = movementCost;
        emit ResourceDeployed(address(resource));
    }
    // --- 修飾子の定義 ---
    modifier validPosition() {//原点&プレイヤーの初期位置は{500000,500000}である(SCALE = 1000000の場合)
        //桁の数が一定であるかどうかをチェック(例：SCALE = 1000000なら、500000500000が原点なので12桁)
        if(playerPosition[msg.sender] < SCALE * SCALE && playerPosition[msg.sender] > (SCALE * SCALE)/10 ) {
            //条件満たす
        }else{
            //条件を満たさないので、初期値に飛ばす
            playerPosition[msg.sender] = encodeCoord(0,0);
        }
        _;
    }

    modifier equalPosition(int256 x, int256 y) {//インタラクトしようとしているスポットがプレイヤーと同じ座標にあるかどうか
        require(playerPosition[msg.sender] == encodeCoord(x,y), "you are not at the Spot.");
        _;
    }

    // ===== 内部ユーティリティ =====
    function encodeCoord(int256 x, int256 y) internal view returns (uint256) {
        // 符号付きintをそのまままとめると危険なので、オフセットを使う例
        uint256 ux = uint256(x +int256(SCALE)/2); // 座標範囲を -5000 ~ +5000 と仮定
        uint256 uy = uint256(y +int256(SCALE)/2);
        return ux * SCALE + uy;
    }

    function decodeCoord(uint256 coordCode) internal view returns (int256,int256) {
        // 符号付きintをそのまままとめると危険なので、オフセットを使う例
        int256 intSCALE = int256(SCALE);
        int256 ux = int256(coordCode)/intSCALE - intSCALE / 2; // 座標範囲を -5000 ~ +5000 と仮定
        int256 uy = int256(coordCode)%intSCALE - intSCALE / 2;
        return (ux ,uy);
    }

    function getArea(int256 x, int256 y) public view returns(uint256){
        x = x / 100;
        y = y / 100;
        return encodeCoord(x,y);
    }

    function abs(int256 x) internal pure returns (uint256) {
        return uint256(x >= 0 ? x : -x);
    }

    function absDiffSafe(int256 a, int256 b) public pure returns (uint256) {
        int256 diff = a - b;
        // type(int256).minのオーバーフロー防止
        if (diff == type(int256).min) {
            return uint256(type(int256).max);
        }
        return abs(diff);
    }

    // ===== スポット作成 (DAOのInitPoolから呼ばれる)=====
    function createSpot(int256 x, int256 y, uint256 spotType, uint256 initialScale) public virtual onlyOwner {
        uint256 key = encodeCoord(x, y);
        require(!spots[key].exists, "Spot already exists");
        spots[key] = ResourceSpot(spotType,initialScale,true);
        uint256 area = getArea(x,y);
        emit SpotCreated(area, x, y, spotType);
    }

    function InteractSpot(int256 x, int256 y) public virtual equalPosition(x,y){
        string memory info = getSpot (x, y);
        uint256 spotType = spots[encodeCoord(x,y)].spotType;
        emit SpotInteracted(msg.sender, x, y, spotType, info);
    }

    // ===== 時間経過によるエネルギー回復 =====
    function claimEnergy() public {
        uint256 elapsed = block.timestamp - lastRecovery[msg.sender];
        require(elapsed >= ENERGY_RECOVERY_INTERVAL, "Wait more time");
        uint256 energy = resource.balanceOf(msg.sender,resource.ENERGY());
        uint256 recoverAmount = (elapsed / ENERGY_RECOVERY_INTERVAL) * ENERGY_RECOVERY_AMOUNT;
        if (energy + recoverAmount > ENERGY_MAX) {
            recoverAmount = ENERGY_MAX - energy;
        }

        lastRecovery[msg.sender] = block.timestamp;
        resource.mint(msg.sender, resource.ENERGY(), recoverAmount);
    }

    /// @notice GodTicketを1枚burnしないと実行できないmint
    function mintResourceToken(uint256[] memory tokenId, uint256[] memory amount) external {
        // --- 1️⃣ GodTicketを持っているかチェック ---
        require(godTicket.balanceOf(msg.sender) >= 1, "Need at least 1 GodTicket");

        // --- 2️⃣ GodTicketをburn ---
        // GodTicketコントラクト側にburnFromの権限を与えておく必要あり
        godTicket.burnFrom(msg.sender, 1);

        // --- 3️⃣ 資源トークンmint ---
        resource.mintBatch(msg.sender, tokenId, amount);
    }

    function getSpot (int256 x, int256 y) view virtual public returns(string memory){
        uint256 key = encodeCoord(x, y);
        ResourceSpot memory s = spots[key];
        require(s.exists, "Spot does not exist");

        string memory json = string.concat(
            "{",
                "\"key\": ", Strings.toString(key), ",",
                "\"spotType\": ", Strings.toString(s.spotType), ",",
                "\"level\": ", Strings.toString(s.level), ",",
                "\"exists\": ", s.exists ? "true" : "false",
            "}"
        );

        return json;
    }

    function movePlayer(int256 newX, int256 newY)public validPosition{
        uint256 currentCoordCode = playerPosition[msg.sender];
        if(playerPosition[msg.sender] == 0){//座標コードの初期化が済んでいない

        }

        (int256 currentX,int256 currentY) = decodeCoord(currentCoordCode);
        //エネルギー必要量を算出
        uint256 delta = absDiffSafe(newX, currentX) + absDiffSafe(newY, currentY);
        uint256 energyAmount = delta * MovementCost;
        uint256 balance = resource.balanceOf(msg.sender,resource.ENERGY());
        require(balance >= energyAmount ,
            string.concat(
                "you need more ENERGY. required: ",
                Strings.toString(energyAmount),
                ", but you have: ",
                Strings.toString(balance)
            ));
        //エネルギーを消費
        resource.burn(msg.sender, resource.ENERGY(), energyAmount);
        //プレイヤーの座標を更新
        uint256 newCoord = encodeCoord(newX, newY);
        playerPosition[msg.sender] = newCoord;

        emit PositionUpdated(msg.sender, newX, newY);
        
    }

    function setMovementCost(uint256 value) external onlyOwner{
        MovementCost = value;
    }

    function getPlayerPosition() external view returns(int256, int256){
        uint256 currentCoordCode = playerPosition[msg.sender];
        (int256 currentX,int256 currentY) = decodeCoord(currentCoordCode);
        return (currentX, currentY);
    }

    function balanceObTest() external view onlyOwner returns(uint256){
        uint256 value = resource.balanceOf(msg.sender,resource.ENERGY());
        return value;
    }

}
