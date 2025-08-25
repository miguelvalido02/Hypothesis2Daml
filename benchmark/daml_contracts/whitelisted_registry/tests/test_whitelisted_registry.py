from decimal import Decimal
from hypothesis import given, settings, strategies as st
from daml_pbt import make_request, allocate_unique_party

PKG = "cd2c479891484bf1eeef1c0e4bab05511d84ee0853c116817ecf18cbf0f0ade2"
REG_TID = f"{PKG}:WhitelistedRegistry:WhitelistedRegistry"

def create_registry(owner: str, wl: list[str]) -> str:
    res = make_request("create", act_as=owner, template_id=REG_TID, payload={"owner": owner, "whitelisted": wl})
    return res["contractId"]

def change_owner(cid: str, owner: str, new_owner: str) -> str:
    res = make_request("exercise", act_as=owner, template_id=REG_TID, contract_id=cid, choice="ChangeOwner", argument={"newOwner": new_owner})
    return res["exerciseResult"]

def set_whitelisted(cid: str, owner: str, addr: str, is_whitelisted: bool) -> str:
    res = make_request("exercise", act_as=owner, template_id=REG_TID, contract_id=cid, choice="SetWhitelisted", argument={"addr": addr, "isWhitelisted": is_whitelisted})
    return res["exerciseResult"]

def is_whitelisted(cid: str, caller: str, addr: str) -> bool:
    res = make_request("exercise", act_as=caller, template_id=REG_TID, contract_id=cid, choice="IsWhitelisted", argument={"addr": addr, "caller": caller})
    return bool(res["exerciseResult"])

def get_whitelist(cid: str) -> list[str]:
    res = make_request("query", template_ids=[REG_TID], query={"contractId": cid})
    assert isinstance(res, list) and len(res) == 1
    return res[0]["payload"]["whitelisted"]

@given(flag=st.booleans())
@settings(max_examples=10, deadline=None)
def test_non_owner_cannot_set_or_change(flag):
    owner = allocate_unique_party("Owner")
    attacker = allocate_unique_party("Attacker")
    target = allocate_unique_party("Target")
    cid = create_registry(owner, [])
    try:
        make_request("exercise", act_as=attacker, template_id=REG_TID, contract_id=cid, choice="SetWhitelisted", argument={"addr": target, "isWhitelisted": flag})
        assert False
    except AssertionError:
        pass
    try:
        make_request("exercise", act_as=attacker, template_id=REG_TID, contract_id=cid, choice="ChangeOwner", argument={"newOwner": attacker})
        assert False
    except AssertionError:
        pass

@given(which=st.sampled_from([0, 1]))
@settings(max_examples=10, deadline=None)
def test_setwhitelisted(which):
    owner = allocate_unique_party("Owner")
    p1 = allocate_unique_party("P1")
    p2 = allocate_unique_party("P2")

    cid = create_registry(owner, [])
    assert is_whitelisted(cid, owner, p1) is False
    assert is_whitelisted(cid, owner, p2) is False

    target = [p1, p2][which]
    other  = [p2, p1][which]

    cid = set_whitelisted(cid, owner, target, True)

    assert is_whitelisted(cid, owner, target) is True
    assert is_whitelisted(cid, owner, other) is False

