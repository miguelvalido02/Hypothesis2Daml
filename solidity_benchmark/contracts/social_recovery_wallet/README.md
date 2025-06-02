# Social Recovery Wallet
This is a simplified version of
[this](https://github.com/verumlotus/social-recovery-wallet/blob/main/src/Wallet.sol)
contract by [@verumlotus](https://github.com/verumlotus).

The concept was popularized by
[this](https://vitalik.ca/general/2021/01/11/recovery.html) article by Vitalik Buterin.

## Specification
This wallet can be used by the owner to make transactions by calling `the
executeExternalTx()` function, by provinding the desired recipient
contract/externally owned account (EOA), an ether value, and arbitrary data.

In case of lost private key, a recovery process can be initiated by a guardian.
The guardian first calls `initiateRecovery()` with the address of the new
owner, followed by a threshold number of guardians calling `supportRecovery()`
with the new owner's address. Finally, any guardian can call
`executeRecovery()` to change the wallet's owner.

Additionally, owners have the ability to manage guardians by removing
compromised or malicious guardians. The owner initiates the removal process by
calling `initiateGuardianRemoval()` with the hash of the guardian's address,
which queues the guardian for removal after a 3-day delay. The owner then calls
`executeGuardianRemoval()` after the delay, providing the hash of a new
guardian's address to finalize the removal and add the new guardian.
Alternatively, the owner can call `cancelGuardianRemoval()` to restore the
guardian state.


## Properties
- **no-recov**: the recovery can never happen (should fail).
- **owner-cannot-change**: the first owner is always the owner, in other words: the owner cannot change (should fail).
- **recov-fails**: `executeRecovery()` will fail if not enough guardians have joined the recovery process.
- **recov-implies-guardian**: if an address `addr` has participated in a recovery, then `addr` is a guardian. Should fail in v1 because guardians can be removed.
- **recov-succeeds**: if a number of guardians greater than or equal to the threshold have participated in the same recovery round, and selected the same new owner, then `executeRecovery()` will succeed and `owner == newOwner`.

## Versions
- **v1**: conformant to specification
- **v2**: removed guardian management

## Ground truth
|        | no-recov               | owner-cannot-change    | recov-fails            | recov-implies-guardian | recov-succeeds         |
|--------|------------------------|------------------------|------------------------|------------------------|------------------------|
| **v1** | 0                      | 0                      | 1                      | 0                      | 1                      |
| **v2** | 0                      | 0                      | 1                      | 1                      | 1                      |
 

## Experiments
