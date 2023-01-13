pragma solidity ^0.4.24;

import "./Ownable.sol";

 // Identity Management and Tax Definition Contract
contract Administrative is Ownable {
    // The existing roles
    enum Role {Authority, TaxPayer, None}

    // address maps to true if the address is registered
    mapping(address => bool) public valid;

    // Maps vat IDs to the corresponding address
    mapping(uint => address) vatidMap;

    // assigns a role to each address
    mapping(address => Role) permissionMap;

    // Assigns a public encryption key to each address
    mapping(address => bytes32) pk;

    // Assigns a debit value to each address
    mapping(address => uint256) public debit;

    // Assigns a credit value to each address
    mapping(address => uint256) public credit;

    constructor() public {
        // The address of the owner is valid
        valid[msg.sender] = true;   
        // The owner has the Authority role
        permissionMap[msg.sender] = Role.Authority; 
    }

    //Checks the validity of the address as well as the role of the msg.sender
    modifier onlyBy(Role _role)
    {
        require(valid[msg.sender], "Not authorized");
        require(permissionMap[msg.sender] == _role, "Unsufficient permissions");
        _;
    }

    /**
    * Registers a new business - a business can only be added by an Authority
    * Param definitions
        vatid: the VAT ID to register
        pk_sig: the address of the taxpayer
        pk_enc: 256 bit public encryption key
    */
    function addTaxPayer(uint vatid, address pk_sig, bytes32 pk_enc) public onlyBy(Role.Authority){
        require(valid[pk_sig] == false && vatidMap[vatid] == address(0), "Address already registered");
        valid[pk_sig] = true;
        vatidMap[vatid] = pk_sig;
        permissionMap[pk_sig] = Role.TaxPayer;
        pk[pk_sig] = pk_enc;
        debit[pk_sig] = 0;
        credit[pk_sig] = 0;
    }

    function increaseDebit(uint _duetax, address pk_sig) public returns (bool success){
        debit[pk_sig] = debit[pk_sig] + _duetax;
        return true;
    }

    function decreaseDebit(uint _duetax, address pk_sig) public returns (bool success){
        debit[pk_sig] = debit[pk_sig] - _duetax;
        return true;
    }

    function getDebit(address pk_sig) public constant returns (uint256 current) {
        require(isValid(pk_sig));
        return debit[pk_sig];
    }

    function increaseCredit(uint _duetax, address pk_sig) public returns (bool success){
        credit[pk_sig] = credit[pk_sig] + _duetax;
        return true;
    }

    function decreaseCredit(uint _duetax, address pk_sig) public returns (bool success){
        credit[pk_sig] = credit[pk_sig] - _duetax;
        return true;
    }

    function getCredit(address pk_sig) public constant returns (uint256 current) {
        require(isValid(pk_sig));
        return credit[pk_sig];
    }

    /**
     * Revokes the VAT ID of a business
     * Param definitions
        vatid: the VAT ID to revoke
     */
    function revokeTaxPayer(uint vatid) public onlyBy(Role.Authority){
        address adr = vatidMap[vatid];
        require(valid[adr] && (permissionMap[adr]==Role.TaxPayer), "VAT ID cannot be revoked");
        valid[adr] = false;
        vatidMap[vatid] = address(0);
        permissionMap[adr] = Role.None;
    }

    /**
     * Checks if the address belongs to a valid business
     * Param definitions
        adr: the address to check
     */
    function isValid(address adr) public view returns (bool) {
        return valid[adr] && (permissionMap[adr] == Role.TaxPayer);
    }

    // Rate data structure
    struct RateParam {
        bytes32 rateCode;
        string rateName;
        uint32 rateValue;
        string regulationReference;
        uint rateIndex;
        bool IsActive;
    }

    /**
     * rateStructs is for indexing based on rateCode
     * rateList is for sequential access based on rateCode to get the rate row data
    */
    mapping (bytes32 => RateParam) rateStructs;
    bytes32[] rateList;

    // Checks if the rate is valid
    function isRate (bytes32 rateCode) public view returns (bool isIndeed) {
        if (rateList.length == 0) return false;
        return rateList[rateStructs[rateCode].rateIndex] == rateCode;
    }

    function createTaxRate(bytes32 rateCode, string rateName, uint32 rateValue, string regulationReference, bool isActive) public onlyOwner returns (bool success) {
        // Prevents duplicated tax documents
        require(!isRate(rateCode));
        rateStructs[rateCode].rateCode = rateCode;
        rateStructs[rateCode].rateName = rateName;
        rateStructs[rateCode].rateValue = rateValue;
        rateStructs[rateCode].regulationReference = regulationReference;
        rateStructs[rateCode].rateIndex = rateList.push(rateCode) - 1;
        rateStructs[rateCode].IsActive = isActive;
        
        return true;
    }

    function getRateValue (bytes32 _rateCode) public view returns (uint32 value) {
            require(isRate(_rateCode));
            return rateStructs[_rateCode].rateValue;
        }

}