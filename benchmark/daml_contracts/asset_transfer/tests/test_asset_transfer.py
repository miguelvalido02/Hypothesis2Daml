from decimal import Decimal
import requests
from hypothesis import given, settings, strategies as st
from daml_pbt import make_request, make_auth, allocate_unique_party, ensure_ok

BASE = "http://localhost:7575/v1"
PKG = "14914ff053f75db12473ef2a2fb4ed792aa577554493e67307126dfe1905af2b"
AT_TID = f"{PKG}:AssetTransfer:AssetTransfer"

alpha = st.text(alphabet="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 -_", min_size=1, max_size=40)
money = st.decimals(min_value="0.01", max_value="1000000.00", places=2)

def fetch_payload(cid: str, act_as: str) -> dict:
    r = requests.post(f"{BASE}/fetch",
                      json={"templateId": AT_TID, "contractId": cid},
                      headers=make_auth(act_as))
    res = ensure_ok(r, "/fetch")
    return res["payload"]

def state_of(p: dict) -> str:
    s = p["state"]
    return s if isinstance(s, str) else str(s)

def create_asset(owner: str, buyers: list[str], desc: str, asking: Decimal) -> str:
    payload = {
        "owner": owner,
        "potentialBuyers": buyers,
        "buyer": None,
        "inspector": None,
        "appraiser": None,
        "description": desc,
        "askingPrice": str(asking),
        "offerPrice": None,
        "state": "Active",
    }
    res = make_request("create", act_as=owner, template_id=AT_TID, payload=payload)
    return res["contractId"]

def make_offer(cid: str, buyer: str, inspector: str, appraiser: str, price: Decimal) -> str:
    res = make_request("exercise", act_as=buyer, template_id=AT_TID, contract_id=cid,
                       choice="MakeOffer",
                       argument={"buyerParty": buyer, "newInspector": inspector, "newAppraiser": appraiser, "newOfferPrice": str(price)})
    return res["exerciseResult"]

def modify_offer(cid: str, buyer: str, price: Decimal) -> str:
    res = make_request("exercise", act_as=buyer, template_id=AT_TID, contract_id=cid,
                       choice="ModifyOffer",
                       argument={"newOfferPrice": str(price)})
    return res["exerciseResult"]

def accept_offer(cid: str, owner: str) -> str:
    res = make_request("exercise", act_as=owner, template_id=AT_TID, contract_id=cid,
                       choice="AcceptOffer", argument={})
    return res["exerciseResult"]

def reject_offer(cid: str, owner: str) -> str:
    res = make_request("exercise", act_as=owner, template_id=AT_TID, contract_id=cid,
                       choice="Reject", argument={})
    return res["exerciseResult"]

def rescind_offer(cid: str, buyer: str) -> str:
    res = make_request("exercise", act_as=buyer, template_id=AT_TID, contract_id=cid,
                       choice="RescindOffer", argument={})
    return res["exerciseResult"]

def mark_inspected(cid: str, inspector: str) -> str:
    res = make_request("exercise", act_as=inspector, template_id=AT_TID, contract_id=cid,
                       choice="MarkInspected", argument={})
    return res["exerciseResult"]

def mark_appraised(cid: str, appraiser: str) -> str:
    res = make_request("exercise", act_as=appraiser, template_id=AT_TID, contract_id=cid,
                       choice="MarkAppraised", argument={})
    return res["exerciseResult"]

def accept_seller(cid: str, owner: str) -> str:
    res = make_request("exercise", act_as=owner, template_id=AT_TID, contract_id=cid,
                       choice="Accept", argument={})
    return res["exerciseResult"]

def accept_by_buyer(cid: str, buyer: str) -> str:
    res = make_request("exercise", act_as=buyer, template_id=AT_TID, contract_id=cid,
                       choice="AcceptByBuyer", argument={})
    return res["exerciseResult"]

@given(desc=alpha, asking=money, offer=money)
@settings(max_examples=12, deadline=None)
def test_make_offer_sets_fields(desc, asking, offer):
    owner = allocate_unique_party("Seller")
    b1    = allocate_unique_party("Buyer1")
    b2    = allocate_unique_party("Buyer2")
    insp  = allocate_unique_party("Inspector")
    appr  = allocate_unique_party("Appraiser")

    cid = create_asset(owner, [b1, b2], desc, asking)
    cid = make_offer(cid, b1, insp, appr, offer)
    p = fetch_payload(cid, owner)

    assert state_of(p) == "OfferPlaced"
    assert p["buyer"] == b1
    assert p["inspector"] == insp
    assert p["appraiser"] == appr
    assert Decimal(str(p["offerPrice"])) == Decimal(str(offer))
    assert p["potentialBuyers"] == [b1, b2, appr, insp]

@given(desc=alpha, asking=money, offer=money)
@settings(max_examples=12, deadline=None)
def test_reject_resets_fields(desc, asking, offer):
    owner = allocate_unique_party("Seller")
    b1    = allocate_unique_party("Buyer1")
    b2    = allocate_unique_party("Buyer2")
    insp  = allocate_unique_party("Inspector")
    appr  = allocate_unique_party("Appraiser")

    cid = create_asset(owner, [b1, b2], desc, asking)
    cid = make_offer(cid, b1, insp, appr, offer)
    cid = reject_offer(cid, owner)
    p = fetch_payload(cid, owner)

    assert state_of(p) == "Active"
    assert p["buyer"] is None
    assert p["offerPrice"] is None
    assert p["inspector"] is None
    assert p["appraiser"] is None

