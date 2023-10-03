// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

//    ______     ______   ______   ______     ______     __         ______    
//   /\  __ \   /\  == \ /\__  _\ /\  __ \   /\  __ \   /\ \       /\  ___\   
//   \ \ \/\ \  \ \  _-/ \/_/\ \/ \ \ \/\ \  \ \ \/\ \  \ \ \____  \ \___  \  
//    \ \_____\  \ \_\      \ \_\  \ \_____\  \ \_____\  \ \_____\  \/\_____\ 
//     \/_____/   \/_/       \/_/   \/_____/   \/_____/   \/_____/   \/_____/ 
//                                                                      

// Website: https://optools.app
// Twitter: https://twitter.com/opToolsApp
// Telegram: https://t.me/opToolsApp

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract OpToolsLockerV1 is AccessControl, ReentrancyGuard {
    using Address for address payable;
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    struct LockInfo {
        bool exists;
        address token;
        address owner;
        uint amount;
        uint unlockTimestamp;
        uint withdrawnAmount;
    }

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    address public immutable admin;
    bool public depositsEnabled;
    uint public currentLockId;
    uint public lockFee = 0.25 ether;

    mapping (address => uint[]) public userLockIds;
    mapping (address => uint) public userLockCount;
    mapping (uint => LockInfo) public locks;

    address payable private fund;

    event TokenLocked (
        uint lockId,
        address indexed token,
        address indexed owner,
        uint amount,
        uint timestamp
    );

    event LockExtended (
        uint lockId,
        uint timestamp
    );

    event LockIncreased (
        uint lockId,
        uint amount
    );

    event LockAmountSplit (
        uint existingLockId,
        uint newLockId,
        uint amountForNewLock
    );

    event LockOwnershipTransferred (
        uint lockId,
        address owner
    );

    event TokenUnlocked (
        uint lockId,
        uint amount
    );

    constructor() {
        admin = _msgSender();
        fund = payable(0x3732003143C71C6B2879961b4088eD0A25Ec09fE);

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MANAGER_ROLE, admin);
    }

    /** PUBLIC FUNCTIONS */

    function lockToken(address owner, address token, uint amount, uint timestamp) external payable nonReentrant mustBeEnabled {
        require (amount > 0, "Amount must be larger than zero");
        require (IERC20(token).balanceOf(_msgSender()) >= amount, "Your token balance is too low");
        require (timestamp >= block.timestamp.add(24 hours), "Unlock timestamp must be at least 24 hours in the future");
        require (msg.value >= lockFee, "Payable amount must be at least equal to lock fee");

        userLockIds[owner].push(currentLockId);
        userLockCount[owner] = userLockCount[owner].add(1);

        uint balanceBefore = IERC20(token).balanceOf(address(this));
        IERC20(token).transferFrom(_msgSender(), address(this), amount);
        uint balanceAfter = IERC20(token).balanceOf(address(this));
        uint deltaBalance = balanceAfter.sub(balanceBefore);
        Address.sendValue(fund, address(this).balance);

        LockInfo memory lockInfo = LockInfo(true, token, owner, deltaBalance, timestamp, 0);
        locks[currentLockId] = lockInfo;
        emit TokenLocked(currentLockId, token, owner, deltaBalance, timestamp);
        currentLockId++;
    }

    function extendLock(uint lockId, uint timestamp) external mustBeEnabled mustBeOwner(lockId) mustBeLocked(lockId) {
        require (timestamp > locks[lockId].unlockTimestamp, "New unlock timestamp must be further in the future than previous one");
        locks[lockId].unlockTimestamp = timestamp;
        emit LockExtended(lockId, timestamp);
    }

    function increaseLock(uint lockId, uint amount) external nonReentrant mustBeEnabled mustBeOwner(lockId) mustBeLocked(lockId) {
        require (amount > 0, "Amount must be larger than zero");
        address token = locks[lockId].token;
        require (IERC20(token).balanceOf(_msgSender()) >= amount, "Your token balance is too low");

        uint balanceBefore = IERC20(token).balanceOf(address(this));
        IERC20(token).transferFrom(_msgSender(), address(this), amount);
        uint balanceAfter = IERC20(token).balanceOf(address(this));
        uint deltaBalance = balanceAfter.sub(balanceBefore);

        locks[lockId].amount = locks[lockId].amount.add(deltaBalance);
        emit LockIncreased(lockId, deltaBalance);
    }

    function splitLock(uint lockId, address owner, uint amountForNewLock, uint timestamp) external payable nonReentrant mustBeEnabled mustBeOwner(lockId) mustBeLocked(lockId) {
        require (amountForNewLock > 0, "Amount must be larger than zero");
        require (amountForNewLock <= locks[lockId].amount.sub(locks[lockId].withdrawnAmount), "Amount is bigger than withdrawable amount");
        require (timestamp >= locks[lockId].unlockTimestamp, "Unlock timestamp for split lock can not be lower than existing one");
        require (msg.value >= lockFee, "Payable amount must be at least equal to lock fee");
        address token = locks[lockId].token;

        locks[lockId].amount = locks[lockId].amount.sub(amountForNewLock);

        userLockIds[owner].push(currentLockId);
        userLockCount[owner] = userLockCount[owner].add(1);
        Address.sendValue(fund, address(this).balance);

        LockInfo memory lockInfo = LockInfo(true, token, owner, amountForNewLock, timestamp, 0);
        locks[currentLockId] = lockInfo;
        emit TokenLocked(currentLockId, token, owner, amountForNewLock, timestamp);
        emit LockAmountSplit(lockId, currentLockId, amountForNewLock);
        currentLockId++;
    }

    function transferLockOwnership(uint lockId, address newOwner) external mustBeEnabled mustBeOwner(lockId) mustBeLocked(lockId) {
        _removeLockIdFromUserArray(lockId, _msgSender());
        userLockCount[_msgSender()] = userLockCount[_msgSender()].sub(1);

        userLockIds[newOwner].push(currentLockId);
        userLockCount[newOwner] = userLockCount[newOwner].add(1);
        locks[lockId].owner = newOwner;
        emit LockOwnershipTransferred(lockId, newOwner);
    }

    function unlockToken(uint lockId, uint amount) external nonReentrant mustBeOwner(lockId) mustBeUnlocked(lockId) {
        require (amount > 0, "Amount must be bigger than zero");
        require (amount <= locks[lockId].amount.sub(locks[lockId].withdrawnAmount), "Amount is bigger than withdrawable amount");
        address token = locks[lockId].token;

        locks[lockId].withdrawnAmount = locks[lockId].withdrawnAmount.add(amount);
        if (locks[lockId].withdrawnAmount == locks[lockId].amount) {
            _removeLockIdFromUserArray(lockId, _msgSender());
            userLockCount[_msgSender()] = userLockCount[_msgSender()].sub(1);
        }

        IERC20(token).transfer(locks[lockId].owner, amount);
        emit TokenUnlocked(lockId, amount);
    }

    /** INTERNAL FUNCTIONS */

    function _removeLockIdFromUserArray(uint lockId, address owner) internal {
        for (uint i; i < userLockIds[owner].length; i++) {
            if (userLockIds[owner][i] == lockId) {
                userLockIds[owner][i] = userLockIds[owner][userLockIds[owner].length - 1];
                userLockIds[owner].pop();
                break;
            }
        }
    }

    /** RESTRICTED FUNCTIONS */

    function setDepositsEnabled(bool _depositsEnabled) external onlyRole(MANAGER_ROLE) {
        depositsEnabled = _depositsEnabled;
    }

    function setLockFee(uint _lockFee) external onlyRole(MANAGER_ROLE) {
        lockFee = _lockFee;
    }

    function setFund(address _fund) external onlyRole(MANAGER_ROLE) {
        fund = payable(_fund);
    }

    /** MODIFIERS */

    modifier mustBeLocked(uint lockId) {
        require (locks[lockId].exists, "Lock does not exist");
        require (block.timestamp < locks[lockId].unlockTimestamp, "Unlock timestamp already in the past");

        _;
    }

    modifier mustBeUnlocked(uint lockId) {
        require (locks[lockId].exists, "Lock does not exist");
        require (block.timestamp >= locks[lockId].unlockTimestamp, "Unlock timestamp is still in the future");
        require (locks[lockId].withdrawnAmount < locks[lockId].amount, "Entire lock amount has already been withdrawn");

        _;
    }

    modifier mustBeOwner(uint lockId) {
        require (locks[lockId].exists, "Lock does not exist");
        require (_msgSender() == locks[lockId].owner, "Caller is not lock owner");

        _;
    }

    modifier mustBeEnabled() {
        require (depositsEnabled, "Deposits are currently not enabled");

        _;
    }
}