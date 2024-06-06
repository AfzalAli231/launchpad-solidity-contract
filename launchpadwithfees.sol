/**
 *Submitted for verification at amoy.polygonscan.com on 2024-06-04
*/

/**
 *Submitted for verification at amoy.polygonscan.com on 2024-05-27
*/

// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

// Importing necessary libraries

contract LaunchpadContract {
    address public admin; // Address of the admin who manages the launchpad

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
        uint256 minPurchase; // Minimum amount of tokens a user can buy
        uint256 maxPurchase; // Maximum amount of tokens a user can buy
        uint256 startTime; // Start time of the sale
        uint256 endTime; // End time of the sale
        uint256 totalTx; // End time of the sale
        bool live; // Status of the Launchpad
        bool cancel; // Status of the Launchpad
        uint256 pauseUntil;
        uint256 pauseStart;
        uint256 livePauseCount;
        uint256 softCap;
    }

    struct LaunchpadToken {
        uint256 hardCap; // Maximum amount of tokens available for sale
        uint256 tokenAmount;
        address tokenOwner;
        address token; // Address of the token being sold
        string name;
        string symbol;
        uint256 tokenPrice; // Price of 1 token in wei
        uint256 devPaid;
        uint256 raisedAmount; // Amount of tokens raised
    }

    mapping(uint256 => Launchpad) public launchpads;
    mapping(uint256 => LaunchpadToken) public launchpadTokens;
    mapping(uint256 => LockupDetails) public lockupDetails;
    mapping(uint256 => LockupHolder[]) public lockupHolders;
    mapping(uint256 => ReleaseData[]) public tokenReleaseData;
    uint256 public totalLaunchpads; // Total number of launchpads
    uint256 public platformFee = 1; // 1% platform fee


    event LaunchpadAdded(uint256 indexed launchpadId);
    event LaunchpadCanceled(uint256 indexed launchpadId);
    event LaunchpadPaused(uint256 indexed launchpadId);
    event LaunchpadUnpaused(uint256 indexed launchpadId);
    event CurrentTime(uint256 indexed currentTime);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }

    modifier onlyAdminOrTokenOwner(uint256 launchpadId) {
        require(
            msg.sender == admin || msg.sender == launchpadTokens[launchpadId].tokenOwner,
            "Only admin or token owner can call this function"
        );
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function updatePlatformFee(uint256 _platformFee) external onlyAdmin {
        platformFee = _platformFee;
    }

    function applyPlatformFee(uint256 amount) internal {
        uint256 platformFeeAmount = (amount * platformFee) / 100;
        require(platformFeeAmount > 0, "Platform fee is zero");

        // Transfer platform fee to the contract owner (admin)
        (bool success, ) = admin.call{value: platformFeeAmount}("");
        require(success, "Platform fee transfer failed");
    }

    // Function to add a new project
    function createLaunchpad(
        address token,
        string memory name,
        string memory symbol,
        uint256 tokenPrice,
        uint256 minPurchase,
        uint256 maxPurchase,
        uint256 hardCap,
        uint256 softCap,
        uint256 startTime,
        uint256 endTime,
        uint256 cliffDuration,
        bool live,
        uint256 tokenAmount
    ) external payable {
        require(token != address(0), "Token address cannot be zero");
        require(
            msg.value >= (((hardCap * tokenPrice * 1) / 100) + ((hardCap * 5) / 100)) / 1 ether,
            "Insufficient funds"
        );
        require(hardCap >= softCap, "HardCap must be more than softCap");
        require(
            hardCap > softCap + ((softCap * 40) / 100),
            "Hard Cap must be 40% more than soft cap"
        );

        uint256 launchpadId = totalLaunchpads++;

        launchpads[launchpadId] = Launchpad({
            minPurchase: minPurchase,
            maxPurchase: maxPurchase,
            startTime: startTime,
            endTime: endTime,
            totalTx: 0,
            live: live,
            cancel: false,
            pauseUntil: block.timestamp,
            pauseStart: block.timestamp,
            livePauseCount: 0,
            softCap: softCap
        });

        launchpadTokens[launchpadId] = LaunchpadToken({
            token: token,
            name: name,
            symbol: symbol,
            tokenPrice: tokenPrice,
            hardCap: hardCap,
            tokenAmount: tokenAmount,
            tokenOwner: msg.sender,
            devPaid: (hardCap * 5) / 100,
            raisedAmount: 0
        });

        uint256 endTimeMilliSec = endTime;
        uint256 cliffPeriodMilliSec = endTimeMilliSec + cliffDuration;

        lockupDetails[launchpadId] = LockupDetails({
            cliffPeriod: cliffPeriodMilliSec + cliffDuration,
            cliffDuration: cliffDuration
        });

        IERC20(token).transferFrom(msg.sender, address(this), tokenAmount);
            applyPlatformFee(msg.value);


        emit LaunchpadAdded(launchpadId);
    }

    function setOwner(address newOwner) external onlyAdmin {
        admin = newOwner;
    }

    function livePauseLaunchpad(uint256 launchpadId) external onlyAdminOrTokenOwner(launchpadId) {
        require(!launchpads[launchpadId].cancel, "Launchpad canceled");
        require(block.timestamp <= launchpads[launchpadId].endTime, "Vesting already finished");

        if (block.timestamp < launchpads[launchpadId].pauseUntil) {
            require(block.timestamp > launchpads[launchpadId].pauseStart + 43200, "Live Pause Time is restricted to twelve hours");
            launchpads[launchpadId].live = true;
            launchpads[launchpadId].pauseStart = block.timestamp;
            launchpads[launchpadId].pauseUntil = block.timestamp;
            emit LaunchpadUnpaused(launchpadId);
        } else {
            require(launchpads[launchpadId].livePauseCount < 3, "Live pause cycle completed");
            launchpads[launchpadId].live = false;
            launchpads[launchpadId].pauseUntil = block.timestamp + 172800;
            launchpads[launchpadId].pauseStart = block.timestamp;
            launchpads[launchpadId].livePauseCount += 1;
            emit LaunchpadPaused(launchpadId);
        }
    }

    function vest(uint256 launchpadId, uint256 tokenAmount) external payable {
        require(!launchpads[launchpadId].cancel, "Launchpad canceled");
        require(launchpads[launchpadId].live || block.timestamp > launchpads[launchpadId].pauseUntil, "Launchpad not active");
        require(block.timestamp <= launchpads[launchpadId].endTime, "Vesting already finished");

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

        require(newTotalInvested >= launchpads[launchpadId].minPurchase, "Minimum investment not satisfied");
        require(newTotalInvested <= launchpads[launchpadId].maxPurchase, "Maximum investment exceeded");
        require(newTotalInvested + launchpadTokens[launchpadId].raisedAmount <= launchpadTokens[launchpadId].hardCap, "Hardcap limit reached");

        holder.claimableTokens += tokenAmount;
        holder.totalInvested = newTotalInvested;
        holder.vestedDate = block.timestamp;

        launchpadTokens[launchpadId].raisedAmount += msg.value;
        launchpads[launchpadId].totalTx += 1;
        applyPlatformFee(msg.value);


        if (launchpadTokens[launchpadId].raisedAmount == launchpadTokens[launchpadId].hardCap) {
            uint256 newCliff = block.timestamp + lockupDetails[launchpadId].cliffDuration;

            if (launchpads[launchpadId].endTime > block.timestamp) {
                uint256 subDuration = launchpads[launchpadId].endTime - block.timestamp;
                for (uint256 i = 0; i < tokenReleaseData[launchpadId].length; i++) {
                    tokenReleaseData[launchpadId][i].releaseTime = tokenReleaseData[launchpadId][i].releaseTime - subDuration;
                }
                launchpads[launchpadId].endTime = block.timestamp;
            }

            if (lockupDetails[launchpadId].cliffPeriod > block.timestamp) {
                lockupDetails[launchpadId].cliffPeriod = newCliff;
            }
        }
    }

    function withdrawRaisedFunds(uint256 launchpadId) external onlyAdmin {
        require(launchpadTokens[launchpadId].raisedAmount >= launchpads[launchpadId].softCap, "Softcap not reached");
        require(block.timestamp >= launchpads[launchpadId].endTime, "Launchpad not ended");

        uint256 raisedAmount = launchpadTokens[launchpadId].raisedAmount;
        launchpadTokens[launchpadId].raisedAmount = 0;

        address tokenOwner = launchpadTokens[launchpadId].tokenOwner;
        uint256 devPaid = launchpadTokens[launchpadId].devPaid;

        (bool successAdmin, ) = admin.call{value: devPaid}("");
        require(successAdmin, "Admin withdrawal failed");

        (bool successTokenOwner, ) = tokenOwner.call{value: raisedAmount - devPaid}("");
        require(successTokenOwner, "Token owner withdrawal failed");
    }

    function claimTokens(uint256 launchpadId) external {
        require(block.timestamp >= lockupDetails[launchpadId].cliffPeriod, "Cliff period not ended");

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

        uint256 perCycleRelease = remainingTokens / tokenReleaseData[launchpadId].length;
        uint256 cyclesToRelease = (block.timestamp - lockupDetails[launchpadId].cliffPeriod) / lockupDetails[launchpadId].cliffDuration;

        uint256 claimableTokens = perCycleRelease * cyclesToRelease;
        holder.claimableTokens -= claimableTokens;
        holder.cycleCompleted += cyclesToRelease;

        IERC20(launchpadTokens[launchpadId].token).transfer(msg.sender, claimableTokens);
    }

    function cancelLaunchpad(uint256 launchpadId) external onlyAdminOrTokenOwner(launchpadId) {
        require(block.timestamp <= launchpads[launchpadId].endTime, "Vesting already finished");
        launchpads[launchpadId].cancel = true;

        uint256 raisedAmount = launchpadTokens[launchpadId].raisedAmount;
        launchpadTokens[launchpadId].raisedAmount = 0;
        (bool success, ) = launchpadTokens[launchpadId].tokenOwner.call{value: raisedAmount}("");
        require(success, "Refund failed");

        emit LaunchpadCanceled(launchpadId);
    }

    function claimRefund(uint256 launchpadId) external {
        require(launchpads[launchpadId].cancel, "Launchpad not canceled");

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
        uint256 refundAmount = holder.totalInvested;

        holder.totalInvested = 0;
        holder.claimableTokens = 0;
        holder.cycleCompleted = 0;

        (bool success, ) = holder.account.call{value: refundAmount}("");
        require(success, "Refund failed");
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function updateLaunchpad(
        uint256 launchpadId,
        address token,
        string memory name,
        string memory symbol,
        uint256 tokenPrice,
        uint256 minPurchase,
        uint256 maxPurchase,
        uint256 hardCap,
        uint256 startTime,
        uint256 endTime,
        uint256 cliffDuration,
        bool live,
        uint256 tokenAmount
    ) external onlyAdmin {
        require(!launchpads[launchpadId].cancel, "Launchpad canceled");

        launchpads[launchpadId] = Launchpad({
            minPurchase: minPurchase,
            maxPurchase: maxPurchase,
            startTime: startTime,
            endTime: endTime,
            totalTx: 0,
            live: live,
            cancel: false,
            pauseUntil: block.timestamp,
            pauseStart: block.timestamp,
            livePauseCount: 0,
            softCap: 0 // Update this field as per your requirements
        });

        launchpadTokens[launchpadId] = LaunchpadToken({
            token: token,
            name: name,
            symbol: symbol,
            tokenPrice: tokenPrice,
            hardCap: hardCap,
            tokenAmount: tokenAmount,
            tokenOwner: msg.sender,
            devPaid: (hardCap * 5) / 100,
            raisedAmount: 0
        });

        lockupDetails[launchpadId] = LockupDetails({
            cliffPeriod: endTime + cliffDuration,
            cliffDuration: cliffDuration
        });

        IERC20(token).transferFrom(msg.sender, address(this), tokenAmount);
    }
}
