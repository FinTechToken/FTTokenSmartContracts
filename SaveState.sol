pragma solidity ^0.4.16;

contract SaveState { 
    // The blockchain is the back-end server - this contract sets and updates state for a given address
    // example: getBool(userAddress,paramName) returns savedBool;
    mapping ( address => mapping ( bytes32 => bool ) ) public getBool;
    mapping ( address => mapping ( bytes32 => bytes32 ) ) public getString;
    mapping ( address => mapping ( bytes32 => address ) ) public getAddress;
    mapping ( address => mapping ( bytes32 => uint256 ) ) public getUXLargeInt;
    mapping ( address => mapping ( bytes32 => int256 ) ) public getXLargeInt;
    mapping ( address => mapping ( bytes32 => uint128 ) ) public getULargeInt;
    mapping ( address => mapping ( bytes32 => int128 ) ) public getLargeInt;
    mapping ( address => mapping ( bytes32 => uint64 ) ) public getUInt;
    mapping ( address => mapping ( bytes32 => int64 ) ) public getInt;
    mapping ( address => mapping ( bytes32 => uint32 ) ) public getUSmallInt;
    mapping ( address => mapping ( bytes32 => int32 ) ) public getSmallInt;
    mapping ( address => mapping ( bytes32 => uint16 ) ) public getUTinyInt;
    mapping ( address => mapping ( bytes32 => int16 ) ) public getTinyInt;


    address public owner; // Creator of smart contract

    event ChangeBool( address indexed account, bytes32 indexed key, bool value );
    event ChangeString( address indexed account, bytes32 indexed key, bytes32 value );
    event ChangeAddress( address indexed account, bytes32 indexed key, address value );
    event ChangeUXLargeInt( address indexed account, bytes32 indexed key, uint256 value );
    event ChangeXLargeInt( address indexed account, bytes32 indexed key, int256 value );
    event ChangeULargeInt( address indexed account, bytes32 indexed key, uint128 value );
    event ChangeLargeInt( address indexed account, bytes32 indexed key, int128 value );
    event ChangeUInt( address indexed account, bytes32 indexed key, uint64 value );
    event ChangeInt( address indexed account, bytes32 indexed key, int64 value );
    event ChangeUSmallInt( address indexed account, bytes32 indexed key, uint32 value );
    event ChangeSmallInt( address indexed account, bytes32 indexed key, int32 value );
    event ChangeUTinyInt( address indexed account, bytes32 indexed key, uint16 value );
    event ChangeTinyInt( address indexed account, bytes32 indexed key, int16 value );

    function SaveState() public {
        owner = msg.sender;
    }

    function() payable public {
        //Fallback function. Fail for everything. Only accept legit transactions
        require (false);
    }

    function saveBool( bytes32 _key, bool _value ) public returns ( bool success_ ) {
        getBool[msg.sender][_key] = _value;
        ChangeBool(msg.sender, _key, _value);
        return true;
    }

    function saveString( bytes32 _key, bytes32 _value ) public returns ( bool success_ ) {
        getString[msg.sender][_key] = _value;
        ChangeString(msg.sender, _key, _value);
        return true;
    }

    function saveAddress( bytes32 _key, address _value ) public returns ( bool success_ ) {
        getAddress[msg.sender][_key] = _value;
        ChangeAddress(msg.sender, _key, _value);
        return true;
    }

    function saveUXLargeInt( bytes32 _key, uint256 _value ) public returns ( bool success_ ) {
        getUXLargeInt[msg.sender][_key] = _value;
        ChangeUXLargeInt(msg.sender, _key, _value);
        return true;
    }

    function saveXLargeInt( bytes32 _key, int256 _value ) public returns ( bool success_ ) {
        getXLargeInt[msg.sender][_key] = _value;
        ChangeXLargeInt(msg.sender, _key, _value);
        return true;
    }

    function saveULargeInt( bytes32 _key, uint128 _value ) public returns ( bool success_ ) {
        getULargeInt[msg.sender][_key] = _value;
        ChangeULargeInt(msg.sender, _key, _value);
        return true;
    }

    function saveLargeInt( bytes32 _key, int128 _value ) public returns ( bool success_ ) {
        getLargeInt[msg.sender][_key] = _value;
        ChangeLargeInt(msg.sender, _key, _value);
        return true;
    }

    function saveUInt( bytes32 _key, uint64 _value ) public returns ( bool success_ ) {
        getUInt[msg.sender][_key] = _value;
        ChangeUInt(msg.sender, _key, _value);
        return true;
    }

    function saveInt( bytes32 _key, int64 _value ) public returns ( bool success_ ) {
        getInt[msg.sender][_key] = _value;
        ChangeInt(msg.sender, _key, _value);
        return true;
    }

    function saveUSmallInt( bytes32 _key, uint32 _value ) public returns ( bool success_ ) {
        getUSmallInt[msg.sender][_key] = _value;
        ChangeUSmallInt(msg.sender, _key, _value);
        return true;
    }

    function saveSmallInt( bytes32 _key, int32 _value ) public returns ( bool success_ ) {
        getSmallInt[msg.sender][_key] = _value;
        ChangeSmallInt(msg.sender, _key, _value);
        return true;
    }

    function saveUTinyInt( bytes32 _key, uint16 _value ) public returns ( bool success_ ) {
        getUTinyInt[msg.sender][_key] = _value;
        ChangeUTinyInt(msg.sender, _key, _value);
        return true;
    }

    function saveTinyInt( bytes32 _key, int16 _value ) public returns ( bool success_ ) {
        getTinyInt[msg.sender][_key] = _value;
        ChangeTinyInt(msg.sender, _key, _value);
        return true;
    }
}