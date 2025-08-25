from hypothesis import given, settings, strategies as st
from daml_pbt import make_request, allocate_unique_party

PKG = "f33b6d5a217f56fc67232d32fcf41f5d388bd59252491badfb791459d867960f"
FF_TID = f"{PKG}:FrequentFlier:FrequentFlier"

def create_ff(airline: str, flier: str, rpm: int, miles: list[int] | None = None, rewards: int = 0) -> str:
    miles = miles or []
    res = make_request(
        "create",
        act_as=airline,
        template_id=FF_TID,
        payload={"airlineRepresentative": airline, "flier": flier, "rewardsPerMile": int(rpm), "miles": [int(x) for x in miles], "totalRewards": int(rewards)},
    )
    return res["contractId"]

def add_miles(cid: str, flier: str, new_miles: list[int]) -> str:
    res = make_request(
        "exercise",
        act_as=flier,
        template_id=FF_TID,
        contract_id=cid,
        choice="AddMiles",
        argument={"newMiles": [int(x) for x in new_miles]},
    )
    return res["exerciseResult"]

def get_miles(cid: str, caller: str) -> list[int]:
    res = make_request(
        "exercise",
        act_as=caller,
        template_id=FF_TID,
        contract_id=cid,
        choice="GetMiles",
        argument={"caller": caller},
    )
    return [int(x) for x in res["exerciseResult"]]

def get_rewards(cid: str, caller: str) -> int:
    res = make_request(
        "exercise",
        act_as=caller,
        template_id=FF_TID,
        contract_id=cid,
        choice="GetRewards",
        argument={"caller": caller},
    )
    return int(res["exerciseResult"])

@given(
    rpm=st.integers(min_value=1, max_value=10),
    new=st.lists(st.integers(min_value=0, max_value=1000), min_size=0, max_size=10),
)
@settings(max_examples=10, deadline=None)
def test_add_miles_updates_rewards_and_list(rpm, new):
    airline = allocate_unique_party("Air")
    flier   = allocate_unique_party("Flier")
    cid = create_ff(airline, flier, rpm, miles=[], rewards=0)
    assert get_miles(cid, airline) == []
    assert get_rewards(cid, airline) == 0
    cid = add_miles(cid, flier, new)
    assert get_miles(cid, airline) == new
    assert get_rewards(cid, airline) == sum(new) * rpm

@given(
    rpm=st.integers(min_value=1, max_value=10),
    new=st.lists(st.integers(min_value=0, max_value=1000), min_size=1, max_size=5),
)
@settings(max_examples=10, deadline=None)
def test_only_flier_can_add_miles(rpm, new):
    airline = allocate_unique_party("Air")
    flier   = allocate_unique_party("Flier")
    cid = create_ff(airline, flier, rpm, miles=[], rewards=0)
    try:
        make_request(
            "exercise",
            act_as=airline,
            template_id=FF_TID,
            contract_id=cid,
            choice="AddMiles",
            argument={"newMiles": [int(x) for x in new]},
        )
        assert False
    except AssertionError:
        pass
    cid2 = add_miles(cid, flier, new)
    assert get_miles(cid2, airline) == new
