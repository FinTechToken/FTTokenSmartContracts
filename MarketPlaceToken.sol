pragma solidity ^0.4.2;

contract TokenERCOptional { // ethereum.org examples
    function receiveApproval( address _from, uint256 _value, address _token, bytes _extraData ) public returns ( bool success_ ); 
}

contract MarketPlace { // MarketPlace
    function withdraw( address _tokenAddress, uint256 _value) public returns ( bool success_ );
    function accountBalance( address _tokenAddress, address _accountHolder ) public returns ( uint256 amount_ );
}
// ToDo; Add Freeze
contract MarketPlaceToken {
    mapping ( address => uint256 ) public balanceOf; //ERC20 Required - Balance of MarketPlace Tokens
    mapping ( address => mapping ( address => uint256 ) ) public allowance; //ERC20 Required - Balance of approvals for transferfrom
    mapping ( address => uint256 ) public paidOut; // MarketPlace fees paid to token holder
    mapping ( address => uint256 ) public account; // Ether balance of MarketPlace Token holder

    mapping ( address => address ) public cast; //
    mapping ( address => uint256 ) public votes; //

    uint256 public totalSupply; // ERC20 Required
    string public name = "MarketPlaceToken"; // ERC20 Optional
    string public symbol = "MPT"; // ERC20 Optional
    uint8 public decimals = 0; // ERC20 Optional - 18 is most common - we use 0 so division for payout works.
    address public author; // Creator of smart contract
    address public admin; // Controller of smart contract
    uint256 public outstandingSupply; // Tokens sold
    address[] public marketplaceAddress; //Address of MarketPlace
    uint256 public payouts; // MarketPlace fees per token
    uint256 public payOutLimit;
    uint256 public raisePrice; 
    uint256 public raiseTokens;

    event Transfer( address indexed from, address indexed to, uint256 value ); // ERC20 Required
    event Approval( address indexed owner, address indexed spender, uint256 value ); // ERC20 Required
    event WithDrawEther(address indexed to, uint256 value, uint256 mNow);
    event NewMarketplace( address indexed marketplace, uint256 mNow );
    event NewPayout( uint256 indexed payOutLimit, uint256 mNow );
    event NewAdmin( address indexed admin, uint256 mNow );
    event NewVote( address indexed voter, address indexed votefor, uint256 total, uint256 mNow );
    event NewPayoutAmount(uint256 payouts, uint256 mNow);
    event NewAddressPaid(address indexed to, uint256 value, uint256 mNow);
    event DoingRaise(uint256 raisePrice, uint256 raiseTokens, uint256 now);
    event ChangingRaise(uint256 raisePrice, uint256 raiseTokens, uint256 now);

    function MarketPlaceToken() public {   //Constructor
        totalSupply = 1000000; //1M non-divisible tokens
        payOutLimit = 1000000000000000000; // 1 Ether
        author = msg.sender;
        admin = msg.sender;
    }

    function() public payable {   //Fallback function. Fail for everything. Only accept legit transactions
        require (false);
    } 

    function transfer( address _to, uint256 _value ) public returns ( bool success_ ) {   //ERC20 Required - Transfer Tokens
        return internalTransfer(msg.sender, _to, _value);
    }
    
    function transferFrom( address _from, address _to, uint256 _value ) public returns ( bool success_ ) {   // ERC20 Required - Transfer after sender is approved.
        require(_value <= allowance[_from][msg.sender]);
        if ( balanceOf[_from] < _value ) {   //if balance is below approval, remove approval
            allowance[_from][msg.sender] = 0; 
            return false;
        }
        allowance[_from][msg.sender] -= _value;
        Approval(_from, msg.sender, allowance[_from][msg.sender]);
        return internalTransfer(_from, _to, _value);
    }

    function internalTransfer( address _from, address _to, uint256 _value ) internal returns ( bool success_ ) {   // Transfor tokens. 
        require(_to != address(0)); // Prevent transfer to 0x0 address.
        require(balanceOf[_from] >= _value);
        require(balanceOf[_to] + _value > balanceOf[_to]);  // Overflow and > 0 check
        setPayOut(_from);
        setPayOut(_to);
        if ( cast[_from] != address(0) ) {   //remove previous vote
            votes[cast[_from]] -= _value;
            NewVote(_from, cast[_from], votes[cast[_from]], now);
        }
        if ( cast[_to] != address(0) ) {   //add new vote
            votes[cast[_to]] += _value;
            NewVote(_to, cast[_to], votes[cast[_to]], now);
        }
        balanceOf[_from] -= _value; 
        balanceOf[_to] += _value;
        Transfer(_from, _to, _value);
        return true;
    }

    function approve( address _spender, uint256 _value ) public returns ( bool success_ ) {   // ERC20 Required - Approve an address to transfor tokens
        require(balanceOf[msg.sender] >= _value);
        require(allowance[msg.sender][_spender] + _value > allowance[msg.sender][_spender]);
        require(allowance[msg.sender][_spender] + _value <= balanceOf[msg.sender]);
        allowance[msg.sender][_spender] += _value;
        Approval(msg.sender, _spender, allowance[msg.sender][_spender]);
        return true;
    }

    function unapprove( address _spender ) public returns( bool success_ ) {   // Unapprove an address
        require(allowance[msg.sender][_spender] > 0);
        allowance[msg.sender][_spender] = 0;
        Approval(msg.sender, _spender, 0);
        return true;
    }

    //ToDo: What happens if they don't have receiveApproval?
    //ToDo: Check example that arguments are in right place.
    //Requires address to have function called "receiveApproval"
    function approveAndCall( address _spender, uint256 _value, bytes _extraData ) public returns ( bool success_ ) {   // Approve Address & Notify _spender ( Ignore reponse )
        if ( approve(_spender, _value) ) {
            TokenERCOptional lTokenSpender = TokenERCOptional(_spender);
            if ( lTokenSpender.receiveApproval(msg.sender, _value, this, _extraData) ) {
                return true;
            } else {
                return false;
            }
        }
        return false;
    }

    function setMarketPlace( address _marketplace ) public returns ( bool success_ ) {   // Only called once to set the marketplace address
        require(msg.sender == admin);
        uint256 i = 0;
        while (i < marketplaceAddress.length) {
            require(_marketplace != marketplaceAddress[i]);
            i++;
        }
        marketplaceAddress.push(_marketplace);
        NewMarketplace(_marketplace, now);
        return true;
    }

    function setPayOutLimit( uint256 _newPayOutLimit ) public returns ( bool success_ ) {
        require(msg.sender == admin);
        payOutLimit = _newPayOutLimit;
        NewPayout(payOutLimit, now);
        return true;
    }

    function electAdmin( address _elect ) public returns ( bool success_ ) {
        require(balanceOf[msg.sender] > 0);
        if ( cast[msg.sender] != address(0) ) {   //remove previous vote
            votes[cast[msg.sender]] -= balanceOf[msg.sender];
            NewVote(msg.sender, cast[msg.sender], votes[cast[msg.sender]], now);
        }
        cast[msg.sender] = _elect;
        if ( _elect != address(0)) {
            votes[_elect] += balanceOf[msg.sender];
            NewVote(msg.sender, _elect, votes[_elect], now);
            if ( _elect != admin && votes[_elect] > totalSupply / 2 ) {
                admin = _elect;
                NewAdmin(admin, now);
            }
        }
        return true;
    }

    function payOut( uint256 _marketPlaceIndex) public returns ( bool success_ ) {   // Distribute Ether from MarketPlace IP to token holders
        require(_marketPlaceIndex < marketplaceAddress.length);
        MarketPlace lMarketPlace = MarketPlace(marketplaceAddress[_marketPlaceIndex]);
        uint256 lValue = lMarketPlace.accountBalance(address(0), this);
        require(lValue >= ( lValue / totalSupply ) * totalSupply);
        lValue = ( lValue / totalSupply ) * totalSupply;
        if ( lValue > payOutLimit ) {   //1 Ether
            if ( lMarketPlace.withdraw(address(0), lValue) ) {
                payouts += ( lValue / totalSupply );
                NewPayoutAmount(payouts, now);
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
            account[_holder] += ( payouts - paidOut[_holder] ) * lTokens;
            NewAddressPaid(_holder, ( payouts - paidOut[_holder] ) * lTokens, now);
            paidOut[_holder] = payouts;
            return true;
        }
        return false;
    }

    function getPayOut() public returns ( bool success_ ) {
        require(balanceOf[msg.sender] > 0 || msg.sender == author);
        return setPayOut(msg.sender);
    }

    function withdraw() public returns ( bool success_ ) {
        uint256 lValue = account[msg.sender];
        if ( lValue > 0 ) {
            account[msg.sender] = 0;
            if ( !msg.sender.send(lValue) ) {
                account[msg.sender] = lValue;
                return false;
            }
            WithDrawEther(msg.sender, lValue, now);
            return true;
        }
        return false;
    }

    function doRaise( uint256 _price, uint256 _tokens) public returns ( bool success_ ) {
        require(msg.sender == author);
        if ( raiseTokens == 0 ) {
            raiseTokens = _tokens;
            raisePrice = _price;
            DoingRaise(raisePrice, raiseTokens, now);
            return true;
        } else {
            if ( raisePrice > _price ) {
                raisePrice = _price;
                ChangingRaise(raisePrice, raiseTokens, now);
                return true;
            } else {
                return false;
            }
        }
        return false;
    }

    function buyMPT() public payable returns ( bool success_ ) {
        require(msg.value > 0);
        require(raiseTokens > 0);
        require(raisePrice > 0);
        uint256 lTokens;
        if ( msg.value > raisePrice * raiseTokens ) {//buy everything remaining and place extra ether in account
            account[msg.sender] += msg.value - ( raisePrice * raiseTokens );
            lTokens = raiseTokens;
        } else {//buy what they can
            lTokens = msg.value / raisePrice;
            require(lTokens * raisePrice == msg.value);//send in an amount without remainders
        }            
        outstandingSupply += lTokens;
        account[author] += raisePrice * lTokens;
        setPayOut(author);
        setPayOut(msg.sender);
        balanceOf[msg.sender] += lTokens;
        Transfer(address(0), msg.sender, lTokens);
        return true;
    }
}
