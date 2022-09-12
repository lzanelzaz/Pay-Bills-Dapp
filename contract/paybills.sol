// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IERC20Token {
    function transfer(address, uint256) external returns (bool);

    function approve(address, uint256) external returns (bool);

    function transferFrom(
        address,
        address,
        uint256
    ) external returns (bool);

    function totalSupply() external view returns (uint256);

    function balanceOf(address) external view returns (uint256);

    function allowance(address, address) external view returns (uint256);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

contract PayBills is Ownable {
    event NewBill(
        uint billId,
        address indexed houseOwnerAddress,
        uint forTimestamp
    );
    event BillPaid(
        address indexed houseOwnerAddress,
        uint forTimestamp,
        uint electricityCost,
        uint waterCost,
        uint internetCost,
        uint total,
        bool isPaid,
        bool paidLate
    );
    address private cUsdTokenAddress =
        0x874069Fa1Eb16D44d622F2e0Ca25eeA172369bC1;

    uint public billsLength;
    // 2% fee of bill to be paid in case of late payment
    uint private constant lateFees = 2;
    // the number of days users have to pay their bills before they have to pay the lateFees
    uint private constant daysToPay = 10 days;

    struct Bill {
        address houseOwnerAddress;
        uint forTimestamp;
        uint electricityCost;
        uint waterCost;
        uint internetCost;
        uint total;
        bool isPaid;
    }

    // [month] = Bill
    mapping(uint => Bill) private bills;

    mapping(address => bool) private admins;

    mapping(uint => bool) private _exists;

    constructor() {
        admins[msg.sender] = true;
    }

    function addAdmin(address _admin) public onlyOwner {
        admins[_admin] = true;
    }

    function removeAdmin(address _admin) public onlyOwner {
        admins[_admin] = false;
    }

    /**
     * @dev allow admins to add a bill for an address
     * @param _houseOwnerAddress the address that has to pay the bill
     */
    function createBill(
        uint _electricityCost,
        uint _waterCost,
        uint _internetCost,
        address _houseOwnerAddress
    ) external {
        require(admins[msg.sender], "Unauthorized caller");
        require(
            _houseOwnerAddress != address(0),
            "Error: Address zero is not a valid address"
        );
        uint totalCost = _electricityCost + _waterCost + _internetCost;
        uint billId = billsLength;
        billsLength++;
        bills[billId] = Bill(
            _houseOwnerAddress,
            block.timestamp,
            _electricityCost,
            _waterCost,
            _internetCost,
            totalCost,
            false
        );
        _exists[billId] = true;
    }

    /**
     * @dev allow home owners to pay their due fees
     * @notice if payment is made after 10 days of the release date of the bill, a 2% fee will be due
     * @notice Bill details will be logged onto the transaction logs and then removed from the platform
     */
    function payBill(uint billId) external payable exists(billId) {
        Bill storage currentBill = bills[billId];
        require(
            currentBill.houseOwnerAddress == msg.sender,
            "Only the house owner can pay their bills"
        );
        require(!currentBill.isPaid, "Bill is already paid");
        currentBill.isPaid = true;
        (bool isLate, uint total) = getBillCost(billId);
        require(
            IERC20Token(cUsdTokenAddress).transferFrom(
                msg.sender, // from
                owner(), // to
                total // bill cost
            ),
            "Transfer failed."
        );
        emit BillPaid(
            currentBill.houseOwnerAddress,
            currentBill.forTimestamp,
            currentBill.electricityCost,
            currentBill.waterCost,
            currentBill.internetCost,
            total,
            currentBill.isPaid,
            isLate
        );
        uint newBillLength = billsLength - 1;
        _exists[newBillLength] = false;
        bills[billId] = bills[newBillLength];
        delete bills[newBillLength];
        billsLength = newBillLength;
    }

    function getBill(uint billId)
        public
        view
        exists(billId)
        returns (
            address houseOwnerAdress,
            uint electricityCost,
            uint waterCost,
            uint internetCost,
            uint total,
            bool isPaid
        )
    {
        Bill memory bill = bills[billId];
        return (
            houseOwnerAdress = bill.houseOwnerAddress,
            electricityCost = bill.electricityCost,
            waterCost = bill.waterCost,
            internetCost = bill.internetCost,
            total = bill.total,
            isPaid = bill.isPaid
        );
    }

    /**
     * @return isLate boolean status of bill not being paid within the deadline specified
     * @return total total cost of bill(late fees may be included if late payment is made)    
    */
    function getBillCost(uint billId)
        public
        view
        exists(billId)
        returns (bool isLate, uint total)
    {
        Bill storage currentBill = bills[billId];
        if (currentBill.forTimestamp + daysToPay >= block.timestamp) {
            return (false, currentBill.total);
        } else {
            uint cost = ((currentBill.total / 100) * lateFees) +
                currentBill.total;
            return (true, cost);
        }
    }

    /**
     * @return _lateFees the current percentage for calculationg due fees in case of late payment
     * @return _daysToPay the current number of days given to pay a bill before late payment fees is applied
     */
    function getPaymentInfo()
        public
        pure
        returns (uint _lateFees, uint _daysToPay)
    {
        return (lateFees, daysToPay);
    }

    modifier exists(uint billId) {
        require(_exists[billId], "Query of nonexistent bill");
        _;
    }
}
