from decimal import Decimal
import requests
from hypothesis import given, settings, strategies as st
from daml_pbt import make_request, make_auth, allocate_unique_party, ensure_ok

BASE = "http://localhost:7575/v1"
PKG = "cb2661eb40b2339cdfdbdf663b82bdfec6835cfb775a7787934754faa7cdbc62"
BAL_TID = f"{PKG}:BorrowAndLending:BorrowAndLending"

tokens_fixed = ["USD", "BTC", "ETH"]
money = st.decimals(min_value="0.01", max_value="100000.00", places=2)
alpha = st.sampled_from(tokens_fixed)

def tup(token: str, amount: Decimal):
    return {"_1": token, "_2": str(amount)}

def fetch_payload(cid: str, act_as: str) -> dict:
    r = requests.post(f"{BASE}/fetch",
                      json={"templateId": BAL_TID, "contractId": cid},
                      headers=make_auth(act_as))
    res = ensure_ok(r, "/fetch")
    return res["payload"]

def create_contract(owner: str, balances: list[tuple[str, Decimal]]) -> str:
    payload = {
        "owner": owner,
        "users": [],
        "lenders": [],
        "borrowers": [],
        "balances": [tup(t, a) for (t, a) in balances],
    }
    res = make_request("create", act_as=owner, template_id=BAL_TID, payload=payload)
    return res["contractId"]

def add_observer(cid: str, owner: str, new_observer: str) -> str:
    res = make_request("exercise", act_as=owner, template_id=BAL_TID, contract_id=cid,
                       choice="AddObserver", argument={"newObserver": new_observer})
    return res["exerciseResult"]

def lend(cid: str, user: str, token: str, amount: Decimal) -> str:
    res = make_request("exercise", act_as=user, template_id=BAL_TID, contract_id=cid,
                       choice="Lend", argument={"user": user, "token": token, "amount": str(amount)})
    return res["exerciseResult"]

def withdraw(cid: str, user: str, token: str, amount: Decimal) -> str:
    res = make_request("exercise", act_as=user, template_id=BAL_TID, contract_id=cid,
                       choice="Withdraw", argument={"user": user, "token": token, "amount": str(amount)})
    return res["exerciseResult"]

def borrow(cid: str, user: str, collateral_token: str, collateral_amount: Decimal,
           borrow_token: str, borrow_amount: Decimal) -> str:
    res = make_request("exercise", act_as=user, template_id=BAL_TID, contract_id=cid,
                       choice="Borrow",
                       argument={
                           "user": user,
                           "collateralToken": collateral_token,
                           "collateralAmount": str(collateral_amount),
                           "borrowToken": borrow_token,
                           "borrowAmount": str(borrow_amount),
                       })
    return res["exerciseResult"]

def repay(cid: str, user: str, collateral_token: str, borrow_token: str) -> str:
    res = make_request("exercise", act_as=user, template_id=BAL_TID, contract_id=cid,
                       choice="Repay",
                       argument={"user": user, "collateralToken": collateral_token, "borrowToken": borrow_token})
    return res["exerciseResult"]

def get_collaterals(cid: str, user: str):
    res = make_request("exercise", act_as=user, template_id=BAL_TID, contract_id=cid,
                       choice="GetCollaterals", argument={"user": user})
    return res["exerciseResult"]

def get_borrowers(cid: str, user: str):
    res = make_request("exercise", act_as=user, template_id=BAL_TID, contract_id=cid,
                       choice="GetBorrowers", argument={"user": user})
    return res["exerciseResult"]

def get_balances(cid: str, user: str) -> dict[str, Decimal]:
    res = make_request("exercise", act_as=user, template_id=BAL_TID, contract_id=cid,
                       choice="GetBalances", argument={"user": user})
    out = {}
    for item in res["exerciseResult"]:
        if isinstance(item, dict) and "_1" in item and "_2" in item:
            out[item["_1"]] = Decimal(str(item["_2"]))
        elif isinstance(item, list) and len(item) == 2:
            out[item[0]] = Decimal(str(item[1]))
        else:
            raise AssertionError(f"Unexpected tuple encoding: {item}")
    return out


