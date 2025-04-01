pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT

interface ITRC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function mint(address account, uint256 amount) external returns (bool);
    function burn(address account, uint256 amount) external returns (bool);
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

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
 * @title Vault
 * @dev Contract for managing liquidity and token mint/burn operations
 */
contract Vault is Ownable {
    // The stablecoin token contract
    ITRC20 private _stableToken;
    
    // The USDT token contract (TRC-20)
    ITRC20 private _usdtToken;
    
    // Oracle price (1 USD in TRX, multiplied by 1e6 for precision)
    uint256 private _trxPriceInUsd; // e.g., 3000000 means 1 TRX = 0.03 USD
    
    // Minimum price update period (in seconds)
    uint256 private _minPriceUpdatePeriod = 1 hours;
    
    // Last price update timestamp
    uint256 private _lastPriceUpdateTime;
    
    // Maximum price deviation per update (in percentage, 1000 = 10%)
    uint256 private _maxPriceDeviation = 1000; // 10% default
    
    // Fees configuration (in basis points, 100 = 1%)
    uint256 private _buyFee = 50;   // 0.5% fee when buying tokens
    uint256 private _sellFee = 50;  // 0.5% fee when selling tokens
    
    // Fee collector address
    address private _feeCollector;
    
    // Treasury stats
    uint256 private _totalTrxReserve;
    uint256 private _totalUsdtReserve;
    
    // Events
    event TokensBought(address indexed buyer, uint256 amountIn, uint256 amountOut, string paymentType);
    event TokensSold(address indexed seller, uint256 amountIn, uint256 amountOut, string paymentType);
    event PriceUpdated(uint256 newPrice, uint256 previousPrice);
    event FeeUpdated(string feeType, uint256 newFee);
    event FeeCollected(address indexed collector, uint256 amount, string currency);
    event FeeCollectorUpdated(address indexed previousCollector, address indexed newCollector);
    event EmergencyWithdraw(address indexed to, uint256 amount, string currency);
    
    /**
     * @dev Constructor sets the token addresses and initial price
     */
    constructor(address stableTokenAddress, address usdtTokenAddress, uint256 initialTrxPriceInUsd) {
        require(stableTokenAddress != address(0), "Vault: stableToken is the zero address");
        require(usdtTokenAddress != address(0), "Vault: usdtToken is the zero address");
        require(initialTrxPriceInUsd > 0, "Vault: initial price must be positive");
        
        _stableToken = ITRC20(stableTokenAddress);
        _usdtToken = ITRC20(usdtTokenAddress);
        _trxPriceInUsd = initialTrxPriceInUsd;
        _feeCollector = msg.sender;
        _lastPriceUpdateTime = block.timestamp;
    }
    
    /**
     * @dev Fallback function to receive TRX
     */
    receive() external payable {
        // Cannot directly send TRX, must use buyTokenWithTRX function
        revert("Vault: direct TRX deposit not allowed, use buyTokenWithTRX");
    }
    
    /**
     * @dev Returns the current TRX price in USD (multiplied by 1e6)
     */
    function getTrxPriceInUsd() public view returns (uint256) {
        return _trxPriceInUsd;
    }
    
    /**
     * @dev Returns the buy fee (in basis points)
     */
    function getBuyFee() public view returns (uint256) {
        return _buyFee;
    }
    
    /**
     * @dev Returns the sell fee (in basis points)
     */
    function getSellFee() public view returns (uint256) {
        return _sellFee;
    }
    
    /**
     * @dev Returns the address of the fee collector
     */
    function getFeeCollector() public view returns (address) {
        return _feeCollector;
    }
    
    /**
     * @dev Returns the total TRX reserve
     */
    function getTrxReserve() public view returns (uint256) {
        return _totalTrxReserve;
    }
    
    /**
     * @dev Returns the total USDT reserve
     */
    function getUsdtReserve() public view returns (uint256) {
        return _totalUsdtReserve;
    }
    
    /**
     * @dev Buy tokens with TRX
     */
    function buyTokenWithTRX() public payable returns (uint256) {
        require(msg.value > 0, "Vault: TRX amount must be positive");
        
        // Calculate token amount based on TRX price
        uint256 trxValueInUsd = (msg.value * _trxPriceInUsd) / 1e6; // Convert to USD value
        
        // Calculate fee
        uint256 fee = (trxValueInUsd * _buyFee) / 10000;
        uint256 netAmount = trxValueInUsd - fee;
        
        // Mint tokens to buyer (1:1 with USD value)
        _stableToken.mint(msg.sender, netAmount);
        
        // Update treasury stats
        _totalTrxReserve += msg.value;
        
        emit TokensBought(msg.sender, msg.value, netAmount, "TRX");
        return netAmount;
    }
    
    /**
     * @dev Buy tokens with USDT
     */
    function buyTokenWithUSDT(uint256 usdtAmount) public returns (uint256) {
        require(usdtAmount > 0, "Vault: USDT amount must be positive");
        
        // Check if caller has approved sufficient USDT
        require(_usdtToken.allowance(msg.sender, address(this)) >= usdtAmount, 
                "Vault: insufficient USDT allowance");
        
        // Transfer USDT from caller to vault
        require(_usdtToken.transferFrom(msg.sender, address(this), usdtAmount), 
                "Vault: USDT transfer failed");
        
        // Calculate fee (USDT is already USD-pegged)
        uint256 fee = (usdtAmount * _buyFee) / 10000;
        uint256 netAmount = usdtAmount - fee;
        
        // Mint tokens to buyer (1:1 with USDT)
        _stableToken.mint(msg.sender, netAmount);
        
        // Update treasury stats
        _totalUsdtReserve += usdtAmount;
        
        emit TokensBought(msg.sender, usdtAmount, netAmount, "USDT");
        return netAmount;
    }
    
    /**
     * @dev Sell tokens for TRX
     */
    function sellTokenForTRX(uint256 tokenAmount) public returns (uint256) {
        require(tokenAmount > 0, "Vault: token amount must be positive");
        require(_stableToken.balanceOf(msg.sender) >= tokenAmount, 
                "Vault: insufficient token balance");
        
        // Calculate fee
        uint256 fee = (tokenAmount * _sellFee) / 10000;
        uint256 netAmount = tokenAmount - fee;
        
        // Calculate TRX to return (converting USD to TRX)
        uint256 trxToReturn = (netAmount * 1e6) / _trxPriceInUsd;
        
        // Check if vault has enough TRX
        require(address(this).balance >= trxToReturn, 
                "Vault: insufficient TRX reserves");
        
        // Burn tokens
        require(_stableToken.burn(msg.sender, tokenAmount), 
                "Vault: token burn failed");
        
        // Update treasury stats
        _totalTrxReserve -= trxToReturn;
        
        // Send TRX to caller
        (bool sent, ) = msg.sender.call{value: trxToReturn}("");
        require(sent, "Vault: Failed to send TRX");
        
        emit TokensSold(msg.sender, tokenAmount, trxToReturn, "TRX");
        return trxToReturn;
    }
    
    /**
     * @dev Sell tokens for USDT
     */
    function sellTokenForUSDT(uint256 tokenAmount) public returns (uint256) {
        require(tokenAmount > 0, "Vault: token amount must be positive");
        require(_stableToken.balanceOf(msg.sender) >= tokenAmount, 
                "Vault: insufficient token balance");
        
        // Calculate fee
        uint256 fee = (tokenAmount * _sellFee) / 10000;
        uint256 netAmount = tokenAmount - fee;
        
        // Check if vault has enough USDT
        require(_usdtToken.balanceOf(address(this)) >= netAmount, 
                "Vault: insufficient USDT reserves");
        
        // Burn tokens
        require(_stableToken.burn(msg.sender, tokenAmount), 
                "Vault: token burn failed");
        
        // Update treasury stats
        _totalUsdtReserve -= netAmount;
        
        // Send USDT to caller
        require(_usdtToken.transfer(msg.sender, netAmount), 
                "Vault: USDT transfer failed");
        
        emit TokensSold(msg.sender, tokenAmount, netAmount, "USDT");
        return netAmount;
    }
    
    /**
     * @dev Collect fees - can only be called by the owner or fee collector
     */
    function collectFees(uint256 trxAmount, uint256 usdtAmount) public {
        require(msg.sender == _feeCollector || msg.sender == owner(), 
                "Vault: caller is not authorized to collect fees");
        
        if (trxAmount > 0) {
            require(address(this).balance >= trxAmount, 
                    "Vault: insufficient TRX for fee collection");
            
            (bool sent, ) = _feeCollector.call{value: trxAmount}("");
            require(sent, "Vault: Failed to send TRX fees");
            
            emit FeeCollected(_feeCollector, trxAmount, "TRX");
        }
        
        if (usdtAmount > 0) {
            require(_usdtToken.balanceOf(address(this)) >= usdtAmount, 
                    "Vault: insufficient USDT for fee collection");
                    
            require(_usdtToken.transfer(_feeCollector, usdtAmount), 
                    "Vault: USDT fee transfer failed");
            
            emit FeeCollected(_feeCollector, usdtAmount, "USDT");
        }
    }
    
    /**
     * @dev Update TRX price in USD - can only be called by owner or authorized oracle
     */
    function updateTrxPrice(uint256 newPrice) public onlyOwner {
        require(newPrice > 0, "Vault: price must be positive");
        require(block.timestamp >= _lastPriceUpdateTime + _minPriceUpdatePeriod, 
                "Vault: price updated too recently");
        
        // Check max price deviation
        uint256 priceDifference;
        if (newPrice > _trxPriceInUsd) {
            priceDifference = newPrice - _trxPriceInUsd;
        } else {
            priceDifference = _trxPriceInUsd - newPrice;
        }
        
        uint256 deviationPercentage = (priceDifference * 10000) / _trxPriceInUsd;
        require(deviationPercentage <= _maxPriceDeviation, 
                "Vault: price deviation too large");
        
        uint256 oldPrice = _trxPriceInUsd;
        _trxPriceInUsd = newPrice;
        _lastPriceUpdateTime = block.timestamp;
        
        emit PriceUpdated(newPrice, oldPrice);
    }
    
    /**
     * @dev Set buy fee - can only be called by owner
     */
    function setBuyFee(uint256 newFee) public onlyOwner {
        require(newFee <= 500, "Vault: fee cannot exceed 5%");
        _buyFee = newFee;
        emit FeeUpdated("Buy", newFee);
    }
    
    /**
     * @dev Set sell fee - can only be called by owner
     */
    function setSellFee(uint256 newFee) public onlyOwner {
        require(newFee <= 500, "Vault: fee cannot exceed 5%");
        _sellFee = newFee;
        emit FeeUpdated("Sell", newFee);
    }
    
    /**
     * @dev Set fee collector address - can only be called by owner
     */
    function setFeeCollector(address newFeeCollector) public onlyOwner {
        require(newFeeCollector != address(0), "Vault: new fee collector is the zero address");
        
        address oldCollector = _feeCollector;
        _feeCollector = newFeeCollector;
        
        emit FeeCollectorUpdated(oldCollector, newFeeCollector);
    }
    
    /**
     * @dev Set minimum price update period - can only be called by owner
     */
    function setMinPriceUpdatePeriod(uint256 newPeriod) public onlyOwner {
        _minPriceUpdatePeriod = newPeriod;
    }
    
    /**
     * @dev Set maximum price deviation - can only be called by owner
     */
    function setMaxPriceDeviation(uint256 newDeviation) public onlyOwner {
        require(newDeviation <= 3000, "Vault: deviation cannot exceed 30%");
        _maxPriceDeviation = newDeviation;
    }
    
    /**
     * @dev Emergency withdraw - only owner can call
     * Should only be used in emergency situations
     */
    function emergencyWithdraw(address payable to, uint256 trxAmount, uint256 usdtAmount) public onlyOwner {
        if (trxAmount > 0) {
            require(address(this).balance >= trxAmount, "Vault: insufficient TRX");
            (bool sent, ) = to.call{value: trxAmount}("");
            require(sent, "Vault: Failed to send TRX");
            emit EmergencyWithdraw(to, trxAmount, "TRX");
        }
        
        if (usdtAmount > 0) {
            require(_usdtToken.balanceOf(address(this)) >= usdtAmount, "Vault: insufficient USDT");
            require(_usdtToken.transfer(to, usdtAmount), "Vault: USDT transfer failed");
            emit EmergencyWithdraw(to, usdtAmount, "USDT");
        }
    }
}