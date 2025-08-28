# tests/test_simple_market.py
from decimal import Decimal
from hypothesis import given, settings, strategies as st
from daml_pbt import make_request, allocate_unique_party

PKG = "c988d208293f53653ca3aa965a21f15fa5bb318df0b41e87722b1d4d9cbf4249"
MARKET_TID = f"{PKG}:SimpleMarket:Market"

def create_market(owner: str, buyer: str, item: str, state: str = "ItemAvailable", offer: Decimal = Decimal("0.0")) -> str:
    # After create:
    # - state = provided (usually "ItemAvailable")
    # - owner/buyer/item set as given
    # - offerPrice initialized (usually "0.0")
    res = make_request(
        "create",
        act_as=owner,
        template_id=MARKET_TID,
        payload={"owner": owner, "buyer": buyer, "item": item, "state": state, "offerPrice": str(offer)},
    )
    return res["contractId"]

def make_offer(cid: str, buyer: str, price: Decimal) -> str:
    # Choice MakeOffer (by buyer):
    # - ItemAvailable → OfferPlaced
    # - offerPrice := price
    res = make_request(
        "exercise",
        act_as=buyer,
        template_id=MARKET_TID,
        contract_id=cid,
        choice="MakeOffer",
        argument={"offerPrice": str(price)},
    )
    return res["exerciseResult"]

def accept_offer(cid: str, owner: str) -> str:
    # Choice AcceptOffer (by owner):
    # - OfferPlaced → Accept
    res = make_request(
        "exercise",
        act_as=owner,
        template_id=MARKET_TID,
        contract_id=cid,
        choice="AcceptOffer",
        argument={},
    )
    return res["exerciseResult"]

def reject_offer(cid: str, owner: str) -> str:
    # Choice RejectOffer (by owner):
    # - OfferPlaced → ItemAvailable
    # - offerPrice reset to "0.0"
    res = make_request(
        "exercise",
        act_as=owner,
        template_id=MARKET_TID,
        contract_id=cid,
        choice="RejectOffer",
        argument={},
    )
    return res["exerciseResult"]

def get_payload(cid: str, reader: str) -> dict:
    # Helper: read the current payload for cid using JSON API /query
    res = make_request("query", read_as=[reader], template_ids=[MARKET_TID], query={})
    for c in res:
        if c["contractId"] == cid:
            return c["payload"]
    raise AssertionError("contract not visible")

@given(state=st.sampled_from(["ItemAvailable", "OfferPlaced", "Accept"]),
       price=st.decimals(min_value="0.01", max_value="10000.00", places=2),
       item=st.sampled_from(["Phone","Book","Bike"]))
@settings(max_examples=12, deadline=None)
def test_makeoffer_only_when_itemavailable(state, price, item):
    owner = allocate_unique_party("Owner")
    buyer = allocate_unique_party("Buyer")
    cid = create_market(owner, buyer, item, state=state)
    if state == "ItemAvailable":
        # Expect: ItemAvailable → OfferPlaced
        cid2 = make_offer(cid, buyer, Decimal(price))
        p = get_payload(cid2, owner)
        assert p["state"] == "OfferPlaced"
    else:
        # Guard: MakeOffer must fail unless state == ItemAvailable
        try:
            make_offer(cid, buyer, Decimal(price))
            assert False
        except AssertionError:
            pass

@given(price=st.decimals(min_value="0.01", max_value="10000.00", places=2),
       item=st.sampled_from(["Phone","Book","Bike"]))
@settings(max_examples=10, deadline=None)
def test_makeoffer_sets_state_offerplaced(price, item):
    owner = allocate_unique_party("Owner")
    buyer = allocate_unique_party("Buyer")
    cid = create_market(owner, buyer, item)  # ItemAvailable
    # Expect: ItemAvailable → OfferPlaced
    cid2 = make_offer(cid, buyer, Decimal(price))
    p = get_payload(cid2, owner)
    assert p["state"] == "OfferPlaced"

@given(item=st.sampled_from(["Phone","Book"]),price = st.decimals(min_value="0.01", max_value="10000.00", places=2))
@settings(max_examples=6, deadline=None)
def test_only_owner_can_accept(item,price):
    owner = allocate_unique_party("Owner")
    buyer = allocate_unique_party("Buyer")
    cid = create_market(owner, buyer, item)           # ItemAvailable
    cid2 = make_offer(cid, buyer, Decimal(price))     # → OfferPlaced
    # Guard: only owner can AcceptOffer
    try:
        accept_offer(cid2, buyer)
        assert False
    except AssertionError:
        pass

@given(item=st.sampled_from(["Phone","Book"]),price = st.decimals(min_value="0.01", max_value="10000.00", places=2))
@settings(max_examples=6, deadline=None)
def test_only_owner_can_reject(item,price):
    owner = allocate_unique_party("Owner")
    buyer = allocate_unique_party("Buyer")
    cid = create_market(owner, buyer, item)           # ItemAvailable
    cid2 = make_offer(cid, buyer, Decimal(price))     # → OfferPlaced
    # Guard: only owner can RejectOffer
    try:
        reject_offer(cid2, buyer)
        assert False
    except AssertionError:
        pass

@given(item=st.sampled_from(["Phone","Book"]),
       state=st.sampled_from(["ItemAvailable", "OfferPlaced", "Accept"]))
@settings(max_examples=6, deadline=None)
def test_owner_accept_only_when_offerplaced(item, state):
    owner = allocate_unique_party("Owner")
    buyer = allocate_unique_party("Buyer")
    cid   = create_market(owner, buyer, item, state=state)

    if state == "OfferPlaced":
        # Expect: OfferPlaced → Accept
        cid2 = accept_offer(cid, owner)
        p    = get_payload(cid2, owner)
        assert p["state"] == "Accept"
    else:
        # Guard: AcceptOffer must fail unless state == OfferPlaced
        try:
            accept_offer(cid, owner)
            assert False
        except AssertionError:
            pass


@given(item=st.sampled_from(["Phone","Book"]),
       state=st.sampled_from(["ItemAvailable", "OfferPlaced", "Accept"]))
@settings(max_examples=6, deadline=None)
def test_owner_reject_only_when_offerplaced(item, state):
    owner = allocate_unique_party("Owner")
    buyer = allocate_unique_party("Buyer")

    if state == "OfferPlaced":
        # Setup directly in OfferPlaced to test rejection:
        cid  = create_market(owner, buyer, item, state="OfferPlaced", offer=Decimal("15.00"))
        # Expect: OfferPlaced → ItemAvailable, offerPrice reset to 0.0
        cid2 = reject_offer(cid, owner)
        p    = get_payload(cid2, owner)
        assert p["state"] == "ItemAvailable"
        assert Decimal(str(p["offerPrice"])) == Decimal("0.0")
    else:
        cid = create_market(owner, buyer, item, state=state)
        # Guard: RejectOffer must fail unless state == OfferPlaced
        try:
            reject_offer(cid, owner)
            assert False
        except AssertionError:
            pass
