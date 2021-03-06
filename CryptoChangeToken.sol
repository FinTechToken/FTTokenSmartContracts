pragma solidity ^0.4.23;

contract TokenERCOptional { // ethereum.org examples
    function receiveApproval( address _from, uint256 _value, address _token, bytes _extraData ) 
        public returns ( bool success_ ); 
}

//ToDo: convert string to bytes32 and do the keccak256

// This smart contract tokenizes blockchain cryptos like Bitcoin. 
// It keeps track of underlying addresses, and tokenized FTT addresses. The totals match, but the details get out of sync since FTT has 1 second blocks and low gas.
// ChangeTokens are like BitCoin where a single transaction goes to two addresses (Sending, and Change).
contract CryptoChangeToken {
    mapping ( address => uint256 ) public balanceOf; //ERC20 Required - Balance of Cryptotokens
    mapping ( address => mapping ( address => uint256 ) ) public allowance; //ERC20 Required - Balance of approvals for transferfrom

    mapping ( bytes32 => address ) public cryptoAddressReceiver; // cryptoAddress => fttAddress
    mapping ( bytes32 => uint256 ) public cryptoAddressBalance; // balance on external blockchain
    mapping ( bytes32 => mapping ( uint256 => bool ) ) public preventDuplicates; //true for cryptoAddress, cryptoBlock that we already processed.
    
    uint256 public totalSupply; // ERC20 Required
    uint256 public totalOutstanding; // Total sold
    string public name = "BitCoin"; // ERC20 Optional
    string public symbol = "C-BTC"; // ERC20 Optional
    uint8 public decimals = 18; // ERC20 Optional - 18 is most common - No fractional tokens - Note: BitCoin only has 8 decimals
    address public author; // Creator of smart contract
    address public admin; // Controller of smart contract
    address public exportEscrow; // Export moves tokens to this address. They go back to admin after external blockchain transaction.
    uint256 public totalEscrow;
    string public change; // If no external address has enough funds to export. We move funds into change first. 
    //This is also the change address when bitcoin is sent.
    uint256 public fees; // Fees we pay for internal movement of external blockchain. (To change address).
    uint256 public coveredFees; // Fees we paid;

    event Transfer( address indexed from, address indexed to, uint256 value ); // ERC20 Required
    event Approval( address indexed owner, address indexed spender, uint256 value ); // ERC20 Required
    event CryptoChange( string indexed from, string indexed to, uint256 indexed blockNumber, uint256 value, uint256 fee ); //Our BC Change
    event CryptoExternalChange( string indexed from, string indexed to, uint256 indexed blockNumber, uint256 value, uint256 fee ); //Ext Change
    event SendToAddress( string indexed cryptoAddress, address indexed sender, uint256 indexed mNow, uint256 value ); //subscribe export.

    constructor() 
        public { //Constructor
        totalSupply = 10000000000000000000000000; //10M tokens + 18 digits
        totalOutstanding = 0;
        totalEscrow = 0;
        author = msg.sender;
        admin = author;
        change = "1Co7e6gTmDEjXZQPQgDuE1jXxYu6DepCDJ"; // BitCoin Change Address
        exportEscrow = 0x00ef5d5cc77db4e7a0dee7f7159b3e74fdb90fa85a;
        balanceOf[admin] = totalSupply;
    }

    function() public payable { //Fallback function. Fail for everything. Only accept legit transactions
        require (false,"No Fallback");
    }

    function transferAdmin( address _to) 
        public returns ( bool success_ ) { //Enable transfer ownership to a smart contract in future
        require(msg.sender == admin,"Admin Function");
        balanceOf[_to] = balanceOf[admin];
        balanceOf[admin] = 0;
        admin = _to;
        return true;
    }

    function transfer( address _to, uint256 _value ) 
        public returns ( bool success_ ) {   //ERC20 Required - Transfer Tokens
        return internalTransfer(msg.sender, _to, _value);
    }
    
    function transferFrom( address _from, address _to, uint256 _value ) 
        public returns ( bool success_ ) {   // ERC20 Required - Transfer after sender is approved.
        require(_value <= allowance[_from][msg.sender], "Not Approved");
        if ( balanceOf[_from] < _value ) {   //if balance is below approval, remove approval
            allowance[_from][msg.sender] = 0; 
            return false;
        }
        allowance[_from][msg.sender] -= _value;
        return internalTransfer(_from, _to, _value);
    }

    function internalTransfer( address _from, address _to, uint256 _value ) 
        internal returns ( bool success_ ) {   // Transfor tokens. 
        require(_to != address(0),"Not able to send to 0x00");
        require(balanceOf[_from] >= _value,"Value is over balance");
        require(balanceOf[_to] + _value > balanceOf[_to],"Send positive value or overflow");
        balanceOf[_from] -= _value; 
        balanceOf[_to] += _value; 
        emit Transfer(_from, _to, _value);
        return true;
    }

    function approve( address _spender, uint256 _value ) 
        public returns ( bool success_ ) {   // ERC20 Required - Approve an address to transfor tokens
        require(balanceOf[msg.sender] >= _value,"Value approving is over balance");
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, allowance[msg.sender][_spender]);
        return true;
    }

    function unapprove( address _spender ) 
        public returns( bool success_ ) {   // Unapprove an address
        return approve(_spender,0);
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

    function internalCryptoTransfer( string _from, bool _fromExt, string _to, bool _toExt, uint256 _value, uint256 _fee, uint256 _blockNumber )
        internal returns ( bool success_ ) {   // Transfor on external blockchain (address 0 is for addresses we don't control)
        require(cryptoAddressBalance[getK(_from)] >= _value || _fromExt,"Not enough From balance if FromExt is false");
        require(_value >= _fee,"Value must be over fee");
        require(cryptoAddressBalance[getK(_to)] + ( _value - _fee ) > cryptoAddressBalance[getK(_to)],"Need positive value and overflow");
        require(fees + _fee >= fees,"Fees overflow check");
        if(!_fromExt) {
            cryptoAddressBalance[getK(_from)] -= ( _value );
        }
        if(!_toExt) {
            cryptoAddressBalance[getK(_to)] += ( _value - _fee );
        }
        uint256 feeInt = _fee;
        if(_fromExt || _toExt)
            feeInt = 0;
        fees += feeInt;
        string memory from = _from;
        string memory to = _to;
        if(_fromExt) {
            from = "";
        }
        if(_toExt) {
            to = "";
        }
        emit CryptoChange(from, to, _blockNumber, _value, feeInt);
        emit CryptoExternalChange(_from, _to, _blockNumber, _value, _fee);
        return true;
    }

    // Sends funds to holding address. Event triggers DB entry to export external funds.
    function export( string _cryptoAddress, uint256 _value )
        public returns (bool success_ ) {
        require(totalEscrow + _value > totalEscrow,"Overflow");
        require(totalOutstanding >= _value,"Value must be under outstanding tokens");
        require(_value > 0, "Value must be positive");
        internalTransfer(msg.sender, exportEscrow, _value);
        totalEscrow += _value;
        totalOutstanding -= _value;
        emit SendToAddress(_cryptoAddress, msg.sender, now, _value);
        return true;
    }

    // DynamoDB triggers this
    function createCryptoAddress( string _cryptoAddress, address _fttAddress ) 
        public returns ( bool success_ ) {
        require(msg.sender == admin,"Admin function");
        cryptoAddressReceiver[getK(_cryptoAddress)] = _fttAddress;
        return true;
    }

    // Subscribe to blockchain addresses. On receipt process by calling this.
    function receive( string _fromCryptoAddress, string _cryptoAddress, uint256 _value, uint256 _cryptoBlockNumber, uint256 _fee) 
        public returns ( bool success_ ) { // When crypto is sent to receiverAddress it is added to receivers ftt address.
        require(msg.sender == admin,"Admin function");
        require(!preventDuplicates[getK(_cryptoAddress)][_cryptoBlockNumber],"Transaction Already Processed");
        require(totalOutstanding + _value > totalOutstanding,"Positive value and overflow");
        require(_value >= _fee,"Value must be over fee");
        preventDuplicates[getK(_cryptoAddress)][_cryptoBlockNumber] = true;
        internalTransfer(admin, cryptoAddressReceiver[getK(_cryptoAddress)], _value - _fee); //checks that toAddress exists.
        internalCryptoTransfer(_fromCryptoAddress, true, _cryptoAddress, false, _value, _fee, _cryptoBlockNumber);
        totalOutstanding += (_value - _fee);
        return true;
    }

    //record movement of external blockchain after it happens.
    function moveCryptoOut( string _cryptoAddressFrom, string _cryptoAddressTo, uint256 _value, uint256 _cryptoBlockNumber, uint256 _fee)
        public returns ( bool success_ ) {
        require(msg.sender == admin,"Admin Function");
        require(_value + _fee >= _value, "Overflow");
        require(totalEscrow >= _value, "Escrow needs value");
        internalCryptoTransfer(_cryptoAddressFrom, false, _cryptoAddressTo, true, _value, _fee, _cryptoBlockNumber);
        if( getK(_cryptoAddressFrom) != getK(change) ) { // If change the change remains. If not change it gets sent to change address
            moveCryptoToChange(_cryptoAddressFrom, cryptoAddressBalance[getK(_cryptoAddressFrom)], _cryptoBlockNumber, 0);
        }
        internalTransfer(exportEscrow, admin, _value);
        totalEscrow -= _value;
        return true;
    }

    function getK( string getHash)
        public pure returns (bytes32){
        return keccak256(abi.encodePacked(getHash));
    }

    //record movement to change account after it happens.
    function moveCryptoToChange( string _cryptoAddressFrom, uint256 _value, uint256 _cryptoBlockNumber, uint256 _fee)
        public returns ( bool success_ ) {
        require(msg.sender == admin,"Admin Function");
        require(_value + _fee >= _value,"Overflow");
        require(_value == cryptoAddressBalance[getK(_cryptoAddressFrom)],"Move ALL value");
        return internalCryptoTransfer(_cryptoAddressFrom, false, change, false, _value, _fee, _cryptoBlockNumber);
    }

    function moveCryptoOutFromChange( string _cryptoAddressTo, uint256 _value, uint256 _cryptoBlockNumber, uint256 _fee)
        public returns ( bool success_ ) {
        return moveCryptoOut(change, _cryptoAddressTo, _value, _cryptoBlockNumber, _fee);
    }

    //always pay fees to change address on blockchain. 
    function payFees( uint256 _feesToPay, string _cryptoAddressFrom, uint256 _fee, uint256 _cryptoBlockNumber )
        public returns ( bool succes_ ) {
        require(msg.sender == admin,"Admin Function");
        require(coveredFees + _feesToPay > coveredFees,"Overflow");
        coveredFees += _feesToPay;
        return internalCryptoTransfer(_cryptoAddressFrom, true, change, false, _feesToPay, _fee, _cryptoBlockNumber);
    }

}
