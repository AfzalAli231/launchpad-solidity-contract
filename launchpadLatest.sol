// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 value) external returns (bool);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);
}

struct LockupHolder {
    uint256 cycleCompleted;
    uint256 claimableTokens;
    uint256 totalInvested;
    uint256 vestedDate;
    address account;
}

struct LockupDetails {
    uint256 cliffPeriod;
    uint256 cliffDuration;
}

struct ReleaseData {
    uint256 releaseTime;
    uint256 perCycleRelease;
}

struct Launchpad {
    uint256 minPurchase;
    uint256 maxPurchase;
    uint256 startTime;
    uint256 endTime;
    uint256 totalTx;
    bool live;
    bool cancel;
    uint256 pauseUntil;
    uint256 pauseStart;
    uint256 livePauseCount;
    uint256 softCap;
}

struct LaunchpadToken {
    uint256 hardCap;
    uint256 tokenAmount;
    address tokenOwner;
    address token;
    string name;
    string symbol;
    uint256 tokenPrice;
    uint256 devPaid;
    uint256 raisedAmount;
    ReleaseData[] tokenReleaseData;
}

struct InitFees {
    address admin;
    uint256 platformFee;
    uint256 devFeePercent;
    uint256 totalLaunchpads;
}

struct CreateLaunchpadParams {
    uint256 tokenPrice;
    uint256 minPurchase;
    uint256 maxPurchase;
    uint256 hardCap;
    uint256 softCap;
    uint256 startTime;
    uint256 endTime;
    uint256 cliffDuration;
    bool live;
    uint256 tokenAmount;
    address token;
    string name;
    string symbol;
    ReleaseData[] tokenReleaseData;
}