@given(desc=alpha, asking=money, offer=money, first_inspect=st.booleans())
@settings(max_examples=15, deadline=None)
def test_inspection_appraisal_converge_to_notional_acceptance(desc, asking, offer, first_inspect):
    owner = allocate_unique_party("Seller")
    b1    = allocate_unique_party("Buyer1")
    b2    = allocate_unique_party("Buyer2")
    insp  = allocate_unique_party("Inspector")
    appr  = allocate_unique_party("Appraiser")

    cid = create_asset(owner, [b1, b2], desc, asking)
    cid = make_offer(cid, b1, insp, appr, offer)
    cid = accept_offer(cid, owner)

    if first_inspect:
        cid = mark_inspected(cid, insp)
        cid = mark_appraised(cid, appr)
    else:
        cid = mark_appraised(cid, appr)
        cid = mark_inspected(cid, insp)

    p = fetch_payload(cid, owner)
    assert state_of(p) == "NotionalAcceptance"

@given(desc=alpha, asking=money, offer=money, buyer_first=st.booleans(), offer2=money)
@settings(max_examples=15, deadline=None)
def test_acceptance_paths_and_guards(desc, asking, offer, buyer_first, offer2):
    owner = allocate_unique_party("Seller")
    b1    = allocate_unique_party("Buyer1")
    b2    = allocate_unique_party("Buyer2")
    insp  = allocate_unique_party("Inspector")
    appr  = allocate_unique_party("Appraiser")

    cid = create_asset(owner, [b1, b2], desc, asking)
    cid = make_offer(cid, b1, insp, appr, offer)
    cid = accept_offer(cid, owner)
    cid = mark_inspected(cid, insp)
    cid = mark_appraised(cid, appr)

    if buyer_first:
        cid = accept_by_buyer(cid, b1)
        cid = accept_seller(cid, owner)
        cid = accept_by_buyer(cid, b1)
    else:
        cid = accept_seller(cid, owner)
        cid = accept_by_buyer(cid, b1)

    p = fetch_payload(cid, owner)
    assert state_of(p) == "Accepted"

    try:
        make_request("exercise", act_as=owner, template_id=AT_TID, contract_id=cid, choice="Terminate", argument={})
        assert False, "Terminate should fail in Accepted"
    except AssertionError:
        pass

    try:
        rescind_offer(cid, b1)
        assert False, "RescindOffer should fail in Accepted"
    except AssertionError:
        pass

@given(desc=alpha, asking=money, offer=money, offer2=money)
@settings(max_examples=12, deadline=None)
def test_modify_offer_changes_price(desc, asking, offer, offer2):
    owner = allocate_unique_party("Seller")
    b1    = allocate_unique_party("Buyer1")
    b2    = allocate_unique_party("Buyer2")
    insp  = allocate_unique_party("Inspector")
    appr  = allocate_unique_party("Appraiser")

    cid = create_asset(owner, [b1, b2], desc, asking)
    cid = make_offer(cid, b1, insp, appr, offer)
    cid = modify_offer(cid, b1, offer2)
    p = fetch_payload(cid, owner)

    assert state_of(p) == "OfferPlaced"
    assert Decimal(str(p["offerPrice"])) == Decimal(str(offer2))

@given(desc=alpha, asking=money, offer=money, first_inspect=st.booleans())
@settings(max_examples=12, deadline=None)
def test_full_path_to_terminated_with_checks(desc, asking, offer, first_inspect):
    owner = allocate_unique_party("Seller")
    b1    = allocate_unique_party("Buyer1")
    b2    = allocate_unique_party("Buyer2")
    insp  = allocate_unique_party("Inspector")
    appr  = allocate_unique_party("Appraiser")

    cid = create_asset(owner, [b1, b2], desc, asking)
    p = fetch_payload(cid, owner)
    assert state_of(p) == "Active"
    assert p["buyer"] is None and p["inspector"] is None and p["appraiser"] is None
    assert p["offerPrice"] is None
    assert p["description"] == desc
    assert Decimal(str(p["askingPrice"])) == Decimal(str(asking))

    cid = make_offer(cid, b1, insp, appr, offer)
    p = fetch_payload(cid, owner)
    assert state_of(p) == "OfferPlaced"
    assert p["buyer"] == b1 and p["inspector"] == insp and p["appraiser"] == appr
    assert Decimal(str(p["offerPrice"])) == Decimal(str(offer))

    cid = accept_offer(cid, owner)
    p = fetch_payload(cid, owner)
    assert state_of(p) == "PendingInspection"

    if first_inspect:
        cid = mark_inspected(cid, insp)
        p = fetch_payload(cid, owner)
        assert state_of(p) == "Inspected"
        cid = mark_appraised(cid, appr)
    else:
        cid = mark_appraised(cid, appr)
        p = fetch_payload(cid, owner)
        assert state_of(p) == "Appraised"
        cid = mark_inspected(cid, insp)

    p = fetch_payload(cid, owner)
    assert state_of(p) == "NotionalAcceptance"

    cid = accept_by_buyer(cid, b1)
    p = fetch_payload(cid, owner)
    assert state_of(p) == "BuyerAccepted"

    res = make_request("exercise", act_as=owner, template_id=AT_TID, contract_id=cid, choice="Terminate", argument={})
    cid = res["exerciseResult"]
    p = fetch_payload(cid, owner)
    assert state_of(p) == "Terminated"

