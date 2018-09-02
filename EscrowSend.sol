pragma solidity ^0.4.23;

contract TokenERC20 {
    function transfer( address _to, uint256 _value ) public returns ( bool success_ );
    function transferFrom( address _from, address _to, uint256 _value ) public returns ( bool success_ );
}

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

    function() public 
        payable { 
        require(false, "No Fallback");
    }

    function freeze() 
        public returns ( bool success_ ) {
        require(owner == msg.sender, "Admin Function");
        freeze = !freeze;
        emit MessageFreeze(freeze, now);
        return true;
    }

    function changeOwner( address _newOwner ) 
        public returns ( bool success_ ) {
        require(owner == msg.sender, "Admin Function");
        owner = _newOwner;
        return true;
    }

    /* This can increase/decrease at any time since fees are taken on submission */
    function updateFees( uint8 _newTransactionFee, uint8 _newTransactionFeeMultiple, uint256 _newTransactionFixedFee ) 
        public payable returns ( bool success_ ) {
        require(owner == msg.sender, "Admin Function");
        transactionFee = _newTransactionFee;
        transactionFeeMultiple = _newTransactionFeeMultiple;
        transactionFixedFee = _newTransactionFixedFee;
        emit MessageChangeFees(transactionFee, transactionFeeMultiple, transactionFixedFee, now);
        return true;
    }

    function getTransactionFee( uint256 _totalAmount ) 
        internal view returns ( uint256 theFee_ ) {
        theFee_ = ( ( _totalAmount / ( 10**uint256(transactionFee) ) ) * transactionFeeMultiple );
        require(theFee_ < _totalAmount, "Fee less than totalamount");
        return theFee_;
    }

    function getOwnerBalance ( address _token )
        public returns ( bool success_ ) {
        require(msg.sender == owner, "Admin Function");
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

    //Call approve on _token prior to calling sendAmount
    function sendAmount( bytes32 _hash, address _token, uint256 _value ) 
        public payable returns ( bool success_ ) {
        require(!freeze, "Frozen");
        require(escrowSender[_hash]==address(0), "Hash already used");
        bool isToken = ( _token != address(0) && _value > 0 );
        bool isEther = ( _token == address(0) && _value == 0 );
        require(!isToken && isEther || isToken && !isEther, "Send Token or Ether");
        require((isToken && msg.value == transactionFixedFee) || (isEther && (msg.value > transactionFixedFee || msg.value==0)),"Need ether fee");
        if ( isToken ) {
            require(( msg.value + ownerBalance[address(0)] ) >= ownerBalance[address(0)], "Overflow1");
            require(( ownerBalance[_token] + getTransactionFee(_value) ) >= ownerBalance[_token], "Overflow2");
            TokenERC20 localToken = TokenERC20(_token);
            if(localToken.transferFrom(msg.sender, this, _value)) {
                ownerBalance[address(0)] = ( ownerBalance[address(0)] + msg.value );
                ownerBalance[_token] = ( ownerBalance[_token] + getTransactionFee(_value) );
                escrowAmount[_hash] = ( _value - getTransactionFee(_value) );
                escrowToken[_hash] = _token;
                escrowSender[_hash] = msg.sender;
                escrowTime[_hash] = now;
                success_ = true;
            }
        }
        if ( isEther ) {
            if(msg.value > 0) {
                uint256 value = msg.value - transactionFixedFee;
                require(( getTransactionFee(value) + transactionFixedFee + ownerBalance[address(0)] ) >= ownerBalance[address(0)], "Overflow3");
                ownerBalance[address(0)] = ownerBalance[address(0)] + getTransactionFee(value) + transactionFixedFee;
                escrowAmount[_hash] = ( value - getTransactionFee(value) );
                success_ = true;
            } else if(msg.value==0) {
                escrowAmount[_hash] = 0;
                success_ = true;
            }
            if( success_ ) {
                if(escrowToken[_hash] != address(0)) {
                    escrowToken[_hash] = address(0);
                }
                escrowSender[_hash] = msg.sender;
                escrowTime[_hash] = now;
            }
        }
        if ( success_ ) {
            emit HashSent(_hash, _token, now);
        }
        return success_;
    }

    function getAmount( string _hashKey ) 
        public returns ( bool success_ ) {
        require(!freeze, "Frozen");
        bytes32 theHash = keccak256(abi.encodePacked(_hashKey));
        require(escrowSender[theHash] != address(0), "Hash must have sender");
        if(escrowAmount[theHash] != 0) {
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
                    escrowSender[theHash] = address(0);
                    escrowTime[theHash] = 0;
                }
            }
        }
        emit HashCached(theHash, now);
        return true;
    }

    function getNeverCached( bytes32 _hash) 
        public returns ( bool success_ ) {
        require(escrowSender[_hash] == msg.sender, "Must be sender");
        uint256 day30 = 60*60*24*30; //60sec*60min*24hour*30days - Assumes approximately 1 second blocks.
        require(escrowTime[_hash] + day30 > escrowTime[_hash], "30days overflow");
        require(escrowTime[_hash] + day30 < now, "Must be 30 days of blocks past hash creation");
        if(escrowAmount[_hash] != 0) {
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
                    escrowSender[_hash] = address(0);
                    escrowTime[_hash] = 0;
                }
            }
        }
        emit HashNeverCached(_hash, now);
        return true;
    }
}
