// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "./Ownable.sol";

contract Stakeable is Ownable {

    constructor() {
        stakeholders.push();
        rewards[7] = 134;
        rewards[30] = 625;
        rewards[60] = 1500;
        rewards[90] = 2450;
        rewards[180] = 7200;
        rewards[360] = 19400;
    }

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

        uint fordays = 1;
        uint256 reward = 0;

        if(rewards[_fordays]>0){
            fordays = _fordays;
            reward = rewards[_fordays];
        }

        uint256 index = stakes[msg.sender];
        uint256 timestamp = block.timestamp;

        if(index == 0){
            index = _addStakeholder(msg.sender);
        }

        stakeholders[index].address_stakes.push(Stake(msg.sender, _amount, timestamp, reward, fordays, 0));
        emit Staked(msg.sender, _amount, index, timestamp, fordays);
    }

    function calculateStakeReward(Stake memory _current_stake) internal view returns(uint256){

        uint256 calculatedhours = (block.timestamp - _current_stake.since) / 1 hours;

        // If the locked day is passed
        if (calculatedhours >= (_current_stake.fordays * 24) ){
            return (_current_stake.amount * _current_stake.reward / 10000);
        }

        // if half of the locked days are passed, %10 percent of the expected interest.
        if (calculatedhours >= (_current_stake.fordays * 12) ){
            return (_current_stake.amount * _current_stake.reward / 100000);
        }

        // Penalty
          return 0;
    }

    function _withdrawStake(uint256 amount, uint256 index) internal returns(uint256){
        uint256 user_index = stakes[msg.sender];
        Stake memory current_stake = stakeholders[user_index].address_stakes[index];
        require(current_stake.amount >= amount, "Staking: Cannot withdraw more than you have staked");

        uint256 reward = calculateStakeReward(current_stake);
        current_stake.amount = current_stake.amount - amount;
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
        uint256 amount = 0;
        uint256 calculatedhours = 0;
        bool canWithdrawable = false;
        StakingSummary memory summary = StakingSummary(0, stakeholders[stakes[msg.sender]].address_stakes);
        for (uint256 s = 0; s < summary.stakes.length; s += 1){
            canWithdrawable = false;
            if(summary.stakes[s].amount>0) {

                calculatedhours = (block.timestamp - summary.stakes[s].since) / 1 hours;
                
                // Completed
                if(calculatedhours >= (summary.stakes[s].fordays * 24)) canWithdrawable = true;
                
                // not completed but user wants withdraw
                if(_notcompleted) canWithdrawable = true;
                
                if(canWithdrawable) {
                        amount += summary.stakes[s].amount + calculateStakeReward(summary.stakes[s]);
                        delete stakeholders[stakes[msg.sender]].address_stakes[s];
                }    
            }
        }
        summary.total_amount = amount;
        return amount;
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



}