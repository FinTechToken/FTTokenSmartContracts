pragma solidity 0.4.23;

contract TokenERC20 {
    function transfer( address _to, uint256 _value ) public returns ( bool success_ );
    function transferFrom( address _from, address _to, uint256 _value ) public returns ( bool success_ );
    function balanceOf( address ) public pure returns (uint256);
}

//copyright 2018 TuitionCoin LLC
contract EscrowSend {
    mapping ( bytes32 => uint256 ) private escrowAmount;
    mapping ( bytes32 => address ) private escrowToken;
    mapping ( bytes32 => address ) private escrowSender;
    mapping ( bytes32 => uint256 ) private escrowTime;
    mapping ( address => uint256 ) private ownerBalance;

    address private owner;

    string public name = "EscrowSend";
    bool public freeze;
    uint256 public transactionFixedFee;
    uint8 public transactionFee;
    uint8 public transactionFeeMultiple;

    event HashSent( bytes32 indexed mHash, address indexed mToken, uint256 mNow );
    event HashCached( bytes32 indexed mHash, uint256 mNow );
    event HashNeverCached( bytes32 indexed mHash, uint256 mNow);
    event MessageChangeFees( uint8 mTransFee, uint8 mTransmultiple, uint256 mTransFlatFee, uint256 mNow );
    event MessageFreeze( bool mFreeze, uint256 mNow );

    constructor() public {
        owner = msg.sender;
        transactionFixedFee = 100000000000000000; //.1 In Ether
        transactionFee = 3; //1=10%, 2=1%, 3=.1%, 4=.01%, 5=.001%, 6=.0001% (Percent of Ether or Token)
        transactionFeeMultiple = 1;
        emit MessageChangeFees(transactionFee, transactionFeeMultiple, transactionFixedFee, now);
    }

    function() payable 
        public { 
        require(false);
    }

    function freeze() 
        public returns ( bool success_ ) {
        require(owner == msg.sender);
        freeze = !freeze;
        emit MessageFreeze(freeze, now);
        return true;
    }

    function changeOwner( address _newOwner ) 
        public returns ( bool success_ ) {
        require(owner == msg.sender);
        owner = _newOwner;
        return true;
    }

    /* This can increase/decrease at any time since fees are taken on submission */
    function updateFees( uint8 _newTransactionFee, uint8 _newTransactionFeeMultiple, uint256 _newTransactionFixedFee ) 
        payable public returns ( bool success_ ) {
        require(owner == msg.sender);
        transactionFee = _newTransactionFee;
        transactionFeeMultiple = _newTransactionFeeMultiple;
        transactionFixedFee = _newTransactionFixedFee;
        emit MessageChangeFees(transactionFee, transactionFeeMultiple, transactionFixedFee, now);
        return true;
    }

    function getTransactionFee( uint256 _totalAmount ) 
        internal view returns ( uint256 theFee_ ) {
        theFee_ = ( ( _totalAmount / ( 10**uint256(transactionFee) ) ) * transactionFeeMultiple );
        require(theFee_ < _totalAmount);
        return theFee_;
    }

    function getOwnerBalance ( address _token )
        public returns ( bool success_ ) {
        require(msg.sender == owner);
        if(ownerBalance[_token] != 0){
            if(_token == address(0)) {
                msg.sender.transfer(ownerBalance[_token]);
                ownerBalance[_token] = 0;
            } else {
                TokenERC20 localToken = TokenERC20(_token);
                if ( localToken.transfer(msg.sender, ownerBalance[_token]) ) {
                    ownerBalance[_token] = 0;
                }
            }
            return true;
        } else {
            return false;
        }
    }

    function getInfo(address _token) public view returns (uint256 info_) {
        TokenERC20 localToken = TokenERC20(_token);
        return localToken.balanceOf(msg.sender);
    }

    //Call approve on _token prior to calling sendAmount
    function sendAmount( bytes32 _hash, address _token, uint256 _value ) 
        payable public returns ( bool success_ ) {
        require(!freeze);
        require(escrowAmount[_hash]==0);
        bool isToken = ( _token != address(0) && _value > 0 );
        bool isEther = ( _token == address(0) && _value == 0 );
        require(!isToken && isEther || isToken && !isEther);
        require(( isToken && msg.value == transactionFixedFee ) || (isEther && msg.value > transactionFixedFee));
        if ( isToken ) {
            require(( msg.value + ownerBalance[address(0)] ) > ownerBalance[address(0)]);
            require(( ownerBalance[_token] + getTransactionFee(_value) ) >= ownerBalance[_token]);
            TokenERC20 localToken = TokenERC20(_token);
            localToken.transferFrom(msg.sender, this, _value);
            ownerBalance[address(0)] = ( ownerBalance[address(0)] + msg.value );
            ownerBalance[_token] = ( ownerBalance[_token] + getTransactionFee(_value) );
            escrowAmount[_hash] = ( _value - getTransactionFee(_value) );
            escrowToken[_hash] = _token;
            escrowSender[_hash] = msg.sender;
            escrowTime[_hash] = now;
            success_ = true;
        }
        if ( isEther ) {
            uint256 value = msg.value - transactionFixedFee;
            require(( getTransactionFee(value) + transactionFixedFee + ownerBalance[address(0)] ) > ownerBalance[address(0)]);
            ownerBalance[address(0)] = ownerBalance[address(0)] + getTransactionFee(value) + transactionFixedFee;
            escrowAmount[_hash] = ( value - getTransactionFee(value) );
            if(escrowToken[_hash] != address(0)) {
                escrowToken[_hash] = address(0);
            }
            escrowSender[_hash] = msg.sender;
            escrowTime[_hash] = now;
            success_ = true;
        }
        if ( success_ ) {
            emit HashSent(_hash, _token, now);
        }
        return success_;
    }

    function getAmount( string _hashKey ) 
        public returns ( bool success_ ) {
        require(!freeze);
        bytes32 theHash = keccak256(_hashKey);
        require(escrowAmount[theHash] != 0);
        if(escrowToken[theHash] == address(0)) {
            msg.sender.transfer(escrowAmount[theHash]);
            escrowAmount[theHash] = 0;
            escrowSender[theHash] = address(0);
            escrowTime[theHash] = 0;
        } else {
            TokenERC20 localToken = TokenERC20(escrowToken[theHash]);
            if ( localToken.transfer(msg.sender, escrowAmount[theHash]) ) {
                escrowAmount[theHash] = 0;
                escrowToken[theHash] = address(0);
                escrowSender[theHash] = 0;
                escrowTime[theHash] = 0;
            }
        }
        emit HashCached(theHash, now);
        return true;
    }

    function getNeverCached( bytes32 _hash) 
        public returns ( bool success_ ) {
        require(escrowAmount[_hash] != 0);
        require(escrowSender[_hash] == msg.sender);
        uint256 day30 = 60*60*24*30; //60sec*60min*24hour*30days - Assumes approximately 1 second blocks.
        require(escrowTime[_hash] + day30 > escrowTime[_hash]);
        require(escrowTime[_hash] + day30 < now);
        if(escrowToken[_hash] == address(0)) {
            msg.sender.transfer(escrowAmount[_hash]);
            escrowAmount[_hash] = 0;
            escrowSender[_hash] = address(0);
            escrowTime[_hash] = 0;
        } else {
            TokenERC20 localToken = TokenERC20(escrowToken[_hash]);
            if ( localToken.transfer(msg.sender, escrowAmount[_hash]) ) {
                escrowAmount[_hash] = 0;
                escrowToken[_hash] = address(0);
                escrowSender[_hash] = 0;
                escrowTime[_hash] = 0;
            }
        }
        emit HashNeverCached(_hash, now);
        return true;
    }
}
