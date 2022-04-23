// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { ERC4626 } from "solmate/tokens/ERC4626.sol";
import {Addresses} from "./utils/Addresses.sol";


contract Streamer {
    using SafeTransferLib for ERC20;

    /*//////////////////////////////////////////////////////////////
                                 Public variables
    //////////////////////////////////////////////////////////////*/ 

    address public owner;
    address public strategy;

    /*//////////////////////////////////////////////////////////////
                                 Structs 
    //////////////////////////////////////////////////////////////*/ 

    // user account
    struct Account {
        // balances of deposits per token - for handling multiple erc20s
        mapping(address => uint256) balances;

        // balance of base token
        uint256 balance;

        // balance of strategy 
        uint256 strategyBalance;

        // whitelisted addresses for an account (bool for active)
        // could create whitelist struct (allowance, num withdraws, etc)
        mapping(address => bool) whitelist;
    }

    struct Addresses {
        address[] tokens;
        mapping(address => uint256) indexes;
    }

    /*//////////////////////////////////////////////////////////////
                                 Events
    //////////////////////////////////////////////////////////////*/ 

    event Deposit(address indexed sender, address token, uint amount, uint balance);
    event DepositBase(address indexed sender, uint amount, uint balance);

    event Withdrawal(address indexed accountOwner, address token, uint amount, uint balance, address recipient);
    event WithdrawalBase(address indexed accountOwner, uint amount, uint balance, address recipient);

    event AuthorizedAddress(address indexed accountOwner, address indexed newAddress, bool active);

    event StrategyUpdated(address value);

    /*//////////////////////////////////////////////////////////////
                                 Custom Errors
    //////////////////////////////////////////////////////////////*/ 

    error Unauthorized(address caller);
    error InsufficientBalance();
    error InvalidAccount();
    error ERC20CallFailed(address target, bool success, bytes data);

    /*//////////////////////////////////////////////////////////////
                                 Private varialbes
    //////////////////////////////////////////////////////////////*/ 

    // map of addresses and balances
    mapping(address => Account) private _accountOwners;
    Addresses private _supportedStrategyTokens;

    constructor() {
        strategy = Addresses.FUSE_POOL_18_ADDRESS;
        owner = msg.sender;
    }

    /*//////////////////////////////////////////////////////////////
                                 External functions
    //////////////////////////////////////////////////////////////*/ 

    function getSupportedStrategyTokens() external view returns (address[] memory) {
        return _supportedStrategyTokens.tokens;
    }

    function isSupportedStrategyToken(address token) external view returns (bool) {
        return _strategyContains(token);
    }

    function setStrategy(address value) external view {
        _onlyOwner();
        strategy = value;
        emit StrategyUpdated(value);
    } 

    function authorizeAddress(address newAddress) external returns (address) {
        Account storage account = _accountOwners[msg.sender];

        // activate address 
        account.whitelist[newAddress] = true;

        emit AuthorizedAddress(msg.sender, newAddress, true);

        return newAddress;
    }

    function unauthorizeAddress(address newAddress) external returns (address) {
        Account storage account = _accountOwners[msg.sender];

        // deactivate address 
        account.whitelist[newAddress] = false;

        emit AuthorizedAddress(msg.sender, newAddress, false);

        return newAddress;
    }

    /*//////////////////////////////////////////////////////////////
                                 Base token functions
    //////////////////////////////////////////////////////////////*/ 

    receive() external payable {
        // get or create account
        Account storage account = _accountOwners[msg.sender];

        // calculate new balance
        uint256 _balance = account.balance + msg.value;

        // set balance
        account.balance = _balance;        

        emit DepositBase(msg.sender, msg.value, _balance);
    }

    function withdrawBase(uint256 amount) external payable returns (uint256) {
        _validBaseWithdrawal(amount, msg.sender);

        // get or create account
        Account storage account = _accountOwners[msg.sender];

        uint256 _balance = account.balance - msg.value;

        // set balance
        account.balance = _balance; 

        payable(msg.sender).transfer(amount);

        emit WithdrawalBase(msg.sender, amount, _balance, msg.sender);

        return _balance;
    }

    function withdrawBaseFrom(uint256 amount, address accountOwner) external payable returns (uint256) {
        _authorizedAccount(accountOwner);
        _validBaseWithdrawal(amount, accountOwner);

        // get or create account
        Account storage account = _accountOwners[accountOwner];

        uint256 _balance = account.balance - msg.value;

        // set balance
        account.balance = _balance; 

        payable(msg.sender).transfer(amount);

        emit WithdrawalBase(accountOwner, amount, _balance, msg.sender);

        return _balance;
    }

     /*//////////////////////////////////////////////////////////////
                                 Yeild Strategy Functions
    //////////////////////////////////////////////////////////////*/

    // how does the 4626 strategy know which token it is recieving and which token to return on withdraw

    function depositToStrategy(address token, uint256 amount) external returns (uint256) {
        // get or create account
        Account storage account = _accountOwners[msg.sender];

        if (_strategyContains(token)) {
            token.approve(address(strategy), amount);
            uint256 shares = ERC4626.deposit(amount, strategy); 

            // update new balance 
            uint256 newStrategyBalance = account.strategyBalance + shares;

            // set balance of strategy 
            account.strategyBalance = newStrategyBalance;
        }

        emit Deposit(msg.sender, token, amount, newStrategyBalance);

        return newStrategyBalance;
    }

    function withdrawFromStrategy(address token, uint256 amount) external returns (uint256) {
        _validStrategyWithdrawal(amount, msg.sender);

        Account storage account = _accountOwners[msg.sender];

        uint256 newStrategyBalance = account.strategyBalance - amount;

        account.strategyBalance = newStrategyBalance;

        ERC4626.withdraw(amount, msg.sender, strategy);

        emit Withdraw(msg.sender, token, amount, newStrategyBalance);

        return newStrategyBalance;
    }

    /*//////////////////////////////////////////////////////////////
                                 ERC20 Token Functions
    //////////////////////////////////////////////////////////////*/

    function deposit(address token, uint256 amount) external returns (uint256) {
        // get or create account
        Account storage account = _accountOwners[msg.sender];

        // update new balance 
        uint256 balance = account.balances[token] + shares;

        // set balance of token 
        account.balances[token] = balance;

        // transfer token
        transferFrom(msg.sender, address(this), amount);
        
        emit Deposit(msg.sender, token, amount, balance);

        return balance;
    }

    function withdraw(address token, uint256 amount) external returns (uint256) {
        _validWithdrawal(amount, msg.sender, token);

        // get or create account
        Account storage account = _accountOwners[msg.sender];

        // update new balance 
        uint256 balance = account.balances[token] - amount;

        // set balance of token 
        account.balances[token] = balance;

        // transfer token
        token.transferFrom(address(this), msg.sender, amount);
        
        emit Withdrawal(msg.sender, token, amount, balance, msg.sender);

        return balance;
    }

    function withdrawFrom(address accountOwner, address token, uint256 amount) external returns (uint256) {
        _authorizedAccount(accountOwner);
        _validWithdrawal(amount, accountOwner, token);

        // get or create account
        Account storage account = _accountOwners[accountOwner];

        // update new balance 
        uint256 balance = account.balances[token] - amount;

        // set balance of token 
        account.balances[token] = balance;

        // transfer token
        token.transferFrom(address(this), msg.sender, amount);
        
        emit Withdrawal(accountOwner, token, amount, balance, msg.sender);

        return balance;
    }
    
    /*//////////////////////////////////////////////////////////////
                                 VALIDATIONS
    //////////////////////////////////////////////////////////////*/

    // check if the msg.sender is the owner
    function _onlyOwner() internal view {
        if (msg.sender != owner) {
            revert Unauthorized(msg.sender);
        }
    }

    function _authorizedAccount(address accountOwner) internal view {
        Account storage account = _accountOwners[accountOwner];

        // check if account is authorized to withdraw from account owner
        if (account.whitelist[msg.sender] != true) {
            revert Unauthorized(msg.sender);
        }
    }

    function _validWithdrawal(uint256 amount, address account, address token) internal view {
        Account storage _account = _accountOwners[account];

        // check that the account has sufficient ERC20 balance 
        if (amount > _account.balances[token]) {
            revert InsufficientBalance();
        }
    }

    function _validBaseWithdrawal(uint256 amount, address account) internal view {
        Account storage _account = _accountOwners[account];

        // check that the account has sufficient base token balance 
        if (amount > _account.balance) {
            revert InsufficientBalance();
        }
    }

    function _validStrategyWithdrawal(uint256 amount, address account) internal view {
        Account storage _account = _accountOwners[account];

        if (amount > _account.strategyBalance) {
            revert InsufficientBalance();
        }
    }

    // check that token is supported by the current strategy 
    function _strategyContains(address token) internal view returns (bool) {
        return _supportedStrategyTokens.indexes[token] != 0;
    }

    // only a owner can add a token to the strategy 
    function _addTokenToStrategy(address token) internal returns (bool) {
        _onlyOwner();

        if (_strategyContains(token)) {
            return false;
        }
        
        _supportedStrategyTokens.tokens.push(token);
        _supportedStrategyTokens.indexes[token] = _supportedStrategyTokens.tokens.length;
        return true;
    }
}
