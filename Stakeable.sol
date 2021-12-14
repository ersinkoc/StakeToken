// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "./Ownable.sol";

contract Stakeable is Ownable {

    constructor() {
        stakeholders.push();

        // ( 10000 * (1.000075 ** (24*7))  - 10000 ) * 1.1
        rewards[7] = 139;
        rewards[30] = 610;
        rewards[60] = 1254;
        rewards[90] = 1934;
        rewards[180] = 4209;
        rewards[360] = 10028;
        startingBlockTimeStamp = block.timestamp;
    }

    uint8 private _decimals = 18; // same as coin decimal

    uint256 private currentStaked;
    uint256 private totalRewards;
    uint256 public startingBlockTimeStamp;
    uint256 public stakeLimitPerWallet = 0;

    mapping(address  => uint256) public alreadystaked;

    mapping(uint => uint256) internal rewards;

    struct Stake{
        address user;
        uint256 amount;
        uint256 since;
        uint256 reward;
        uint256 fordays;
        uint256 claimable;
    }
    struct Stakeholder{
        address user;
        Stake[] address_stakes;        
    }

    struct StakingSummary{
         uint256 total_amount;
         Stake[] stakes;
    }

    Stakeholder[] internal stakeholders;

    mapping(address => uint256) internal stakes;

    event Staked(address indexed user, uint256 amount, uint256 index, uint256 timestamp, uint fordays);

    function _changeReward(uint _day, uint256 _reward) internal {
        rewards[_day] = _reward;
    }

    function _changeStakeLimitPerWallet(uint256 _stakelimit) internal {
        stakeLimitPerWallet = _stakelimit;
    }

    function _addStakeholder(address staker) internal returns (uint256){
        stakeholders.push();
        uint256 userIndex = stakeholders.length - 1;
        stakeholders[userIndex].user = staker;
        stakes[staker] = userIndex;
        return userIndex; 
    }

    function _stake(uint256 _amount, uint _fordays) internal{
        require(_amount > 0, "Cannot stake nothing");
        require(_fordays > 0, "Cannot stake for 0 day");
        //require(currentStaked <= stakeLimit, "Stake limit reached");

        uint fordays = 99999999;
        uint256 reward = 0;
        if(rewards[_fordays]>0){
            fordays = _fordays;
            reward = rewards[_fordays];
        }
        
        uint256 interestRate = getRewardRate(block.timestamp);
        reward = reward * interestRate / 10000;

        uint256 index = stakes[msg.sender];
        uint256 timestamp = block.timestamp;

        if(index == 0){
            index = _addStakeholder(msg.sender);
        }

        stakeholders[index].address_stakes.push(Stake(msg.sender, _amount, timestamp, reward, fordays, 0));
        currentStaked += _amount;

        addStaked(msg.sender, _amount);

        emit Staked(msg.sender, _amount, index, timestamp, fordays);
    }

    function calculateStakeReward(Stake memory _current_stake) internal view returns(uint256){
        
        uint256 calculatedhours = (block.timestamp - _current_stake.since) / 1 hours;

        // If the locked day is passed
        if (calculatedhours >= (_current_stake.fordays * 24) && _current_stake.fordays != 99999999){
            return (_current_stake.amount * _current_stake.reward / 10000);
        }
        else
        {
            uint256 passedDays = calculatedhours / 24;
            // no rewards for first 3 days
            //if (passedDays < 3) return 0;

            if (passedDays > 360) passedDays = 360; // max target

            uint256 reward = 1;
            // %0.000075 per hours * %0.000065 for unlock early

            uint256 rewardPerHour = 1000075;
            if(_current_stake.fordays != 99999999) rewardPerHour = 1000065;
            if(calculatedhours>=1){
                for(uint d = 0; d < calculatedhours; d++){
                    reward = reward * rewardPerHour / 1000000;
                }
            }
            else
            {
                return 0;
            }
            
            //
            uint256 interestRate = getRewardRate(_current_stake.since);
            reward = reward * interestRate / 10000;
        
            return (_current_stake.amount * reward / 10000);
        }
    }

    function _withdrawStake(uint256 amount, uint256 index) internal returns(uint256){
        uint256 user_index = stakes[msg.sender];
        Stake memory current_stake = stakeholders[user_index].address_stakes[index];
        require(current_stake.amount >= amount, "Staking: Cannot withdraw more than you have staked");

        uint256 reward = calculateStakeReward(current_stake);
        current_stake.amount = current_stake.amount - amount;

        currentStaked -= amount;

        removeStaked(msg.sender, amount);

        totalRewards += reward;

        if(current_stake.amount == 0){
            delete stakeholders[user_index].address_stakes[index];
        }else {
            // If not empty then replace the value of it
            stakeholders[user_index].address_stakes[index].amount = current_stake.amount;
            // Reset timer of stake
        stakeholders[user_index].address_stakes[index].since = block.timestamp;    
        }

        return amount+reward;
    }

    function _withdrawAllStakes(bool _notcompleted) internal returns(uint256){
        uint256 totalWithdraw = 0;
        bool canWithdrawable = false;
        StakingSummary memory summary = StakingSummary(0, stakeholders[stakes[msg.sender]].address_stakes);
        for (uint256 s = 0; s < summary.stakes.length; s += 1){
            canWithdrawable = false;
            if(summary.stakes[s].amount>0) {

                uint256 calculatedhours = (block.timestamp - summary.stakes[s].since) / 1 hours;
                
                // Already Completed
                if(calculatedhours >= (summary.stakes[s].fordays * 24)) canWithdrawable = true;
                
                // not completed but user wants withdraw
                if(_notcompleted) canWithdrawable = true;
                
                if(canWithdrawable) {
                        uint256 reward = calculateStakeReward(summary.stakes[s]);
                        currentStaked -= summary.stakes[s].amount;

                        removeStaked(msg.sender, summary.stakes[s].amount);

                        totalRewards += reward;
                        totalWithdraw = totalWithdraw + summary.stakes[s].amount + reward;
                        delete stakeholders[stakes[msg.sender]].address_stakes[s];
                }    
            }
        }
        summary.total_amount = totalWithdraw;
        return totalWithdraw;
    }

    function hasStake(address _staker) public view returns(StakingSummary memory){
        uint256 totalStakeAmount; 
        StakingSummary memory summary = StakingSummary(0, stakeholders[stakes[_staker]].address_stakes);
        for (uint256 s = 0; s < summary.stakes.length; s += 1){
           uint256 availableReward = calculateStakeReward(summary.stakes[s]);
           summary.stakes[s].claimable = availableReward;
           totalStakeAmount = totalStakeAmount+summary.stakes[s].amount;
        }
        summary.total_amount = totalStakeAmount;
        return summary;
    }


    function _totalStakeCheck(address _staker) internal view returns(uint256){
        uint256 totalStakeAmount; 
        StakingSummary memory summary = StakingSummary(0, stakeholders[stakes[_staker]].address_stakes);
        for (uint256 s = 0; s < summary.stakes.length; s += 1){
           totalStakeAmount += totalStakeAmount+summary.stakes[s].amount;
        }
        return totalStakeAmount;
    }


    function totalTokenSupplyInStaked() public view returns(uint256){
        return currentStaked;
    }

    function getTotalRewards() public view returns(uint256){
        return totalRewards;
    }

    function getRewardRate(uint256 since) public view returns(uint256){

        uint256 elapsedDays = (since - startingBlockTimeStamp) / 1 days;
        uint256 factor = 10000;
        if(elapsedDays<=3650){
            factor -= elapsedDays;
        }else{
            factor = 6350;
        } 
        return factor;
    }

    function addStaked(address _staker, uint256 _amount) internal {
            alreadystaked[_staker] += _amount;
    }

    function removeStaked(address _staker, uint256 _amount) internal {
            alreadystaked[_staker] -= _amount;
    }

    function getStaked(address _staker) internal view returns(uint256){
        return alreadystaked[_staker];
    }
}