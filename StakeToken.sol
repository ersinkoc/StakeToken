// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./Ownable.sol";
import "./Stakeable.sol";

contract StakeToken is Ownable, Stakeable{
  
  uint private _totalSupply;
  uint8 private _decimals;
  string private _symbol;
  string private _name;

  mapping (address => uint256) private _balances;

  mapping (address => mapping (address => uint256)) private _allowances;
  
  event Transfer(address indexed from, address indexed to, uint256 value);

  event Approval(address indexed owner, address indexed spender, uint256 value);

  constructor(string memory token_name, string memory short_symbol, uint8 token_decimals, uint256 token_totalSupply){
      _name = token_name;
      _symbol = short_symbol;
      _decimals = token_decimals;
      _totalSupply = token_totalSupply;
      _balances[msg.sender] = _totalSupply;
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

  function _mint(address account, uint256 amount) internal {
    require(account != address(0), "StakeToken: cannot mint to zero address");
    _totalSupply = _totalSupply + (amount);
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
      return rewards[_days];
  } 

  function changeReward(uint _days, uint256 _reward) public onlyOwner returns(bool) {
    if (_checkValidDays(_days)){
      require(_reward > 0 , "StakeToken: Reward not valid");
      _changeReward(_days, _reward);
      return true;
    }
    return false;
  }

  function stake(uint256 _amount, uint256 _days) public {
    require(_amount < _balances[msg.sender], "StakeToken: Cannot stake more than you own");
    require(_days > 0, "StakeToken: Cannot stake for 0 days");
    if (_checkValidDays(_days)) {
      _stake(_amount, _days);
      _burn(msg.sender, _amount);
    }
  }

  function withdrawStake(uint256 amount, uint256 stake_index)  public {
    uint256 amount_to_mint = _withdrawStake(amount, stake_index);
    _mint(msg.sender, amount_to_mint);
  }

  function withdrawAllStakes(bool _notcompleted) public {
    uint256 amount_to_mint = _withdrawAllStakes(_notcompleted);
    _mint(msg.sender, amount_to_mint);
  }

  function _checkValidDays(uint256 _days) internal pure returns(bool) {
    if (_days == 7 || _days == 30 || _days == 60 || _days == 90 || _days == 180 || _days == 360) return true;
    return false;
  }
}
