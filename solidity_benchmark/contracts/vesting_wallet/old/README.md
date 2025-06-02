# Vesting Wallet

## Specification
Vesting Wallet is a simpler version of
[this](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/finance/VestingWallet.sol)
implementation by OpenZeppelin. It handles the vesting of ethers for a given
beneficiary. The vesting follows a given vesting schedule, the default is a
linear curve. Every ether transferred to this contract will follow the vesting
schedule as if it was locked from the beginning. Consequently, if the vesting
has already started, any amount sent to this contract will be immediately
releasable.

## Versions
- **v1**: conformant to specification;
- **v2**: virtual block.number variable, see
  [BlockNumberSMT](../../smtCheckerNotes/block_number/);
- **v3**: virtual block.number, `_balance` & `_deposited` ghost variables.
- **v4**: `_balance` & `_deposited` ghost variables.
- **v5**: virtual block.number variable (`delay()` method)
- **v6**: virtual block.number (`delay()` method), `_balance` & `_deposited` ghost variables.

## Properties
- **p1**: the amount releasable is always less than or equal to the contract
  balance;
- **p2**: balance plus released equals total ever deposited.

## Experiments

|      | p1                 | p2                    |
| ---- | ------------------ | --------------------- |
|**v1**| :x:                | -                     |
|**v2**| :x:                | :x:                   |
|**v3**| :x:                | :heavy_check_mark:    |
|**v4**| -                  | :x:                   |
|**v5**| :x:                | :x:                   |
|**v6**| :x:                | :question:            |
