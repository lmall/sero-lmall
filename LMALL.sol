pragma solidity ^0.4.25;

import "./seroInterface.sol";

contract LMALL is SeroInterface{
  address private _owner;
    
  string private _symbol = "LMALL";
  string private _name ="LMALL";
  uint8 private _decimals = 18;
  string private _descp = "LMALL coin";
  uint256 private _totalSupply = 210000000 * 10 ** uint256(_decimals);

  modifier onlyOwner() {
    require(msg.sender == _owner);
    _;
  }

  constructor() public payable{
    _owner=msg.sender;
    require(sero_issueToken(_totalSupply, _symbol));
  }

  function transferOwnership(address newOwner) public onlyOwner {
    if (newOwner != address(0)) {
      _owner = newOwner;
    }
  }
  
  /**
   * @return the name of the stableCoin.
   */
  function name() public view returns (string memory) {
    return _name;
  }
    
  /**
   * @return the symbol of the stableCoin.
   */
  function symbol() public view returns (string memory) {
    return _symbol;
  }
    
  function totalSupply() public view returns (uint256) {
    return _totalSupply;
  }
    
  function balanceOf() public returns(uint256 amount) {
    return sero_balanceOf(_symbol);
  }
    
  /**
   * @return the number of decimals of the stableCoin.
   */
  function decimals() public view returns (uint8) {
    return _decimals;
  }
    
  function description() public view returns (string) {
    return _descp;
  }
    
  function setDescription(string descp)  public onlyOwner{
    _descp = descp;
  }

  function transfer(address _to, uint256 _value) public onlyOwner returns (bool success){
    return sero_send(_to, _symbol, _value, '', '');
  }
}
