import requests
from hypothesis import given, settings, strategies as st
from daml_pbt import make_request, make_auth, allocate_unique_party, ensure_ok

BASE = "http://localhost:7575/v1"
PKG = "96e0e79add91322ee74dfc969c825c088622b5d000d89cd7d912a3bda7ca085a"
LOCKER_TID = f"{PKG}:DigitalLocker:DigitalLocker"

alpha = st.text(alphabet="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 -_", min_size=1, max_size=24)

def fetch_payload(cid: str, act_as: str) -> dict:
    r = requests.post(
        f"{BASE}/fetch",
        json={"templateId": LOCKER_TID, "contractId": cid},
        headers=make_auth(act_as),
    )
    res = ensure_ok(r, "/fetch")
    return res["payload"]

def create_locker(owner: str, bank: str, third: list[str], friendly_name: str) -> str:
    # After create: state = Requested
    # - bankAgent set; thirdParties set
    # - currentAuthorizedUser = None
    # - lockerStatus = "Created"
    # - image/expirationDate/lockerIdentifier/intendedPurpose/rejectionReason/thirdPartyRequestor = None
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
    # Requested → DocumentReview
    # - lockerStatus becomes "Pending"
    res = make_request(
        "exercise",
        act_as=bank,
        template_id=LOCKER_TID,
        contract_id=cid,
        choice="BeginReviewProcess",
        argument={},
    )
    return res["exerciseResult"]

def upload_documents(bank: str, cid: str, identifier: str, img: str) -> str:
    # DocumentReview → AvailableToShare
    # - lockerStatus = "Approved"
    # - lockerIdentifier = identifier
    # - image = img
    res = make_request(
        "exercise",
        act_as=bank,
        template_id=LOCKER_TID,
        contract_id=cid,
        choice="UploadDocuments",
        argument={"identifier": identifier, "img": img},
    )
    return res["exerciseResult"]

def request_access(requestor: str, cid: str, purpose: str) -> str:
    # AvailableToShare → SharingRequestPending
    # - thirdPartyRequestor = requestor
    # - currentAuthorizedUser = None
    # - intendedPurpose = purpose
    res = make_request(
        "exercise",
        act_as=requestor,
        template_id=LOCKER_TID,
        contract_id=cid,
        choice="RequestLockerAccess",
        argument={"requestor": requestor, "purpose": purpose},
    )
    return res["exerciseResult"]

def accept_request(owner: str, cid: str) -> str:
    # SharingRequestPending → SharingWithThirdParty
    # - currentAuthorizedUser = thirdPartyRequestor (now the active user)
    res = make_request(
        "exercise",
        act_as=owner,
        template_id=LOCKER_TID,
        contract_id=cid,
        choice="AcceptSharingRequest",
        argument={},
    )
    return res["exerciseResult"]

def release_access(current_user: str, cid: str) -> str:
    # SharingWithThirdParty → AvailableToShare
    # - lockerStatus = "Available"
    # - thirdPartyRequestor = None
    # - currentAuthorizedUser = None
    # - intendedPurpose = None
    res = make_request(
        "exercise",
        act_as=current_user,
        template_id=LOCKER_TID,
        contract_id=cid,
        choice="ReleaseLockerAccess",
        argument={},
    )
    return res["exerciseResult"]

def share_with_third(owner: str, cid: str, recipient: str, exp: str, purpose: str) -> str:
    # AvailableToShare → SharingWithThirdParty
    # - thirdPartyRequestor = recipient
    # - currentAuthorizedUser = recipient
    # - expirationDate = exp
    # - intendedPurpose = purpose
    # - lockerStatus = "Shared"
    res = make_request(
        "exercise",
        act_as=owner,
        template_id=LOCKER_TID,
        contract_id=cid,
        choice="ShareWithThirdParty",
        argument={"recipient": recipient, "expDate": exp, "purpose": purpose},
    )
    return res["exerciseResult"]

