pragma solidity ^0.4.24;

import "./Administrative.sol";
import "./Ownable.sol";
import "./ERC20Pausable.sol";

contract BCFiscal is Ownable{

    IERC20 public token;
   
   // Allows the association of the BC Fiscal with the CBDC Token
    function changeToken(IERC20 newToken) onlyOwner public {
        token = newToken;
    }

    address constant public zeroAddress = 0x0000000000000000000000000000000000000000;

    // Refers to the Identity Management and Tax Definition Contract
    Administrative adm;

    /* 
    * Tax Document data structure
    * Param definitions
        rateCode: the tax code for each tax document item
        taxBase: the tax base for each tax document item
        quantity: the quantity for each tax document item
        dueTax: total due tax related to the tax document
        seller: the sender of the tax document
        buyer: the receiver of the tax document
        docHash: the encrypted data of XML file
        month: month of the transaction
        year: year of the transaction
        docIndex: position of the tax document data
    */
    struct TaxDocument{
        bytes32[] rateCode;    
        uint256[] taxBase;      
        uint256[] quantity;     
        uint256 dueTax;
        address seller;     
        address buyer;      
        string docHash;       
        bytes32 docCode;
        uint256 month;
        uint256 year;
        uint docIndex;
    }

    /*
     * taxDocs is for indexing based on docCode
     * taxList is for sequential access based on docCode to get the tax row data
    */
    mapping (bytes32 => TaxDocument) taxDocs;
    bytes32[] taxList;

    /* 
    * Payments data structure
    * Param definitions
        payCode: the payment code
        payIndex: position of the payment data
        payer: the address of the payer
        month: month of the transaction
        year: year of the transaction
        amount: total payment value
    */
    struct Payments {
        bytes32 payCode;
        uint256 payIndex;
        address payer;
        uint256 month;
        uint256 year;
        uint256 amount;
    }

    /*
     * payStructs is for indexing based on payCode
     * taxList is for sequential access based on payCode to get the payment data
    */
    mapping (bytes32 => Payments) payStructs;
    bytes32[] payList;

   // Allows the association of the BC Fiscal with the Administrative contract
    constructor(address _adm) public {
        adm = Administrative(_adm);
    }

    // Checks if the tax document is valid
    function isTaxDoc (bytes32 docCode) public constant returns (bool isIndeed) {
        if (taxList.length == 0) return false;
        return taxList[taxDocs[docCode].docIndex] == docCode;
    }

   // Checks if the payment is valid
    function isPayment (bytes32 payCode) public constant returns (bool isIndeed) {
        if (payList.length == 0) return false;
        return payList[payStructs[payCode].payIndex] == payCode;
    }

    // Registers an authorized tax document to the BC Fiscal
    function newTaxDocument(bytes32[] memory _rateCode, uint256[] memory _taxBase, uint256[] memory _quantity, uint256 _dueTax, address _seller, address _buyer, string _DocHash, bytes32 _DocCode, uint256 _month, uint256 _year) public returns (bool success){
        // Checks if the seller is registered
        require(adm.isValid(_seller), "Seller invalid");  
        // Checks if the buyer is registered. Also makes sure it's an internal operation
        require(adm.isValid(_buyer), "Buyer invalid - not an internal operation"); 
        // Prevents duplicated tax documents
        require(!isTaxDoc(_DocCode));

        uint256 duetaxCheck = 0;

        // Consolidates all itens of the tax document
        for(uint j = 0; j<_rateCode.length; j++){
           duetaxCheck = duetaxCheck + _taxBase[j]*_quantity[j]*adm.getRateValue(_rateCode[j])/100;
           }

        require(duetaxCheck == _dueTax , "Incorrect due tax"); 

        taxDocs[_DocCode].rateCode = _rateCode;
        taxDocs[_DocCode].taxBase = _taxBase;
        taxDocs[_DocCode].quantity = _quantity;
        taxDocs[_DocCode].dueTax = _dueTax;
        taxDocs[_DocCode].seller = _seller;
        taxDocs[_DocCode].buyer = _buyer;
        taxDocs[_DocCode].docHash = _DocHash;
        taxDocs[_DocCode].docCode = _DocCode;
        taxDocs[_DocCode].month = _month;
        taxDocs[_DocCode].year = _year;
        taxDocs[_DocCode].docIndex = taxList.push(_DocCode) - 1;

        return true;
    }

    // Registers the debits and credits for the participants of a given transactions (or tax document)
    function checkingDoc(bytes32 _docCode) public returns (bool success) {
        adm.increaseDebit(taxDocs[_docCode].dueTax,taxDocs[_docCode].seller);
        adm.increaseCredit(taxDocs[_docCode].dueTax,taxDocs[_docCode].buyer);
        return true;
    }

    // Should be called periodically by taxpayers 
    // Beforehand, the taxpayer needs to give permission to the Smart Contract Addressm so the transferFrom function can work properly
    function createPayment(bytes32 _payCode, uint256 _month, uint256 _year) public returns (bool result) {
        // Prevents duplicated tax documents
        require(!isPayment(_payCode));
        
        uint256 balance=0;
        uint256 debit=adm.getDebit(msg.sender);
        uint256 credit=adm.getCredit(msg.sender);

        if (debit >= credit) {
            balance = debit - credit;
            } 
            
        else {
            balance = 0;
             }
       
       require(token.balanceOf(msg.sender) >= balance, "Not enough balance to pay");
       
       // Transfers the due tax amount to the Smart Contract owner, which is the Tax Authority
       if(token.transferFrom(msg.sender,owner(), balance)){
           if (debit >= credit) {
            adm.decreaseDebit(debit,msg.sender);
            adm.decreaseCredit(credit,msg.sender);
            } 

            else {
            adm.decreaseDebit(debit,msg.sender);
            adm.decreaseCredit(debit,msg.sender);
            }

      }

        payStructs[_payCode].payCode = _payCode;
        payStructs[_payCode].payIndex = payList.push(_payCode) - 1;
        payStructs[_payCode].payer = msg.sender;
        payStructs[_payCode].month = _month;
        payStructs[_payCode].year = _year;
        payStructs[_payCode].amount = balance;

       return true;
    }

    // Gets the details of a payment, based on payment code
     function getPaymentDetail(bytes32 payCode) public constant returns (bytes32 PayCode, uint256 PayIndex, 
        address Payer, uint256 month, uint256 year, uint256 amount) {
        Payments memory p = payStructs[payCode];
        return (p.payCode, p.payIndex, p.payer, p.month, p.year, p.amount);
    }

}