@given(tok=alpha, a1=money, a2=money)
@settings(max_examples=12, deadline=None)
def test_lend_accumulates_and_updates_contract_balance(tok, a1, a2):
    owner = allocate_unique_party("Owner")
    u     = allocate_unique_party("User")

    # State: empty lenders/borrowers; balances initialized per tokens_fixed; users=[]
    cid = create_contract(owner, [(t, Decimal("0")) for t in tokens_fixed])

    # State: users=[u] (observer added); all balances still 0; lenders/borrowers unchanged
    cid = add_observer(cid, owner, u)

    # State after first lend: lenders contains one entry for (u,tok,a1); contract balance[tok]+=a1
    cid = lend(cid, u, tok, Decimal(a1))

    # State after second lend: same lender entry for (u,tok) increased by a2; balance[tok]+=a2
    cid = lend(cid, u, tok, Decimal(a2))

    cols = get_collaterals(cid, u)
    toks = [c["token"] for c in cols if c["owner"] == u]
    bals = {c["token"]: Decimal(str(c["balance"])) for c in cols if c["owner"] == u}
    assert tok in toks
    assert bals[tok] == Decimal(a1) + Decimal(a2)

    balmap = get_balances(cid, u)
    assert balmap[tok] >= Decimal(a1) + Decimal(a2)

@given(tok=alpha, a1=money, a2=money)
@settings(max_examples=12, deadline=None)
def test_withdraw_respects_lender_balance(tok, a1, a2):
    owner = allocate_unique_party("Owner")
    u     = allocate_unique_party("User")

    # State: empty, balances 0
    cid = create_contract(owner, [(t, Decimal("0")) for t in tokens_fixed])

    # State: users=[u]
    cid = add_observer(cid, owner, u)

    # State: lender(u,tok)=a1; balances[tok]+=a1
    cid = lend(cid, u, tok, Decimal(a1))

    # State: lender(u,tok) reduced by w; balances[tok]-=w; w <= a1
    w = min(Decimal(a1), Decimal(a2))
    cid = withdraw(cid, u, tok, w)

    cols = get_collaterals(cid, u)
    bals = {c["token"]: Decimal(str(c["balance"])) for c in cols if c["owner"] == u}
    assert bals.get(tok, Decimal("0")) == Decimal(a1) - w

    balmap = get_balances(cid, u)
    assert balmap[tok] >= Decimal("0")

@given(coll_tok=alpha, borrow_tok=alpha, coll_amt=money, borrow_amt=money)
@settings(max_examples=15, deadline=None)
def test_borrow_and_repay_roundtrip(coll_tok, borrow_tok, coll_amt, borrow_amt):
    # Pre-condition state we aim for before Borrow:
    # - u1 has collateral c_amt in coll_tok
    # - contract has >= b_amt of borrow_tok
    # - no active loan for (u1, borrow_tok, coll_tok)
    assume_diff = coll_tok != borrow_tok
    if not assume_diff:
        return

    owner = allocate_unique_party("Owner")
    u1    = allocate_unique_party("User1")
    u2    = allocate_unique_party("User2")

    # State: empty lenders/borrowers; balances 0; users=[]
    cid = create_contract(owner, [(t, Decimal("0")) for t in tokens_fixed])

    # State: users=[u1,u2]
    cid = add_observer(cid, owner, u1)
    cid = add_observer(cid, owner, u2)

    b_amt = Decimal(borrow_amt).quantize(Decimal("0.01"))
    if b_amt <= 0:
        return
    c_amt = max(Decimal(coll_amt).quantize(Decimal("0.01")), (b_amt * 2).quantize(Decimal("0.01")))

    # State: lender(u1,coll_tok)=c_amt; balances[coll_tok]+=c_amt
    cid = lend(cid, u1, coll_tok, c_amt)

    # State: lender(u2,borrow_tok)=b_amt; balances[borrow_tok]+=b_amt
    cid = lend(cid, u2, borrow_tok, b_amt)

    # State after Borrow:
    # - balances[borrow_tok]-=b_amt
    # - lender(u1,coll_tok)-=c_amt
    # - borrowers += (u1, coll_tok, c_amt, borrow_tok, b_amt)
    cid = borrow(cid, u1, coll_tok, c_amt, borrow_tok, b_amt)

    cols_u1 = get_collaterals(cid, u1)
    bals_u1 = {c["token"]: Decimal(str(c["balance"])) for c in cols_u1 if c["owner"] == u1}
    assert bals_u1[coll_tok] == Decimal("0")

    brs_u1 = get_borrowers(cid, u1)
    assert any(b["borrowToken"] == borrow_tok and b["collateralToken"] == coll_tok and Decimal(str(b["borrowAmount"])) == b_amt for b in brs_u1)

    # State after Repay:
    # - balances[borrow_tok]+=b_amt
    # - lender(u1,coll_tok)+=c_amt (collateral returned)
    # - borrowers entry removed
    cid = repay(cid, u1, coll_tok, borrow_tok)

    cols_u1 = get_collaterals(cid, u1)
    bals_u1 = {c["token"]: Decimal(str(c["balance"])) for c in cols_u1 if c["owner"] == u1}
    assert bals_u1[coll_tok] == c_amt

    brs_u1 = get_borrowers(cid, u1)
    assert all(not (b["borrowToken"] == borrow_tok and b["collateralToken"] == coll_tok) for b in brs_u1)
