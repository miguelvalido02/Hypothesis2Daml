# tests/test_zerotokenbank.py
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
    res = make_request(
        "create",
        act_as=operator,
        template_id=BANK_TID,
        payload={"operator": operator},
    )
    return res["contractId"]

def open_account(bank_cid: str, operator: str, user: str) -> str:
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
    res = make_request(
        "exercise",
        act_as=user,
        template_id=UB_TID,
        contract_id=ub_cid,
        choice="GetBalance",
        argument={},
    )
    return Decimal(str(res["exerciseResult"]))

# ---------- Property test ----------

@given(d=st.decimals(min_value="0.01", max_value="199.99", places=2))
@settings(max_examples=5, deadline=None)
def test_deposit_increases_balance(d):
    operator = allocate_unique_party("Operator")  # unique party for each example
    bank = create_bank(operator)
    ub   = open_account(bank, operator, operator)
    b0   = get_balance(ub, operator)
    ub   = deposit(ub, operator, Decimal(d))
    b1   = get_balance(ub, operator)
    assert b1 == b0 + Decimal(d)
