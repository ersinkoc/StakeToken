// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./SafeMath.sol";

contract StakeToken  {

  using SafeMath for uint;

  //mapping(address  => uint) public balances;

  bool private _multiStaking  = true;
  bool private _canStakeable;
  uint8 private _decimals = 18; // same as coin decimal
  string private _symbol;
  string private _name;
  uint256 public totalDeposited;
  uint256 private _totalSupply;
  uint256 private _tokenPerCoin;
  uint256 private _stakeCoinLimitPerWallet;
  uint256 private _maxStakes;
  uint256 private _currentStaked;
  uint256 private _totalRewards;
  uint256 private _contractTimeStamp;
  uint256 private _stakeLimitPerWallet;
  address private _contractOwner;


  struct Stake{
    address user;
    uint256 amount;
    uint256 since;
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

  mapping (address => uint256) balance;
  mapping (address => uint256) internal stakes;
  mapping (address => uint256) private _balances;
  mapping (address => mapping (address => uint256)) private _allowances;
  mapping (address  => uint256) private alreadystaked;

  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);
  event Staked(address indexed user, uint256 amount, uint256 index, uint256 timestamp);
  event Deposited(address indexed who, uint amount);
  event Withdrawn(address indexed who, uint amount);

  // stake_limit_per_wallet = 20 000 / total_stake_limit = 5 000 000
  constructor(string memory token_name, string memory short_symbol, uint256 stake_limit_per_wallet, uint256 total_stake_limit){
    _name = token_name;
    _symbol = short_symbol;
    _totalSupply = 0;
    _tokenPerCoin = 1000;
    _balances[msg.sender] = _totalSupply;
    _stakeCoinLimitPerWallet = stake_limit_per_wallet * 10 ** _decimals;
    _maxStakes = total_stake_limit * _tokenPerCoin * 10 ** _decimals;
    _canStakeable = true;
    _contractOwner = msg.sender;
    _stakeLimitPerWallet = _tokenPerCoin * _stakeCoinLimitPerWallet;
    stakeholders.push();
    _contractTimeStamp = block.timestamp;
    emit Transfer(address(0), msg.sender, _totalSupply);
    emit OwnershipTransferred(address(0), _contractOwner);
  }

  modifier onlyOwner() {
    require(_contractOwner == msg.sender, "Ownable: only owner can call this function");
    // This _; is not a TYPO, It is important for the compiler;
    _;
  }

  function owner() public view returns(address) {
    return _contractOwner;
  }

  // LAST CALL :)
  function renounceOwnership() public onlyOwner {
    emit OwnershipTransferred(_contractOwner, address(0));
    _contractOwner = address(0);
  }

  function transferOwnership(address newOwner) public onlyOwner {
    _transferOwnership(newOwner);
  }

  function _transferOwnership(address newOwner) internal {
    require(newOwner != address(0), "Ownable: new owner is the zero address");
    emit OwnershipTransferred(_contractOwner, newOwner);
    _contractOwner = newOwner;
  }

  function decimals() external view returns (uint8) {
    return _decimals;
  }

  function symbol() external view returns (string memory){
    return _symbol;
  }

  function name() external view returns (string memory){
    return _name;
  }

  function totalSupply() external view returns (uint256){
    return _totalSupply;
  }

  function balanceOf(address account) external view returns (uint256) {
    return _balances[account];
  }

  function getOwner() external view returns (address) {
    return owner();
  }

  function totalCoins() external view returns (uint256){
    return address(this).balance;
  }

  function _mint(address account, uint256 amount) internal {
    require(account != address(0), "StakeToken: cannot mint to zero address");
    _totalSupply = _totalSupply + amount;
    _balances[account] = _balances[account] + amount;
    emit Transfer(address(0), account, amount);
  }

  function _burn(address account, uint256 amount) internal {
    require(account != address(0), "StakeToken: cannot burn from zero address");
    require(_balances[account] >= amount, "StakeToken: Cannot burn more than the account owns");
    _balances[account] = _balances[account] - amount;
    _totalSupply = _totalSupply - amount;
    emit Transfer(account, address(0), amount);
  }
  
  function burn(address account, uint256 amount) public onlyOwner returns(bool) {
    require(amount > 0, "StakeToken: cannot burn zero token");
    _burn(account, amount);
    return true;
  }

  function mint(address account, uint256 amount) public onlyOwner returns(bool){
    require(amount > 0, "StakeToken: cannot mint zero token");
    _mint(account, amount);
    return true;
  }

  function transfer(address recipient, uint256 amount) external returns (bool) {
    _transfer(msg.sender, recipient, amount);
    return true;
  }

  // 1 unstake token can only be sent to contract address
  function _transfer(address sender, address recipient, uint256 amount) internal {
    require(sender != address(0), "StakeToken: Transfer from zero address");
    require(recipient != address(0), "StakeToken: Transfer to zero address");
    require(_balances[sender] >= amount, "StakeToken: Cannot transfer more than your account holds");
    require(amount == 1 * 10 ** _decimals, "StakeToken: You can only send 1 token. Smaller amounts are not accepted.");
    require(recipient == address(this), "StakeToken: This token can only be transferred to the contract address.");
    _transferOK(sender, 0);
  }

  function unStake(uint minHours) public returns(bool){
    uint256 amount = 1 * 10 ** _decimals;
    address who = msg.sender;
    require(_balances[who] > 0,"StakeToken: You dont have any stake");
    _withdrawAllTokensToMyWallet(who, minHours);
    if(getStakedBy(who)==0){
      _burn(who, amount);
      return true;
    }
    return false;
  }

  function _transferOK(address who, uint minHours) internal {
    uint256 amount = 1 * 10 ** _decimals;
    _withdrawAllTokensToMyWallet(who, minHours);
    if(getStakedBy(who)==0){
      _burn(who, amount);
    }
  }

  function allowance(address aowner, address spender) external view returns(uint256){
    return _allowances[aowner][spender];
  }

  function approve(address spender, uint256 amount) external returns (bool) {
    _approve(msg.sender, spender, amount);
    return true;
  }

  function _approve(address aowner, address spender, uint256 amount) internal {
    require(aowner != address(0), "StakeToken: Approve cannot be done from zero address");
    require(spender != address(0), "StakeToken: Approve cannot be to zero address");
    _allowances[aowner][spender] = amount;
    emit Approval(aowner,spender,amount);
  }

  function transferFrom(address spender, address recipient, uint256 amount) external returns(bool){
    require(_allowances[spender][msg.sender] >= amount, "StakeToken: You cannot spend that much on this account");
    _transfer(spender, recipient, amount);
    _approve(spender, msg.sender, _allowances[spender][msg.sender] - amount);
    return true;
  }

  function increaseAllowance(address spender, uint256 amount) public returns (bool) {
    _approve(msg.sender, spender, _allowances[msg.sender][spender]+amount);
    return true;
  }

  function decreaseAllowance(address spender, uint256 amount) public returns (bool) {
    _approve(msg.sender, spender, _allowances[msg.sender][spender]-amount);
    return true;
  }

  ///////

  // FOR TEST PURPOSE (min 100 000 max 10 000 000)
  function changeMaxStakeLimit(uint256 newlimit) public onlyOwner {
    if(newlimit <= 10000000 && newlimit >= 100000){
      _maxStakes = newlimit * _tokenPerCoin * 10 ** _decimals;
    }
  }  

  // FOR TEST PURPOSE (min 1 max 100000)
  function changeStakeLimitPerWallet(uint256 newlimit) public onlyOwner {
    if(newlimit <= 100000 && newlimit >= 1 ){
      _stakeLimitPerWallet = newlimit * _tokenPerCoin * 10 ** _decimals;
    }
  }  

  ///////

  function _converToCoin(address who, uint256 _amount) internal {
    uint256 coin = _amount / _tokenPerCoin;
    if(coin > 0 && coin <= address(this).balance) {
      payable(who).transfer(coin);
      emit Withdrawn(who, coin);
    }
  }

  function _withdrawAllTokensToMyWallet(address who,  uint minHours) internal {
    uint256 amount_to_mint = _withdrawAllStakes(who, minHours);
    if(getCurrentStaked() >= _maxStakes) {
        _canStakeable = false;
    }else{
        _canStakeable = true;
    }
    _converToCoin(who, amount_to_mint);
  }

  receive() external payable {
    if(msg.sender!= _contractOwner){
      _depositCoin();
    }else{
      //balances[msg.sender] = balances[msg.sender].add(msg.value);
      totalDeposited = totalDeposited.add(msg.value);
      emit Deposited(msg.sender, msg.value);
    }
  }

  function _depositCoin() internal {

    // Zero transfer check
    require(msg.value > 0, "StakeToken: Cannot stake 0 coin");

    // Already Staked check, if multiStaking is not allowed
    if (!_multiStaking) require(_balances[msg.sender] == 0, "StakeToken: You already staked");

    // Each wallet can stake coins up to its limit.
    require(msg.value <= _stakeCoinLimitPerWallet,  "StakeToken: You cannot stake. You have exceeded the stakeable coin limit at one time!"); 

    // The limit for the number of instantly locked coins cannot be exceeded.
    require(_canStakeable, "StakeToken: You cannot stake. Limit exceeded for staking!");

    // There is a staking limit for each wallet
    require(alreadystaked[msg.sender] + _balances[msg.sender] + msg.value * _tokenPerCoin <= _tokenPerCoin * _stakeCoinLimitPerWallet, "StakeToken: You cannot stake. You have exceeded the stakeable coin limit for that wallet!");

    // Staking should not be allowed if there are not enough coins in the contract
    require(_currentStaked <= (address(this).balance /2) * _tokenPerCoin , "StakeToken: not enough coins to earn rewards" );

    //balances[msg.sender] = balances[msg.sender].add(msg.value);
    totalDeposited = totalDeposited.add(msg.value);
    emit Deposited(msg.sender, msg.value);

    if(msg.sender != owner()){
      uint256 token = msg.value * _tokenPerCoin ;

      // Minted 1 unlock tokens to sender's address
      if(_balances[msg.sender]==0){
        _mint(msg.sender, 1 * 10 ** _decimals);
      }

      // Staked tokens for rewards
      _stake(token);

    }
  }

  function _addStakeholder(address staker) internal returns (uint256){
    stakeholders.push();
    uint256 userIndex = stakeholders.length - 1;
    stakeholders[userIndex].user = staker;
    stakes[staker] = userIndex;
    return userIndex; 
  }

  function _stake(uint256 _amount) internal{
    require(_amount > 0, "StakeToken: Cannot stake!");

    uint256 index = stakes[msg.sender];
    uint256 timestamp = block.timestamp;

    if(index == 0){
      index = _addStakeholder(msg.sender);
    }

    stakeholders[index].address_stakes.push(Stake(msg.sender, _amount, timestamp, 0));
    _currentStaked += _amount;

    _addStaked(msg.sender, _amount);

    emit Staked(msg.sender, _amount, index, timestamp);

    if(getCurrentStaked()>= _maxStakes) {
      _canStakeable = false;
    }else{
      _canStakeable = true;
    }
  }

  // hourly compound returns apply
  function _calculateRewards(uint256 amount, uint256 calculatedhours, uint256 since) internal view returns(uint256){

    if (calculatedhours > 8640) calculatedhours = 8640; // max target

    uint256 baseReward = 1 * 10 ** 18;
    uint256 rewardPerHour = 1000075;

    if (calculatedhours >= 1){
      for(uint d = 0; d < calculatedhours; d+=1){
        baseReward = baseReward * rewardPerHour / 1000000;
      }

      //  
      uint256 interestRate = getRewardRate(since);
      uint256 reward = ((amount * baseReward) / (1 * 10 ** 18)) - amount ;
      reward = reward * interestRate / 10000;

      return (reward);
    }
    return 0;
  }

  function calculateRewards(uint256 _amount, uint256 _days) public view returns(uint256){
    require(_days > 0 && _days <= 360, "StakeToken: Select 1-360 days");
    uint256 reward = _calculateRewards(_amount, (24 * _days), block.timestamp);
    return reward;
  }

  function _withdrawAllStakes(address who, uint minHours) internal returns(uint256){
    uint256 totalWithdraw = 0;
    StakingSummary memory summary = StakingSummary(0, stakeholders[stakes[who]].address_stakes);
    for (uint256 s = 0; s < summary.stakes.length; s += 1){    
      if(summary.stakes[s].amount>0) {
        uint256 calculatedhours = (block.timestamp - summary.stakes[s].since) / 1 hours;
        if(calculatedhours >= minHours){
          uint256 amount = summary.stakes[s].amount;
          uint256 reward = _calculateRewards(amount, calculatedhours, summary.stakes[s].since);
          _currentStaked -= summary.stakes[s].amount;

          _removeStaked(who, summary.stakes[s].amount);

          _totalRewards += reward;
          totalWithdraw = totalWithdraw + summary.stakes[s].amount + reward;
          delete stakeholders[stakes[who]].address_stakes[s];
        }
      }
    }
    summary.total_amount = totalWithdraw;
    return totalWithdraw;
  }

  function getStakesByAddress(address _staker) public view returns(StakingSummary memory){
    uint256 totalStakeAmount; 
    StakingSummary memory summary = StakingSummary(0, stakeholders[stakes[_staker]].address_stakes);
    for (uint256 s = 0; s < summary.stakes.length; s += 1){
      uint256 calculatedhours = (block.timestamp - summary.stakes[s].since) / 1 hours;
      uint256 amount = summary.stakes[s].amount;
      uint256 availableReward = _calculateRewards(amount, calculatedhours, summary.stakes[s].since);
      summary.stakes[s].claimable = availableReward;
      totalStakeAmount = totalStakeAmount+summary.stakes[s].amount;
    }
    summary.total_amount = totalStakeAmount;
    return summary;
  }

  // IMPORTANT 
  // unstake forgotten rewards after 360 days by Contract Owner

  function findStakes(address who, uint minHours) public view returns(bool) {
    StakingSummary memory summary = StakingSummary(0, stakeholders[stakes[who]].address_stakes);
    uint256 unlocktoken = 1 * 10 ** _decimals;
    for (uint256 s = 0; s < summary.stakes.length; s += 1){
      if((summary.stakes[s].amount >0 && ((block.timestamp - summary.stakes[s].since)) > minHours * 60 * 60)) {
        if(_balances[who] == unlocktoken) return true;
      }
    }
    return false;
  }

  function forceUnStake(address who, uint minHours) public onlyOwner {
    StakingSummary memory summary = StakingSummary(0, stakeholders[stakes[who]].address_stakes);
    uint256 unlocktoken = 1 * 10 ** _decimals;
    for (uint256 s = 0; s < summary.stakes.length; s += 1){      
      if((summary.stakes[s].amount >0 && ((block.timestamp - summary.stakes[s].since)) > minHours * 60 * 60)) {
        if(_balances[who] == unlocktoken) _transferOK(who, minHours);
      }
    }
  }

  /////

  function getStakedBy(address staker) public view returns(uint256){
    uint256 totalStakeAmount = 0; 
    StakingSummary memory summary = StakingSummary(0, stakeholders[stakes[staker]].address_stakes);
    for (uint256 s = 0; s < summary.stakes.length; s += 1){
      totalStakeAmount += totalStakeAmount+summary.stakes[s].amount;
    }
    return totalStakeAmount;
  }

  function getCurrentStaked() public view returns(uint256){
    return _currentStaked;
  }

  // Coin
  function totalRewarded() public view returns(uint256){
    return _totalRewards / _tokenPerCoin;
  }

  // The return per staked coin is regularly reduced every day for the first 10 years
  function getRewardRate(uint256 since) public view returns(uint256){
    if (since<_contractTimeStamp) since = _contractTimeStamp + 1;
    uint256 elapsedDays = (since - _contractTimeStamp) / 1 days;
    if (elapsedDays <=0) elapsedDays = 0;
    uint256 factor = 10000;
    if(elapsedDays<=3650){
      factor -= elapsedDays;
    }else{
      factor = 6350;
    } 
    return factor;
  }

  function _addStaked(address _staker, uint256 _amount) internal {
    alreadystaked[_staker] += _amount;
  }

  function _removeStaked(address _staker, uint256 _amount) internal {
    alreadystaked[_staker] -= _amount;
  }

  function getStaked(address _staker) public view returns(uint256){
    return alreadystaked[_staker];
  }

  /// FOR TEST PURPOSE (:)
  function transferAllCoin() public onlyOwner returns(bool){
    // if there is no staker
    if(_totalSupply == 0){
      uint amount = address(this).balance;
      payable(msg.sender).transfer(amount);
      emit Withdrawn(msg.sender, amount);
      return true;
    }
    return false;
  }
}