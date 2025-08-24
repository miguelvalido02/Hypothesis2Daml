# tests/test_zerotokenbank.py
import base64, json, requests
from decimal import Decimal
from hypothesis import given, settings, strategies as st

BASE = "http://localhost:7575/v1"

# Package ID from your DAR (seen in the error you pasted)
PKG = "c6f004b1cd672ae532964d33767186c66d1b0673ce87a0e05b35e7b78c2fc514"

# JSON API expects a single string: "<packageId>:<module>:<entity>"
BANK_TID = f"{PKG}:ZeroTokenBank:Bank"
UB_TID   = f"{PKG}:ZeroTokenBank:UserBalance"

# Your allocated party id (exact string from `daml ledger allocate-parties`)
ALICE = "Alice::12209b2da14834fdb9899c0556179fe1c4b087f2e26aca8fc7c725d1a6844ea9b0df"

def make_auth(act_as_party: str):
    # Dev JWT with alg=none; fine for local JSON API
    def b64url(b: bytes) -> str: return base64.urlsafe_b64encode(b).rstrip(b"=").decode("ascii")
    header  = b64url(json.dumps({"alg":"none","typ":"JWT"}).encode())
    payload = b64url(json.dumps({
        "https://daml.com/ledger-api": {
            "ledgerId": "sandbox",
            "applicationId": "pbt-tests",
            "actAs": [act_as_party],
            "readAs": []
        }
    }).encode())
    return {"Authorization": f"Bearer {header}.{payload}."}

def create_bank(operator: str) -> str:
    r = requests.post(
        f"{BASE}/create",
        json={"templateId": BANK_TID, "payload": {"operator": operator}},
        headers=make_auth(operator),
    )
    if r.status_code != 200:
        raise AssertionError(f"/create failed {r.status_code}: {r.text}")
    return r.json()["result"]["contractId"]

def open_account(bank_cid: str, operator: str, user: str) -> str:
    cmd = {"templateId": BANK_TID, "contractId": bank_cid, "choice": "OpenAccount",
           "argument": {"user": user}}
    r = requests.post(f"{BASE}/exercise", json=cmd, headers=make_auth(operator))
    if r.status_code != 200:
        raise AssertionError(f"/exercise OpenAccount failed {r.status_code}: {r.text}")
    return r.json()["result"]["exerciseResult"]

def deposit(ub_cid: str, user: str, amount: Decimal) -> str:
    cmd = {"templateId": UB_TID, "contractId": ub_cid, "choice": "Deposit",
           "argument": {"amount": str(amount)}}
    r = requests.post(f"{BASE}/exercise", json=cmd, headers=make_auth(user))
    if r.status_code != 200:
        raise AssertionError(f"/exercise Deposit failed {r.status_code}: {r.text}")
    return r.json()["result"]["exerciseResult"]

def get_balance(ub_cid: str, user: str) -> Decimal:
    cmd = {"templateId": UB_TID, "contractId": ub_cid, "choice": "GetBalance", "argument": {}}
    r = requests.post(f"{BASE}/exercise", json=cmd, headers=make_auth(user))
    if r.status_code != 200:
        raise AssertionError(f"/exercise GetBalance failed {r.status_code}: {r.text}")
    return Decimal(str(r.json()["result"]["exerciseResult"]))

@given(d=st.decimals(min_value="0.01", max_value="199.99", places=2))
@settings(max_examples=5, deadline=None)
def test_deposit_increases_balance(d):
    bank = create_bank(ALICE)
    ub   = open_account(bank, ALICE, ALICE)
    b0   = get_balance(ub, ALICE)
    ub   = deposit(ub, ALICE, Decimal(d))
    b1   = get_balance(ub, ALICE)
    assert b1 == b0 + Decimal(d)
