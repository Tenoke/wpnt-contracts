pragma solidity ^0.8.2;

import "./Waypoint.sol";
import "./ERC20/utils/SafeERC20.sol";



contract WaypointStake {
    using SafeERC20 for Waypoint;
    
    string public name = "Waypoint Staking";
    mapping(address => bool) public owners;
    Waypoint public waypoint;
    uint public lastTimestamp = 0;
    uint public totalIssued = 0;
    uint maxIssued = 2000000000000000000000000;
    uint public poolStep = 1;
    uint public rewardingPeriod = 86000; // just under 24 hours
    uint public rewardsPerPeriod =  maxIssued / 375;
    uint public totalStakingBalance = 0;

    address[] public stakers;
    mapping(address => uint) public stakingBalance; 
    mapping(address => uint) public stakedAtMul; 
    mapping(uint => uint) public rewardPerTokenAtMul; 

    uint public unlockPeriod = 86400; // 24 hours
    mapping(address => uint) public unlockAt; 
    mapping(address => uint) public unlockBalance; 
    uint public unlockBalanceTotal = 0;

    mapping(address => uint[]) public sendAmounts;
    address[] public sendAddresses; 
    uint sendAddressesIndex = 0;
    uint public gasBalance = 0;
    
    event Issue(
        uint256 rewardPerTokenAtMul,
        uint256 poolStep
    );
    event Staked(
        address from,
        uint256 amount
    );

    event UnStaked(
        address from,
        uint256 amount
    );

    event AddedOwner(
        address onwer
    );

    event RemovedOwner(
        address onwer
    );

    constructor(Waypoint _waypoint) {
        waypoint = _waypoint;
        owners[msg.sender] = true;
        emit AddedOwner(msg.sender);
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function stakeTokens(uint _amount) public {
        require(_amount > 100, "amount cannot be less than 100");
        issueTokens();

        waypoint.safeTransferFrom(msg.sender, address(this), _amount);
        uint newBalance = compound(msg.sender) + _amount;

        // Update staking balance
        totalStakingBalance = totalStakingBalance + _amount;
        stakedAtMul[msg.sender] = poolStep;
        stakingBalance[msg.sender] = newBalance;
        emit Staked(msg.sender, _amount);
    }

    function compound(address _to) public view returns (uint newBalance) {
        uint balance = stakingBalance[_to];
        if (0 < stakedAtMul[_to] &&  stakedAtMul[_to] < poolStep)
        {
            // calculate rewards
            for (uint i=stakedAtMul[_to];i<poolStep; i++) {
                balance = balance + (balance * rewardPerTokenAtMul[i] / 1e18);
            }
        }
        return balance;
    }

    function compound(address _to, uint steps) public view returns (uint newBalance) {
        uint balance = stakingBalance[_to];
        if (0 < stakedAtMul[_to] &&  stakedAtMul[_to] < steps)
        {
            // calculate rewards
            for (uint i=stakedAtMul[_to];i<steps; i++) {
                balance = balance + (balance * rewardPerTokenAtMul[i] / 1e18);
            }
        }
        return balance;
    }

    function updateStakingBalance(uint steps) public  {
        steps = min(stakedAtMul[msg.sender] + steps, poolStep);
        uint newBalance = compound(msg.sender, steps);
        stakedAtMul[msg.sender] = steps;
        stakingBalance[msg.sender] = newBalance;
    }

    function unstakeTokensRequest() public {
        require(stakingBalance[msg.sender] > 0, "staking balance cannot be 0");
        require(unlockBalance[msg.sender] == 0, "unlock balance cannot be more 0");
        issueTokens();

        uint balance = compound(msg.sender);
        totalStakingBalance = totalStakingBalance - balance;
        // Reset staking balance
        stakingBalance[msg.sender] = 0;
        unlockAt[msg.sender] = block.timestamp + unlockPeriod;
        unlockBalance[msg.sender] = balance;
        unlockBalanceTotal = unlockBalanceTotal + balance;
        emit UnStaked(msg.sender, balance);

    }

    function unstakeTokensWithdraw() public {
        require(block.timestamp > unlockAt[msg.sender]);
        waypoint.processMints(address(this));

        uint balance = unlockBalance[msg.sender];
        require(balance > 0, "unlock staking balance cannot be 0");

        delete unlockBalance[msg.sender];
        delete unlockAt[msg.sender];
        unlockBalanceTotal = unlockBalanceTotal - balance;
        waypoint.safeTransfer(msg.sender, balance);
    }

    function issueTokens() public {
        uint newTimestamp = block.timestamp;
        if (newTimestamp < lastTimestamp + rewardingPeriod) {
            return;
        }
        if (totalIssued + rewardsPerPeriod >= maxIssued){
            return;
        }
        if (totalStakingBalance < 1000){
            return;
        }
        lastTimestamp = newTimestamp;
        waypoint.mint(address(this), rewardsPerPeriod);
        rewardPerTokenAtMul[poolStep] = (rewardsPerPeriod) * 1e18 / totalStakingBalance;
        totalStakingBalance =  totalStakingBalance + (totalStakingBalance * rewardPerTokenAtMul[poolStep] / 1e18);
        poolStep = poolStep + 1;
        totalIssued = totalIssued + rewardsPerPeriod;
        emit Issue(rewardPerTokenAtMul[poolStep-1], poolStep-1);
    }

    function transfer(address _to, uint amount) external {
        // Only owner can call this function
        require(owners[msg.sender] == true, "request must be made by an owner");
        require(amount < waypoint.balanceOf(address(this)) - totalStakingBalance - unlockBalanceTotal - gasBalance, "caller cannot withdraw from used balances" );
        waypoint.safeTransfer(_to, amount);
    }

    function transferGas(address _to) external {
        // Only owner can call this function
        require(owners[msg.sender] == true, "request must be made by an owner");
        require(gasBalance + unlockBalanceTotal < waypoint.balanceOf(address(this)), "caller cannot withdraw from unlock balance" );
        waypoint.safeTransfer(_to, gasBalance);
        gasBalance = 0;
    }


    function transferBridge(address _to, uint _amount, uint _gasAmount) external {
        // for use in bridging
        require(owners[msg.sender] == true, "request must be made by an owner");
        require(_amount > 0, 'bridging amount must be more than 0');
        waypoint.mint(address(this), _amount + _gasAmount);
        gasBalance = gasBalance + _gasAmount;
        if (waypoint.balanceOf(address(this)) > _amount + unlockBalanceTotal) {
                waypoint.safeTransfer(_to, _amount);
        } else {
            sendAddresses.push(_to);
            sendAmounts[_to].push(_amount);
            unlockBalanceTotal = unlockBalanceTotal + _amount;
        }
    }

    function transferBridgeNoMint(address _to, uint _amount) external {
        // for use in bridging with seperate batch minting
        require(owners[msg.sender] == true, "request must be made by an owner");
        require(waypoint.balanceOf(address(this)) > _amount + unlockBalanceTotal, 'bridging amount must be more than amount and locked amount together');
        waypoint.safeTransfer(_to, _amount);
    }

    function processSends(uint nSends) external returns (bool success) {
        require(nSends > 0, 'requires processing at least 1 send');

        // for use in delayed bridging
        if (sendAddresses.length <= sendAddressesIndex) {
            return false;
        }
        uint i;
        address _to;
        uint amount;
        uint j;
        nSends = min(sendAddresses.length, sendAddressesIndex+nSends);
        // for (i=sendAddressesIndex;i<nSends;i++) {
        for (i=sendAddressesIndex;i<nSends;i++) {
            _to = sendAddresses[i];
            for (j=0;j<sendAmounts[_to].length;j++) {
                // check next amount to send
                amount = sendAmounts[_to][j];
                if (waypoint.balanceOf(address(this)) < amount + unlockBalanceTotal) {
                    return false;
                }
                if (j == sendAmounts[_to].length - 1) {
                    delete sendAmounts[_to];
                    break;
                }
                if (amount > 0) {
                    sendAmounts[_to][j] = 0;
                    break;
                }
            }

            delete sendAddresses[i];
            sendAddressesIndex = sendAddressesIndex + 1;
            unlockBalanceTotal = unlockBalanceTotal - amount;
            waypoint.safeTransfer(_to, amount);
        }
        return true;

    }

    function addOwner(address _to) public returns (bool success) {
        require(owners[msg.sender] == true, "request must be made by an owner");
        owners[_to] = true;
        emit AddedOwner(_to);
        return true;
    }

    function changeRewardsPerPeriod(uint _period) public returns (bool success) {
        require(owners[msg.sender] == true, "request must be made by an owner");
        rewardsPerPeriod = _period;
        return true;
    }

    function changeRewardingPeriod(uint _period) public returns (bool success) {
        require(owners[msg.sender] == true, "request must be made by an owner");
        rewardingPeriod = _period;
        return true;
    }

    function removeOwner(address _to) public returns (bool success) {
        require(owners[msg.sender] == true, "request must be made by an owner");
        delete owners[_to];
        emit RemovedOwner(_to);
        return true;
    }

}
