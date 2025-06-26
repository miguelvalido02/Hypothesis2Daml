pragma solidity 0.5.7;

/**

 * @title ERC20 interface

 * @dev see https://eips.ethereum.org/EIPS/eip-20

 */

interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);
}

contract Trickle {
    uint256 private lastAgreementId;

    struct Agreement {
        IERC20 token;
        address recipient;
        address sender;
        uint256 totalAmount;
        uint256 releasedAmount;
        bool cancelled;
    }

    mapping(uint256 => Agreement) private agreements;

    modifier senderOnly(uint256 agreementId) {
        require(msg.sender == agreements[agreementId].sender);

        _;
    }

    function createAgreement(
        IERC20 token,
        address recipient,
        uint256 totalAmount
    ) external {
        require(totalAmount > 0);

        require(token != IERC20(0x0));

        require(recipient != address(0x0));

        uint256 agreementId = ++lastAgreementId;

        agreements[agreementId] = Agreement({
            token: token,
            recipient: recipient,
            totalAmount: totalAmount,
            sender: msg.sender,
            releasedAmount: 0,
            cancelled: false
        });

        token.transferFrom(
            agreements[agreementId].sender,
            address(this),
            agreements[agreementId].totalAmount
        );
    }

    function getAgreement(
        uint256 agreementId
    )
        external
        view
        returns (
            IERC20 token,
            address recipient,
            address sender,
            uint256 totalAmount,
            uint256 releasedAmount,
            bool cancelled
        )
    {
        Agreement memory record = agreements[agreementId];

        return (
            record.token,
            record.recipient,
            record.sender,
            record.totalAmount,
            record.releasedAmount,
            record.cancelled
        );
    }

    function withdrawTokens(uint256 agreementId) public {
        require(
            agreementId <= lastAgreementId && agreementId != 0,
            "Invalid agreement specified"
        );

        Agreement storage record = agreements[agreementId];

        require(!record.cancelled);

        uint256 unreleased = withdrawAmount(agreementId);

        require(unreleased > 0);

        record.releasedAmount = record.releasedAmount + unreleased;

        record.token.transfer(record.recipient, unreleased);
    }

    function cancelAgreement(
        uint256 agreementId
    ) external senderOnly(agreementId) {
        Agreement storage record = agreements[agreementId];

        require(!record.cancelled);

        if (withdrawAmount(agreementId) > 0) {
            withdrawTokens(agreementId);
        }

        uint256 releasedAmount = record.releasedAmount;

        uint256 cancelledAmount = record.totalAmount - releasedAmount;

        record.token.transfer(record.sender, cancelledAmount);

        record.cancelled = true;
    }

    function withdrawAmount(
        uint256 agreementId
    ) private view returns (uint256) {
        return
            availableAmount(agreementId) -
            agreements[agreementId].releasedAmount;
    }

    function availableAmount(
        uint256 agreementId
    ) private view returns (uint256) {
        return agreements[agreementId].totalAmount;
    }
}
