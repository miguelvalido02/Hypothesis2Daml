# Introduction

This tool provides a Python library for **property-based testing** of **Daml**
contracts, executing them via the **Daml JSON API**.
The `daml_pbt` module integrates with **Hypothesis** (data generation and
shrinking) and **pytest** (execution and reporting), allowing you to validate
**invariants**, **pre/postconditions**, and **stateful workflows** with
automatically generated examples and **reproducible counterexamples**.

**Key features**

* Helpers to create contracts, exercise choices, and run queries.
* Automatic input generation with Hypothesis and counterexample shrinking.
* Per-test party isolation (prevents interference between cases).
* Integration with pytest to run locally and in continuous integration (CI).

**What you’ll find in this repository**

* The `daml_pbt` module with the helpers.
* **Concrete examples** of Daml contracts with reference properties.
* **Reusable templates** to quickly bootstrap new tests.

**Prerequisites**

* **Daml SDK** running locally (**Sandbox** and **JSON API**).
* **Python 3.x** with `pytest`, `hypothesis`, and `requests`.
* A **DAR** file for your Daml project.

# How to run the tool

For all commands, be in the Daml project folder (where `daml.yaml` is).

If you don’t have a virtual environment yet, run:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -U pip pytest hypothesis requests
```

If you don’t have a DAR file yet, run:

```bash
daml build
```

You’ll need **3 terminals** to run the tests.

### Terminal A

Run:

```bash
daml sandbox --port 6865
```

### Terminal B

Run:

```bash
daml json-api --ledger-host localhost --ledger-port 6865 --http-port 7575
```

### Terminal C

Upload the DAR:

```bash
daml ledger upload-dar --host localhost --port 6865 .daml/dist/TestBankTemplate-1.0.0.dar
```

After ensuring the virtual environment exists (first step), run:

```bash
source .venv/bin/activate
```

To run a single test:

```bash
pytest -q -s tests/test_bank_template.py::test_deposit_increases_balance
```

To run all tests in the file:

```bash
pytest -q -s tests/test_bank_template.py
```

---

# Test file

There are some example test files in this repo but here are two quick tips.

How to import the library:

```python
from daml_pbt import make_request, make_auth, make_admin_auth, ensure_ok, allocate_party, allocate_unique_party
```

You need to obtain the `package_id`. Run:

```bash
daml damlc inspect-dar .daml/dist/TestBankTemplate-1.0.0.dar
```

You’ll see something like in the output:

```
DAR archive contains the following packages: TestBankTemplate-1.0.0-c6f004b1cd672ae532964d33767186c66d1b0673ce87a0e05b35e7b78c2fc514 "c6f004b1cd672ae532964d33767186c66d1b0673ce87a0e05b35e7b78c2fc514"
```

The constant `PKG` is the value inside quotes:

```python
PKG = "c6f004b1cd672ae532964d33767186c66d1b0673ce87a0e05b35e7b78c2fc514"
```

---

# Examples and templates

## Concrete examples

There are **8** concrete examples in this repository, located at:
`miguel-valido-repo/benchmark/daml_contracts/`

* **AssetTransfer**
  Buy/sell workflow with states (e.g., `Active`, `OfferPlaced`, `PendingInspection`,
  `Inspected`, `Accepted`/`Rejected`) and roles (owner, buyer, inspector, appraiser).
  *Properties*: valid transitions, accept/reject guards, role-based permissions.

* **BorrowAndLending**
  Loan pool: deposit (lend), withdraw, borrow, and repay.
  *Properties*: `Lend` accumulates balances; `Withdraw` respects available balance;
  `Borrow/Repay` round-trip restores state correctly.

* **DefectiveComponentCounter**
  Counting defective components with manufacturer-only permissions.
  *Properties*: `ComputeTotal` preserves the sum; only the manufacturer is authorized.

* **DigitalLocker**
  Digital locker for sharing documents with requests and revocations.
  *Properties*: `UploadDocuments` sets fields; `Request→Accept→Release` cycle;
  `Share→Revoke` round-trip restores state correctly.

* **FrequentFlier**
  Frequent-flier miles program with accrual and reward rules.
  *Properties*: `AddMiles` updates miles/rewards; only the flier is authorized.

* **SimpleMarket**
  Simple marketplace with offer/accept/reject and state changes.
  *Properties*: `MakeOffer` only from `ItemAvailable`; `MakeOffer` moves to
  `OfferPlaced`; only the owner may accept/reject; guards enforced.

* **WhitelistedRegistry**
  Registry with an owner and a whitelist of authorized parties.
  *Properties*: only the owner may change owner/whitelist; `SetWhitelisted`
  toggles membership; `IsWhitelisted` reflects the actual state.

* **ZeroTokenBank**
  Minimal “bank” without a native token: open account, deposit, withdraw, check balance.
  *Properties*: deposit increases balance correctly; withdraw is forbidden at zero balance.

---

### Templates

There are **3** templates, available at:
`miguel-valido-repo/benchmark/daml_contracts/templates`

* **BorrowLendingTemplate**
  Base for lending pools: `Lend`, `Withdraw`, `Borrow`, `Repay`, per-party balances,
  and limit validations. Useful to test accounting invariants, collateral rules,
  and borrow/repay round-trips.

* **WhitelistedRegistryTemplate**
  Access-control pattern with owner and whitelist: `SetWhitelisted` (toggle),
  `IsWhitelisted` (query), and owner transfer. A base for scenarios where
  authorizations and roles change over time.

* **ZeroTokenBankTemplate**
  Minimal custodial “bank”: open account, deposit, withdraw, query.
  Ideal for simple invariants (balance never negative, consistent sum of balances)
  and basic permission tests.

> Tip: each template and concrete example includes a small starter set of
> properties in its corresponding `tests/` directory, which you can use as a
> baseline.

## Generative AI usage statement

I used generative AI tools to help implement and execute the property-based
tests. All AI-suggested content was reviewed, adapted, and validated before
being included. Responsibility for the properties, tests, and code is entirely
mine.
