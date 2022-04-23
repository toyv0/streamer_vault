// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { ERC4626 } from "solmate/mixins/ERC4626.sol";

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

        // balance of yeild strategy 
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

    event Withdraw(address indexed accountOwner, address token, uint amount, uint balance, address recipient);
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

    constructor(address _strategy, address _owner) {
        strategy = _strategy; // add Addresses.FUSE_POOL_18_ADDRESS
        owner = _owner;
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

    function setStrategy(address value) external {
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

    // get the balance of a whitelisted user 
    function getAuthorizedBalance(address accountOwner) external returns (uint256) {
        Account storage account = _accountOwners[accountOwner];
        if (account.whitelist[msg.sender] = true) {
            return account.balance; 
        } else {
            return 0;
        }
    }

    // get the balance of an account 
    function getAccountBalance(address account) external view returns (uint256) {
        Account storage account = _accountOwners[account];
        
        return account.balance;
    }

    function getERC20Balance(address token, address account) external view returns (uint256) {
        Account storage account = _accountOwners[account];
        return account.balances[token];
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

    // add ReentrancyGuard from open zeppelin 
    // could make this internal and call within greater deposit function 
    function depositToStrategy(address token, uint256 amount) external returns (uint256) {
        // get or create account
        Account storage account = _accountOwners[msg.sender];
        uint256 newStrategyBalance;

        if (_strategyContains(token)) {
            //token.approve(address(strategy), amount);
            uint256 shares = ERC4626(strategy).deposit(amount, address(this)); 

            // update new balance 
            newStrategyBalance = account.strategyBalance + shares;

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

        ERC4626(token).withdraw(amount, msg.sender, strategy);

        emit Withdraw(msg.sender, token, amount, newStrategyBalance, msg.sender);

        return newStrategyBalance;
    }

    /*//////////////////////////////////////////////////////////////
                                 ERC20 Token Functions
    //////////////////////////////////////////////////////////////*/

    function deposit(address token, uint256 amount) external returns (uint256) {
        // get or create account
        Account storage account = _accountOwners[msg.sender];

        // update new balance 
        uint256 balance = account.balances[token] + amount;

        // set balance of token 
        account.balances[token] = balance;

        // transfer token
        ERC20(token).transferFrom(msg.sender, address(this), amount);
        
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
        ERC20(token).transferFrom(address(this), msg.sender, amount);
        
        emit Withdraw(msg.sender, token, amount, balance, msg.sender);

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
        ERC20(token).transfer(msg.sender, amount);
        
        emit Withdraw(accountOwner, token, amount, balance, msg.sender);

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
