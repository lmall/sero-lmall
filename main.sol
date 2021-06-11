pragma solidity ^0.4.25;

import "./DataSets.sol";
import "./seroInterface.sol";
import "./Util.sol";

contract CAT is SeroInterface {
    using SafeMath for uint256;

    //////////////////////////////////////// define constant
    uint256 constant calcDecimal = 1e18;

    //////////////////// define system
    DataSets.SystemInfo private sInfo;
    string private constant SERO_CURRENCY = "SERO";

    //////////////////////////////////////// modifier

    // for solidity < 5.0
    modifier IsHuman() {
        address _addr = msg.sender;
        uint256 _codeLength;

        assembly {
            _codeLength := extcodesize(_addr)
        }
        require(_codeLength == 0, "sorry humans only");
        _;
    }

    modifier IsAdmin() {
        require(
            msg.sender == sInfo.superAdmin || sInfo.admins[msg.sender] == 1,
            "only admin"
        );
        _;
    }

    modifier IsSuperAdmin() {
        require(sInfo.superAdmin == msg.sender, "only super admin");
        _;
    }

    modifier IsOperator() {
        require(sInfo.operators[msg.sender] == 1, "only operator");
        _;
    }

    //////////////////////////////////////// event
    event ConsumOrder(
        uint256 indexed storeID,
        uint256 indexed consumerID,
        string orderInfo,
        uint256 cost
    );

    //////////////////////////////////////// constructor
    constructor(
        uint256 exchange,
        uint256 nextUpdate,
        uint256 duration,
        address dev,
        uint256 nextShareUpdate,
        uint256 shareDuration
    ) public {
        require(exchange > 0, "exchange must > 0");
        require(nextUpdate > now, "nextUpdate must > now");
        require(nextShareUpdate > now, "nextShareUpdate must > now");

        sInfo.exchange = exchange;
        sInfo.nextUpdate = nextUpdate;
        sInfo.updateDuration = duration;
        sInfo.nextShareUpdate = nextShareUpdate;
        sInfo.updateShareDuration = shareDuration;
        sInfo.maxHeight = 300;
        sInfo.firstTime = nextUpdate;

        sInfo.decimal = 1e18;
        sInfo.bR = sInfo.decimal;

        sInfo.costToBase = sInfo.decimal.mul(625) / 100;
        sInfo.toConsumer = sInfo.decimal.mul(625) / 100;
        sInfo.toStore = sInfo.decimal;
        sInfo.toAff = sInfo.decimal.mul(625) / 100 / 2;
        sInfo.releasePR = sInfo.decimal.mul(5) / 10000;
        sInfo.maxSBalanceR = sInfo.decimal / 60;
        sInfo.toDev = sInfo.decimal / 50;
        sInfo.levelRewardR = sInfo.decimal.mul(4) / 100;
        sInfo.levelInfos.push(
            DataSets.LevelInfo({
                bigZone: sInfo.decimal.mul(100000),
                smallTotalZone: sInfo.decimal.mul(200000),
                shareRatioS: sInfo.decimal / 50,
                totalS: 0,
                lastTotalS: 0,
                avgS: 0,
                personNum: 0
            })
        );
        sInfo.levelInfos.push(
            DataSets.LevelInfo({
                bigZone: sInfo.decimal.mul(200000),
                smallTotalZone: sInfo.decimal.mul(400000),
                shareRatioS: sInfo.decimal / 100,
                totalS: 0,
                lastTotalS: 0,
                avgS: 0,
                personNum: 0
            })
        );
        sInfo.levelInfos.push(
            DataSets.LevelInfo({
                bigZone: sInfo.decimal.mul(800000),
                smallTotalZone: sInfo.decimal.mul(1600000),
                shareRatioS: sInfo.decimal / 100,
                totalS: 0,
                lastTotalS: 0,
                avgS: 0,
                personNum: 0
            })
        );
        sInfo.levelInfos.push(
            DataSets.LevelInfo({
                bigZone: sInfo.decimal.mul(1600000),
                smallTotalZone: sInfo.decimal.mul(3200000),
                shareRatioS: sInfo.decimal / 100,
                totalS: 0,
                lastTotalS: 0,
                avgS: 0,
                personNum: 0
            })
        );

        sInfo.superAdmin = msg.sender;
        sInfo.newPlayerID = 1;

        // for debug
        // sInfo.releasePR = sInfo.decimal.mul(5) / 1000;

        sInfo.dev = registerPlayer("superdev", sInfo.newPlayerID, dev);
    }

    //////////////////////////////////////// super admin func

    function AddAdmin(address admin) public IsSuperAdmin() {
        require(sInfo.admins[admin] == 0, "already add this admin");
        sInfo.admins[admin] = 1;
    }

    function DelAdmin(address admin) public IsSuperAdmin() {
        require(sInfo.admins[admin] == 1, "this addr is not admin");
        sInfo.admins[admin] = 0;
    }

    function ChangeSuperAdmin(address suAdmin) public IsSuperAdmin() {
        require(suAdmin != address(0x0), "empty new super admin");

        sInfo.superAdmin = suAdmin;
    }

    //////////////////////////////////////// admin func
    function AddOperator(address operator) public IsAdmin() {
        require(sInfo.operators[operator] == 0, "already add this operator");
        sInfo.operators[operator] = 1;
    }

    function DelOperator(address operator) public IsAdmin() {
        require(sInfo.operators[operator] == 1, "this addr is not operator");
        sInfo.operators[operator] = 0;
    }

    function RegisterTopUser(string memory affName, address addr)
        public
        IsAdmin()
    {
        registerPlayer(affName, sInfo.newPlayerID, addr);
    }

    function UpdateHeight(uint256 height) public IsAdmin() {
        require(height > 0, "height must > 0");
        sInfo.maxHeight = height;
    }

    //////////////////////////////////////// operator func
    function UpdateExchange(uint256 exchange) public IsOperator() {
        require(exchange > 0, "exchange can't equal 0");

        sInfo.exchange = exchange;

        updateMulti(100);
    }

    //////////////////////////////////////// public func
    function Consum(
        string memory cmAffName,
        address cmAddr,
        uint256 cost,
        string orderInfo
    ) public payable IsHuman() {
        //////////////////// check
        require(cost > 0, "cost should > 0");
        require(strings.equal(SERO_CURRENCY, sero_msg_currency()), "only sero");

        (uint256 chargeR, uint256 chargeS) = ConsumToSero(cost);

        require(msg.value >= chargeS, "sero not enough");

        uint256 storeID = sInfo.playerAddrID[msg.sender];
        require(storeID != 0, "storeID is not exist");

        updateMulti(0);

        //////////////////// exec
        uint256 cID = sInfo.playerAddrID[cmAddr];
        if (cID == 0) {
            cID = registerPlayerByAff(cmAffName, storeID, cmAddr);
        }

        require(cID != storeID, "cID == storeID");

        assign(storeID, cID, cost, chargeR, chargeS);

        emit ConsumOrder(storeID, cID, orderInfo, cost);
    }

    function Charge(bytes32 affName, string memory myAffName)
        public
        payable
        IsHuman()
    {
        require(strings.equal(SERO_CURRENCY, sero_msg_currency()), "only sero");

        uint256 myID = sInfo.playerAddrID[msg.sender];
        if (myID == 0) {
            require(
                msg.value >= sInfo.decimal.mul(100),
                "new user must charge 100 sero"
            );
            uint256 affID = sInfo.playerAffNameID[affName];
            require(affID != 0, "must have aff player");
            myID = registerPlayerByAff(myAffName, affID, msg.sender);
        } else {
            require(msg.value > 0, "must charge sero");
        }

        updateMulti(0);

        uint256 base = SeroToRmb(msg.value);
        uint256 cost = base.mul(sInfo.costToBase) / sInfo.decimal;

        assign(myID, myID, cost, base, msg.value);
    }

    function Withdraw() public IsHuman() {
        uint256 myID = sInfo.playerAddrID[msg.sender];
        require(myID != 0, "user must exist");

        updateMulti(0);

        DataSets.PlayerInfo storage myInfo = sInfo.playerInfo[myID];

        updateAvai(myInfo);

        if (myInfo.nAvaiSero == 0) {
            return;
        }

        uint256 value = myInfo.nAvaiSero;
        myInfo.nAvaiSero = 0;
        sero_send(msg.sender, "sero", value, "", 0);
    }

    function ManualUpdate(uint256 times) public {
        updateMulti(times);
    }

    //////////////////////////////////////// view
    function ConsumToSero(uint256 cost)
        public
        view
        returns (uint256 chargeR, uint256 chargeS)
    {
        chargeR = cost.mul(sInfo.decimal) / sInfo.costToBase;
        chargeS = RmbToSero(chargeR);
        return;
    }

    function SeroToRmb(uint256 s) public view returns (uint256 r) {
        return s.mul(sInfo.exchange) / sInfo.decimal;
    }

    function RmbToSero(uint256 r) public view returns (uint256 s) {
        return r.mul(sInfo.decimal) / sInfo.exchange;
    }

    function LevelInfo(uint256 i)
        public
        view
        returns (
            uint256 totalS,
            uint256 lastTotalS,
            uint256 avgS,
            uint256 personNum
        )
    {
        require(i < sInfo.levelInfos.length, "i is too large");
        DataSets.LevelInfo storage levelInfo = sInfo.levelInfos[i];

        return (
            levelInfo.totalS,
            levelInfo.lastTotalS,
            levelInfo.avgS,
            levelInfo.personNum
        );
    }

    function SystemParam()
        public
        view
        returns (
            uint256 aR,
            uint256 bR,
            uint256 aS,
            uint256 lastRatio,
            uint256 firstTime,
            uint256 wasteStar,
            uint256 wasteShareS
        )
    {
        return (
            sInfo.aR,
            sInfo.bR,
            sInfo.aS,
            sInfo.lastRatio,
            sInfo.firstTime,
            sInfo.wasteStar,
            sInfo.wasteShareS
        );
    }

    function SystemInfo()
        public
        view
        returns (
            uint256 exchange,
            uint256 nextUpdate,
            uint256 nextShareUpdate,
            uint256 sBalance,
            uint256 rRefund,
            uint256 tCost,
            uint256 tCharged,
            uint256 tAffReward,
            uint256 tRefund,
            uint256 tARefund,
            uint256 lastRatio,
            uint256 newPlayerID
        )
    {
        return (
            sInfo.exchange,
            sInfo.nextUpdate,
            sInfo.nextShareUpdate,
            sInfo.sBalance,
            sInfo.rRefund,
            sInfo.tCost,
            sInfo.tCharged,
            sInfo.tAffReward,
            sInfo.tRefund,
            sInfo.tARefund,
            sInfo.lastRatio,
            sInfo.newPlayerID
        );
    }

    /* function PlayerParam(uint256 myID) */
    /*         public */
    /*         view */
    /*         returns(uint256 aR, */
    /*                 uint256 bR, */
    /*                 uint256 aS, */
    /*                 uint256 nextUpdate){ */
    /*     DataSets.PlayerInfo storage pInfo = sInfo.playerInfo[myID]; */
    /*     return (pInfo.aR, pInfo.bR, pInfo.aS, pInfo.nextUpdate); */
    /* } */

    function PlayerInfo3(uint256 myID)
        public
        view
        returns (
            uint256 aR,
            uint256 bR,
            uint256 aS,
            uint256[4] levelAvg,
            uint256 nextUpdate,
            uint256 rRefund,
            uint256 nAvaiSero
        )
    {
        DataSets.PlayerInfo storage pInfo = sInfo.playerInfo[myID];

        return (
            pInfo.aR,
            pInfo.bR,
            pInfo.aS,
            pInfo.levelAvgS,
            pInfo.nextUpdate,
            pInfo.rRefund,
            pInfo.nAvaiSero
        );
    }

    function PlayerInfo2(uint256 myID)
        public
        view
        returns (
            uint256 bigZone,
            uint256 totalSmallZone,
            uint256 level,
            uint256 rRefund,
            uint256 nAvaiSero,
            uint256 tShareReward
        )
    {
        DataSets.PlayerInfo storage pInfo = sInfo.playerInfo[myID];
        rRefund = pInfo.rRefund;
        nAvaiSero = pInfo.nAvaiSero;
        tShareReward = pInfo.tShareReward;

        (avaiR, avaiS, ) = calcShare(pInfo);
        nAvaiSero = nAvaiSero.add(avaiS);
        tShareReward = tShareReward.add(avaiR);
        rRefund = rRefund.sub(avaiR);

        (uint256 avaiR, uint256 avaiS) =
            calcRefundAvai(
                pInfo.nextUpdate,
                rRefund,
                pInfo.aR,
                pInfo.bR,
                pInfo.aS
            );
        rRefund = rRefund.sub(avaiR);
        nAvaiSero = nAvaiSero.add(avaiS);

        return (
            pInfo.bigZone,
            pInfo.totalSmallZone,
            pInfo.level,
            rRefund,
            nAvaiSero,
            tShareReward
        );
    }

    function PlayerInfo2ByAddr(address addr)
        public
        view
        returns (
            uint256 bigZone,
            uint256 totalSmallZone,
            uint256 level,
            uint256 rRefund,
            uint256 nAvaiSero,
            uint256 tShareReward
        )
    {
        uint256 myID = sInfo.playerAddrID[addr];
        return PlayerInfo2(myID);
    }

    function PlayerInfo2ByName(string memory name)
        public
        view
        returns (
            uint256 bigZone,
            uint256 totalSmallZone,
            uint256 level,
            uint256 rRefund,
            uint256 nAvaiSero,
            uint256 tShareReward
        )
    {
        bytes32 dealName = NameFilter.nameFilter(name);
        uint256 myID = sInfo.playerAffNameID[dealName];

        return PlayerInfo2(myID);
    }

    function PlayerInfo1(uint256 myID)
        public
        view
        returns (
            uint256 ID,
            uint256 affedID,
            uint256 invitedNum,
            bytes32 affName,
            uint256 tCost,
            uint256 tMyCharged,
            uint256 tCharged,
            uint256 tAffReward,
            uint256 tRefund,
            uint256 tStarReward
        )
    {
        // require(myID != 0, "my ID should != 0");

        DataSets.PlayerInfo storage pInfo = sInfo.playerInfo[myID];

        return (
            pInfo.ID,
            pInfo.affedID,
            pInfo.invitedNum,
            pInfo.affName,
            pInfo.tCost,
            pInfo.tMyCharged,
            pInfo.tCharged,
            pInfo.tAffReward,
            pInfo.tRefund,
            pInfo.tStarReward
        );
    }

    function PlayerInfo1ByAddr(address addr)
        public
        view
        returns (
            uint256 ID,
            uint256 affedID,
            uint256 invitedNum,
            bytes32 affName,
            uint256 tCost,
            uint256 tMyCharged,
            uint256 tCharged,
            uint256 tAffReward,
            uint256 tRefund,
            uint256 tStarReward
        )
    {
        uint256 myID = sInfo.playerAddrID[addr];
        return PlayerInfo1(myID);
    }

    function PlayerInfo1ByName(string memory name)
        public
        view
        returns (
            uint256 ID,
            uint256 affedID,
            uint256 invitedNum,
            bytes32 affName,
            uint256 tCost,
            uint256 tMyCharged,
            uint256 tCharged,
            uint256 tAffReward,
            uint256 tRefund,
            uint256 tStarReward
        )
    {
        bytes32 dealName = NameFilter.nameFilter(name);
        uint256 myID = sInfo.playerAffNameID[dealName];

        return PlayerInfo1(myID);
    }

    //////////////////////////////////////// private
    // must called by every public function
    function updateMulti(uint256 times) private {
        updateShare();
        updateMultiNormal(times);
    }

    function updateShare() private {
        if (now < sInfo.nextShareUpdate) {
            return;
        }

        for (uint256 i = 0; i < sInfo.levelInfos.length; i++) {
            DataSets.LevelInfo storage levelInfo = sInfo.levelInfos[i];
            uint256 diffS = levelInfo.totalS.sub(levelInfo.lastTotalS);
            if (levelInfo.personNum == 0) {
                sInfo.sBalance = sInfo.sBalance.add(diffS);
                levelInfo.lastTotalS = levelInfo.totalS;
                continue;
            }

            levelInfo.avgS = levelInfo.avgS.add(diffS / levelInfo.personNum);
            levelInfo.lastTotalS = levelInfo.totalS;
        }

        uint256 diffTimes =
            now.sub(sInfo.nextShareUpdate) / sInfo.updateShareDuration;
        sInfo.nextShareUpdate = sInfo.nextShareUpdate.add(
            sInfo.updateShareDuration.mul(diffTimes.add(1))
        );

        return;
    }

    function updateMultiNormal(uint256 times) private {
        if (now < sInfo.nextUpdate) {
            return;
        }

        uint256 needTimes =
            (now.sub(sInfo.nextUpdate) / sInfo.updateDuration).add(1);

        if (needTimes > times && times != 0) {
            needTimes = times;
        }

        if (needTimes > 0) {
            newUpdate(needTimes);
        }
    }

    function newUpdate(uint256 times) private {
        if (times == 0) {
            return;
        }

        uint256 ratio;
        uint256 release;
        uint256 releaseS;

        uint256 tRelease;
        uint256 tReleaseS;

        uint256 adR;
        uint256 bdR = sInfo.decimal;

        for (uint256 i = 0; i < times; i++) {
            (release, releaseS, ratio) = getRatio(
                sInfo.rRefund.sub(tRelease),
                sInfo.sBalance.sub(tReleaseS)
            );

            adR = adR.add(ratio.mul(bdR) / sInfo.decimal);
            bdR = bdR.mul(sInfo.decimal.sub(ratio)) / sInfo.decimal;

            tRelease = tRelease.add(release);
            tReleaseS = tReleaseS.add(releaseS);
        }

        uint256 newDayRe = sInfo.bR.mul(adR) / sInfo.decimal;
        sInfo.aR = sInfo.aR.add(newDayRe);
        sInfo.bR = sInfo.bR.mul(bdR) / sInfo.decimal;
        sInfo.aS = sInfo.aS.add(newDayRe.mul(sInfo.decimal) / sInfo.exchange);
        sInfo.lastRatio = ratio;

        sInfo.nextUpdate = sInfo.nextUpdate.add(
            sInfo.updateDuration.mul(times)
        );
        sInfo.rRefund = sInfo.rRefund.sub(tRelease);
        sInfo.tARefund = sInfo.tARefund.add(tRelease);
        sInfo.sBalance = sInfo.sBalance.sub(tReleaseS);
    }

    function getRatio(uint256 rRefund, uint256 sBalance)
        private
        view
        returns (
            uint256 release,
            uint256 releaseS,
            uint256 ratio
        )
    {
        release = rRefund.mul(sInfo.releasePR) / sInfo.decimal;
        if (release > 0) {
            ratio = sInfo.releasePR;
        }

        uint256 max = SeroToRmb(sBalance);
        max = max.mul(sInfo.maxSBalanceR) / sInfo.decimal;
        if (release > max) {
            release = max;
            if (rRefund > 0) {
                ratio = release.mul(sInfo.decimal) / rRefund;
            } else {
                ratio = 0;
            }
        }

        releaseS = RmbToSero(release);

        return (release, releaseS, ratio);
    }

    function assign(
        uint256 sid,
        uint256 cid,
        uint256 cost,
        uint256 base,
        uint256 baseS
    ) private {
        DataSets.PlayerInfo storage storeInfo = sInfo.playerInfo[sid];
        // update sero balance
        if (msg.value > baseS) {
            storeInfo.nAvaiSero = storeInfo.nAvaiSero.add(msg.value.sub(baseS));
        }

        sInfo.tCost = sInfo.tCost.add(cost);
        sInfo.tCharged = sInfo.tCharged.add(base);

        DataSets.PlayerInfo storage cInfo = sInfo.playerInfo[cid];

        // assign
        uint256 total;
        uint256 tmp;
        uint256 tmpS;
        uint256 balanceS = baseS;

        tmp = assignConsumer(cInfo, cost, base);
        total = total.add(tmp);

        if (cid != sid) {
            tmp = assignStore(storeInfo, base);
            total = total.add(tmp);
        }

        uint256 affID = cInfo.affedID;
        (tmp, tmpS) = assignAff(sInfo.playerInfo[affID], cInfo, base, baseS);
        sInfo.tAffReward = sInfo.tAffReward.add(tmp);
        total = total.add(tmp);
        balanceS = balanceS.sub(tmpS);

        sInfo.tRefund = sInfo.tRefund.add(total);

        // assign other
        tmpS = assignDev(baseS);
        balanceS = balanceS.sub(tmpS);

        tmpS = assignShare(baseS);
        balanceS = balanceS.sub(tmpS);
        sInfo.sBalance = sInfo.sBalance.add(balanceS);
    }

    function assignStore(DataSets.PlayerInfo storage pInfo, uint256 base)
        private
        returns (uint256 refund)
    {
        pInfo.tCharged = pInfo.tCharged.add(base);
        refund = base.mul(sInfo.toStore) / sInfo.decimal;
        addPlayerRefund(pInfo, refund);
        return refund;
    }

    function checkLevel(DataSets.PlayerInfo storage pInfo) private {
        if (pInfo.level > 0) {
            updateAvai(pInfo);
        }

        while (pInfo.level < sInfo.levelInfos.length) {
            DataSets.LevelInfo storage levelInfo =
                sInfo.levelInfos[pInfo.level];
            if (
                pInfo.bigZone >= levelInfo.bigZone &&
                pInfo.totalSmallZone >= levelInfo.smallTotalZone
            ) {
                if (pInfo.level > 0) {
                    DataSets.LevelInfo storage oldLevelInfo =
                        sInfo.levelInfos[pInfo.level - 1];
                    oldLevelInfo.personNum--;
                }

                pInfo.levelAvgS[pInfo.level] = levelInfo.avgS;
                pInfo.level++;
                levelInfo.personNum++;

                continue;
            }
            break;
        }
    }

    function assignStarReward(
        DataSets.PlayerInfo storage pInfo,
        uint256 baseS,
        uint256 levelDiff
    ) private returns (uint256 rewardS) {
        rewardS = baseS.mul(sInfo.levelRewardR).mul(levelDiff) / sInfo.decimal;
        uint256 rewardR = SeroToRmb(rewardS);
        uint256 wasteR = 0;
        if (rewardR > pInfo.rRefund) {
            wasteR = rewardR.sub(pInfo.rRefund);
            rewardR = pInfo.rRefund;
            rewardS = RmbToSero(rewardR);
        }
        pInfo.rRefund = pInfo.rRefund.sub(rewardR);
        pInfo.nAvaiSero = pInfo.nAvaiSero.add(rewardS);
        pInfo.tStarReward = pInfo.tStarReward.add(rewardR);

        sInfo.rRefund = sInfo.rRefund.sub(rewardR);
        sInfo.tARefund = sInfo.tARefund.add(rewardR);
        sInfo.wasteStar = sInfo.wasteStar.add(wasteR);

        return;
    }

    function assignDev(uint256 baseS) private returns (uint256 devS) {
        DataSets.PlayerInfo storage devInfo = sInfo.playerInfo[sInfo.dev];
        devS = baseS.mul(sInfo.toDev) / sInfo.decimal;
        devInfo.nAvaiSero = devInfo.nAvaiSero.add(devS);
        return;
    }

    function assignShare(uint256 baseS) private returns (uint256 shareS) {
        for (uint256 i = 0; i < sInfo.levelInfos.length; i++) {
            DataSets.LevelInfo storage levelInfo = sInfo.levelInfos[i];
            uint256 nowShareS =
                baseS.mul(levelInfo.shareRatioS) / sInfo.decimal;
            levelInfo.totalS = levelInfo.totalS.add(nowShareS);
            shareS = shareS.add(nowShareS);
        }

        return shareS;
    }

    function assignAff(
        DataSets.PlayerInfo storage affInfo,
        DataSets.PlayerInfo storage cInfo,
        uint256 base,
        uint256 baseS
    ) private returns (uint256 refund, uint256 totalRewardS) {
        if (affInfo.ID == cInfo.ID) {
            return (0, 0);
        }

        refund = base.mul(sInfo.toAff) / sInfo.decimal;
        addAffRefund(affInfo, refund);

        // for tree
        uint256 height = 0;
        uint256 subTotalZone =
            cInfo.tMyCharged.add(cInfo.bigZone).add(cInfo.totalSmallZone);
        uint256 nowLevel = 0;
        while (height < sInfo.maxHeight) {
            if (affInfo.bigZone < subTotalZone) {
                affInfo.totalSmallZone = affInfo
                    .totalSmallZone
                    .add(affInfo.bigZone)
                    .add(base)
                    .sub(subTotalZone);
                affInfo.bigZone = subTotalZone;
            } else {
                affInfo.totalSmallZone = affInfo.totalSmallZone.add(base);
            }

            checkLevel(affInfo);
            if (affInfo.level > nowLevel) {
                updateAvai(affInfo);
                totalRewardS = totalRewardS.add(
                    assignStarReward(
                        affInfo,
                        baseS,
                        affInfo.level.sub(nowLevel)
                    )
                );
                nowLevel = affInfo.level;
            }

            if (affInfo.ID == affInfo.affedID) {
                break;
            }

            subTotalZone = affInfo.tMyCharged.add(affInfo.bigZone).add(
                affInfo.totalSmallZone
            );
            affInfo = sInfo.playerInfo[affInfo.affedID];

            height++;
        }

        return (refund, totalRewardS);
    }

    function assignConsumer(
        DataSets.PlayerInfo storage pInfo,
        uint256 cost,
        uint256 base
    ) private returns (uint256 refund) {
        addCost(pInfo, cost);

        refund = base.mul(sInfo.toConsumer) / sInfo.decimal;
        addPlayerRefund(pInfo, refund);

        pInfo.tMyCharged = pInfo.tMyCharged.add(base);

        return refund;
    }

    function addCost(DataSets.PlayerInfo storage pInfo, uint256 value) private {
        if (pInfo.tCost > pInfo.tAffReward) {
            pInfo.tCost = pInfo.tCost.add(value);
            return;
        }

        uint256 diff = pInfo.tAffReward.sub(pInfo.tCost);
        pInfo.tCost = pInfo.tCost.add(value);
        if (pInfo.tCost < pInfo.tAffReward) {
            diff = value;
        }
        addPlayerRefund(pInfo, diff);
    }

    function addAffRefund(DataSets.PlayerInfo storage pInfo, uint256 value)
        private
    {
        if (pInfo.tAffReward > pInfo.tCost) {
            pInfo.tAffReward = pInfo.tAffReward.add(value);
            return;
        }

        pInfo.tAffReward = pInfo.tAffReward.add(value);
        if (pInfo.tAffReward > pInfo.tCost) {
            value = value.sub(pInfo.tAffReward.sub(pInfo.tCost));
        }

        addPlayerRefund(pInfo, value);
    }

    function addPlayerRefund(DataSets.PlayerInfo storage pInfo, uint256 value)
        private
    {
        updateAvai(pInfo);

        updatePlayerParam(pInfo);

        pInfo.tRefund = pInfo.tRefund.add(value);
        pInfo.rRefund = pInfo.rRefund.add(value);
        sInfo.rRefund = sInfo.rRefund.add(value);
    }

    function updateAvai(DataSets.PlayerInfo storage pInfo) private {
        updateSharePerson(pInfo);

        if (sInfo.nextUpdate == pInfo.nextUpdate || pInfo.rRefund == 0) {
            return;
        }

        (uint256 avaiR, uint256 avaiS) = calcAvai(pInfo);

        // update param
        updatePlayerParam(pInfo);

        // update player stats
        pInfo.rRefund = pInfo.rRefund.sub(avaiR);

        // update sero avai balance
        pInfo.nAvaiSero = pInfo.nAvaiSero.add(avaiS);
    }

    function updateSharePerson(DataSets.PlayerInfo storage pInfo) private {
        (uint256 avaiR, uint256 avaiS, uint256 wasteS) = calcShare(pInfo);
        if (avaiS == 0) {
            return;
        }
        pInfo.rRefund = pInfo.rRefund.sub(avaiR);
        pInfo.nAvaiSero = pInfo.nAvaiSero.add(avaiS);
        pInfo.tShareReward = pInfo.tShareReward.add(avaiR);
        pInfo.levelAvgS[pInfo.level - 1] = sInfo.levelInfos[pInfo.level - 1]
            .avgS;
        if (wasteS > 0) {
            sInfo.wasteShareS = sInfo.wasteShareS.add(wasteS);
            sInfo.sBalance = sInfo.sBalance.add(wasteS);
        }
    }

    function updatePlayerParam(DataSets.PlayerInfo storage pInfo) private {
        if (sInfo.nextUpdate == pInfo.nextUpdate) {
            return;
        }

        pInfo.aR = sInfo.aR;
        pInfo.bR = sInfo.bR;
        pInfo.aS = sInfo.aS;
        pInfo.nextUpdate = sInfo.nextUpdate;
    }

    function calcShare(DataSets.PlayerInfo storage pInfo)
        private
        view
        returns (
            uint256 avaiR,
            uint256 avaiS,
            uint256 wasteS
        )
    {
        if (pInfo.level == 0) {
            return (0, 0, 0);
        }

        DataSets.LevelInfo storage levelInfo =
            sInfo.levelInfos[pInfo.level - 1];

        uint256 avgS = levelInfo.avgS;
        if (now >= sInfo.nextShareUpdate) {
            avgS = avgS.add(
                levelInfo.totalS.sub(levelInfo.lastTotalS) / levelInfo.personNum
            );
        }

        avaiS = avaiS.add(avgS.sub(pInfo.levelAvgS[pInfo.level - 1]));

        avaiR = SeroToRmb(avaiS);
        if (avaiR > pInfo.rRefund) {
            avaiR = pInfo.rRefund;

            wasteS = avaiS;
            avaiS = RmbToSero(avaiR);
            wasteS = wasteS.sub(avaiS);
        }

        return;
    }

    function calcAvai(DataSets.PlayerInfo storage pInfo)
        private
        view
        returns (uint256 avaiR, uint256 avaiS)
    {
        return
            calcRefundAvai(
                pInfo.nextUpdate,
                pInfo.rRefund,
                pInfo.aR,
                pInfo.bR,
                pInfo.aS
            );
    }

    function calcRefundAvai(
        uint256 nextUpdate,
        uint256 rRefund,
        uint256 aR,
        uint256 bR,
        uint256 aS
    ) private view returns (uint256 avaiR, uint256 avaiS) {
        if (sInfo.nextUpdate <= nextUpdate || rRefund == 0) {
            return (0, 0);
        }
        uint256 paramR = sInfo.aR.sub(aR);
        paramR = paramR.mul(sInfo.decimal) / bR;
        avaiR = rRefund.mul(paramR) / sInfo.decimal;

        uint256 paramS = sInfo.aS.sub(aS);
        paramS = paramS.mul(sInfo.decimal) / bR;
        avaiS = rRefund.mul(paramS) / sInfo.decimal;

        return (avaiR, avaiS);
    }

    function registerPlayerByAff(
        string memory affName,
        uint256 affedID,
        address addr
    ) private returns (uint256 pid) {
        DataSets.PlayerInfo storage affInfo = sInfo.playerInfo[affedID];
        require(affInfo.ID != 0, "aff player is not exist");

        pid = registerPlayer(affName, affedID, addr);
        affInfo.invitedNum = affInfo.invitedNum.add(1);

        return pid;
    }

    // not check affedID
    function registerPlayer(
        string memory affName,
        uint256 affedID,
        address addr
    ) private returns (uint256 pid) {
        pid = sInfo.playerAddrID[addr];
        require(pid == 0, "already register");

        bytes32 dealName = NameFilter.nameFilter(affName);
        require(
            sInfo.playerAffNameID[dealName] == 0,
            "the name has registered"
        );

        // register new id
        pid = sInfo.newPlayerID;
        sInfo.newPlayerID = pid.add(1);

        DataSets.PlayerInfo storage pInfo = sInfo.playerInfo[pid];
        pInfo.addr = addr;
        pInfo.ID = pid;
        pInfo.affedID = affedID;
        pInfo.affName = dealName;

        sInfo.playerAddrID[addr] = pid;
        sInfo.playerAffNameID[dealName] = pid;
        return pid;
    }
}
