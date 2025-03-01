// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITRC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract TronLottery {
    address public owner;
    ITRC20 public usdt;

    enum Status { PENDING, LOST, WON, CLAIMED }

    struct Ticket {
        uint256 contestId;
        address user;
        Status status;
        uint256 participationAmount;
        uint256 winningAmount;
    }

    mapping(uint256 => Ticket[]) public contestTickets;
    mapping(address => uint256[]) public userTickets;

    event TicketPurchased(address indexed user, uint256 contestId, uint256 amount);
    event WinnersDeclared(uint256 contestId);
    event PrizeClaimed(address indexed user, uint256 contestId, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not contract owner");
        _;
    }

    constructor(address _usdt) {
        owner = msg.sender;
        usdt = ITRC20(_usdt);
    }

    function buyTicket(uint256 contestId, uint256 amount) external {
        require(amount > 0, "Amount must be greater than zero");
        require(usdt.transferFrom(msg.sender, address(this), amount), "USDT transfer failed");

        Ticket memory newTicket = Ticket({
            contestId: contestId,
            user: msg.sender,
            status: Status.PENDING,
            participationAmount: amount,
            winningAmount: 0
        });

        contestTickets[contestId].push(newTicket);
        userTickets[msg.sender].push(contestTickets[contestId].length - 1);

        emit TicketPurchased(msg.sender, contestId, amount);
    }

    function setWinners(uint256 contestId, address[] calldata winners, uint256[] calldata winningAmounts) external onlyOwner {
        require(winners.length == winningAmounts.length, "Mismatched array lengths");

        for (uint256 i = 0; i < winners.length; i++) {
            for (uint256 j = 0; j < contestTickets[contestId].length; j++) {
                if (contestTickets[contestId][j].user == winners[i]) {
                    contestTickets[contestId][j].status = Status.WON;
                    contestTickets[contestId][j].winningAmount = winningAmounts[i];
                }
            }
        }
        emit WinnersDeclared(contestId);
    }

    function claimPrize(uint256 contestId) external {
        for (uint256 i = 0; i < contestTickets[contestId].length; i++) {
            Ticket storage ticket = contestTickets[contestId][i];
            if (ticket.user == msg.sender && ticket.status == Status.WON) {
                require(usdt.transfer(msg.sender, ticket.winningAmount), "USDT transfer failed");
                ticket.status = Status.CLAIMED;
                emit PrizeClaimed(msg.sender, contestId, ticket.winningAmount);
            }
        }
    }
}
