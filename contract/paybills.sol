// SPDX-License-Identifier: MIT  
pragma solidity ^0.8.0;

interface IERC20Token {
  function transfer(address, uint256) external returns (bool);
  function approve(address, uint256) external returns (bool);
  function transferFrom(address, address, uint256) external returns (bool);
  function totalSupply() external view returns (uint256);
  function balanceOf(address) external view returns (uint256);
  function allowance(address, address) external view returns (uint256);

  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract PayBills {

    address private cUsdTokenAddress = 0x874069Fa1Eb16D44d622F2e0Ca25eeA172369bC1;

    struct Bill {
        address payable houseOwnerAdress;
        uint electricityCost;
        uint waterCost;
        uint internetCost;
        uint total;
        bool isPaid;
    }

    // [month] = Bill
    mapping(uint => Bill) private bills;

    modifier validMonthNumber(uint _month) {
        require(1 <= _month && _month <= 12, "Month number should be from 1 to 12");
        _;
    }
    
    function createBill(
        uint _month,
        uint _electricityCost,
        uint _waterCost,
        uint _internetCost
    ) public validMonthNumber(_month)  {
        bills[_month] = Bill(
            payable(msg.sender),
            _electricityCost,
            _waterCost,
            _internetCost,
            _electricityCost + _waterCost + _internetCost,
            false
        );
    }

    function payBill(uint _month) public payable {
        require(msg.sender != bills[_month].houseOwnerAdress);
        require(
          IERC20Token(cUsdTokenAddress).transferFrom(
            msg.sender,             // from
            bills[_month].houseOwnerAdress,  // to
            bills[_month].total              // bill cost
          ),
          "Transfer failed."
        );
        bills[_month].isPaid = true;
    }

    function getBill(uint _month) public view validMonthNumber(_month) 
    returns (
        address houseOwnerAdress,
        uint electricityCost, 
        uint waterCost, 
        uint internetCost, 
        uint total,
        bool isPaid
    )
    {
        Bill memory bill = bills[_month];
        return (
            houseOwnerAdress    = bill.houseOwnerAdress,
            electricityCost     = bill.electricityCost,
            waterCost           = bill.waterCost,
            internetCost        = bill.internetCost,
            total               = bill.total,
            isPaid              = bill.isPaid
        );
    }


}