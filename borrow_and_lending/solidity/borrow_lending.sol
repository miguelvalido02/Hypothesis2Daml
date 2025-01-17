// Borrow and lending © 2025 by Miguel Valido is licensed under CC BY 4.0

pragma solidity ^0.8.26;

interface IERC20 {
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    function balanceOf(address account) external view returns (uint256);
}

contract BorrowAndLending {
    //Assumes all tokens have the same decimals and the same price
    struct Borrower {
        uint amountBorrowed;
        uint collateralAmount;
        address collateralToken;
        bool hasRepaid;
    }

    mapping(address => mapping(address => uint256)) public lenders; // lender -> token -> amountLent
    mapping(address => mapping(address => Borrower)) public borrowers; // borrower -> token -> Borrower

    mapping(address => uint256) public totalLendingPool; // token -> amount

    address[] public borrowTokens;
    address[] public collateralTokens;

    // Constructor accepts arrays of borrow tokens and collateral tokens
    constructor(
        address[] memory _borrowTokens,
        address[] memory _collateralTokens
    ) {
        borrowTokens = _borrowTokens;
        collateralTokens = _collateralTokens;
    }

    function lend(address _collateralToken, uint _amount) external {
        require(_amount > 0, "Lending amount must be greater than zero");
        require(
            isValidCollateralToken(_collateralToken),
            "Invalid collateral token"
        );

        IERC20 collateralToken = IERC20(_collateralToken);
        require(
            collateralToken.transferFrom(msg.sender, address(this), _amount),
            "Token transfer failed"
        );

        lenders[msg.sender][_collateralToken] += _amount;

        totalLendingPool[_collateralToken] += _amount;
    }

    function borrow(
        address _borrowToken,
        uint _borrowAmount,
        address _collateralToken,
        uint _collateralAmount
    ) external {
        require(_borrowAmount > 0, "Borrow amount must be greater than zero");
        require(isValidBorrowToken(_borrowToken), "Invalid borrow token");
        require(
            isValidCollateralToken(_collateralToken),
            "Invalid collateral token"
        );
        require(
            lenders[msg.sender][_collateralToken] >= _collateralAmount,
            "No sufficient collateral lent"
        );
        require(
            _collateralAmount > 2 * _borrowAmount,
            "Collateral must be greater than 2x the borrow amount"
        );
        require(
            borrowers[msg.sender][_borrowToken].amountBorrowed == 0 ||
                borrowers[msg.sender][_borrowToken].hasRepaid == true,
            "Borrower already has an active loan"
        );

        // Reduce the collateral amount from the lender's balance
        lenders[msg.sender][_collateralToken] -= _collateralAmount;

        require(
            _borrowAmount <= totalLendingPool[_borrowToken],
            "Not enough liquidity in the pool"
        );

        totalLendingPool[_borrowToken] -= _borrowAmount;

        // Store the borrow details in the Borrower struct
        borrowers[msg.sender][_borrowToken] = Borrower({
            amountBorrowed: _borrowAmount,
            collateralAmount: _collateralAmount,
            collateralToken: _collateralToken,
            hasRepaid: false
        });

        IERC20 borrowToken = IERC20(_borrowToken);
        require(
            borrowToken.transfer(msg.sender, _borrowAmount),
            "Borrow transfer failed"
        );
    }

    function repay(address _borrowToken) external {
        Borrower storage borrower = borrowers[msg.sender][_borrowToken];
        require(borrower.amountBorrowed > 0, "No loan to repay");
        require(!borrower.hasRepaid, "Loan already repaid");

        uint repaymentAmount = borrower.amountBorrowed;

        // Update state before making external calls (checks-effects-interactions pattern)
        borrower.hasRepaid = true;

        IERC20 borrowToken = IERC20(_borrowToken);
        require(
            borrowToken.transferFrom(
                msg.sender,
                address(this),
                repaymentAmount
            ),
            "Repayment failed"
        );

        lenders[msg.sender][borrower.collateralToken] += borrower
            .collateralAmount;
        totalLendingPool[borrower.collateralToken] += borrower.collateralAmount;

        // Increase the lending pool balance of the borrow token
        totalLendingPool[_borrowToken] += repaymentAmount;
    }

    function withdraw(address _collateralToken) external {
        uint amountLent = lenders[msg.sender][_collateralToken];
        require(amountLent > 0, "No assets to withdraw");

        require(
            amountLent <= totalLendingPool[_collateralToken],
            "Not enough funds to withdraw"
        );

        // Update state before making external calls (checks-effects-interactions pattern)
        lenders[msg.sender][_collateralToken] = 0;
        totalLendingPool[_collateralToken] -= amountLent;

        IERC20 collateralToken = IERC20(_collateralToken);
        require(
            collateralToken.transfer(msg.sender, amountLent),
            "Withdrawal transfer failed"
        );
    }

    function getLendingPoolBalance(
        address _token
    ) external view returns (uint256) {
        return totalLendingPool[_token];
    }

    // Helper function to check if the collateral token is valid
    function isValidCollateralToken(
        address _token
    ) internal view returns (bool) {
        for (uint i = 0; i < collateralTokens.length; i++) {
            if (collateralTokens[i] == _token) {
                return true;
            }
        }
        return false;
    }

    // Helper function to check if the borrow token is valid
    function isValidBorrowToken(address _token) internal view returns (bool) {
        for (uint i = 0; i < borrowTokens.length; i++) {
            if (borrowTokens[i] == _token) {
                return true;
            }
        }
        return false;
    }
}
