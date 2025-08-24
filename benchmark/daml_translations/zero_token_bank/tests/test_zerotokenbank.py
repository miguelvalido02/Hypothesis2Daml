# tests/test_zerotokenbank.py
import base64, json, requests
from decimal import Decimal
from hypothesis import given, settings, strategies as st

BASE = "http://localhost:7575/v1"

# Package ID from your DAR
PKG = "c6f004b1cd672ae532964d33767186c66d1b0673ce87a0e05b35e7b78c2fc514"

# JSON API wants "<packageId>:<module>:<entity>"
BANK_TID = f"{PKG}:ZeroTokenBank:Bank"
UB_TID   = f"{PKG}:ZeroTokenBank:UserBalance"

# Your allocated party id (exact string)
ALICE = "Alice::12209b2da14834fdb9899c0556179fe1c4b087f2e26aca8fc7c725d1a6844ea9b0df"

# ---------- Auth + Request plumbing ----------

def _b64url(b: bytes) -> str:
    return base64.urlsafe_b64encode(b).rstrip(b"=").decode("ascii")

def make_auth(act_as_party: str | None = None, read_as: list[str] | None = None,
              ledger_id: str = "sandbox", app_id: str = "pbt-tests") -> dict[str, str]:
    """Dev JWT (alg=none). Works locally with JSON API."""
    act_as = [act_as_party] if act_as_party else []
    read_as = read_as or []
    header  = _b64url(json.dumps({"alg": "none", "typ": "JWT"}).encode())
    payload = _b64url(json.dumps({
        "https://daml.com/ledger-api": {
            "ledgerId": ledger_id,
            "applicationId": app_id,
            "actAs": act_as,
            "readAs": read_as,
        }
    }).encode())
    return {"Authorization": f"Bearer {header}.{payload}."}

def ensure_ok(r: requests.Response, context: str) -> dict:
    if r.status_code != 200:
        raise AssertionError(f"{context} failed {r.status_code}: {r.text}")
    body = r.json()
    if "result" not in body:
        raise AssertionError(f"{context} missing 'result': {body}")
    return body["result"]

def make_request(
    op: str,
    *,
    act_as: str | None = None,
    read_as: list[str] | None = None,
    template_id: str | None = None,
    payload: dict | None = None,
    contract_id: str | None = None,
    choice: str | None = None,
    argument: dict | None = None,
    template_ids: list[str] | None = None,
    query: dict | None = None,
) -> dict:
    """
    Generic JSON API call.

    op:
      - "create": requires template_id, payload
      - "exercise": requires template_id, contract_id, choice, argument
      - "query": requires template_ids (list[str]) and optional query dict
    Returns the 'result' object from JSON API response.
    """
    headers = make_auth(act_as, read_as)

    if op == "create":
        body = {"templateId": template_id, "payload": payload}
        r = requests.post(f"{BASE}/create", json=body, headers=headers)
        return ensure_ok(r, "/create")

    elif op == "exercise":
        body = {
            "templateId": template_id,
            "contractId": contract_id,
            "choice": choice,
            "argument": argument or {},
        }
        r = requests.post(f"{BASE}/exercise", json=body, headers=headers)
        return ensure_ok(r, "/exercise")

    elif op == "query":
        body = {"templateIds": template_ids or [], "query": query or {}}
        r = requests.post(f"{BASE}/query", json=body, headers=headers)
        return ensure_ok(r, "/query")

    else:
        raise ValueError(f"Unsupported op '{op}'")

# ---------- Helpers built on make_request ----------

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
    bank = create_bank(ALICE)
    ub   = open_account(bank, ALICE, ALICE)
    b0   = get_balance(ub, ALICE)
    ub   = deposit(ub, ALICE, Decimal(d))
    b1   = get_balance(ub, ALICE)
    assert b1 == b0 + Decimal(d)
