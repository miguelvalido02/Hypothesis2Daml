import base64, json, requests, uuid
from decimal import Decimal
from hypothesis import given, settings, strategies as st
from daml_pbt import make_request, make_auth, make_admin_auth, ensure_ok, allocate_party, allocate_unique_party

# Package ID from the DAR
PKG = "c6f004b1cd672ae532964d33767186c66d1b0673ce87a0e05b35e7b78c2fc514"

# JSON API wants "<packageId>:<module>:<entity>"
BANK_TID = f"{PKG}:ZeroTokenBank:Bank"
UB_TID   = f"{PKG}:ZeroTokenBank:UserBalance"

def create_bank(operator: str) -> str:
    # Create Bank:
    # - signatory = operator
    # - returns contractId of Bank
    res = make_request(
        "create",
        act_as=operator,
        template_id=BANK_TID,
        payload={"operator": operator},
    )
    return res["contractId"]

def open_account(bank_cid: str, operator: str, user: str) -> str:
    # Choice OpenAccount (by operator):
    # - creates UserBalance for 'user'
    # - initial balance = 0.0
    # - returns contractId of new UserBalance
    res = make_request(
        "exercise",
        act_as=operator,
        template_id=BANK_TID,
        contract_id=bank_cid,
        choice="OpenAccount",
        argument={"user": user},
    )
    return res["exerciseResult"]

def deposit(ub_cid: str, user: str, amount: Decimal) -> str:
    # Choice Deposit (by user):
    # - precondition: amount < 200.0
    # - effect: balance := balance + amount
    # - returns contractId of updated UserBalance
    res = make_request(
        "exercise",
        act_as=user,
        template_id=UB_TID,
        contract_id=ub_cid,
        choice="Deposit",
        argument={"amount": str(amount)},
    )
    return res["exerciseResult"]

def get_balance(ub_cid: str, user: str) -> Decimal:
    # Nonconsuming GetBalance (by user):
    # - returns Decimal current balance
    res = make_request(
        "exercise",
        act_as=user,
        template_id=UB_TID,
        contract_id=ub_cid,
        choice="GetBalance",
        argument={},
    )
    return Decimal(str(res["exerciseResult"]))

# ---------- Property tests ----------

@given(d=st.decimals(min_value="0.01", max_value="199.99", places=2))
@settings(max_examples=5, deadline=None)
def test_deposit_increases_balance(d:Decimal):
    # Setup: operator opens an account for herself
    operator = allocate_unique_party("Operator")      # unique party per example
    bank = create_bank(operator)                      # create Bank
    ub   = open_account(bank, operator, operator)     # create UserBalance with balance=0

    # Before deposit: balance = b0
    b0   = get_balance(ub, operator)

    # Action: Deposit 'd' (valid range per template)
    ub   = deposit(ub, operator, d)

    # After deposit: balance must increase by exactly 'd'
    b1   = get_balance(ub, operator)
    assert b1 == b0 + d

@given(amount=st.decimals(min_value="0.00", max_value="250.00", places=2))
@settings(max_examples=25, deadline=None)
def test_cannot_withdraw_any_amount_without_deposit(amount):
    # Setup: operator opens an account for Alice; starting balance = 0
    operator = allocate_unique_party("Operator")
    alice    = allocate_unique_party("Alice")
    bank     = create_bank(operator)
    ub       = open_account(bank, operator, alice)

    # Invariant: with zero balance, any Withdraw must fail
    assert get_balance(ub, alice) == Decimal("0")

    # Attempt Withdraw(amount) with balance=0:
    # - preconditions in template require amount > 0, amount <= 100, and amount <= balance
    # - since balance=0, request must fail for any amount > 0; and for amount=0 as well (amount>0 required)
    try:
        make_request(
            "exercise",
            act_as=alice,
            template_id=UB_TID,
            contract_id=ub,
            choice="Withdraw",
            argument={"amount": str(Decimal(amount))},
        )
    except AssertionError:
        return  # expected failure surfaced by ensure_ok
    raise AssertionError("expected withdrawal to fail with zero balance")
