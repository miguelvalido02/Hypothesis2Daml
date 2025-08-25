from hypothesis import given, settings, strategies as st
from daml_pbt import make_request, allocate_unique_party

PKG = "b46b4ba42416f39c25b6fe0f41c14f0110d33505d925136bbbb8e9a15b860d59"
TID = f"{PKG}:DefectiveComponentCounter:DefectiveCounter"

def create_counter(manufacturer: str, defective: int, state: str = "Create") -> str:
    res = make_request("create", act_as=manufacturer, template_id=TID,
                       payload={"manufacturer": manufacturer, "defectiveComponents": defective, "state": state})
    return res["contractId"]

def compute_total(cid: str, manufacturer: str) -> str:
    res = make_request("exercise", act_as=manufacturer, template_id=TID,
                       contract_id=cid, choice="ComputeTotal", argument={})
    return res["exerciseResult"]

def get_payload(cid: str, reader: str) -> dict:
    res = make_request("query", read_as=[reader], template_ids=[TID], query={})
    for c in res:
        if c["contractId"] == cid:
            return c["payload"]
    raise AssertionError("contract not found for reader")

@given(n=st.integers(min_value=0, max_value=10**6))
@settings(max_examples=10, deadline=None)
def test_compute_total_sets_state_and_preserves_count(n):
    m = allocate_unique_party("M")
    cid = create_counter(m, n, "Create")
    p0 = get_payload(cid, m)
    assert p0["state"] == "Create"
    cid2 = compute_total(cid, m)
    p1 = get_payload(cid2, m)
    assert p1["state"] == "ComputeTotal"
    assert int(p1["defectiveComponents"]) == n

@given(n=st.integers(min_value=0, max_value=100))
@settings(max_examples=5, deadline=None)
def test_only_manufacturer_can_compute(n):
    m = allocate_unique_party("M")
    attacker = allocate_unique_party("X")
    cid = create_counter(m, n, "Create")
    try:
        make_request("exercise", act_as=attacker, template_id=TID,
                     contract_id=cid, choice="ComputeTotal", argument={})
        assert False
    except AssertionError:
        pass