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
 * @title DynamicStable
 * @dev Implementation of the TRC-20 Token with dynamic mint/burn functions
 */
contract DynamicStable is Ownable {
    string private _name;
    string private _symbol;
    uint8 private _decimals;
    uint256 private _totalSupply;

    // Vault address authorized to mint/burn tokens
    address private _vaultAddress;
    
    // Max supply cap (can be set to max uint256 for unlimited)
    uint256 private _maxSupply;
    
    // Supply adjustment configuration
    bool private _adjustmentEnabled = true;
    
    // Mapping of account balances
    mapping(address => uint256) private _balances;
    
    // Mapping of allowances
    mapping(address => mapping(address => uint256)) private _allowances;
    
    // Events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Minted(address indexed to, uint256 amount);
    event Burned(address indexed from, uint256 amount);
    event VaultUpdated(address indexed previousVault, address indexed newVault);
    event MaxSupplyUpdated(uint256 previousMaxSupply, uint256 newMaxSupply);
    event AdjustmentStatusChanged(bool enabled);

    /**
     * @dev Constructor that sets initial values
     */
    constructor(string memory tokenName, string memory tokenSymbol, uint8 tokenDecimals, uint256 maxSupply) {
        _name = tokenName;
        _symbol = tokenSymbol;
        _decimals = tokenDecimals;
        _maxSupply = maxSupply;
    }
    
    /**
     * @dev Returns the name of the token
     */
    function name() public view returns (string memory) {
        return _name;
    }
    
    /**
     * @dev Returns the symbol of the token
     */
    function symbol() public view returns (string memory) {
        return _symbol;
    }
    
    /**
     * @dev Returns the number of decimals used
     */
    function decimals() public view returns (uint8) {
        return _decimals;
    }
    
    /**
     * @dev Returns the total token supply
     */
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }
    
    /**
     * @dev Returns the maximum token supply cap
     */
    function maxSupply() public view returns (uint256) {
        return _maxSupply;
    }
    
    /**
     * @dev Returns the vault address authorized to mint/burn
     */
    function vaultAddress() public view returns (address) {
        return _vaultAddress;
    }
    
    /**
     * @dev Returns true if supply adjustment is enabled
     */
    function adjustmentEnabled() public view returns (bool) {
        return _adjustmentEnabled;
    }
    
    /**
     * @dev Returns the balance of an account
     */
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }
    
    /**
     * @dev Returns the allowance set for a spender by an owner
     */
    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }
    
    /**
     * @dev Sets an allowance for a spender by the caller
     */
    function approve(address spender, uint256 amount) public returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }
    
    /**
     * @dev Transfers tokens from the caller to recipient
     */
    function transfer(address recipient, uint256 amount) public returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }
    
    /**
     * @dev Transfers tokens from sender to recipient using the caller's allowance
     */
    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {
        _transfer(sender, recipient, amount);
        
        uint256 currentAllowance = _allowances[sender][msg.sender];
        require(currentAllowance >= amount, "TRC20: transfer amount exceeds allowance");
        _approve(sender, msg.sender, currentAllowance - amount);
        
        return true;
    }
    
    /**
     * @dev Internal function to set allowance
     */
    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "TRC20: approve from the zero address");
        require(spender != address(0), "TRC20: approve to the zero address");
        
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    
    /**
     * @dev Internal function to transfer tokens
     */
    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "TRC20: transfer from the zero address");
        require(recipient != address(0), "TRC20: transfer to the zero address");
        require(_balances[sender] >= amount, "TRC20: transfer amount exceeds balance");
        
        _balances[sender] -= amount;
        _balances[recipient] += amount;
        
        emit Transfer(sender, recipient, amount);
    }
    
    /**
     * @dev Creates `amount` tokens and assigns them to `account`
     * Can only be called by vault or owner
     */
    function mint(address account, uint256 amount) public returns (bool) {
        require(msg.sender == _vaultAddress || msg.sender == owner(), "DynamicStable: caller is not authorized to mint");
        require(_adjustmentEnabled, "DynamicStable: supply adjustment is disabled");
        require(account != address(0), "DynamicStable: mint to the zero address");
        require(_totalSupply + amount <= _maxSupply, "DynamicStable: mint would exceed max supply");
        
        _totalSupply += amount;
        _balances[account] += amount;
        
        emit Transfer(address(0), account, amount);
        emit Minted(account, amount);
        
        return true;
    }
    
    /**
     * @dev Destroys `amount` tokens from `account`
     * Can only be called by vault or owner
     */
    function burn(address account, uint256 amount) public returns (bool) {
        require(msg.sender == _vaultAddress || msg.sender == owner() || msg.sender == account, 
                "DynamicStable: caller is not authorized to burn");
        require(_adjustmentEnabled, "DynamicStable: supply adjustment is disabled");
        require(account != address(0), "DynamicStable: burn from the zero address");
        require(_balances[account] >= amount, "DynamicStable: burn amount exceeds balance");
        
        _balances[account] -= amount;
        _totalSupply -= amount;
        
        emit Transfer(account, address(0), amount);
        emit Burned(account, amount);
        
        return true;
    }
    
    /**
     * @dev Sets the vault address that is authorized to mint/burn
     * Can only be called by owner
     */
    function setVaultAddress(address newVaultAddress) public onlyOwner {
        require(newVaultAddress != address(0), "DynamicStable: new vault is the zero address");
        
        address oldVault = _vaultAddress;
        _vaultAddress = newVaultAddress;
        
        emit VaultUpdated(oldVault, newVaultAddress);
    }
    
    /**
     * @dev Updates the maximum supply cap
     * Can only be called by owner
     */
    function setMaxSupply(uint256 newMaxSupply) public onlyOwner {
        require(newMaxSupply >= _totalSupply, "DynamicStable: new max supply is less than current total supply");
        
        uint256 oldMaxSupply = _maxSupply;
        _maxSupply = newMaxSupply;
        
        emit MaxSupplyUpdated(oldMaxSupply, newMaxSupply);
    }
    
    /**
     * @dev Enables or disables supply adjustment
     * Can only be called by owner
     */
    function setAdjustmentEnabled(bool enabled) public onlyOwner {
        _adjustmentEnabled = enabled;
        emit AdjustmentStatusChanged(enabled);
    }
}