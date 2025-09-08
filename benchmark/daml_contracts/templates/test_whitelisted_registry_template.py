# Template PBT for a "WhitelistedRegistry"-style contract.
# 1) Replace PKG below with your actual package ID.
# 2) Update module/entity names in REG_TID if your module or template names differ.
# 3) In each helper function, adjust payload/argument fields as per your contract.

from decimal import Decimal
from hypothesis import given, settings, strategies as st
from daml_pbt import make_request, allocate_unique_party

PKG = "PASTE_YOUR_PKG_HERE"
REG_TID = f"{PKG}:WhitelistedRegistry:WhitelistedRegistry"

def create_registry(owner: str, wl: list[str]) -> str:
    # After create:
    # - owner set to 'owner'
    # - whitelisted initialized to the provided list 'wl'
    # NOTE: Add or remove fields as per your contract (payload keys & types).
    res = make_request(
        "create",
        act_as=owner,
        template_id=REG_TID,
        payload={
            "owner": owner,              # <-- add/remove fields as per your contract
            "whitelisted": wl,           # <-- add/remove fields as per your contract
        },
    )
    return res["contractId"]

def change_owner(cid: str, owner: str, new_owner: str) -> str:
    # Choice ChangeOwner (by current owner):
    # - owner becomes 'new_owner'
    # - whitelisted remains unchanged
    # NOTE: Add or remove fields as per your contract (argument keys & types).
    res = make_request(
        "exercise",
        act_as=owner,
        template_id=REG_TID,
        contract_id=cid,
        choice="ChangeOwner",
        argument={
            "newOwner": new_owner,       # <-- add/remove fields as per your contract
        },
    )
    return res["exerciseResult"]

def set_whitelisted(cid: str, owner: str, addr: str, is_whitelisted: bool) -> str:
    # Choice SetWhitelisted (by owner):
    # - if is_whitelisted == True, ensure 'addr' is present in whitelist
    # - if is_whitelisted == False, ensure 'addr' is absent from whitelist
    # NOTE: Add or remove fields as per your contract (argument keys & types).
    res = make_request(
        "exercise",
        act_as=owner,
        template_id=REG_TID,
        contract_id=cid,
        choice="SetWhitelisted",
        argument={
            "addr": addr,                # <-- add/remove fields as per your contract
            "isWhitelisted": is_whitelisted,  # <-- add/remove fields as per your contract
        },
    )
    return res["exerciseResult"]

def is_whitelisted(cid: str, caller: str, addr: str) -> bool:
    # Nonconsuming read: returns True iff 'addr' is currently whitelisted
    # NOTE: Add or remove fields as per your contract (argument keys & types).
    res = make_request(
        "exercise",
        act_as=caller,
        template_id=REG_TID,
        contract_id=cid,
        choice="IsWhitelisted",
        argument={
            "addr": addr,                # <-- add/remove fields as per your contract
            "caller": caller,            # <-- add/remove fields as per your contract
        },
    )
    return bool(res["exerciseResult"])

def get_whitelist(cid: str) -> list[str]:
    # Helper via /query to fetch current whitelist (expects a single visible match)
    # NOTE: Adjust query shape or visibility as per your contract.
    res = make_request("query", template_ids=[REG_TID], query={"contractId": cid})
    assert isinstance(res, list) and len(res) == 1
    return res[0]["payload"]["whitelisted"]  # <-- update field name if different

@given(flag=st.booleans())
@settings(max_examples=10, deadline=None)
def test_non_owner_cannot_set_or_change(flag):
    owner = allocate_unique_party("Owner")
    attacker = allocate_unique_party("Attacker")
    target = allocate_unique_party("Target")

    # Initial registry: owner=Owner, whitelisted=[]
    cid = create_registry(owner, [])

    # Guard: only the owner can SetWhitelisted
    try:
        make_request(
            "exercise",
            act_as=attacker,
            template_id=REG_TID,
            contract_id=cid,
            choice="SetWhitelisted",
            argument={
                "addr": target,             # <-- add/remove fields as per your contract
                "isWhitelisted": flag,      # <-- add/remove fields as per your contract
            },
        )
        assert False, "Non-owner must not be able to SetWhitelisted"
    except AssertionError:
        pass

    # Guard: only the owner can ChangeOwner
    try:
        make_request(
            "exercise",
            act_as=attacker,
            template_id=REG_TID,
            contract_id=cid,
            choice="ChangeOwner",
            argument={
                "newOwner": attacker,       # <-- add/remove fields as per your contract
            },
        )
        assert False, "Non-owner must not be able to ChangeOwner"
    except AssertionError:
        pass

@given(which=st.sampled_from([0, 1]))
@settings(max_examples=10, deadline=None)
def test_setwhitelisted(which):
    owner = allocate_unique_party("Owner")
    p1 = allocate_unique_party("P1")
    p2 = allocate_unique_party("P2")

    # Start with empty whitelist
    cid = create_registry(owner, [])
    assert is_whitelisted(cid, owner, p1) is False
    assert is_whitelisted(cid, owner, p2) is False

    # Toggle one party on; the other remains off
    target = [p1, p2][which]
    other  = [p2, p1][which]

    # After SetWhitelisted(target, True): 'target' ∈ whitelist; 'other' ∉ whitelist
    cid = set_whitelisted(cid, owner, target, True)

    assert is_whitelisted(cid, owner, target) is True
    assert is_whitelisted(cid, owner, other) is False
