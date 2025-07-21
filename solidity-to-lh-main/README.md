# Solidity to Haskell Converter

A tool that translates Solidity smart contracts to Liquid Haskell code, preserving the contract's logic while adding formal verification capabilities through Liquid Haskell's refinement types.

## Features

- Converts Solidity contracts to Liquid Haskell code
- Preserves contract state and functions
- Handles enums, state variables, and function parameters
- Converts Solidity types to appropriate Haskell types
- Generates Liquid Haskell refinement types from require/assert conditions
- Web interface for interactive conversion
- Command-line tools for batch processing

## Installation

```bash
# Clone the repository
git clone https://github.com/GonzaloConsoli/solidity-to-lh.git

npm install
```
## Usage
#### Web Interface
```bash
npm run dev
```
#### Command Line Tools
Run a single contract:
```bash
node scripts/run_contract.js <contract-name>
```

## Testing
For converting all smart contracts and checking that ghc parses them in the test_contracts folder
```bash
npm run comp
```
For running unit test
```bash
npm run test
```

## Project Structure

- src - Source code
  - index.js - Main conversion logic
  - gatherState.js - State variable processing
  - gatherFunctions.js - Function processing 
  - generateData.js - Haskell data type generation
  - generateFunctions.js - Haskell function generation
  - liquidConditions.js - Refinement type generation
  - typeMappings.js - Type conversion utilities
  - translator.js - AST translation utilities
  - server.js - Web server
- scripts - Command line tools
- test_contracts - Example Solidity contracts
- __tests__ - Unit tests

