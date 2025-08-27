# tests/test_digital_locker_pbt.py
import requests
from hypothesis import given, settings, strategies as st
from daml_pbt import make_request, make_auth, allocate_unique_party, ensure_ok

BASE = "http://localhost:7575/v1"
PKG = "bcd0cd07503d4ecb4340f7ad3cb9e8045ad8fe1ed1703672a0c35bd5c7c897d0"
LOCKER_TID = f"{PKG}:DigitalLocker:DigitalLocker"

alpha = st.text(alphabet="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 -_", min_size=1, max_size=24)

def fetch_payload(cid: str, act_as: str) -> dict:
    r = requests.post(f"{BASE}/fetch",
                      json={"templateId": LOCKER_TID, "contractId": cid},
                      headers=make_auth(act_as))
    res = ensure_ok(r, "/fetch")
    return res["payload"]

def create_locker(owner: str, bank: str, third: list[str], friendly_name: str) -> str:
    payload = {
        "owner": owner,
        "state": "Requested",
        "bankAgent": bank,
        "thirdParties": third,
        "currentAuthorizedUser": None,
        "lockerStatus": "Created",
        "image": None,
        "lockerFriendlyName": friendly_name,
        "expirationDate": None,
        "lockerIdentifier": None,
        "intendedPurpose": None,
        "rejectionReason": None,
        "thirdPartyRequestor": None,
    }
    res = make_request("create", act_as=owner, template_id=LOCKER_TID, payload=payload)
    return res["contractId"]

def begin_review(bank: str, cid: str) -> str:
    res = make_request("exercise", act_as=bank, template_id=LOCKER_TID,
                       contract_id=cid, choice="BeginReviewProcess", argument={})
    return res["exerciseResult"]

def upload_documents(bank: str, cid: str, identifier: str, img: str) -> str:
    res = make_request("exercise", act_as=bank, template_id=LOCKER_TID,
                       contract_id=cid, choice="UploadDocuments",
                       argument={"identifier": identifier, "img": img})
    return res["exerciseResult"]

def request_access(requestor: str, cid: str, purpose: str) -> str:
    res = make_request("exercise", act_as=requestor, template_id=LOCKER_TID,
                       contract_id=cid, choice="RequestLockerAccess",
                       argument={"requestor": requestor, "purpose": purpose})
    return res["exerciseResult"]

def accept_request(owner: str, cid: str) -> str:
    res = make_request("exercise", act_as=owner, template_id=LOCKER_TID,
                       contract_id=cid, choice="AcceptSharingRequest", argument={})
    return res["exerciseResult"]

def release_access(current_user: str, cid: str) -> str:
    res = make_request("exercise", act_as=current_user, template_id=LOCKER_TID,
                       contract_id=cid, choice="ReleaseLockerAccess", argument={})
    return res["exerciseResult"]

def share_with_third(owner: str, cid: str, recipient: str, exp: str, purpose: str) -> str:
    res = make_request("exercise", act_as=owner, template_id=LOCKER_TID,
                       contract_id=cid, choice="ShareWithThirdParty",
                       argument={"recipient": recipient, "expDate": exp, "purpose": purpose})
    return res["exerciseResult"]

def revoke_access(owner: str, cid: str) -> str:
    res = make_request("exercise", act_as=owner, template_id=LOCKER_TID,
                       contract_id=cid, choice="RevokeAccessFromThirdParty", argument={})
    return res["exerciseResult"]

def state_tag(payload: dict) -> str:
    s = payload["state"]
    return s if isinstance(s, str) else str(s)

#alpha = st.text(
#    alphabet="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 -_",
#    min_size=1,
#    max_size=24,
#)
@given(identifier=alpha, img=alpha, friendly=alpha)
@settings(max_examples=12, deadline=None)
def test_upload_documents_sets_fields(identifier, img, friendly):
    owner = allocate_unique_party("Owner")
    bank  = allocate_unique_party("Bank")
    tp    = allocate_unique_party("TP")
    cid = create_locker(owner, bank, [tp], friendly)
    cid = begin_review(bank, cid)
    cid = upload_documents(bank, cid, identifier=identifier, img=img)
    p = fetch_payload(cid, owner)
    assert state_tag(p) == "AvailableToShare"
    assert p["lockerStatus"] == "Approved"
    assert p["lockerIdentifier"] == identifier
    assert p["image"] == img
    assert p["lockerFriendlyName"] == friendly

@given(purpose=alpha, friendly=alpha)
@settings(max_examples=15, deadline=None)
def test_request_accept_release_clears_fields(purpose, friendly):
    owner = allocate_unique_party("Owner")
    bank  = allocate_unique_party("Bank")
    tp    = allocate_unique_party("TP")
    cid = create_locker(owner, bank, [tp], friendly)
    cid = begin_review(bank, cid)
    cid = upload_documents(bank, cid, identifier="ID", img="IMG")
    cid = request_access(tp, cid, purpose=purpose)
    p = fetch_payload(cid, owner)
    assert state_tag(p) == "SharingRequestPending"
    assert p["thirdPartyRequestor"] == tp
    assert p["intendedPurpose"] == purpose
    cid = accept_request(owner, cid)
    p = fetch_payload(cid, owner)
    assert state_tag(p) == "SharingWithThirdParty"
    assert p["currentAuthorizedUser"] == tp
    cid = release_access(tp, cid)
    p = fetch_payload(cid, owner)
    assert state_tag(p) == "AvailableToShare"
    assert p["currentAuthorizedUser"] is None
    assert p["thirdPartyRequestor"] is None
    assert p["intendedPurpose"] is None

@given(exp=alpha, purpose=alpha, friendly=alpha)
@settings(max_examples=12, deadline=None)
def test_share_then_revoke_roundtrip(exp, purpose, friendly):
    owner = allocate_unique_party("Owner")
    bank  = allocate_unique_party("Bank")
    tp    = allocate_unique_party("TP")
    cid = create_locker(owner, bank, [tp], friendly)
    cid = begin_review(bank, cid)
    cid = upload_documents(bank, cid, identifier="X", img="Y")
    cid = share_with_third(owner, cid, recipient=tp, exp=exp, purpose=purpose)
    p = fetch_payload(cid, owner)
    assert state_tag(p) == "SharingWithThirdParty"
    assert p["currentAuthorizedUser"] == tp
    assert p["expirationDate"] == exp
    assert p["intendedPurpose"] == purpose
    cid = revoke_access(owner, cid)
    p = fetch_payload(cid, owner)
    assert state_tag(p) == "AvailableToShare"
    assert p["currentAuthorizedUser"] is None
    assert p["thirdPartyRequestor"] is None
    assert p["intendedPurpose"] is None
