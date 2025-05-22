pragma solidity ^0.5.0;

//0xdC4c1B5ffFf18111CC856B65757cB9E8B76164E9.sol
interface IMarket {
    function isFinalized() external view returns (bool);

    function isInvalid() external view returns (bool);

    function getWinningPayoutNumerator(
        uint256 _outcome
    ) external view returns (uint256);

    function getEndTime() external view returns (uint256);
}

contract CharityChallenge {
    event Received(address indexed sender, uint256 value);

    event Donated(address indexed npo, uint256 value);

    event Claimed(address indexed claimer, uint256 value);

    event SafetyHatchClaimed(address indexed claimer, uint256 value);

    address payable public contractOwner;

    // key is npo address, value is ratio

    mapping(address => uint8) public npoRatios;

    uint8 sumRatio;

    address payable[] public npoAddresses;

    address public marketAddress;

    bool public unlockOnNo;

    IMarket market;

    uint256 public challengeEndTime;

    uint256 public challengeSafetyHatchTime1;

    uint256 public challengeSafetyHatchTime2;

    // Valid outcomes are 'YES', 'NO' and 'INVALID'

    bool public isEventFinalized;

    // hasChallengeAccomplished will be set to true if we got the expected

    // result that allow to unlock the funds.

    bool public hasChallengeAccomplished;

    bool private safetyHatchClaimSucceeded;

    mapping(address => uint256) public donorBalances;

    uint256 public donorCount;

    constructor(
        address payable _contractOwner,
        address payable[] memory _npoAddresses,
        uint8[] memory _ratios,
        address _marketAddress,
        bool _unlockOnNo
    ) public {
        require(_npoAddresses.length == _ratios.length);

        uint length = _npoAddresses.length;

        for (uint i = 0; i < length; i++) {
            address payable npo = _npoAddresses[i];

            npoAddresses.push(npo);

            require(_ratios[i] > 0, "Ratio must be a positive number");

            npoRatios[npo] = _ratios[i];

            sumRatio += _ratios[i];
        }

        contractOwner = _contractOwner;

        marketAddress = _marketAddress;

        market = IMarket(_marketAddress);

        unlockOnNo = _unlockOnNo;

        challengeEndTime = market.getEndTime();

        challengeSafetyHatchTime1 = challengeEndTime + 26 weeks;

        challengeSafetyHatchTime2 = challengeSafetyHatchTime1 + 52 weeks;

        isEventFinalized = false;

        hasChallengeAccomplished = false;
    }

    function() external payable {
        require(now <= challengeEndTime);

        require(msg.value > 0);

        if (donorBalances[msg.sender] == 0 && msg.value > 0) {
            donorCount++;
        }

        donorBalances[msg.sender] += msg.value;

        emit Received(msg.sender, msg.value);
    }

    function balanceOf(address _donorAddress) public view returns (uint256) {
        if (safetyHatchClaimSucceeded) {
            return 0;
        }

        return donorBalances[_donorAddress];
    }

    function finalize() external {
        require(now > challengeEndTime);

        require(now <= challengeSafetyHatchTime1);

        require(!isEventFinalized);

        doFinalize();
    }

    function doFinalize() private {
        bool hasError;

        (hasChallengeAccomplished, hasError) = checkAugur();
        //require(!hasError);
        if (!hasError) {
            isEventFinalized = true;

            if (hasChallengeAccomplished) {
                uint256 totalContractBalance = address(this).balance;

                uint length = npoAddresses.length;

                uint256 donatedAmount = 0;

                for (uint i = 0; i < length - 1; i++) {
                    address payable npo = npoAddresses[i];

                    uint8 ratio = npoRatios[npo];

                    uint256 amount = (totalContractBalance * ratio) / sumRatio;

                    donatedAmount += amount;

                    npo.transfer(amount);

                    emit Donated(npo, amount);
                }

                // Don't want to keep any amount in the contract

                uint256 remainingAmount = totalContractBalance - donatedAmount;

                address payable npo = npoAddresses[length - 1];

                npo.transfer(remainingAmount);

                emit Donated(npo, remainingAmount);
            }
        }
    }

    function getExpectedDonationAmount(
        address payable _npo
    ) external view returns (uint256) {
        require(npoRatios[_npo] > 0);

        uint256 totalContractBalance = address(this).balance;

        uint8 ratio = npoRatios[_npo];

        uint256 amount = (totalContractBalance * ratio) / sumRatio;

        return amount;
    }

    function claim() external {
        require(now > challengeEndTime);

        require(isEventFinalized || now > challengeSafetyHatchTime1);

        require(!hasChallengeAccomplished || now > challengeSafetyHatchTime1);

        require(balanceOf(msg.sender) > 0);

        uint256 claimedAmount = balanceOf(msg.sender);

        donorBalances[msg.sender] = 0;

        msg.sender.transfer(claimedAmount);

        emit Claimed(msg.sender, claimedAmount);
    }

    function safetyHatchClaim() external {
        require(now > challengeSafetyHatchTime2);

        require(msg.sender == contractOwner);

        uint totalContractBalance = address(this).balance;

        safetyHatchClaimSucceeded = true;

        contractOwner.transfer(address(this).balance);

        emit SafetyHatchClaimed(contractOwner, totalContractBalance);
    }

    function checkAugur() private view returns (bool happened, bool errored) {
        if (market.isFinalized()) {
            if (market.isInvalid()) {
                // Treat 'invalid' outcome as 'no'
                // because 'invalid' is one of the valid outcomes

                return (false, false);
            } else {
                uint256 no = market.getWinningPayoutNumerator(0);

                uint256 yes = market.getWinningPayoutNumerator(1);

                if (unlockOnNo) {
                    return (yes < no, false);
                }

                return (yes > no, false);
            }
        } else {
            return (false, true);
        }
    }
}
//[{"constant":false,"inputs":[],"name":"safetyHatchClaim","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[{"name":"","type":"uint256"}],"name":"npoAddresses","outputs":[{"name":"","type":"address"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"hasChallengeAccomplished","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[],"name":"finalize","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[],"name":"claim","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[{"name":"","type":"address"}],"name":"npoRatios","outputs":[{"name":"","type":"uint8"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_npo","type":"address"}],"name":"getExpectedDonationAmount","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_donorAddress","type":"address"}],"name":"balanceOf","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"","type":"address"}],"name":"donorBalances","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"challengeSafetyHatchTime1","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"marketAddress","outputs":[{"name":"","type":"address"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"isEventFinalized","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"unlockOnNo","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"challengeEndTime","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"donorCount","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"contractOwner","outputs":[{"name":"","type":"address"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"challengeSafetyHatchTime2","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"VERSION","outputs":[{"name":"","type":"string"}],"payable":false,"stateMutability":"view","type":"function"},{"inputs":[{"name":"_contractOwner","type":"address"},{"name":"_npoAddresses","type":"address[]"},{"name":"_ratios","type":"uint8[]"},{"name":"_marketAddress","type":"address"},{"name":"_unlockOnNo","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"constructor"},{"payable":true,"stateMutability":"payable","type":"fallback"},{"anonymous":false,"inputs":[{"indexed":true,"name":"sender","type":"address"},{"indexed":false,"name":"value","type":"uint256"}],"name":"Received","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"name":"npo","type":"address"},{"indexed":false,"name":"value","type":"uint256"}],"name":"Donated","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"name":"claimer","type":"address"},{"indexed":false,"name":"value","type":"uint256"}],"name":"Claimed","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"name":"claimer","type":"address"},{"indexed":false,"name":"value","type":"uint256"}],"name":"SafetyHatchClaimed","type":"event"}]
