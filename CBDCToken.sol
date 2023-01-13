pragma solidity ^0.4.24;

import "./Adm.sol";
import "./Ownable.sol";
import "./ERC20Pausable.sol";

contract CBDCToken is ERC20Pausable {

  string public constant name = "Real Digital";
  string public constant symbol = "BRLD";
  uint8 public constant decimals = 0;

  /*
   * Initial supply will be  10 trillion or 10*10**12
   * Each CBDC represents 1 Real Digital
  */ 

  address public owner;

  uint256 public constant INITIAL_SUPPLY = 10*10**12 * (10 ** uint256(decimals));

 // Constructor gives msg.sender all of existing tokens.
  constructor() public {
    owner = msg.sender;
    _mint(msg.sender, INITIAL_SUPPLY);
  }
}