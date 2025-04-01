pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT

/**
 * @title Ownable
 * @dev Set contract owner with authority controls
 */
contract Ownable {
    address private _owner;
    address private _pendingOwner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initialize contract and set deployer as owner
     */
    constructor() {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), _owner);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }
    
    /**
     * @dev Throws if called by any account other than the pending owner.
     */
    modifier onlyPendingOwner() {
        require(msg.sender == _pendingOwner, "Ownable: caller is not the pending owner");
        _;
    }

    /**
     * @dev Initiates ownership transfer to a new address
     */
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _pendingOwner = newOwner;
    }
    
    /**
     * @dev Accepts ownership transfer (must be called by pending owner)
     */
    function acceptOwnership() public onlyPendingOwner {
        emit OwnershipTransferred(_owner, _pendingOwner);
        _owner = _pendingOwner;
        _pendingOwner = address(0);
    }
}

/**
 * @title Vault interface - used to update price in the Vault
 */
interface IVault {
    function updateTrxPrice(uint256 newPrice) external;
}

/**
 * @title PriceOracle
 * @dev Oracle for updating TRX/USD price in the Vault
 */
contract PriceOracle is Ownable {
    // The vault contract to update
    IVault private _vault;
    
    // Authorized oracle updaters
    mapping(address => bool) private _oracleUpdaters;
    
    // Price data
    uint256 private _currentTrxPriceInUsd; // Multiplied by 1e6 for precision
    uint256 private _lastUpdateTimestamp;
    
    // Security parameters
    uint256 private _maxPriceDeviation = 1000; // 10% max deviation per update
    uint256 private _minUpdateInterval = 1 hours; // Minimum time between updates
    
    // Events
    event PriceUpdated(uint256 newPrice, uint256 previousPrice, address updater);
    event UpdaterAdded(address indexed updater);
    event UpdaterRemoved(address indexed updater);
    event VaultUpdated(address indexed previousVault, address indexed newVault);
    event MaxDeviationUpdated(uint256 oldDeviation, uint256 newDeviation);
    event MinIntervalUpdated(uint256 oldInterval, uint256 newInterval);
    
    // Modifiers
    modifier onlyUpdater() {
        require(_oracleUpdaters[msg.sender] || msg.sender == owner(), "PriceOracle: caller is not an updater");
        _;
    }
    
    /**
     * @dev Constructor sets the initial price and vault
     */
    constructor(address vaultAddress, uint256 initialPrice) {
        require(vaultAddress != address(0), "PriceOracle: vault is the zero address");
        require(initialPrice > 0, "PriceOracle: initial price must be positive");
        
        _vault = IVault(vaultAddress);
        _currentTrxPriceInUsd = initialPrice;
        _lastUpdateTimestamp = block.timestamp;
        
        // Add owner as an updater
        _oracleUpdaters[msg.sender] = true;
        emit UpdaterAdded(msg.sender);
    }
    
    /**
     * @dev Returns the current TRX price in USD (multiplied by 1e6)
     */
    function getCurrentPrice() public view returns (uint256) {
        return _currentTrxPriceInUsd;
    }
    
    /**
     * @dev Returns the timestamp of the last price update
     */
    function getLastUpdateTime() public view returns (uint256) {
        return _lastUpdateTimestamp;
    }
    
    /**
     * @dev Returns the maximum allowed price deviation per update (in basis points)
     */
    function getMaxDeviation() public view returns (uint256) {
        return _maxPriceDeviation;
    }
    
    /**
     * @dev Returns the minimum interval between price updates (in seconds)
     */
    function getMinInterval() public view returns (uint256) {
        return _minUpdateInterval;
    }
    
    /**
     * @dev Checks if an address is an authorized updater
     */
    function isUpdater(address account) public view returns (bool) {
        return _oracleUpdaters[account];
    }
    
    /**
     * @dev Updates the TRX price in USD
     * Can only be called by authorized updaters
     */
    function updatePrice(uint256 newPrice) public onlyUpdater {
        require(newPrice > 0, "PriceOracle: price must be positive");
        require(block.timestamp >= _lastUpdateTimestamp + _minUpdateInterval, 
                "PriceOracle: update interval too short");
        
        // Check max price deviation
        uint256 priceDifference;
        if (newPrice > _currentTrxPriceInUsd) {
            priceDifference = newPrice - _currentTrxPriceInUsd;
        } else {
            priceDifference = _currentTrxPriceInUsd - newPrice;
        }
        
        uint256 deviationPercentage = (priceDifference * 10000) / _currentTrxPriceInUsd;
        require(deviationPercentage <= _maxPriceDeviation, 
                "PriceOracle: price deviation too large");
        
        uint256 oldPrice = _currentTrxPriceInUsd;
        _currentTrxPriceInUsd = newPrice;
        _lastUpdateTimestamp = block.timestamp;
        
        // Update price in vault
        _vault.updateTrxPrice(newPrice);
        
        emit PriceUpdated(newPrice, oldPrice, msg.sender);
    }
    
    /**
     * @dev Add a new updater
     * Can only be called by owner
     */
    function addUpdater(address updater) public onlyOwner {
        require(updater != address(0), "PriceOracle: updater is the zero address");
        require(!_oracleUpdaters[updater], "PriceOracle: account is already an updater");
        
        _oracleUpdaters[updater] = true;
        emit UpdaterAdded(updater);
    }
    
    /**
     * @dev Remove an updater
     * Can only be called by owner
     */
    function removeUpdater(address updater) public onlyOwner {
        require(_oracleUpdaters[updater], "PriceOracle: account is not an updater");
        
        _oracleUpdaters[updater] = false;
        emit UpdaterRemoved(updater);
    }
    
    /**
     * @dev Update the vault address
     * Can only be called by owner
     */
    function setVault(address newVaultAddress) public onlyOwner {
        require(newVaultAddress != address(0), "PriceOracle: new vault is the zero address");
        
        address oldVault = address(_vault);
        _vault = IVault(newVaultAddress);
        
        emit VaultUpdated(oldVault, newVaultAddress);
    }
    
    /**
     * @dev Set maximum price deviation (in basis points)
     * Can only be called by owner
     */
    function setMaxDeviation(uint256 newMaxDeviation) public onlyOwner {
        require(newMaxDeviation <= 3000, "PriceOracle: deviation cannot exceed 30%");
        
        uint256 oldDeviation = _maxPriceDeviation;
        _maxPriceDeviation = newMaxDeviation;
        
        emit MaxDeviationUpdated(oldDeviation, newMaxDeviation);
    }
    
    /**
     * @dev Set minimum update interval (in seconds)
     * Can only be called by owner
     */
    function setMinInterval(uint256 newMinInterval) public onlyOwner {
        uint256 oldInterval = _minUpdateInterval;
        _minUpdateInterval = newMinInterval;
        
        emit MinIntervalUpdated(oldInterval, newMinInterval);
    }
    
    /**
     * @dev Force update price (bypass interval and deviation checks)
     * Can only be called by owner, for emergency use
     */
    function forceUpdatePrice(uint256 newPrice) public onlyOwner {
        require(newPrice > 0, "PriceOracle: price must be positive");
        
        uint256 oldPrice = _currentTrxPriceInUsd;
        _currentTrxPriceInUsd = newPrice;
        _lastUpdateTimestamp = block.timestamp;
        
        // Update price in vault
        _vault.updateTrxPrice(newPrice);
        
        emit PriceUpdated(newPrice, oldPrice, msg.sender);
    }
}