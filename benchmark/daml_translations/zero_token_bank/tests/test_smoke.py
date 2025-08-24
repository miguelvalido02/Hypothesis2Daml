import requests
from decimal import Decimal
from hypothesis import given, settings, strategies as st

BASE = "http://localhost:7575/v1"
AUTH = {"Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJodHRwczovL2RhbWwuY29tL2xlZGdlci1hcGkiOnsibGVkZ2VySWQiOiJzYW5kYm94IiwiYXBwbGljYXRpb25JZCI6IkhUVFAtSlNPTi1BUEktR2F0ZXdheSIsImFjdEFzIjpbIkFsaWNlIl19fQ.FIjS4ao9yu1XYnv1ZL3t7ooPNIyQYAHY3pmzej4EMCM"}

BANK_TID = "ZeroTokenBank:Bank"
UB_TID   = "ZeroTokenBank:UserBalance"

def hdr_actas(party: str):
    return {**AUTH, "X-DA-ActAs": party}

def alloc(name: str) -> str:
    r = requests.post(f"{BASE}/parties/allocate",
                      json={"identifierHint": name},
                      headers=AUTH)
    r.raise_for_status()
    return r.json()["result"]["party"]

def create_bank(operator: str) -> str:
    r = requests.post(f"{BASE}/create",
                      json={"templateId": BANK_TID, "payload": {"operator": operator}},
                      headers=hdr_actas(operator))
    r.raise_for_status()
    return r.json()["result"]["contractId"]

def open_account(bank_cid: str, operator: str, user: str) -> str:
    cmd = {"templateId": BANK_TID, "contractId": bank_cid,
           "choice": "OpenAccount", "argument": {"user": user}}
    r = requests.post(f"{BASE}/exercise", json=cmd, headers=hdr_actas(operator))
    r.raise_for_status()
    return r.json()["result"]["exerciseResult"]  # ContractId UserBalance

def deposit(ub_cid: str, user: str, amount: Decimal) -> str:
    cmd = {"templateId": UB_TID, "contractId": ub_cid,
           "choice": "Deposit", "argument": {"amount": str(amount)}}
    r = requests.post(f"{BASE}/exercise", json=cmd, headers=hdr_actas(user))
    r.raise_for_status()
    return r.json()["result"]["exerciseResult"]

def withdraw(ub_cid: str, user: str, amount: Decimal) -> str:
    cmd = {"templateId": UB_TID, "contractId": ub_cid,
           "choice": "Withdraw", "argument": {"amount": str(amount)}}
    r = requests.post(f"{BASE}/exercise", json=cmd, headers=hdr_actas(user))
    r.raise_for_status()
    return r.json()["result"]["exerciseResult"]

def get_balance(ub_cid: str, user: str) -> Decimal:
    cmd = {"templateId": UB_TID, "contractId": ub_cid, "choice": "GetBalance", "argument": {}}
    r = requests.post(f"{BASE}/exercise", json=cmd, headers=hdr_actas(user))
    r.raise_for_status()
    return Decimal(str(r.json()["result"]["exerciseResult"]))

def setup_account():
    operator = alloc("Operator")
    user     = alloc("User")
    bank     = create_bank(operator)
    ub       = open_account(bank, operator, user)
    return operator, user, ub

@given(d=st.decimals(min_value="0.01", max_value="199.99", places=2))
@settings(max_examples=20, deadline=None)
def test_deposit_increases_balance(d):
    _, user, ub = setup_account()
    b0 = get_balance(ub, user)
    ub = deposit(ub, user, Decimal(d))
    b1 = get_balance(ub, user)
    assert b1 == b0 + Decimal(d)

@given(
    deps=st.lists(st.decimals(min_value="0.01", max_value="199.99", places=2), min_size=1, max_size=10),
    wds =st.lists(st.decimals(min_value="0.01", max_value="100.00",  places=2), min_size=0, max_size=10),
)
@settings(max_examples=15, deadline=None)
def test_sum_withdrawals_le_sum_deposits_and_nonneg(deps, wds):
    _, user, ub = setup_account()
    total_dep = Decimal("0")
    total_wd  = Decimal("0")

    for x in deps:
        x = Decimal(x)
        ub = deposit(ub, user, x)
        total_dep += x

    for x in wds:
        x = Decimal(x)
        bal = get_balance(ub, user)
        amt = min(Decimal("100.00"), x, bal)
        if amt > 0:
            ub = withdraw(ub, user, amt)
            total_wd += amt

    final_bal = get_balance(ub, user)
    assert final_bal >= 0
    assert total_wd <= total_dep
    assert final_bal == total_dep - total_wd

@settings(max_examples=10, deadline=None)
@given(seed=st.integers(min_value=1, max_value=10**9))
def test_can_withdraw_all_in_finite_steps(seed):
    _, user, ub = setup_account()
    import random
    random.seed(seed)
    for _ in range(random.randint(2, 6)):
        amt = Decimal(str(round(random.uniform(1, 199.99), 2)))
        ub = deposit(ub, user, amt)

    while True:
        bal = get_balance(ub, user)
        if bal == 0:
            break
        step = min(bal, Decimal("100.00"))
        ub = withdraw(ub, user, step)

    assert get_balance(ub, user) == 0