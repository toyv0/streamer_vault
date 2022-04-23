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

    event StrategyUpdated(address strategy, address underlying);

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
    address underlyingStrategyToken;

    constructor(address _strategy, address _owner, address _underlying) {
        strategy = _strategy; // deployed fei strategy 
        owner = _owner;
        underlyingStrategyToken = _underlying; 
    }

    /*//////////////////////////////////////////////////////////////
                                 External functions
    //////////////////////////////////////////////////////////////*/ 

    function getSupportedStrategyToken() external view returns (address) {
        return underlyingStrategyToken;
    }

    function setStrategy(address _strategy, address _underlying) external {
        _onlyOwner();
        strategy = _strategy;
        underlyingStrategyToken = _underlying;
        emit StrategyUpdated(_strategy, _underlying);
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

    function getYeildStrategyBalance(address token, address account) external view returns (uint256) {
        Account storage account = _accountOwners[account];
        return account.strategyBalance;
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

    function _depositToStrategy(uint256 amount) internal returns (uint256) {
        // get or create account
        Account storage account = _accountOwners[msg.sender];

        uint256 newStrategyBalance;

        ERC20(underlyingStrategyToken).transferFrom(msg.sender, address(this), amount);
        ERC20(underlyingStrategyToken).approve(address(strategy), amount);
        uint256 shares = ERC4626(strategy).deposit(amount, address(this)); 

        // update new balance 
        newStrategyBalance = account.strategyBalance + shares;
 
        // set balance of strategy 
        account.strategyBalance = newStrategyBalance;

        emit Deposit(msg.sender, underlyingStrategyToken, amount, newStrategyBalance);

        return newStrategyBalance;
    }

    function _withdrawFromStrategy(uint256 amount) internal returns (uint256) {
        _validStrategyWithdrawal(amount, msg.sender);
        Account storage account = _accountOwners[msg.sender];

        uint256 newStrategyBalance;

        uint256 shares = ERC4626(strategy).withdraw(amount, address(this), msg.sender); // who is owner? 
        ERC20(underlyingStrategyToken).transfer(msg.sender, amount);    

        newStrategyBalance = account.strategyBalance - shares;

        account.strategyBalance = newStrategyBalance;

        emit Withdraw(msg.sender, underlyingStrategyToken, amount, newStrategyBalance, msg.sender);

        return newStrategyBalance;
    }

    /*//////////////////////////////////////////////////////////////
                                 ERC20 Token Functions
    //////////////////////////////////////////////////////////////*/

    // add ReentrancyGuard from open zeppelin 
    function deposit(address token, uint256 amount) external returns (uint256) {
        if (underlyingStrategyToken == token) {
            _depositToStrategy(amount);
        } else {
            Account storage account = _accountOwners[msg.sender];

            // move this to internal deposit function
            // update new balance 
            uint256 balance = account.balances[token] + amount;

            // set balance of token 
            account.balances[token] = balance;

            // transfer token
            ERC20(token).transferFrom(msg.sender, address(this), amount);
            
            emit Deposit(msg.sender, token, amount, balance);

            return balance;
        }
    }

    function withdraw(address token, uint256 amount) external returns (uint256) {
        _validWithdrawal(amount, msg.sender, token);

        if (underlyingStrategyToken == token) {
            _withdrawFromStrategy(amount);
        } else {
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

    }

    function withdrawFrom(address accountOwner, address token, uint256 amount) external returns (uint256) {
        _authorizedAccount(accountOwner);
        _validWithdrawal(amount, accountOwner, token);

        // get or create account
        Account storage account = _accountOwners[accountOwner];

        if (underlyingStrategyToken == token) {
            _withdrawFromStrategy(amount);
        } else {
            // update new balance 
            uint256 balance = account.balances[token] - amount;

            // set balance of token 
            account.balances[token] = balance;

            // transfer token
            ERC20(token).transfer(msg.sender, amount);
            
            emit Withdraw(accountOwner, token, amount, balance, msg.sender);

            return balance;
        }
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

}
