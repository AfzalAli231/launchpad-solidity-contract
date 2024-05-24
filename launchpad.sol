// SPDX-License-Identifier: MIT

// File: @openzeppelin/contracts/token/ERC20/IERC20.sol


// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.20;

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
    event Approval(address indexed owner, address indexed spender, uint256 value);

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
    function allowance(address owner, address spender) external view returns (uint256);

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
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

// File: launchpad/launchpad.sol


pragma solidity ^0.8.0;
// Importing necessary libraries


contract Launchpad {
    address public admin; // Address of the admin who manages the launchpad
    struct Project {
        address token; // Address of the token being sold
        string name;
        string symbol;
        uint256 tokenPrice; // Price of 1 token in wei
        uint256 minPurchase; // Minimum amount of tokens a user can buy
        uint256 maxPurchase; // Maximum amount of tokens a user can buy
        uint256 hardCap; // Maximum amount of tokens available for sale
        uint256 raisedAmount; // Amount of tokens raised
        uint256 startTime; // Start time of the sale
        uint256 endTime; // End time of the sale
        bool active; // Status of the project
        address tokenOwner;
    }
    mapping(uint256 => Project) public projects; // Mapping of project IDs to projects
    uint256 public totalProjects; // Total number of projects
    mapping(uint256 => mapping(address => uint256)) public balances; // Mapping to track user balances for each project
    mapping(address => bool) public usedTokenAddresses;

    event TokensPurchased(
        address indexed buyer,
        uint256 amount,
        uint256 projectId
    );
    event SaleStarted(uint256 projectId, uint256 startTime, uint256 endTime);
    event SaleCompleted(uint256 projectId, uint256 raisedAmount);
    event ProjectAdded(uint256 indexed projectId);
    event ProjectPaused(uint256 indexed projectId);
    event ProjectUnpaused(uint256 indexed projectId);

    // Modifier to ensure only the admin can execute certain functions
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }

    modifier onlyAdminOrTokenOwner(uint256 projectId) {
        require(
            msg.sender == admin || msg.sender == projects[projectId].tokenOwner,
            "Only admin or token owner can call this function"
        );
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    // Function to add a new project
    function addProject(
        address _token,
        string memory _name,
        string memory _symbol,
        uint256 _tokenPrice,
        uint256 _minPurchase,
        uint256 _maxPurchase,
        uint256 _hardCap,
        uint256 _startTime,
        uint256 _endTime
    ) external payable {
        require(_token != address(0), "Token address cannot be zero");
        require(!usedTokenAddresses[_token], "Token address already used for a project");

        uint256 projectId = totalProjects++;
        uint256 onePercentOfHardCap = (_hardCap * 1) / 100; // Calculate 1% of hard cap
        uint256 tokensToSend = onePercentOfHardCap * _tokenPrice; // Calculate tokens to send
        require(msg.value >= tokensToSend, "Insufficient funds");

        payable(address(this)).transfer(msg.value);

        projects[projectId] = Project({
            token: _token,
            name: _name,
            symbol: _symbol,
            tokenPrice: _tokenPrice,
            minPurchase: _minPurchase,
            maxPurchase: _maxPurchase,
            hardCap: _hardCap,
            raisedAmount: 0,
            startTime: _startTime,
            endTime: _endTime,
            active: false,
            tokenOwner: msg.sender
        });

        usedTokenAddresses[_token] = true;

        emit ProjectAdded(projectId);
    }

    // Function to start the sale for a project
    function startSale(uint256 projectId) external onlyAdminOrTokenOwner(projectId) {
         require(
            block.timestamp >= projects[projectId].startTime,
            "Start time has not reached "
        );
        require(!projects[projectId].active, "Sale is not active");
        projects[projectId].active = true;
        emit SaleStarted(
            projectId,
            projects[projectId].startTime,
            projects[projectId].endTime
        );
    }

    // Function to buy tokens for a project
    function buyTokens(uint256 projectId, uint256 _tokenAmount)
        external
        payable
    {
        // require(projects[projectId].active == true, "Sale is not active");
        require(
            block.timestamp >= projects[projectId].startTime &&
                block.timestamp <= projects[projectId].endTime,
            "Sale is not started yet"
        );
        require(
            _tokenAmount >= projects[projectId].minPurchase &&
                _tokenAmount <= projects[projectId].maxPurchase,
            "Invalid token amount"
        );
        require(
            projects[projectId].raisedAmount + _tokenAmount <=
                projects[projectId].hardCap,
            "Sale hard cap reached"
        );
        uint256 cost = _tokenAmount * projects[projectId].tokenPrice;
        require(msg.value >= cost, "Insufficient funds");
        IERC20(projects[projectId].token).transfer(msg.sender, _tokenAmount);
        balances[projectId][msg.sender] += _tokenAmount;
        projects[projectId].raisedAmount += _tokenAmount;
        emit TokensPurchased(msg.sender, _tokenAmount, projectId);
    }

    // Function to end the sale for a project
    function endSale(uint256 projectId)
        external
        onlyAdminOrTokenOwner(projectId)
    {
        require(
            block.timestamp >= projects[projectId].endTime,
            "Endtime has not reached "
        );

        require(projects[projectId].active == true, "Sale is not active");

        // Transfer remaining tokens back to token owner
        uint256 remainingTokens = projects[projectId].hardCap -
            projects[projectId].raisedAmount;
        if (remainingTokens > 0) {
            IERC20(projects[projectId].token).transfer(
                projects[projectId].tokenOwner,
                remainingTokens
            );
        }

        // Mark the sale as inactive
        projects[projectId].active = false;
        emit SaleCompleted(projectId, projects[projectId].raisedAmount);
    }

    function pauseProject(uint256 projectId)
        external
        onlyAdminOrTokenOwner(projectId)
    {
        require(projects[projectId].active, "Sale is not active");
        projects[projectId].active = false;
        emit ProjectPaused(projectId);
    }

    function unPauseProject(uint256 projectId)
        external
        onlyAdminOrTokenOwner(projectId)
    {
        require(!projects[projectId].active, "Sale is already active");
        projects[projectId].active = true;
        emit ProjectUnpaused(projectId);
    }

    // Function to withdraw funds (admin only)
    function withdrawFunds() external onlyAdmin {
        payable(admin).transfer(address(this).balance);
    }

    receive() external payable {}
}