def revoke_access(owner: str, cid: str) -> str:
    # SharingWithThirdParty → AvailableToShare
    # - lockerStatus = "Available"
    # - intendedPurpose = None
    # - thirdPartyRequestor = None
    # - currentAuthorizedUser = None
    res = make_request(
        "exercise",
        act_as=owner,
        template_id=LOCKER_TID,
        contract_id=cid,
        choice="RevokeAccessFromThirdParty",
        argument={},
    )
    return res["exerciseResult"]

def state_tag(payload: dict) -> str:
    s = payload["state"]
    return s if isinstance(s, str) else str(s)

@given(identifier=alpha, img=alpha, friendly=alpha)
@settings(max_examples=12, deadline=None)
def test_upload_documents_sets_fields(identifier, img, friendly):
    owner = allocate_unique_party("Owner")
    bank  = allocate_unique_party("Bank")
    tp    = allocate_unique_party("TP")

    cid = create_locker(owner, bank, [tp], friendly)  # ⇒ Requested
    cid = begin_review(bank, cid)                     # Requested → DocumentReview
    cid = upload_documents(bank, cid,                # DocumentReview → AvailableToShare
                           identifier=identifier, img=img)

    p = fetch_payload(cid, owner)
    # Expected in AvailableToShare after UploadDocuments:
    # - state = AvailableToShare
    # - lockerStatus = "Approved"
    # - lockerIdentifier = identifier; image = img
    # - lockerFriendlyName unchanged
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

    cid = create_locker(owner, bank, [tp], friendly)  # ⇒ Requested
    cid = begin_review(bank, cid)                     # Requested → DocumentReview
    cid = upload_documents(bank, cid,                # DocumentReview → AvailableToShare
                           identifier="ID", img="IMG")
    cid = request_access(tp, cid, purpose=purpose)   # AvailableToShare → SharingRequestPending

    p = fetch_payload(cid, owner)
    # Expected in SharingRequestPending:
    # - thirdPartyRequestor = tp
    # - intendedPurpose = purpose
    # - currentAuthorizedUser = None
    assert state_tag(p) == "SharingRequestPending"
    assert p["thirdPartyRequestor"] == tp
    assert p["intendedPurpose"] == purpose

    cid = accept_request(owner, cid)                 # SharingRequestPending → SharingWithThirdParty
    p = fetch_payload(cid, owner)
    # Expected in SharingWithThirdParty:
    # - currentAuthorizedUser = tp
    assert state_tag(p) == "SharingWithThirdParty"
    assert p["currentAuthorizedUser"] == tp

    cid = release_access(tp, cid)                    # SharingWithThirdParty → AvailableToShare
    p = fetch_payload(cid, owner)
    # Expected after ReleaseLockerAccess:
    # - state = AvailableToShare
    # - currentAuthorizedUser = None
    # - thirdPartyRequestor = None
    # - intendedPurpose = None
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

    cid = create_locker(owner, bank, [tp], friendly)  # ⇒ Requested
    cid = begin_review(bank, cid)                     # Requested → DocumentReview
    cid = upload_documents(bank, cid,                # DocumentReview → AvailableToShare
                           identifier="X", img="Y")
    cid = share_with_third(owner, cid,               # AvailableToShare → SharingWithThirdParty
                           recipient=tp, exp=exp, purpose=purpose)

    p = fetch_payload(cid, owner)
    # Expected in SharingWithThirdParty after share:
    # - currentAuthorizedUser = tp
    # - expirationDate = exp
    # - intendedPurpose = purpose
    # - lockerStatus = "Shared"
    assert state_tag(p) == "SharingWithThirdParty"
    assert p["currentAuthorizedUser"] == tp
    assert p["expirationDate"] == exp
    assert p["intendedPurpose"] == purpose

    cid = revoke_access(owner, cid)                  # SharingWithThirdParty → AvailableToShare
    p = fetch_payload(cid, owner)
    # Expected after RevokeAccessFromThirdParty:
    # - state = AvailableToShare
    # - currentAuthorizedUser = None
    # - thirdPartyRequestor = None
    # - intendedPurpose = None
    assert state_tag(p) == "AvailableToShare"
    assert p["currentAuthorizedUser"] is None
    assert p["thirdPartyRequestor"] is None
    assert p["intendedPurpose"] is None
