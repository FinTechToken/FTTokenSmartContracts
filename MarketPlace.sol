pragma solidity ^0.4.16;

contract TokenERC20 {
    function transfer( address _to, uint256 _value ) public returns ( bool success_ );
    function transferFrom( address _from, address _to, uint256 _value ) public returns ( bool success_ );
}

//copyright 2017 TuitionCoin LLC
contract MarketPlace {
    struct Offer {
        address offerAccount;
        uint256 numberOffered;
    }
    struct Book {
        uint256 nextPrice;
        uint24 currentOffersLength;
        Offer[16777215] currentOffers;
    }
    Book offerBook;
    mapping ( address => mapping ( address => uint256 ) ) public accountBalance;
    mapping ( address => mapping ( bool => mapping ( uint256 => Book ) ) ) public offersAtPrice;
    string public name = "TokenMP";
    string public author = "copyright TuitionCoin LLC";
    address public owner;
    bool public ownerChanged;
    bool public freeze;
    uint256 public addToBookFee;
    uint8 public transactionFee;
    uint8 public transactionFeeMultiple;
    uint8 public bidDecimal = 6; // 1/10^bidDecimal. 1 = .1, 2 = .01. 

    event MessageAccountDeposit( address indexed mToken, address indexed mAccount, uint256 mValue, uint256 mNow );
    event MessageAccountWithdrawal( address indexed mToken, address indexed mAccount, uint256 mValue, uint256 mNow );
    event MessageTransaction( address indexed mToken, address indexed mFromAccount, address indexed mToAccount, uint256 mPrice, uint256 mCount, uint256 mSellerFee, uint256 mNow );
    event MessagePayTransactionFee( address indexed mToken, address indexed mFromAccount, uint256 mCount, uint256 mSellerFee, uint256 mNow);
    event MessageOffer( address indexed mToken, bool indexed mBuy, address indexed mAccount, bool mAddLiquidity, uint256 mPrice, uint256 mCount, uint256 mFee, uint256 mNow );
    event MessageChangeFees( uint8 mTransFee, uint8 mTransmultiple, uint256 mBookFee, uint256 mNow );
    event MessageOwner( address mOwner, uint256 mNow );
    event MessageFreeze( bool mFreeze, uint256 mNow );

    function MarketPlace() public {
        owner = msg.sender;
        addToBookFee = 1000000000000000;
        transactionFee = 3; //1=10%, 2=1%, 3=.1%, 4=.01%, 5=.001%, 6=.0001%
        transactionFeeMultiple = 1;
        MessageChangeFees(transactionFee, transactionFeeMultiple, addToBookFee, now);
        MessageOwner(owner, now);
    }

    function() payable public { 
        require(false);
    }

    //Call approve on _token prior to calling deposit
    function deposit( address _token, uint256 _value ) payable public returns ( bool success_ ) {
        require(!freeze);
        if ( _token != address(0) && _value > 0 ) {
            require(accountBalance[_token][msg.sender] + _value >= accountBalance[_token][msg.sender]);
            TokenERC20 localToken = TokenERC20(_token);
            if ( localToken.transferFrom(msg.sender, this, _value) ) {
                accountBalance[_token][msg.sender] += _value;
                MessageAccountDeposit(_token, msg.sender, _value, now);
                success_ = true;
            } else {
                require(false);
            }
        }
        if ( msg.value > 0 ) {
            require(accountBalance[address(0)][msg.sender] + msg.value >= accountBalance[address(0)][msg.sender]);
            accountBalance[address(0)][msg.sender] += msg.value;
            MessageAccountDeposit(address(0), msg.sender, msg.value, now);
            success_ = true;
        }
        return success_;
    }

    function withdrawal( address _token, uint256 _value) public returns ( bool success_ ) {
        require(accountBalance[_token][msg.sender] >= _value);
        accountBalance[_token][msg.sender] -= _value;
        if ( _token == address(0) ) {
            if ( !msg.sender.send(_value) ) {
                require(false);
            }
        } else {
            TokenERC20 localToken = TokenERC20(_token);
            if ( !localToken.transfer(msg.sender, _value) ) {
                require(false);
            }
        }
        MessageAccountWithdrawal(_token, msg.sender, _value, now);
        return true;
    }

    function makeOffer( address _token, bool _buy, uint256 _amount, uint256 _shares, uint256 _startAmount ) public returns ( bool success_ ) {
        require(!freeze);
        require(_shares != 0);
        require(_amount != 0);
        require(_amount != 2**256 - 1);
        require(_token != address(0));
        require(( _amount * _shares ) / _shares == _amount);
        require((_amount * _shares) / (10**uint256(bidDecimal)) + addToBookFee >= (_amount * _shares) / (10**uint256(bidDecimal)));
        require(((_amount * _shares ) / (10**uint256(bidDecimal))) * (10**uint256(bidDecimal)) == _amount * _shares);
        if ( _buy ) {
            require(accountBalance[address(0)][msg.sender] >= _amount * _shares / (10**uint256(bidDecimal)) + addToBookFee);
        } else {
            require(accountBalance[_token][msg.sender] >= _shares);
            require(((_amount * _shares) / (10**uint256(bidDecimal))) - getTransactionFee((_amount * _shares) / (10**uint256(bidDecimal))) >= addToBookFee);
        }
        uint256[8] memory localVars;
        // use memory to avoid stack too deep
        // lAmountIndex=0;
        // lBidIndex=1;
        // lMyLength=2;
        // lTemp=3;
        // lEtherTrade=4
        // lAddToBookFeeTrade=5
        // localTokenTrade=6
        // localTransactionFee = 7;
        bool noBidFee = false;
        if ( offersAtPrice[_token][false][0].nextPrice == 0 ) {
            offersAtPrice[_token][false][0].nextPrice = 2**256 - 1;
        }
        while ( ( _buy && offersAtPrice[_token][!_buy][0].nextPrice <= _amount ) || ( !_buy && offersAtPrice[_token][!_buy][0].nextPrice >= _amount ) ) {
            localVars[0] = offersAtPrice[_token][!_buy][0].nextPrice;
            localVars[2] = offersAtPrice[_token][!_buy][localVars[0]].currentOffersLength;
            for ( localVars[1] = 0; localVars[1] < localVars[2]; localVars[1]++ ) {
                if ( _shares < offersAtPrice[_token][!_buy][localVars[0]].currentOffers[localVars[1]].numberOffered ) {
                    if ( _shares == 0 ) {
                        completeTrade(localVars[7], localVars[4], localVars[5], localVars[6], _token, _buy);
                        return true;
                    }
                    offersAtPrice[_token][!_buy][localVars[0]].currentOffers[localVars[1]].numberOffered -= _shares;
                    MessageOffer(_token, !_buy, offersAtPrice[_token][!_buy][localVars[0]].currentOffers[localVars[1]].offerAccount, false, localVars[0], _shares, 0, now);
                    if ( _buy ) {                        
                        localVars[3] = getTransactionFee(_shares * _amount / (10**uint256(bidDecimal)));
                        MessageTransaction(_token, offersAtPrice[_token][!_buy][localVars[0]].currentOffers[localVars[1]].offerAccount, msg.sender, localVars[0], _shares, localVars[3], now);
                        localVars[7] += localVars[3];
                        accountBalance[address(0)][offersAtPrice[_token][!_buy][localVars[0]].currentOffers[localVars[1]].offerAccount] += ( (_shares * _amount) / (10**uint256(bidDecimal)) ) - localVars[3];
                    } else {
                        MessageTransaction(_token, msg.sender, offersAtPrice[_token][!_buy][localVars[0]].currentOffers[localVars[1]].offerAccount, localVars[0], _shares, 0, now);
                        accountBalance[_token][offersAtPrice[_token][!_buy][localVars[0]].currentOffers[localVars[1]].offerAccount] += _shares;
                    }
                    localVars[6] += _shares;
                    localVars[4] += (_shares * localVars[0]) / (10**uint256(bidDecimal));
                    completeTrade(localVars[7], localVars[4], localVars[5], localVars[6], _token, _buy);
                    return true;
                } else {
                    if ( offersAtPrice[_token][!_buy][localVars[0]].currentOffers[localVars[1]].numberOffered > 0 ) {
                        if ( _buy ) {
                            localVars[3] = getTransactionFee((_amount * offersAtPrice[_token][!_buy][localVars[0]].currentOffers[localVars[1]].numberOffered) / (10**uint256(bidDecimal)));
                            localVars[7] += localVars[3];
                            MessageTransaction(_token, offersAtPrice[_token][!_buy][localVars[0]].currentOffers[localVars[1]].offerAccount, msg.sender, localVars[0], offersAtPrice[_token][!_buy][localVars[0]].currentOffers[localVars[1]].numberOffered, localVars[3], now);
                            if ( ( (_amount * offersAtPrice[_token][!_buy][localVars[0]].currentOffers[localVars[1]].numberOffered) / (10**uint256(bidDecimal)) ) - localVars[3] >= addToBookFee ) {
                                accountBalance[address(0)][offersAtPrice[_token][!_buy][localVars[0]].currentOffers[localVars[1]].offerAccount] += ( (_amount * offersAtPrice[_token][!_buy][localVars[0]].currentOffers[localVars[1]].numberOffered) / (10**uint256(bidDecimal)) ) - localVars[3] - addToBookFee;
                                MessageOffer(_token, !_buy, offersAtPrice[_token][!_buy][localVars[0]].currentOffers[localVars[1]].offerAccount, false, localVars[0], offersAtPrice[_token][!_buy][localVars[0]].currentOffers[localVars[1]].numberOffered, addToBookFee, now);
                            } else {
                                accountBalance[address(0)][offersAtPrice[_token][!_buy][localVars[0]].currentOffers[localVars[1]].offerAccount] += ( (_amount * offersAtPrice[_token][!_buy][localVars[0]].currentOffers[localVars[1]].numberOffered) / (10**uint256(bidDecimal)) ) - localVars[3];
                                localVars[5] -= addToBookFee;
                                MessageOffer(_token, !_buy, offersAtPrice[_token][!_buy][localVars[0]].currentOffers[localVars[1]].offerAccount, false, localVars[0], offersAtPrice[_token][!_buy][localVars[0]].currentOffers[localVars[1]].numberOffered, 0, now);
                            }
                        } else {
                            MessageTransaction(_token, msg.sender, offersAtPrice[_token][!_buy][localVars[0]].currentOffers[localVars[1]].offerAccount, localVars[0], offersAtPrice[_token][!_buy][localVars[0]].currentOffers[localVars[1]].numberOffered, 0, now);
                            accountBalance[_token][offersAtPrice[_token][!_buy][localVars[0]].currentOffers[localVars[1]].offerAccount] += offersAtPrice[_token][!_buy][localVars[0]].currentOffers[localVars[1]].numberOffered;
                            MessageOffer(_token, !_buy, offersAtPrice[_token][!_buy][localVars[0]].currentOffers[localVars[1]].offerAccount, false, localVars[0], offersAtPrice[_token][!_buy][localVars[0]].currentOffers[localVars[1]].numberOffered, addToBookFee, now);
                        }
                        localVars[4] += ( localVars[0] * offersAtPrice[_token][!_buy][localVars[0]].currentOffers[localVars[1]].numberOffered ) / (10**uint256(bidDecimal));
                        localVars[5] += addToBookFee;
                        localVars[6] += offersAtPrice[_token][!_buy][localVars[0]].currentOffers[localVars[1]].numberOffered;
                        _shares -= offersAtPrice[_token][!_buy][localVars[0]].currentOffers[localVars[1]].numberOffered;
                        offersAtPrice[_token][!_buy][localVars[0]].currentOffers[localVars[1]].numberOffered = 0;
                    }
                }
            }
            offersAtPrice[_token][!_buy][0].nextPrice = offersAtPrice[_token][!_buy][localVars[0]].nextPrice;
            offersAtPrice[_token][!_buy][localVars[0]].currentOffersLength = 1;
            if ( _shares == 0 ) {
                completeTrade(localVars[7], localVars[4], localVars[5], localVars[6], _token, _buy);
                return true;
            }
        }
        if ( localVars[4] != 0 || localVars[6] != 0 ) {
            completeTrade(localVars[7], localVars[4], localVars[5], localVars[6], _token, _buy);
        }
        if ( offersAtPrice[_token][_buy][_amount].currentOffersLength <= 1 ) {
            addOffer(_token, _buy, _amount, _startAmount);
            offersAtPrice[_token][_buy][_amount].currentOffersLength = 10;
            offersAtPrice[_token][_buy][_amount].currentOffers[0].numberOffered = _shares;
            offersAtPrice[_token][_buy][_amount].currentOffers[0].offerAccount = msg.sender;            
        } else {
            for ( localVars[1] = 0; localVars[1] < offersAtPrice[_token][_buy][_amount].currentOffersLength; localVars[1]++ ) {
                if ( offersAtPrice[_token][_buy][_amount].currentOffers[localVars[1]].numberOffered == 0 ) {
                    offersAtPrice[_token][_buy][_amount].currentOffers[localVars[1]].numberOffered = _shares;
                    offersAtPrice[_token][_buy][_amount].currentOffers[localVars[1]].offerAccount = msg.sender;
                    localVars[1] = offersAtPrice[_token][_buy][_amount].currentOffersLength + 1;
                } else {
                    if ( offersAtPrice[_token][_buy][_amount].currentOffers[localVars[1]].offerAccount == msg.sender ) {
                        offersAtPrice[_token][_buy][_amount].currentOffers[localVars[1]].numberOffered = offersAtPrice[_token][_buy][_amount].currentOffers[localVars[1]].numberOffered + _shares;
                        localVars[1] = offersAtPrice[_token][_buy][_amount].currentOffersLength + 1;
                        noBidFee = true;
                    }
                }
            }
            if ( localVars[1] == offersAtPrice[_token][_buy][_amount].currentOffersLength ) {
                offersAtPrice[_token][_buy][_amount].currentOffersLength = offersAtPrice[_token][_buy][_amount].currentOffersLength + 10;
                offersAtPrice[_token][_buy][_amount].currentOffers[localVars[1]].numberOffered = _shares;
                offersAtPrice[_token][_buy][_amount].currentOffers[localVars[1]].offerAccount = msg.sender;
            }
        }
        if ( _buy ) {
            if ( noBidFee ) {
                accountBalance[address(0)][msg.sender] -= ( (_amount * _shares) / (10**uint256(bidDecimal)) );
                MessageOffer(_token, _buy, msg.sender, true, _amount, _shares, 0, now);
            } else {
                accountBalance[address(0)][msg.sender] -= ( (_amount * _shares) / (10**uint256(bidDecimal)) ) + addToBookFee;
                MessageOffer(_token, _buy, msg.sender, true, _amount, _shares, addToBookFee, now);
            }
        } else {
            accountBalance[_token][msg.sender] -= _shares;
            MessageOffer(_token, _buy, msg.sender, true, _amount, _shares, 0, now);
        }
        return true;
    }

    function cancelOffer( address _token, bool _buy, uint256 _amount ) public returns ( bool success_ ) {
        require(_token != address(0));
        require(_amount != 0);
        require(_amount != 2**256 - 1);
        require(offersAtPrice[_token][_buy][_amount].currentOffersLength > 1);
        bool localToDelete = true;
        uint256 localLength = offersAtPrice[_token][_buy][_amount].currentOffersLength;
        uint256 localIndex;
        success_ = false;
        for ( localIndex = 0; localIndex < localLength; localIndex++ ) {
            if ( offersAtPrice[_token][_buy][_amount].currentOffers[localIndex].numberOffered > 0 ) {
                if ( msg.sender == offersAtPrice[_token][_buy][_amount].currentOffers[localIndex].offerAccount ) {
                    if ( _buy ) {
                        accountBalance[address(0)][msg.sender] += (_amount * offersAtPrice[_token][_buy][_amount].currentOffers[localIndex].numberOffered) / (10**uint256(bidDecimal)) + addToBookFee;
                        MessageOffer(_token, _buy, msg.sender, false, _amount, offersAtPrice[_token][_buy][_amount].currentOffers[localIndex].numberOffered, addToBookFee, now);
                    } else {
                        accountBalance[_token][msg.sender] += offersAtPrice[_token][_buy][_amount].currentOffers[localIndex].numberOffered;
                        MessageOffer(_token, _buy, msg.sender, false, _amount, offersAtPrice[_token][_buy][_amount].currentOffers[localIndex].numberOffered, 0, now);
                    }
                    delete offersAtPrice[_token][_buy][_amount].currentOffers[localIndex];
                    //only base this on number to buy. save 20k
                    success_ = true;
                } else {
                    localToDelete = false;
                }
            }
        }
        if ( localToDelete ) {
            offersAtPrice[_token][_buy][_amount].currentOffersLength = 1;
        }
        return success_;
    }

    //approveAndCall to transfer tokens into TokenMP account
    function receiveApproval( address _grantor, uint256 _value, address _from,  bytes _extraData ) public returns ( bool success_ ) {
        require(!freeze);
        require(accountBalance[_from][_grantor] + _value >= accountBalance[_from][_grantor]);
        TokenERC20 localTokenFrom = TokenERC20(_from);
        if ( localTokenFrom.transferFrom(_grantor, this, _value) ) {
            accountBalance[_from][_grantor] += _value;
            MessageAccountDeposit(_from, _grantor, _value, now);
            return true;
        }
        require(false);
    }

    function changeOwner( address _newOwner ) public returns ( bool success_ ) {
        require(owner == msg.sender);
        require(!ownerChanged);
        owner = _newOwner;
        ownerChanged = true;
        MessageOwner(owner, now);
        return true;
    }

    function freeze() public returns ( bool success_ ) {
        require(owner == msg.sender);
        freeze = !freeze;
        MessageFreeze(freeze, now);
        return true;
    }

    /* If totalOffers increase owner must send in ether to cover fees.
    We chose to calculate this off-chain to save the gas for tracking offers
    If totalOffers decreases the contract has extra ether that isn't accessable.
    We chose not to make it accessable */
    function updateFees( uint8 _newTransactionFee, uint8 _newTransactionFeeMultiple, uint256 _newAddToBookFee ) payable public returns ( bool success_ ) {
        require(owner == msg.sender);
        bool lChange;
        if ( ( _newTransactionFee != 0 && transactionFee != _newTransactionFee ) || ( _newTransactionFeeMultiple != 0 && transactionFeeMultiple != _newTransactionFeeMultiple ) ) {
            transactionFee = _newTransactionFee;
            transactionFeeMultiple = _newTransactionFeeMultiple;
            lChange = true;
        }
        if ( _newAddToBookFee != 0 && _newAddToBookFee != addToBookFee ) {
            if ( _newAddToBookFee == 2**256 - 1 ) {
                _newAddToBookFee = 0;
            }
            addToBookFee = _newAddToBookFee;
            lChange = true;
        }
        if ( lChange ) {
            MessageChangeFees(transactionFee, transactionFeeMultiple, addToBookFee, now);
            return true;
        } else {
            return false;
        }
    }

    function completeTrade( uint256 _transactionFee, uint256 _etherTrade, uint256 _addToBookFeeTrade, uint256 _tokenTrade, address _token, bool _buy ) internal {
        if ( _buy ) {
            if ( _addToBookFeeTrade <= _etherTrade ) {
                accountBalance[address(0)][msg.sender] -= ( _etherTrade - _addToBookFeeTrade );
            } else {
                accountBalance[address(0)][msg.sender] += ( _addToBookFeeTrade - _etherTrade );
            }
            accountBalance[_token][msg.sender] += _tokenTrade;
        } else {
            _transactionFee += getTransactionFee(_etherTrade);
            MessagePayTransactionFee(_token, msg.sender, _tokenTrade, _transactionFee, now);
            accountBalance[_token][msg.sender] -= _tokenTrade;
            accountBalance[address(0)][msg.sender] += _etherTrade + _addToBookFeeTrade - _transactionFee;
        }
        if ( _transactionFee > 0 ) {
            accountBalance[address(0)][owner] += _transactionFee;
        }
        return;
    }

    function addOffer( address _token, bool _buy, uint256 _amount, uint256 _startAmount) internal {
        if ( _startAmount > 0 ) {
            if ( _buy ) {
                require(_startAmount > _amount);
            } else {
                require(_startAmount < _amount);
            }
        }
        Book storage localTemp = offerBook;
        if ( offersAtPrice[_token][_buy][0].nextPrice == 0 || offersAtPrice[_token][_buy][0].nextPrice == 2*256 - 1 ) {
            offersAtPrice[_token][_buy][0].nextPrice = _amount;
            if ( !_buy ) {
                offersAtPrice[_token][_buy][_amount].nextPrice = 2**256 - 1;
            }
            return;
        }
        if ( offersAtPrice[_token][_buy][_startAmount].nextPrice == 0 ) {
            _startAmount = 0;
        }
        while ( true ) {
            localTemp = offersAtPrice[_token][_buy][_startAmount];
            if ( ( _amount == localTemp.nextPrice ) ) {
                return;
            }
            if ( ( _buy && _amount > localTemp.nextPrice ) || ( !_buy && _amount < localTemp.nextPrice ) ) {
                offersAtPrice[_token][_buy][_amount].nextPrice = localTemp.nextPrice;
                offersAtPrice[_token][_buy][_startAmount].nextPrice = _amount;
                return;
            }
            _startAmount = localTemp.nextPrice;
        }
        return;
    }

    function getTransactionFee( uint256 _totalAmount ) internal constant returns ( uint256 theFee_ ) {
        return ( ( _totalAmount / ( 10**uint256(transactionFee) ) ) * transactionFeeMultiple );
    }
}