contract LaunchpadContract {
    mapping(uint256 => Launchpad) public launchpads;
    mapping(uint256 => LaunchpadToken) public launchpadTokens;
    mapping(uint256 => LockupDetails) public lockupDetails;
    mapping(uint256 => LockupHolder[]) public lockupHolders;
    InitFees adminData =
        InitFees({
            platformFee: 1,
            devFeePercent: 5,
            totalLaunchpads: 0,
            admin: address(0)
        });

    event LaunchpadAdded(uint256 indexed launchpadId);
    event LaunchpadCanceled(
        uint256 indexed launchpadId,
        address indexed sender,
        uint256 timestamp,
        uint256 raisedAmount
    );
    event CurrentTime(uint256 indexed currentTime);
    event Vested(
        uint256 indexed launchpadId,
        address indexed account,
        uint256 investedAmount,
        uint256 tokenAmount,
        uint256 vestedDate
    );
    event TokensClaimed(
        uint256 indexed launchpadId,
        address indexed claimer,
        uint256 timestamp,
        uint256 claimableTokens,
        uint256 remainingTokens
    );
    event DevFeePercentUpdated(
        address indexed sender,
        uint256 oldDevFeePercent,
        uint256 newDevFeePercent,
        uint256 timestamp
    );
    event PlatformFeeUpdated(
        uint256 indexed oldFee,
        uint256 indexed newFee,
        address indexed sender,
        uint256 timestamp
    );
    event PlatformFeeApplied(
        uint256 amount,
        uint256 platformFeeAmount,
        address indexed sender,
        uint256 timestamp
    );
    event OwnerChanged(
        address indexed oldOwner,
        address indexed newOwner,
        address indexed sender,
        uint256 timestamp
    );
    event LaunchpadPaused(
        uint256 indexed launchpadId,
        address indexed sender,
        uint256 timestamp,
        uint256 pauseUntil,
        uint256 pauseStart,
        uint256 livePauseCount
    );
    event LaunchpadUnpaused(
        uint256 indexed launchpadId,
        address indexed sender,
        uint256 timestamp,
        uint256 pauseUntil,
        uint256 pauseStart,
        uint256 livePauseCount
    );
    event RaisedFundsWithdrawn(
        uint256 indexed launchpadId,
        address indexed admin,
        address indexed tokenOwner,
        uint256 timestamp,
        uint256 raisedAmount,
        uint256 devPaid
    );
    event RefundClaimed(
        uint256 indexed launchpadId,
        address indexed sender,
        uint256 timestamp,
        uint256 refundAmount
    );
    event FundsWithdrawn(
        address indexed admin,
        uint256 indexed amount,
        uint256 timestamp
    );

    modifier onlyAdmin() {
        require(
            msg.sender == adminData.admin,
            "Only admin can call this function"
        );
        _;
    }

    modifier onlyAdminOrTokenOwner(uint256 launchpadId) {
        require(
            msg.sender == adminData.admin ||
                msg.sender == launchpadTokens[launchpadId].tokenOwner,
            "Only admin or token owner can call this function"
        );
        _;
    }

    constructor() {
        adminData.admin = msg.sender;
    }

    function updatePlatformFee(uint256 _platformFee) external onlyAdmin {
        uint256 oldFee = adminData.platformFee;
        adminData.platformFee = _platformFee;
        emit PlatformFeeUpdated(
            oldFee,
            _platformFee,
            msg.sender,
            block.timestamp
        );
    }

    function updatedevFeePercent(uint256 _devFeePercent) external onlyAdmin {
        uint256 oldDevFeePercent = adminData.devFeePercent;
        adminData.devFeePercent = _devFeePercent;
        emit DevFeePercentUpdated(
            msg.sender,
            oldDevFeePercent,
            _devFeePercent,
            block.timestamp
        );
    }

    function applyPlatformFee(uint256 amount) internal {
        uint256 platformFeeAmount = (amount * adminData.platformFee) / 100;
        require(platformFeeAmount > 0, "Platform fee is zero");

        (bool success, ) = adminData.admin.call{value: platformFeeAmount}("");
        require(success, "Platform fee transfer failed");
    }

    // Function to add a new project
    function createLaunchpad(CreateLaunchpadParams memory params)
        external
        payable
    {
        require(params.token != address(0), "Token address cannot be zero");
        require(
            msg.value >=
                ((params.hardCap * params.tokenPrice * 1) /
                    100 +
                    (params.hardCap * 5) /
                    100) /
                    1 ether,
            "Insufficient funds"
        );
        require(
            params.hardCap >= params.softCap,
            "HardCap must be more than softCap"
        );
        require(
            params.hardCap > params.softCap + (params.softCap * 40) / 100,
            "Hard Cap must be 40% more than soft cap"
        );

        uint256 launchpadId = adminData.totalLaunchpads++;
        _createLaunchpadCore(
            launchpadId,
            CreateLaunchpadParams({
                tokenPrice: params.tokenPrice,
                minPurchase: params.minPurchase,
                maxPurchase: params.maxPurchase,
                hardCap: params.hardCap,
                softCap: params.softCap,
                startTime: params.startTime,
                endTime: params.endTime,
                cliffDuration: params.cliffDuration,
                live: params.live,
                tokenAmount: params.tokenAmount,
                token: params.token,
                name: params.name,
                symbol: params.symbol,
                tokenReleaseData: params.tokenReleaseData
            })
        );
        applyPlatformFee(msg.value);

        emit LaunchpadAdded(launchpadId);
    }

    function _createLaunchpadCore(
        uint256 launchpadId,
        CreateLaunchpadParams memory params
    ) internal {
        launchpads[launchpadId] = Launchpad({
            minPurchase: params.minPurchase,
            maxPurchase: params.maxPurchase,
            startTime: params.startTime,
            endTime: params.endTime,
            totalTx: 0,
            live: params.live,
            cancel: false,
            pauseUntil: block.timestamp,
            pauseStart: block.timestamp,
            livePauseCount: 0,
            softCap: params.softCap
        });

        LaunchpadToken storage token = launchpadTokens[launchpadId];
        token.token = params.token;
        token.name = params.name;
        token.symbol = params.symbol;
        token.tokenPrice = params.tokenPrice;
        token.hardCap = params.hardCap;
        token.tokenAmount = params.tokenAmount;
        token.tokenOwner = msg.sender;
        token.devPaid = (params.hardCap * 5) / 100;
        token.raisedAmount = 0;

        // Initialize and copy the tokenReleaseData array
        for (uint256 i = 0; i < params.tokenReleaseData.length; i++) {
            token.tokenReleaseData.push(params.tokenReleaseData[i]);
        }

        launchpadTokens[launchpadId] = token;

        uint256 cliffPeriodMilliSec = params.endTime + params.cliffDuration;
        lockupDetails[launchpadId] = LockupDetails({
            cliffPeriod: cliffPeriodMilliSec + params.cliffDuration,
            cliffDuration: params.cliffDuration
        });
        IERC20(params.token).transferFrom(
            msg.sender,
            address(this),
            params.tokenAmount
        );
    }

    function setOwner(address newOwner) external onlyAdmin {
        address oldOwner = adminData.admin;
        adminData.admin = newOwner;
        emit OwnerChanged(oldOwner, newOwner, msg.sender, block.timestamp);
    }

    function livePauseLaunchpad(uint256 launchpadId)
        external
        onlyAdminOrTokenOwner(launchpadId)
    {
        require(!launchpads[launchpadId].cancel, "Launchpad canceled");
        require(
            block.timestamp <= launchpads[launchpadId].endTime,
            "Vesting already finished"
        );

        if (block.timestamp < launchpads[launchpadId].pauseUntil) {
            require(
                block.timestamp > launchpads[launchpadId].pauseStart + 43200,
                "Live Pause Time is restricted to twelve hours"
            );
            launchpads[launchpadId].live = true;
            launchpads[launchpadId].pauseStart = block.timestamp;
            launchpads[launchpadId].pauseUntil = block.timestamp;
            emit LaunchpadUnpaused(
                launchpadId,
                msg.sender,
                block.timestamp,
                launchpads[launchpadId].pauseUntil,
                launchpads[launchpadId].pauseStart,
                launchpads[launchpadId].livePauseCount
            );
        } else {
            require(
                launchpads[launchpadId].livePauseCount < 3,
                "Live pause cycle completed"
            );
            launchpads[launchpadId].live = false;
            launchpads[launchpadId].pauseUntil = block.timestamp + 172800;
            launchpads[launchpadId].pauseStart = block.timestamp;
            launchpads[launchpadId].livePauseCount += 1;
            emit LaunchpadPaused(
                launchpadId,
                msg.sender,
                block.timestamp,
                launchpads[launchpadId].pauseUntil,
                launchpads[launchpadId].pauseStart,
                launchpads[launchpadId].livePauseCount
            );
        }
    }

    function vest(uint256 launchpadId, uint256 tokenAmount) external payable {
        require(!launchpads[launchpadId].cancel, "Launchpad canceled");
        require(
            launchpads[launchpadId].live ||
                block.timestamp > launchpads[launchpadId].pauseUntil,
            "Launchpad not active"
        );
        require(
            block.timestamp <= launchpads[launchpadId].endTime,
            "Vesting already finished"
        );

        uint256 holderIndex;
        bool holderFound = false;

        for (uint256 i = 0; i < lockupHolders[launchpadId].length; i++) {
            if (lockupHolders[launchpadId][i].account == msg.sender) {
                holderIndex = i;
                holderFound = true;
                break;
            }
        }

        if (!holderFound) {
            holderIndex = lockupHolders[launchpadId].length;
            lockupHolders[launchpadId].push(
                LockupHolder({
                    totalInvested: 0,
                    claimableTokens: 0,
                    vestedDate: 0,
                    cycleCompleted: 0,
                    account: msg.sender
                })
            );
        }

        LockupHolder storage holder = lockupHolders[launchpadId][holderIndex];
        uint256 newTotalInvested = holder.totalInvested + msg.value;

        require(
            newTotalInvested >= launchpads[launchpadId].minPurchase,
            "Minimum investment not satisfied"
        );
        require(
            newTotalInvested <= launchpads[launchpadId].maxPurchase,
            "Maximum investment exceeded"
        );
        require(
            newTotalInvested + launchpadTokens[launchpadId].raisedAmount <=
                launchpadTokens[launchpadId].hardCap,
            "Hardcap limit reached"
        );

        holder.claimableTokens += tokenAmount;
        holder.totalInvested = newTotalInvested;
        holder.vestedDate = block.timestamp;

        launchpadTokens[launchpadId].raisedAmount += msg.value;
        launchpads[launchpadId].totalTx += 1;
        applyPlatformFee(msg.value);

        if (
            launchpadTokens[launchpadId].raisedAmount ==
            launchpadTokens[launchpadId].hardCap
        ) {
            uint256 newCliff = block.timestamp +
                lockupDetails[launchpadId].cliffDuration;

            if (launchpads[launchpadId].endTime > block.timestamp) {
                uint256 subDuration = launchpads[launchpadId].endTime -
                    block.timestamp;

                for (
                    uint256 i = 0;
                    i < launchpadTokens[launchpadId].tokenReleaseData.length;
                    i++
                ) {
                    launchpadTokens[launchpadId]
                        .tokenReleaseData[i]
                        .releaseTime -= subDuration;
                }

                launchpads[launchpadId].endTime = block.timestamp;
            }

            if (lockupDetails[launchpadId].cliffPeriod > block.timestamp) {
                lockupDetails[launchpadId].cliffPeriod = newCliff;
            }
        }
    }

    function withdrawRaisedFunds(uint256 launchpadId)
        external
        onlyAdminOrTokenOwner(launchpadId)
    {
        LaunchpadToken storage launchpadToken = launchpadTokens[launchpadId];
        require(
            block.timestamp > launchpads[launchpadId].endTime,
            "Launchpad not ended"
        );
        require(
            launchpadToken.raisedAmount >= launchpads[launchpadId].softCap,
            "Soft cap not reached"
        );
        require(!launchpads[launchpadId].cancel, "Launchpad is canceled");

        uint256 raisedAmount = launchpadToken.raisedAmount;
        uint256 devPaid = launchpadToken.devPaid;
        uint256 amountToTransfer = raisedAmount - devPaid;

        require(
            address(this).balance >= amountToTransfer,
            "Insufficient balance"
        );

        (bool success, ) = launchpadToken.tokenOwner.call{
            value: amountToTransfer
        }("");
        require(success, "Funds transfer failed");

        launchpadToken.raisedAmount = 0;
        launchpadToken.devPaid = 0;

        emit RaisedFundsWithdrawn(
            launchpadId,
            msg.sender,
            launchpadToken.tokenOwner,
            block.timestamp,
            raisedAmount,
            devPaid
        );
    }

    function claimTokens(uint256 launchpadId) external {
        require(
            block.timestamp >= lockupDetails[launchpadId].cliffPeriod,
            "Cliff period not ended"
        );

        uint256 holderIndex;
        bool holderFound = false;

        for (uint256 i = 0; i < lockupHolders[launchpadId].length; i++) {
            if (lockupHolders[launchpadId][i].account == msg.sender) {
                holderIndex = i;
                holderFound = true;
                break;
            }
        }

        require(holderFound, "Holder not found");

        LockupHolder storage holder = lockupHolders[launchpadId][holderIndex];
        uint256 remainingTokens = holder.claimableTokens;
        require(remainingTokens > 0, "No tokens to claim");

        uint256 perCycleRelease = remainingTokens /
            launchpadTokens[launchpadId].tokenReleaseData.length;
        uint256 cyclesToRelease = (block.timestamp -
            lockupDetails[launchpadId].cliffPeriod) /
            lockupDetails[launchpadId].cliffDuration;

        uint256 claimableTokens = perCycleRelease * cyclesToRelease;
        holder.claimableTokens -= claimableTokens;
        holder.cycleCompleted += cyclesToRelease;

        IERC20(launchpadTokens[launchpadId].token).transfer(
            msg.sender,
            claimableTokens
        );
    }

    function cancelLaunchpad(uint256 launchpadId)
        external
        onlyAdminOrTokenOwner(launchpadId)
    {
        require(
            block.timestamp <= launchpads[launchpadId].endTime,
            "Vesting already finished"
        );
        launchpads[launchpadId].cancel = true;

        // uint256 raisedAmount = launchpadTokens[launchpadId].raisedAmount;
        uint256 devPaid = launchpadTokens[launchpadId].devPaid;
        // launchpadTokens[launchpadId].raisedAmount = 0;
        launchpadTokens[launchpadId].devPaid = 0;
        uint256 tokenAmount = launchpadTokens[launchpadId].tokenAmount;
        launchpadTokens[launchpadId].tokenAmount = 0;
        require(
            IERC20(launchpadTokens[launchpadId].token).transfer(
                launchpadTokens[launchpadId].tokenOwner,
                tokenAmount
            ),
            "Token transfer failed"
        );
        (bool success, ) = launchpadTokens[launchpadId].tokenOwner.call{
            value: devPaid
        }("");
        require(success, "Refund failed");

        emit LaunchpadCanceled(
            launchpadId,
            msg.sender,
            block.timestamp,
            devPaid
        );
    }

    function claimRefund(uint256 launchpadId) external {
        require(launchpads[launchpadId].cancel, "Launchpad is not canceled");

        uint256 investedAmount;
        for (uint256 i = 0; i < lockupHolders[launchpadId].length; i++) {
            if (lockupHolders[launchpadId][i].account == msg.sender) {
                investedAmount = lockupHolders[launchpadId][i].totalInvested;
                lockupHolders[launchpadId][i].totalInvested = 0;
                break;
            }
        }

        require(investedAmount > 0, "No funds to refund");

        uint256 refundAmount = investedAmount;
        require(
            address(this).balance >= refundAmount,
            "Insufficient balance for refund"
        );

        (bool success, ) = msg.sender.call{value: refundAmount}("");
        require(success, "Refund transfer failed");

        emit RefundClaimed(
            launchpadId,
            msg.sender,
            block.timestamp,
            refundAmount
        );
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getLockupHolderBySender(uint256 launchpadId)
        external
        view
        returns (
            uint256 cycleCompleted,
            uint256 claimableTokens,
            uint256 totalInvested,
            uint256 vestedDate,
            address account
        )
    {
        LockupHolder[] storage holders = lockupHolders[launchpadId];
        for (uint256 i = 0; i < holders.length; i++) {
            if (holders[i].account == msg.sender) {
                LockupHolder storage holder = holders[i];
                return (
                    holder.cycleCompleted,
                    holder.claimableTokens,
                    holder.totalInvested,
                    holder.vestedDate,
                    holder.account
                );
            }
        }
        revert("Holder not found");
    }

    function getReleaseData(uint256 launchpadId)
        external
        view
        returns (
            uint256[] memory releaseTimes,
            uint256[] memory perCycleReleases
        )
    {
        uint256 length = launchpadTokens[launchpadId].tokenReleaseData.length;
        releaseTimes = new uint256[](length);
        perCycleReleases = new uint256[](length);

        for (
            uint256 i = 0;
            i < launchpadTokens[launchpadId].tokenReleaseData.length;
            i++
        ) {
            releaseTimes[i] = launchpadTokens[launchpadId]
                .tokenReleaseData[i]
                .releaseTime;
            perCycleReleases[i] = launchpadTokens[launchpadId]
                .tokenReleaseData[i]
                .perCycleRelease;
        }

        return (releaseTimes, perCycleReleases);
    }

    function withdrawFunds(uint256 amount) external onlyAdmin {
        require(
            amount <= address(this).balance,
            "Insufficient contract balance"
        );
        payable(adminData.admin).transfer(amount);
        emit FundsWithdrawn(adminData.admin, amount, block.timestamp);
    }
}
