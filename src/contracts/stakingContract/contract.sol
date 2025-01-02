
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract stakingContract is ReentrancyGuard, Ownable {
    using SafeMath for uint256;

    IERC20 public stakingToken;
    IERC20 public rewardToken;

    uint256 private constant REWARD_RATE_DENOMINATOR = 1e18;
    uint256 public rewardRate;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) private _balances;
    uint256 private _totalSupply;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);
    event RewardRateUpdated(uint256 newRate);
    event StakingTokenUpdated(address newStakingToken);
    event RewardTokenUpdated(address newRewardToken);

    constructor() Ownable() {
        stakingToken = IERC20(0x1234567890123456789012345678901234567890); // Replace with actual token address
        rewardToken = IERC20(0x0987654321098765432109876543210987654321); // Replace with actual token address
        require(address(stakingToken) != address(0), "Staking token cannot be zero address");
        require(address(rewardToken) != address(0), "Reward token cannot be zero address");
        rewardRate = 100 * 1e18; // 100 tokens per second, adjust as needed
    }

    function rewardPerToken() public view returns (uint256) {
        if (_totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored.add(
            block.timestamp.sub(lastUpdateTime).mul(rewardRate).mul(1e18).div(_totalSupply)
        );
    }

    function earned(address account) public view returns (uint256) {
        return _balances[account].mul(
            rewardPerToken().sub(userRewardPerTokenPaid[account])
        ).div(1e18).add(rewards[account]);
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    function stake(uint256 amount) external nonReentrant updateReward(msg.sender) {
        require(amount > 0, "Cannot stake 0");
        _totalSupply = _totalSupply.add(amount);
        _balances[msg.sender] = _balances[msg.sender].add(amount);
        require(stakingToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) external nonReentrant updateReward(msg.sender) {
        require(amount > 0, "Cannot withdraw 0");
        require(_balances[msg.sender] >= amount, "Insufficient balance");
        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        require(stakingToken.transfer(msg.sender, amount), "Transfer failed");
        emit Withdrawn(msg.sender, amount);
    }

    function claimRewards() external nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            require(rewardToken.transfer(msg.sender, reward), "Transfer failed");
            emit RewardsClaimed(msg.sender, reward);
        }
    }

    function setRewardRate(uint256 _rewardRate) external onlyOwner updateReward(address(0)) {
        require(_rewardRate > 0 && _rewardRate <= 1000 * 1e18, "Invalid reward rate");
        rewardRate = _rewardRate;
        emit RewardRateUpdated(_rewardRate);
    }

    function withdrawExcessTokens(IERC20 token, uint256 amount) external onlyOwner {
        require(token != stakingToken || token.balanceOf(address(this)).sub(_totalSupply) >= amount, "Cannot withdraw staked tokens");
        require(token.transfer(owner(), amount), "Transfer failed");
    }

    function setStakingToken(IERC20 _stakingToken) external onlyOwner {
        require(address(_stakingToken) != address(0), "Staking token cannot be zero address");
        stakingToken = _stakingToken;
        emit StakingTokenUpdated(address(_stakingToken));
    }

    function setRewardToken(IERC20 _rewardToken) external onlyOwner {
        require(address(_rewardToken) != address(0), "Reward token cannot be zero address");
        rewardToken = _rewardToken;
        emit RewardTokenUpdated(address(_rewardToken));
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }
}
