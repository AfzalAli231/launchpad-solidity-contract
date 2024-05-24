// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);
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
        uint256 cliffduration;
    }

    struct ReleaseData {
        uint256 releasetime;
        uint256 percyclerelease;
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

    mapping(uint256 => Launchpad) public launchpads; // Mapping of Launchpad IDs to launchpads
    mapping(uint256 => LaunchpadToken) public launchpadtokens; // Mapping of Launchpad IDs to launchpads
    mapping(uint256 => LockupDetails) public lockupdetails;
    mapping(uint256 => LockupHolder[]) public lockupHolders;
    mapping(uint256 => ReleaseData[]) public tokenreleasedata;
    uint256 public totalLaunchpads; // Total number of launchpads

    event LaunchpadAdded(uint256 indexed launchpadId);
    event LaunchpadCanceled(uint256 indexed launchpadId);
    event LaunchpadPaused(uint256 indexed launchpadId);
    event LaunchpadUnpaused(uint256 indexed launchpadId);

    // Modifier to ensure only the admin can execute certain functions
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }

    modifier onlyAdminOrTokenOwner(uint256 launchpadId) {
        require(
            msg.sender == admin ||
                msg.sender == launchpadtokens[launchpadId].tokenOwner,
            "Only admin or token owner can call this function"
        );
        _;
    }

    constructor() {
        admin = msg.sender;
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
            msg.value >=
                ((hardCap * tokenPrice * 1) / 100) + ((hardCap * 5) / 100),
            "Insufficient funds"
        );
        require(hardCap >= softCap, "HardCap must be more than softCap");
        require(
            hardCap > softCap + ((softCap * 40) / 100),
            "Hard Cap must be 40% more than soft cap"
        );
        payable(address(this)).transfer(msg.value);
        IERC20(token).transferFrom(msg.sender, address(this), tokenAmount);

        uint launchpadId = totalLaunchpads++;

        launchpads[launchpadId] = Launchpad({
            live: live,
            minPurchase: minPurchase,
            maxPurchase: maxPurchase,
            startTime: startTime,
            endTime: endTime,
            totalTx: 0,
            cancel: false,
            pauseUntil: block.timestamp,
            pauseStart: block.timestamp,
            livePauseCount: 0,
            softCap: softCap
        });

        launchpadtokens[launchpadId] = LaunchpadToken({
            token: token,
            name: name,
            symbol: symbol,
            tokenPrice: tokenPrice,
            hardCap: hardCap,
            raisedAmount: 0,
            tokenOwner: msg.sender,
            devPaid: (hardCap * 5) / 100,
            tokenAmount: tokenAmount
        });

        // developer will add days that will start after end time so following is the feature to add cliff period in end time
        uint endTimeMiliSec = endTime;
        uint cliffPeriodMiliSec = endTimeMiliSec + cliffDuration;

        lockupdetails[launchpadId] = LockupDetails({
            cliffPeriod: cliffPeriodMiliSec + cliffDuration,
            cliffduration: cliffDuration
        });

        emit LaunchpadAdded(launchpadId);
    }

    // Function to updateOwner
    function setOwner(address newOwner) external onlyAdmin {
        admin = newOwner;
    }

    function livePauseLaunchpad(
        uint256 launchpadId
    ) external onlyAdminOrTokenOwner(launchpadId) {
        require(
            !launchpads[launchpadId].cancel &&
                launchpadtokens[launchpadId].tokenOwner == msg.sender &&
                launchpadtokens[launchpadId].token != address(0),
            "Launchpad Doesn't Exist!"
        );
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
            emit LaunchpadUnpaused(launchpadId);
        } else {
            require(
                launchpads[launchpadId].livePauseCount < 3,
                "Live pause cycle is completed"
            );
            launchpads[launchpadId].live = false;
            launchpads[launchpadId].pauseUntil = block.timestamp + 172800;
            launchpads[launchpadId].pauseStart = block.timestamp;
            launchpads[launchpadId].livePauseCount += 1;
            emit LaunchpadPaused(launchpadId);
        }
    }

    function vest(uint256 launchpadId, uint256 tokenAmount) external payable {
        require(
            launchpadtokens[launchpadId].token != address(0) &&
                !launchpads[launchpadId].cancel,
            "Launchpad doesn't exist or not accessible"
        );
        require(
            launchpads[launchpadId].live || launchpads[launchpadId].pauseUntil > block.timestamp,
            "Launchpad is not active"
        );
        require(
            launchpads[launchpadId].endTime < block.timestamp,
            "Vesting already finished"
        );

        uint256 holderIndex = lockupHolders[launchpadId].length;
        bool holderFound = false;

        // Check if the investor already exists in lockupHolders
        for (uint256 i = 0; i < lockupHolders[launchpadId].length; i++) {
            if (lockupHolders[launchpadId][i].account == msg.sender) {
                holderIndex = i;
                holderFound = true;
                break;
            }
        }

        // If investor not found, add them to lockupHolders
        if (!holderFound) {
            lockupHolders[launchpadId].push(
                LockupHolder({
                    totalInvested: 0,
                    claimableTokens: 0,
                    vestedDate: 0,
                    cycleCompleted: 0,
                    account: msg.sender
                })
            );

            holderIndex = lockupHolders[launchpadId].length;
        }

        require(
            (lockupHolders[launchpadId][holderIndex].totalInvested +
                msg.value) >= launchpads[launchpadId].minPurchase,
            "Minimum investment not satisfied"
        );
        require(
            (lockupHolders[launchpadId][holderIndex].totalInvested +
                msg.value) <= launchpads[launchpadId].maxPurchase,
            "Maximum investment exceeded"
        );
        require(
            (lockupHolders[launchpadId][holderIndex].totalInvested +
                msg.value) +
                launchpadtokens[launchpadId].raisedAmount <=
                launchpadtokens[launchpadId].hardCap,
            "Hardcap limit reached"
        );

        // Update investor's data
        lockupHolders[launchpadId][holderIndex].claimableTokens += tokenAmount;
        lockupHolders[launchpadId][holderIndex].totalInvested += msg.value;
        lockupHolders[launchpadId][holderIndex].vestedDate = block.timestamp;

        require(
            launchpadtokens[launchpadId].raisedAmount !=
                launchpadtokens[launchpadId].hardCap,
            "Hardcap limit reached"
        );

        // If hardcap is reached, adjust cliffPeriod
        if (
            msg.value + launchpadtokens[launchpadId].raisedAmount ==
            launchpadtokens[launchpadId].hardCap
        ) {
            uint256 newCliff = block.timestamp +
                lockupdetails[launchpadId].cliffduration;

            if (launchpads[launchpadId].endTime > block.timestamp) {
                uint256 sub_duration = launchpads[launchpadId].endTime -
                    block.timestamp;
                for (
                    uint256 i = 0;
                    i < tokenreleasedata[launchpadId].length;
                    i++
                ) {
                    tokenreleasedata[launchpadId][i]
                        .releasetime -= sub_duration;
                }
            }

            lockupdetails[launchpadId].cliffPeriod = newCliff;
        }

        // Transfer received funds to the contract
        payable(address(this)).transfer(msg.value);

        // Update raised amount and total transactions
        launchpadtokens[launchpadId].raisedAmount += msg.value;
        launchpads[launchpadId].totalTx += 1;
    }

    function retrieve(
        uint256 launchpadId
    ) external onlyAdminOrTokenOwner(launchpadId) {
        require(
            launchpadtokens[launchpadId].tokenOwner == msg.sender &&
                launchpadtokens[launchpadId].token != address(0) &&
                !launchpads[launchpadId].cancel,
            "Launchpad doesn't exist or not accessible"
        );

        require(
            block.timestamp <= launchpads[launchpadId].endTime,
            "Vesting already finished"
        );

        uint256 holderIndex = 0;
        bool foundHolder = false;

        // Find the index of the lockup holder for the sender
        for (uint256 i = 0; i < lockupHolders[launchpadId].length; i++) {
            if (lockupHolders[launchpadId][i].account == msg.sender) {
                holderIndex = i;
                foundHolder = true;
                break;
            }
        }

        require(foundHolder, "User not found in lockup holders");

        require(
            lockupHolders[launchpadId][holderIndex].claimableTokens > 0,
            "No claimable tokens available"
        );

        // Reduce the raised amount by the total invested amount of the holder
        launchpadtokens[launchpadId].raisedAmount -= lockupHolders[launchpadId][
            holderIndex
        ].totalInvested;

        // Transfer the total invested amount back to the sender
        payable(msg.sender).transfer(
            lockupHolders[launchpadId][holderIndex].totalInvested
        );

        // Reset the lockup holder's data
        lockupHolders[launchpadId][holderIndex] = LockupHolder({
            totalInvested: 0,
            claimableTokens: 0,
            vestedDate: 0,
            cycleCompleted: 0,
            account: msg.sender
        });
    }

    function cancel(
        uint256 launchpadId
    ) external onlyAdminOrTokenOwner(launchpadId) {
        require(
            launchpadtokens[launchpadId].tokenOwner == msg.sender &&
                !launchpads[launchpadId].cancel &&
                launchpadtokens[launchpadId].token != address(0),
            "Launchpad doesn't exist"
        );
        require(
            launchpads[launchpadId].endTime > block.timestamp,
            "Vesting already finished"
        );
        require(
            launchpadtokens[launchpadId].raisedAmount >
                launchpadtokens[launchpadId].hardCap,
            "Hard cap not reached"
        );

        for (uint256 i = 0; i < lockupHolders[launchpadId].length; i++) {
            LockupHolder memory holder = lockupHolders[launchpadId][i];
            payable(holder.account).transfer(holder.totalInvested);
        }

        payable(admin).transfer(launchpadtokens[launchpadId].devPaid);
        IERC20 tokenContract = IERC20(launchpadtokens[launchpadId].token);
        tokenContract.transfer(
            msg.sender,
            launchpadtokens[launchpadId].tokenAmount
        );

        launchpads[launchpadId].cancel = true;

        emit LaunchpadCanceled(launchpadId);
    }

    function sendInvestmentToDev(
        uint256 launchpadId,
        uint256 tokenAmount
    ) external onlyAdmin {
        require(
            launchpadtokens[launchpadId].tokenOwner == msg.sender &&
                launchpadtokens[launchpadId].token != address(0) &&
                !launchpads[launchpadId].cancel,
            "Launchpad doesn't exist or not accessible"
        );
        require(
            launchpads[launchpadId].endTime <= block.timestamp ||
                launchpadtokens[launchpadId].hardCap ==
                launchpadtokens[launchpadId].raisedAmount,
            "Vesting not finished or hard cap not reached"
        );

        // Transfer any excess tokens back to the token owner
        if (
            launchpadtokens[launchpadId].hardCap <
            launchpadtokens[launchpadId].raisedAmount
        ) {
            IERC20 tokenContract = IERC20(launchpadtokens[launchpadId].token);
            tokenContract.transfer(
                launchpadtokens[launchpadId].tokenOwner,
                tokenAmount
            );
        }

        // Transfer raised funds plus developer's share to the token owner
        payable(launchpadtokens[launchpadId].tokenOwner).transfer(
            launchpadtokens[launchpadId].raisedAmount +
                launchpadtokens[launchpadId].devPaid
        );
    }

    function claimTokens(uint256 launchpadId, uint256 epochCycle) external {
        require(
            launchpadtokens[launchpadId].tokenOwner == msg.sender &&
                launchpadtokens[launchpadId].token != address(0) &&
                !launchpads[launchpadId].cancel,
            "Launchpad doesn't exist or not accessible"
        );

        require(
            launchpads[launchpadId].endTime <= block.timestamp ||
                launchpadtokens[launchpadId].hardCap ==
                launchpadtokens[launchpadId].raisedAmount,
            "Vesting not finished or hard cap not reached"
        );

        // Fetch launchpad data
        LaunchpadToken memory launchpadtoken = launchpadtokens[launchpadId];
        ReleaseData[] memory tokenrelease = tokenreleasedata[launchpadId];
        LockupDetails memory lockupdetail = lockupdetails[launchpadId];

        require(
            lockupdetail.cliffPeriod <= block.timestamp,
            "Cliff Period not ended"
        );

        // Fetch release data for the given epoch cycle
        ReleaseData memory releaseData = tokenrelease[epochCycle];

        require(
            releaseData.percyclerelease > 0 &&
                releaseData.releasetime < block.timestamp,
            "Cannot claim tokens"
        );

        // Find the index of the lockup holder for the sender
        uint256 holderIndex = 0;
        bool foundHolder = false;
        for (uint256 i = 0; i < lockupHolders[launchpadId].length; i++) {
            if (lockupHolders[launchpadId][i].account == msg.sender) {
                holderIndex = i;
                foundHolder = true;
                break;
            }
        }

        require(foundHolder, "User not found in lockup holders");

        // Ensure there are claimable tokens available
        require(
            lockupHolders[launchpadId][holderIndex].claimableTokens > 0,
            "No claimable tokens available"
        );

        LockupHolder memory currentHolder = lockupHolders[launchpadId][
            holderIndex
        ];

        // Ensure the current cycle is not already completed
        require(
            currentHolder.cycleCompleted < epochCycle,
            "Cannot claim tokens"
        );

        // Update the cycle completion status for the holder
        lockupHolders[launchpadId][holderIndex].cycleCompleted = epochCycle;

        // Calculate the amount of tokens to be claimed for the current cycle
        uint256 calculate_claim_token_amount = (currentHolder.claimableTokens *
            releaseData.percyclerelease) / 100;

        // Transfer the calculated tokens to the holder
        IERC20 tokenContract = IERC20(launchpadtoken.token);
        tokenContract.transfer(msg.sender, calculate_claim_token_amount);
    }

    // Function to withdraw funds (admin only)
    function withdrawFunds() external onlyAdmin {
        payable(admin).transfer(address(this).balance);
    }

    receive() external payable {}
}
