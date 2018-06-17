pragma solidity ^0.4.23;

contract TokenERCOptional { // ethereum.org examples
    function receiveApproval( address _from, uint256 _value, address _token, bytes _extraData ) public returns ( bool success_ ); 
}

contract TradingToken {
    mapping ( address => uint256 ) public balanceOf; //ERC20 Required - Balance of Free Tokens
    mapping ( address => bool ) public gotFree; //Has address gotten free token
    mapping ( address => mapping ( address => uint256 ) ) public allowance; //ERC20 Required - Balance of approvals for transferfrom
    
    uint256 public totalSupply; // ERC20 Required
    uint256 public totalOutstanding;
    string public name = "TradingToken"; // ERC20 Optional
    string public symbol = "Trade"; // ERC20 Optional
    uint8 public decimals = 18; // ERC20 Optional - 18 is most common - No fractional tokens
    address public author; // Creator of smart contract
    address public admin; // Controller of smart contract
    
    event Transfer( address indexed from, address indexed to, uint256 value ); // ERC20 Required
    event Approval( address indexed owner, address indexed spender, uint256 value ); // ERC20 Required

    constructor() public { //Constructor
        totalSupply = 10000000000000000000000000; //10M tokens + 18 digits
        totalOutstanding = 0;
        author = msg.sender;
    }

    function() 
        payable public { //Fallback function. Fail for everything. Only accept legit transactions
        require (false);
    }

    function transfer( address _to, uint256 _value ) 
        public returns ( bool success_ ) {   //ERC20 Required - Transfer Tokens
        return internalTransfer(msg.sender, _to, _value);
    }
    
    function transferFrom( address _from, address _to, uint256 _value ) 
        public returns ( bool success_ ) {   // ERC20 Required - Transfer after sender is approved.
        require(_value <= allowance[_from][msg.sender]);
        if ( balanceOf[_from] < _value ) {   //if balance is below approval, remove approval
            allowance[_from][msg.sender] = 0; 
            return false;
        }
        allowance[_from][msg.sender] -= _value;
        return internalTransfer(_from, _to, _value);
    }

    function internalTransfer( address _from, address _to, uint256 _value ) 
        internal returns ( bool success_ ) {   // Transfor tokens. 
        require(_to != address(0)); // Prevent transfer to 0x0 address.
        require(balanceOf[_from] >= _value);
        require(balanceOf[_to] + _value > balanceOf[_to]);  // Overflow and > 0 check
        balanceOf[_from] -= _value; 
        balanceOf[_to] += _value; 
        emit Transfer(_from, _to, _value);
        return true;
    }

    function approve( address _spender, uint256 _value ) 
        public returns ( bool success_ ) {   // ERC20 Required - Approve an address to transfor tokens
        require(balanceOf[msg.sender] >= _value);
        allowance[msg.sender][_spender] += _value;
        emit Approval(msg.sender, _spender, allowance[msg.sender][_spender]);
        return true;
    }

    function unapprove( address _spender ) 
        public returns( bool success_ ) {   // Unapprove an address
        require(allowance[msg.sender][_spender] > 0);
        allowance[msg.sender][_spender] = 0;
        emit Approval(msg.sender, _spender, 0);
        return true;
    }

    //ToDo: What happens if they don't have receiveApproval?
    //ToDo: Check example that arguments are in right place.
    //Requires address to have function called "receiveApproval"
    function approveAndCall( address _spender, uint256 _value, bytes _extraData ) 
        public returns ( bool success_ ) {   // Approve Address & Notify _spender ( Ignore reponse )
        if ( approve(_spender, _value) ) {
            TokenERCOptional lTokenSpender = TokenERCOptional(_spender);
            lTokenSpender.receiveApproval(msg.sender, _value, this, _extraData);
            return true;
        }
        return false;
    }

    function getFreeToken() 
        public returns ( bool success_ ) {
        require(totalSupply > totalOutstanding);
        require(!gotFree[msg.sender]); 
        totalOutstanding += 5000000000000000000;
        balanceOf[msg.sender] += 5000000000000000000;
        gotFree[msg.sender] = true;
        emit Transfer(address(0), msg.sender, 5000000000000000000);
        return true;
    }
}