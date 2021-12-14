// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./Ownable.sol";
import "./Stakeable.sol";
import "./SafeMath.sol";

contract StakeToken is Ownable, Stakeable{

  using SafeMath for uint;

  mapping(address  => uint) public balances;
  uint public totalDeposited;
  mapping (address => uint) balance;

  uint private _totalSupply;
  uint8 private _decimals = 18; // same as coin decimal
  string private _symbol;
  string private _name;
  uint256 private _tokenPerCoin;
  uint256 private _stakeCoinLimit;

  mapping (address => uint256) private _balances;

  mapping (address => mapping (address => uint256)) private _allowances;
  
  event Transfer(address indexed from, address indexed to, uint256 value);

  event Approval(address indexed owner, address indexed spender, uint256 value);

  constructor(string memory token_name, string memory short_symbol, uint256 token_totalSupply, uint256 token_perCoin, uint256 token_stakeCoinLimit){
      _name = token_name;
      _symbol = short_symbol;
      _totalSupply = token_totalSupply * 10 ** _decimals;
      _tokenPerCoin = token_perCoin;
      _balances[msg.sender] = _totalSupply;
      _stakeCoinLimit = token_stakeCoinLimit * 10 ** _decimals;
      _changeStakeLimitPerWallet(_tokenPerCoin * _stakeCoinLimit);
      emit Transfer(address(0), msg.sender, _totalSupply);
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

  function getCoinBalanceInContract() external view returns (uint256){
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

  function _transfer(address sender, address recipient, uint256 amount) internal {
    require(sender != address(0), "StakeToken: transfer from zero address");
    require(recipient != address(0), "StakeToken: transfer to zero address");
    require(_balances[sender] >= amount, "StakeToken: cant transfer more than your account holds");
    _balances[sender] = _balances[sender] - amount;
    _balances[recipient] = _balances[recipient] + amount;
    emit Transfer(sender, recipient, amount);
  }

  function allowance(address owner, address spender) external view returns(uint256){
    return _allowances[owner][spender];
  }

  function approve(address spender, uint256 amount) external returns (bool) {
    _approve(msg.sender, spender, amount);
    return true;
  }

  function _approve(address owner, address spender, uint256 amount) internal {
    require(owner != address(0), "StakeToken: approve cannot be done from zero address");
    require(spender != address(0), "StakeToken: approve cannot be to zero address");
    _allowances[owner][spender] = amount;
    emit Approval(owner,spender,amount);
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

  function getRewardByDays(uint _days) public view returns(uint256){
      uint256 factor = getInterestRateToday();
      return rewards[_days] * factor / 10000;
  } 

  function changePerCoin(uint256 _tokenpercoin) public onlyOwner returns(bool) {
      require(_tokenpercoin > 0 , "StakeToken: perCoin not valid");
      _tokenPerCoin = _tokenpercoin;
      return true;
   }

   function getTokenPerCoin() public view returns(uint256){
      return _tokenPerCoin;
  } 

  function changeReward(uint _days, uint256 _reward) public onlyOwner returns(bool) {
    if (_checkValidDays(_days)){
      require(_reward > 0 , "StakeToken: Reward not valid");
      _changeReward(_days, _reward);
      return true;
    }
    return false;
  }

  function stakeForDays(uint256 _amount, uint256 _days) public {
    require(_days > 0, "StakeToken: Cannot stake  - Select 7, 30, 60, 90, 180 or 360 days");
    require(_amount <= _balances[msg.sender], "StakeToken: Cannot stake more than you own");
    require(_amount  >= 500, "StakeToken: Cannot stake less than 500 Token");
    canStake(msg.sender, _amount);

    
    if (_checkValidDays(_days)) {
      _stake(_amount, _days);
      _burn(msg.sender, _amount);
    }
  }

  function stakeWithoutEndDate(uint256 _amount) public {
    require(_amount <= _balances[msg.sender], "StakeToken: Cannot stake more than you own");
    require(_amount  >= 500, "StakeToken: Cannot stake less than 500 Token");
    canStake(msg.sender, _amount);
    _stake(_amount, 99999999);
    _burn(msg.sender, _amount);
    
  }



  function convertMyTokensToCoin(uint256 _amount) public {
    require(_amount <= _balances[msg.sender], "StakeToken: Cannot onvert more than you own");
    require(_amount >= _tokenPerCoin, "StakeToken: Cannot convert");

      //calculate Coin
      uint256 coin = _amount / _tokenPerCoin * 995 / 1000; // %0.5
      if(coin > 0 && coin <= address(this).balance) {
        _burn(msg.sender, _amount);
        payable(msg.sender).transfer(coin);
      }
  }

  // function withdrawTokensByIndex(uint256 amount, uint256 stake_index)  public {
  //   uint256 amount_to_mint = _withdrawStake(amount, stake_index);
  //   _mint(msg.sender, amount_to_mint);
  // }

  function withdrawAllTokensToMyWallet(bool _notcompleted) public {
    uint256 amount_to_mint = _withdrawAllStakes(_notcompleted);
    _mint(msg.sender, amount_to_mint);
  }

  function _checkValidDays(uint256 _days) internal pure returns(bool) {
    if (_days == 7 || _days == 30 || _days == 60 || _days == 90 || _days == 180 || _days == 360) return true;
    return false;
  }


  function totalStakeCheck(address staker) public view returns(uint256){
    return _totalStakeCheck(staker);
  }

  function canStake(address _staker, uint256 _amount) internal view returns(bool){
    
    require(totalStakeCheck(_staker) + _amount <= _tokenPerCoin * _stakeCoinLimit, "You cannot stake more than our imits");

    return true;
  }

  /// MAIN COIN

  event Deposited(address indexed who, uint amount);
  event Withdrawn(address indexed who, uint amount);

  receive() external payable {
      depositCoin();
  }

  function depositCoin() public payable {
    
    require(msg.value > 0 && msg.value < _stakeCoinLimit , "Limit Reached!");

    canStake(msg.sender, msg.value * _tokenPerCoin);

    balances[msg.sender] = balances[msg.sender].add(msg.value);
    totalDeposited = totalDeposited.add(msg.value);
    emit Deposited(msg.sender, msg.value);

    if(msg.sender != owner()){
      // Mint Tokens Who Sending Coins :)
      uint256 token = msg.value * _tokenPerCoin ;

      // Minted 1/2 tokens to sender's address
      _mint(msg.sender, token /2 );

      // Staked 1/2 tokens for rewards
      _stake(token / 2 , 99999999);
    }
  }



  // function withdrawCoin(uint _amount) internal  {
  //   require(balances[msg.sender] >= _amount);
  //   balances[msg.sender] = balances[msg.sender].sub(_amount);
  //   totalDeposited = totalDeposited.sub(_amount);
  //   payable(msg.sender).transfer(_amount);
  //   emit Withdrawn(msg.sender, _amount);
  // }


  // DELETE IT

  function withdrawCoinsToAddress(address _addresto, uint256 _amount) public onlyOwner {
    if(_amount > 0 && _amount <= address(this).balance) {
      payable(_addresto).transfer(_amount);
    }
  }



}
