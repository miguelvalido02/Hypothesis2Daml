# daml_pbt.py
import base64, json, requests, uuid

BASE = "http://localhost:7575/v1"

def _b64url(b: bytes) -> str:
    return base64.urlsafe_b64encode(b).rstrip(b"=").decode("ascii")

def make_auth(act_as_party=None, read_as=None, ledger_id="sandbox", app_id="pbt-tests"):
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
    header  = _b64url(json.dumps({"alg": "none", "typ": "JWT"}).encode())
    payload = _b64url(json.dumps({
        "https://daml.com/ledger-api": {
            "ledgerId": ledger_id,
            "applicationId": app_id,
            "admin": True
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
    headers = make_auth(act_as, read_as)
    if op == "create":
        body = {"templateId": template_id, "payload": payload}
        r = requests.post(f"{BASE}/create", json=body, headers=headers)
        return ensure_ok(r, "/create")
    elif op == "exercise":
        body = {"templateId": template_id, "contractId": contract_id, "choice": choice, "argument": argument or {}}
        r = requests.post(f"{BASE}/exercise", json=body, headers=headers)
        return ensure_ok(r, "/exercise")
    elif op == "query":
        body = {"templateIds": template_ids or [], "query": query or {}}
        r = requests.post(f"{BASE}/query", json=body, headers=headers)
        return ensure_ok(r, "/query")
    else:
        raise ValueError(f"Unsupported op '{op}'")

def allocate_party(identifier_hint: str, display_name: str | None = None, is_local: bool = True) -> str:
    body = {"identifierHint": identifier_hint, "displayName": display_name or identifier_hint, "isLocal": is_local}
    r = requests.post(f"{BASE}/parties/allocate", json=body, headers=make_admin_auth())
    res = ensure_ok(r, "/parties/allocate")
    if isinstance(res, dict):
        if "party" in res:
            return res["party"]
        if "partyDetails" in res and isinstance(res["partyDetails"], dict) and "party" in res["partyDetails"]:
            return res["partyDetails"]["party"]
        if "identifier" in res:
            return res["identifier"]
    raise AssertionError(f"/parties/allocate unexpected result shape: {res}")

def allocate_unique_party(prefix: str = "Operator") -> str:
    hint = f"{prefix}-{uuid.uuid4().hex[:12]}"
    return allocate_party(hint, display_name=hint)
