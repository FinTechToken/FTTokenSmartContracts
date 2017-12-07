pragma solidity ^0.4.2;

contract TokenERCOptional { // ethereum.org examples
    function receiveApproval( address _from, uint256 _value, address _token, bytes _extraData ) returns ( bool success_ ); 
}

contract MarketPlace { // MarketPlace
    function withdraw( address _tokenAddress, uint256 _value) returns ( bool success_ );
    function accountBalance( address _tokenAddress, address _accountHolder ) returns ( uint256 amount_ );
}
// ToDo; Add Freeze
contract MarketPlaceToken {
    mapping ( address => uint256 ) public balanceOf; //ERC20 Required - Balance of MarketPlace Tokens
    mapping ( address => mapping ( address => uint256 ) ) public allowance; //ERC20 Required - Balance of approvals for transferfrom
    mapping ( address => uint256 ) public paidOut; // MarketPlace fees paid to token holder
    mapping ( address => uint256 ) public account; // Ether balance of MarketPlace Token holder

    mapping ( address => mapping ( address => uint256 ) ) public elect; //
    mapping ( address => address ) public cast; //
    mapping ( address => uint256 ) public votes; //

    uint256 public totalSupply; // ERC20 Required
    string public name = "MarketPlaceToken"; // ERC20 Optional
    string public symbol = "MPT"; // ERC20 Optional
    uint8 public decimals; // ERC20 Optional - 18 is most common - No fractional tokens
    address public author; // Creator of smart contract
    address public admin; // Controller of smart contract
    uint256 public outstandingSupply; // Tokens sold
    address public marketplaceAddress; //Address of MarketPlace
    uint256 public payouts; // MarketPlace fees per token
    uint256 public payOutLimit;
    uint8 public raise; // What is author selling MarketPlace Tokens for

    event Transfer( address indexed from, address indexed to, uint256 value ); // ERC20 Required
    event Approval( address indexed owner, address indexed spender, uint256 value ); // ERC20 Required

    function MarketPlaceToken() {   //Constructor
        totalSupply = 10000000; //10M tokens
        payOutLimit = 1000000000000000000; // 1 Ether
        author = msg.sender;
        admin = msg.sender; //ToDo: method to elect
    }

    function() payable {   //Fallback function. Fail for everything. Only accept legit transactions
        require (false);
    } 

    function transfer( address _to, uint256 _value ) returns ( bool success_ ) {   //ERC20 Required - Transfer Tokens
        return internalTransfer(msg.sender, _to, _value);
    }
    
    function transferFrom( address _from, address _to, uint256 _value ) returns ( bool success_ ) {   // ERC20 Required - Transfer after sender is approved.
        require(_value <= allowance[_from][msg.sender]);
        if ( balanceOf[_from] < _value ) {   //if balance is below approval, remove approval
            allowance[_from][msg.sender] = 0; 
            return false;
        }
        allowance[_from][msg.sender] -= _value;
        return internalTransfer(_from, _to, _value);
    }

    function internalTransfer( address _from, address _to, uint256 _value ) internal returns ( bool success_ ) {   // Transfor tokens. 
        require(_to != address(0)); // Prevent transfer to 0x0 address.
        require(balanceOf[_from] >= _value);
        require(balanceOf[_to] + _value > balanceOf[_to]);  // Overflow and > 0 check
        setPayOut(_from);
        setPayOut(_to);
        balanceOf[_from] -= _value; 
        balanceOf[_to] += _value; 
        Transfer(_from, _to, _value);
        return true;
    }

    function approve( address _spender, uint256 _value ) returns ( bool success_ ) {   // ERC20 Required - Approve an address to transfor tokens
        require(balanceOf[msg.sender] >= _value);
        allowance[msg.sender][_spender] += _value;
        Approval(msg.sender, _spender, allowance[msg.sender][_spender]);
        return true;
    }

    function unapprove( address _spender ) returns( bool success_ ) {   // Unapprove an address
        require(allowance[msg.sender][_spender] > 0);
        allowance[msg.sender][_spender] = 0;
        Approval(msg.sender, _spender, 0);
        return true;
    }

    //ToDo: What happens if they don't have receiveApproval?
    //ToDo: Check example that arguments are in right place.
    //Requires address to have function called "receiveApproval"
    function approveAndCall( address _spender, uint256 _value, bytes _extraData ) returns ( bool success_ ) {   // Approve Address & Notify _spender ( Ignore reponse )
        if ( approve(_spender, _value) ) {
            TokenERCOptional lTokenSpender = TokenERCOptional(_spender);
            lTokenSpender.receiveApproval(msg.sender, _value, this, _extraData);
            return true;
        }
        return false;
    }

    function setMarketPlace( address _marketplace ) returns ( bool success_ ) {   // Only called once to set the marketplace address
        require(msg.sender == author);
        require(marketplaceAddress == address(0));
        marketplaceAddress = _marketplace;
        return true;
    }

    function setPayOutLimit( uint256 _newPayOutLimit ) returns ( bool success_ ) {
        require(msg.sender == admin);
        payOutLimit = _newPayOutLimit;
        return true;
    } 

    function electAdmin( address _elect ) returns ( bool success_ ) {
        require(balanceOf[msg.sender] > 0);
        require(balanceOf[msg.sender] != elect[msg.sender][_elect]);
        if ( cast[msg.sender] != address(0) ) {   //remove previous vote
            votes[cast[msg.sender]] -= elect[msg.sender][cast[msg.sender]];
            elect[msg.sender][cast[msg.sender]] = 0;
        }
        elect[msg.sender][_elect] = balanceOf[msg.sender];
        votes[_elect] += balanceOf[msg.sender];
        if ( _elect != admin && votes[_elect] > totalSupply / 2 ) {
            admin = _elect;
        }
        return true;
    }

    function payOut( ) returns ( bool success_ ) {   // Distribute Ether from MarketPlace IP to token holders
        MarketPlace lMarketPlace = MarketPlace(marketplaceAddress);
        uint256 lValue = lMarketPlace.accountBalance(address(0), this);
        require(lValue >= ( lValue / totalSupply ) * totalSupply);
        lValue = ( lValue / totalSupply ) * totalSupply;
        if ( lValue > payOutLimit ) {   //1 Ether
            if ( lMarketPlace.withdraw(address(0), lValue) ) {
                payouts += lValue / totalSupply;
                return true;
            } else {
                return false;
            }
        } else {
            return false;
        }
    }

    function setPayOut( address _holder ) internal returns ( bool success_ ) {   
        if ( paidOut[_holder] < payouts ) {
            uint256 lTokens = balanceOf[_holder];
            if ( _holder == author ) {
                lTokens += totalSupply - outstandingSupply;
            }
            paidOut[_holder] = payouts;   
            account[_holder] += ( payouts - paidOut[_holder] ) * lTokens;
            return true;
        }
        return false;
    }

    function getPayOut() returns ( bool success_ ) {
        require(balanceOf[msg.sender] > 0 || msg.sender == author);
        return setPayOut(msg.sender);
    }

    function withdraw() returns ( bool success_ ) {
        uint256 lValue = account[msg.sender];
        if ( lValue > 0 ) {
            account[msg.sender] = 0;
            if ( !msg.sender.send(lValue) ) {
                account[msg.sender] = lValue;
                return false;
            }
            return true;
        }
        return false;
    }

    function increaseRaise() returns ( bool success_ ) {
        require(msg.sender == author);
        raise++;
        return true;
    }

    function buyMPT() payable returns ( bool success_ ) {
        require(msg.value > 0 && raise > 0);
        uint256 lPrice;
        uint256 lTokensLeft;
        if ( raise >= 1 && totalSupply - outstandingSupply >= 8000000 ) {
            lPrice = 2500000000000000;
            lTokensLeft = 2000000 - outstandingSupply;
        } else {
            if ( raise >= 2 && totalSupply - outstandingSupply >= 6000000 ) {
                lPrice = 25000000000000000;
                lTokensLeft = 4000000 - outstandingSupply;
            } else {
                if ( raise >= 3 && totalSupply - outstandingSupply >= 4000000 ) {
                    lPrice = 250000000000000000;
                    lTokensLeft = 6000000 - outstandingSupply;
                } else {
                    if ( raise >= 4 && totalSupply - outstandingSupply >= 2000000 ) {
                        lPrice = 2500000000000000000;
                        lTokensLeft = 8000000 - outstandingSupply;
                    } else {
                        if ( raise >= 5 && totalSupply - outstandingSupply > 0 ) {
                            lPrice = 25000000000000000000;
                            lTokensLeft = totalSupply - outstandingSupply;
                        }
                    }
                }
            }
        }
        if ( lPrice > 0 && lTokensLeft > 0 ) {
            if ( msg.value > lPrice * lTokensLeft ) {//buy everything remaining and place extra ether in account
                account[msg.sender] += msg.value - lPrice * lTokensLeft;
            } else {//buy what they can
                lTokensLeft = msg.value / lPrice;
                require(lTokensLeft * lPrice == msg.value);//send in an amount without remainders
            }            
            outstandingSupply += lTokensLeft;
            account[author] += lPrice * lTokensLeft;
            setPayOut(author);
            setPayOut(msg.sender);
            balanceOf[msg.sender] += lTokensLeft;
            Transfer(address(0), msg.sender, lTokensLeft);
            return true;
        }
        require(false); // If they can't buy return msg.value
    }
}