# tests/test_zerotokenbank.py
import base64, json, requests, uuid
from decimal import Decimal
from hypothesis import given, settings, strategies as st

BASE = "http://localhost:7575/v1"

# Package ID from your DAR
PKG = "c6f004b1cd672ae532964d33767186c66d1b0673ce87a0e05b35e7b78c2fc514"

# JSON API wants "<packageId>:<module>:<entity>"
BANK_TID = f"{PKG}:ZeroTokenBank:Bank"
UB_TID   = f"{PKG}:ZeroTokenBank:UserBalance"

# ---------- Auth helpers ----------

def _b64url(b: bytes) -> str:
    return base64.urlsafe_b64encode(b).rstrip(b"=").decode("ascii")

def make_auth(act_as_party=None, read_as=None, ledger_id="sandbox", app_id="pbt-tests"):
    """Dev JWT (alg=none) for normal ledger calls: create/exercise/query."""
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

def make_admin_auth(ledger_id="sandbox", app_id="pbt-tests"):
    """Dev JWT (alg=none) with admin privileges for /v1/parties endpoints."""
    header  = _b64url(json.dumps({"alg": "none", "typ": "JWT"}).encode())
    payload = _b64url(json.dumps({
        "https://daml.com/ledger-api": {
            "ledgerId": ledger_id,
            "applicationId": app_id,
            "admin": True
        }
    }).encode())
    return {"Authorization": f"Bearer {header}.{payload}."}

# ---------- Generic request helper ----------

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
    act_as=None,
    read_as=None,
    template_id=None,
    payload=None,
    contract_id=None,
    choice=None,
    argument=None,
    template_ids=None,
    query=None,
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

# ---------- Party management (unique per example) ----------

def allocate_party(identifier_hint: str, display_name: str | None = None, is_local: bool = True) -> str:
    body = {
        "identifierHint": identifier_hint,
        "displayName": display_name or identifier_hint,
        "isLocal": is_local,
    }
    r = requests.post(f"{BASE}/parties/allocate", json=body, headers=make_admin_auth())
    res = ensure_ok(r, "/parties/allocate")
    if "party" in res:
        return res["party"]
    if "partyDetails" in res and isinstance(res["partyDetails"], dict) and "party" in res["partyDetails"]:
        return res["partyDetails"]["party"]
    if "identifier" in res:
            return res["identifier"]
    raise AssertionError(f"/parties/allocate unexpected result shape: {res}")

def allocate_unique_party(prefix: str = "Operator") -> str:
    """Always-new party (prevents flakiness from shared state)."""
    hint = f"{prefix}-{uuid.uuid4().hex[:12]}"
    return allocate_party(hint, display_name=hint)

# ------------Specific to this contract ----------

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
