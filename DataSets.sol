pragma solidity ^0.4.25;

library DataSets{
    //////////////////////////////////////// define system struct

    struct LevelInfo {
        uint256 bigZone;
        uint256 smallTotalZone;
        uint256 shareRatioS;
        uint256 totalS;
        uint256 lastTotalS;
        uint256 avgS;
        uint256 personNum;
    }

    struct SystemInfo{
        uint256 exchange; // 1 sero = ? rmb
        uint256 nextUpdate; // timestamp
        uint256 updateDuration; // unit second
        uint256 nextShareUpdate; // timestamp
        uint256 updateShareDuration; // unit second
        uint256 maxHeight;
        uint256 firstTime;

        // param
        // a4 = a1+(1-a1)a2+(1-a1)(1-a2)a3+(1-a1)(1-a2)(1-a3)a4
        // b4 = 1x(1-a1)(1-a2)(1-a3)(1-a4)
        uint256 aR;
        uint256 bR;
        uint256 aS;
        uint256 decimal;
        uint256 lastRatio;

        // ratio
        uint256 costToBase;
        uint256 toConsumer;
        uint256 toStore;
        uint256 toAff;
        uint256 toDev;
        uint256 levelRewardR;
        uint256 chargeSR;
        uint256 releasePR; // person one day release max rmb.
        uint256 maxSBalanceR; // sero balance release max ratio.
        LevelInfo[] levelInfos;

        // statistic
        uint256 sBalance; // sero balance

        uint256 rRefund; // remain refund
        
        uint256 tCost; // total cost
        uint256 tCharged; // total charged
        uint256 tAffReward; // total aff reward
        uint256 tRefund; // total refund, include aff not affect refund, 
        uint256 tARefund; // total already refund.

        uint256 wasteStar;
        uint256 wasteShareS;

        // admin
        address superAdmin;
        uint256 dev;
        mapping(address => uint256) admins;
        mapping(address => uint256) operators;

        // player
        uint256 newPlayerID;
        mapping(uint256 => PlayerInfo) playerInfo;
        // address->pid
        mapping(address => uint256) playerAddrID;
        // affName->pid
        mapping(bytes32 => uint256) playerAffNameID;
    }

    //////////////////////////////////////// define player struct
    
    struct PlayerInfo{
        address addr;
        uint256 ID;
        
        uint256 affedID;
        uint256 invitedNum;
        bytes32 affName;

        uint256 bigZone;
        uint256 totalSmallZone;
        uint256 level;
        
        uint256 tCost; // total cost
        uint256 tMyCharged;
        uint256 tCharged; // total give other charged
        uint256 tAffReward; // total aff reward
        uint256 tRefund; // total refund, include already refund and unrefund.
        uint256 tStarReward;
        uint256 tShareReward;

        uint256 rRefund; // remain refund
        uint256 nAvaiSero; // now available sero

        uint256 aR;
        uint256 bR;
        uint256 aS;
        uint256[4] levelAvgS;
        
        uint256 nextUpdate;
    }
}
