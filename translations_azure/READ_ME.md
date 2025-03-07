# Azure Translations
## Azure Benchmark
The Azure benchmark can be found at:
https://github.com/Azure-Samples/blockchain/tree/master/blockchain-workbench/application-and-smart-contract-samples

## Overview
This repository contains translations of **Azure smart contracts** (originally written in Solidity) into **Daml**, along with **unit tests** for each contract. Each folder includes:

1. **Daml Translation** – A contract written in **Daml** that replicates the functionality of the original **Azure smart contract**.
2. **Unit Tests** – **Daml script tests** to validate the correct execution of most **state transitions** and **role-based access control**.

## Execution Trace Commentary
Writing every **significant execution trace by hand** is **impractical** due to the complexity and number of possible transitions in real-world contract executions.

## Visibility Constraints in Daml
One key challenge encountered during these translations is that **parties cannot interact with a contract unless they have visibility over it**. This differs from Solidity, where a party can execute a function even if they were not initially involved in contract creation.  

### **Implications & Workarounds**
To resolve this, several variables had to be **explicitly specified at contract creation** to **ensure that all necessary parties had access**. Examples include:

- **Asset Transfer** – `potentialBuyers` must be specified at the beginning so buyers can make offers.
- **Digital Locker** – `thirdParties` (array) must be set at creation so they can interact with the contract.
- **Simple Market** – The `buyer` must be predefined at the start to allow interactions.

By adding these fields upfront, we ensure that all required parties **have visibility** and can properly execute their intended actions within the contract.
