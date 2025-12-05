<a id="top"></a>

# Pinacle (Reference Repository)

![DRG4FOOD](https://img.shields.io/badge/DRG4FOOD-project-green)
![Status](https://img.shields.io/badge/status-reference-lightgrey)
![release](https://img.shields.io/badge/release-v0.1.0-blue)
![License](https://img.shields.io/badge/license-MIT-brightgreen)

Pinacle is a DRG4FOOD Open Call project applying AI-supported nutrition planning with privacy-preserving digital identity to food-aid workflows. Developed by Sapienza University of Rome, Co2gether and Konnecta (Food Bank of Western Greece) and carried out from **October 2024 to September 2025**. Pinacle contributes an open, reusable ZKP identity layer to the DRG4FOOD Toolbox, enabling privacy-preserving verification capabilities across food-system applications.

---

## Overview

Pinacle is a responsible digital solution that enhances food-aid operations through AI-driven nutrition planning and privacy-preserving digital identity. Designed for food banks and community organisations, it bridges surplus food logistics with the personal realities of nutrition, health, and cultural preferences — helping turn donated food into personalised wellbeing for vulnerable groups. 

At its core, Pinacle introduces a **privacy-preserving identity and authorisation** layer based on **Zero-Knowledge Proofs (ZKPs)**. A dedicated verifier smart contract enables secure, on-chain validation of identity proofs without revealing personal data. This decentralised mechanism supports GDPR-aligned data handling, strengthening trust between food recipients, intermediaries, and food banks, and protecting the dignity and privacy of recipients while enabling personalised service.

By integrating nutrition intelligence, community co-design, and privacy-first architecture, Pinacle demonstrates how ethical AI can support fairer, more transparent food-aid systems.


---

## About the Solution

Pinacle developed an integrated, AI-driven platform that connects food banks, volunteers, and recipients through three interoperable tools:

- **Citizen mobile app** – Allows individuals to manage their dietary profile, receive personalised recommendations, and access food-aid services using privacy-preserving credentials.
- **Food-bank operators web dashboard** – Supports planning, stock management, and distribution workflows, aligning donated food inventories with recipients' needs.
- **Privacy-preserving backend** – Matches food items to individual dietary requirements, using ZKPs and verifiable credentials to ensure sensitive attributes remain confidential.

Together, these components enable food-aid organisations to plan and distribute food more efficiently while offering recipients guidance that is healthy, culturally relevant, and respectful of their privacy.

[↑ Back to top](#top)

---

## Open-Source Components

The privacy-preserving identity and authorisation layer developed within the project is published as open-source in the Pinacle project GitHub space: 

[Pinacle Verifier Smart Contract Repository](https://github.com/drg4food-pinacle/verifier-smart-contract).  
This repository consists of:

- **ZKP Verifier smart contract** – A Solidity verifier contract that enables on-chain validation of **Zero-Knowledge Proofs (ZKPs)**. It verifies user attributes **without revealing any personal data**, supporting decentralised and GDPR-aligned access control.

- **Go deployment & utility tools** – Go-based tooling for compiling, deploying, and interacting with the verifier, zkLogin contract, and supporting components (mimc, Merkle utilities, account generators).

- **ZKP demo** – A Go-based demonstration intended to run an end-to-end proof generation and verification pipeline using the verifier contract.

> **Note:**  
> The broader Pinacle solution (mobile app, operator dashboard, nutrition backend) is *not* open source. 
> The Pinacle repository provides the **identity layer only**, offered as a reusable building block for privacy-preserving applications.

[↑ Back to top](#top)

---

## How You Can Use It

The verifier component can be reused or extended in several ways:

### For Developers Building Privacy-Preserving Services

- Integrate ZKP-based identity verification into new applications requiring selective disclosure.
- Use the contract as a template for building GDPR-aligned authentication workflows.
- Adapt the scripts to deploy and test on different Ethereum-compatible chains.

### For Researchers Exploring Digital Identity

- Experiment with ZKPs for food-system or public-service scenarios.
- Prototype new authorisation mechanisms based on verifiable attributes.
- Analyse performance, gas usage, and usability across different setups.

### For Open-Innovation Partners

- Combine the verifier with new user applications, dashboards, or backend services.
- Validate access rights without centralised identity storage.
- Extend the approach to community-driven or decentralised infrastructures.

Because it is modular and privacy-preserving by design, the verifier is suitable for responsible digital-identity experiments far beyond the original Pinacle project.

[↑ Back to top](#top)

---

## Contribution to the DRG4FOOD Toolbox

Pinacle has provided their verifier smart contract tooling as a reusable and scalable building block to the DRG4Food Toolbox; for projects requiring privacy-preserving role-based access control. This is published and maintained in the Pinacle project GitHub space:

**[Pinacle Verifier Smart Contract Repository](https://github.com/drg4food-pinacle/verifier-smart-contract)**

The Pinacle repository provides:

- Go-based smart contract deployment tools
- A zkLogin demonstration contract
- A Circom circuit library
- A ZKP test (`pinacle.go`) intended to run end-to-end

However, several required proving artifacts (`*.zkey`, `.wasm`, verification key) are not included in the repository due to the large file size, the trusted-setup script is currently incomplete for external users (the prover artifacts are not included in the repository, and the setup script does not yet generate a matching verifier contract). As a result, the Pinacle ZKP demo cannot be executed end-to-end using the repository as-is.

[↑ Back to top](#top)

---

## Purpose of This Repository

This **DRG4FOOD Reference Repository** resolves the steps required to *reproduce the proving process locally* and documents the remaining blockers preventing the full end-to-end ZKP demo. This reference repository provides:

- A **revised, cross-platform `setup.sh`** capable of running the entire Groth16 trusted setup for any Pinacle Circom circuit
- A lightly improved **`deploy.go`** with adjusted gas settings and debugging outputs
- Documentation of the **trusted setup pipeline**, including guidelines for **reproducing all successful steps**
- A transparent explanation of the **current blocker preventing the final ZKP test**

> **Important:**  
> This repository does *not* mirror or fork Pinacle's code. All original source code remains in the Pinacle repository. This DRG4FOOD repo only provides **reference documentation and utilities revised after testing**.

As such, this reference repository acts as a **translation layer** that aims to make the Pinacle verifier tooling more reproducible, portable, and accessible to external developers using the DRG4FOOD Toolbox.

[↑ Back to top](#top)

---

## This Reference Repository Structure

```
pinacle/
│
├── setup.sh              # DRG4FOOD revised trusted-setup script (macOS + Linux)
├── deploy.go             # Updated gas settings + diagnostics (documentation only)
└── README.md             # (this file)
```

[↑ Back to top](#top)

---

## Understanding the Pinacle ZKP Pipeline

### Circom Circuit

The Circom circuit is the mathematical program defining what the Zero-Knowledge Proof must prove. It specifies the private computation a user performs **without revealing the private inputs**. Pinacle's circuit implements the identity logic behind their zkLogin, including:

- MiMC hashing
- Ethereum-address public signals
- Merkle-tree membership verification
- Constraints binding user identity fields

---

### What `setup.sh` does

The `setup.sh` script performs the trusted setup and circuit compilation required for Groth16 proof generation and verification.

**1. Compile Circom Circuit**

The first step compiles the Circom circuit and produces:

- **Pinacle.r1cs** — The constraint system (the mathematical rules the proof must satisfy).
- **Pinacle.wasm** — Program used to compute witnesses needed for proof generation (fills in the values according to the rules).

These two files define **what the prover must compute** and **how the witness is produced.**

**2. Groth16 Ceremony (two-phase `snarkjs` setup)**

The script then runs a two-phase Groth16 setup using `snarkjs`:

Phase 1 — Powers-of-Tau (circuit-agnostic)
Produces:

- `potXX_final.ptau` — Universal parameters shared across circuits, generated from multi-party contributions.

In the Pinacle setup, the pipeline performs three contributions:

1. Participant 1 → randomness added
2. Participant 2 → randomness added
3. "Bellman challenge" contribution, cross-checked with a challenge/response protocol

This ensures:

- no single party knows the toxic waste
- final parameters cannot be forged
- the setup remains auditable and cryptographically secure

Phase 2 — Circuit-specific setup

Using the circuit (`pinacle.r1cs`) and the Phase 1 PTAU file (`potXX_final.ptau`), the script then produces:

- **pinacle_final.zkey** – Circuit-specific proving key containing both *proving parameters* and *verification parameters*.
- **verification_key.json** – A JSON file generated from `pinacle_final.zkey`. Contains the circuit-specific verification parameters used for **off-chain** proof checking.

This step fully defines **how proofs are created**, and **how they are checked off-chain**.


**3. On-Chain Verifier Contract (planned / manual step)**

What should *also* be produced (but is currently **not** generated in the tested `setup.sh`) is:

- **Verifier.sol** – A Solidity smart contract exported from `pinacle_final.zkey`. It encodes the same circuit-specific verification parameters for **on-chain** Groth16 proof checking.

This final step defines **how proofs are checked on-chain**, ensuring the verifier contract and the prover use exactly the same cryptographic parameters.

> **Note:** At present, `verifier.sol` must be exported manually (see below).


### How to run `setup.sh`

From the repository root:

```bash
# (optional) Make sure the script is executable
chmod +x setup.sh

# Run the trusted setup and circuit compilation
./setup.sh

```
### Prerequisites

- `node` and `npm` installed  
- `snarkjs` available in your environment (globally or via `npx`)  
- `circom` installed and available on your `PATH`  

### What the script will do

1. Compile the circuit (`pinacle.r1cs`, `pinacle.wasm`)  
2. Run the Groth16 setup (Phase 1 + Phase 2)  
3. Output:
   - the Powers-of-Tau file (`potXX_final.ptau`)  
   - the final proving key (`pinacle_final.zkey`)  
   - the verification key (`verification_key.json`)  


### About the DRG4FOOD Toolbox revised `setup.sh` script

The `setup.sh` in this reference repository is a **DRG4FOOD-revised version** of Pinacle’s original script. It resolves several environment-specific issues with commands and paths and adds full **macOS/Linux compatibility** by resolving Linux-specific assumptions, replacing **GNU-only utilities** with cross-platform equivalents, and ensuring that `snarkjs` and Node tooling run reliably on macOS. It now executes end-to-end on both macOS and Linux and completes the **full prover-side Groth16 setup** (circuit compilation, Phase 1 and Phase 2). 

> **Note:** This script does **not** generate the on-chain `Verifier.sol` file. The final exporter step (`zkey → Verifier.sol`) is pending clarification from the Pinacle team and is therefore intentionally not included.


[↑ Back to top](#top)

---

## Deploying the Contracts

Before deployment, three environment variables must be set in `deployer/.env`:

```bash
GETH_NODE_URL=         # RPC URL of the Ethereum node, must be a valid URL (following standard URL formatting rules)
GETH_NODE_KEYSTORE=    # Path to the keystore directory, must exists
GETH_NODE_PASSWORD=    # Password for the keystore
```

Run the following commands:

```bash
cd deployer
go run cmd/deploy/deploy.go
```

This is where the cryptographic parameters become on-chain logic.

- **Create a transactor:** Loads the keystore, decrypts the key, connects to the chain
- **Deploy smart contracts in order:**
  - Mimc.sol - the hash function
  - Verifier.sol - must match your proving key
  - zkLogin.sol - ties everything together (vk + MiMC + Merkle roots + address logic)
- **Save addresses for other tools:** addresses/addresses.json


### About the DRG4FOOD Toolbox revised `deploy.go`

The `deploy.go` in this reference repository is a **lightly revised version** of Pinacle’s original deployment script. The Pinacle team deployed their contracts on a **GoQuorum RAFT-based network** (with gas checks disabled via `GasFeeCap=0`). Subsequent testing on a **local Geth development node** required additional visibility and tuning, because Geth enforces different gas rules and block limits.

**Additional diagnostics added:**
- Deployment logging for contract addresses, bytecode sizes, gas usage, and receipt status.  
- These diagnostics were essential for detecting silent constructor reverts, confirming when contracts deployed successfully, and understanding why transactions failed on Geth.  
- They do **not** modify any contract logic—only provide better transparency for developers using different node setups.

**Why the gas settings were updated:**
- Examining the local Geth dev chain (`eth.getBlock("latest").gasLimit`) showed a block gas cap of **11,738,125**, which explains why the original `GasLimit` of 20,000,000 failed on this node.  
- Measuring actual gas consumption of Mimc, Verifier, and zkLogin during deployment (e.g., `gasUsed=7,946,307` for zkLogin) indicated that a safe cross-platform limit of **~11M** was appropriate.  
- We also added explicit `GasTipCap` and `GasFeeCap` values, which Geth requires even in dev mode (this may differ across node types or configurations).

Together, these adjustments make the deployer run reliably on **both Geth and GoQuorum**, without altering contract behaviour. The revised script aims to provide a clearer, more portable, and easier-to-debug deployment experience across Ethereum-compatible nodes.


[↑ Back to top](#top)

---

## Running the Pinacle Zero Knowledge Proof Test

This is where the trusted-setup outputs are used to generate a real zero knowledge proof locally and ask the blockchain to verify it.

```bash
go run cmd/pinacle/pinacle.go
```

### What This Program Does

- **Computes a witness:** Takes the user's private inputs and runs the circuit (via `Pinacle.wasm`) to produce hidden values — the "secret computation" the user proves knowledge of.

- **Generates a Zero-Knowledge Proof:** Uses the proving key (`Pinacle_final.zkey`) to turn the witness into a compact cryptographic proof.

- **Verifies the proof on-chain:** Submits the proof to the deployed `Verifier.sol` contract, which checks it using the corresponding verification parameters:
  - Contract addresses
  - Verifier contract
  - zkLogin logic

If the proof is valid, the blockchain confirms the user's identity/authorisation without ever seeing their private data.

> **Current limitation:** As noted above, the reference repository does not yet include an automated export of a matching `Verifier.sol` from a newly generated `.zkey`. Until this final verifier-regeneration step is implemented, the full end-to-end `pinacle.go` demo cannot be reliably executed using this repository alone.

[↑ Back to top](#top)

---

## ZKP Pipeline Architecture

```
                [ Circom Circuit ]
              Pinacle.circom (identity logic)
       (MiMC hashing, Merkle proof, address constraints)
                              |
                              v
                 1. Compile Circom circuit
                      (via setup.sh)
                              |
              +---------------+-----------------+
              |                                 |
              v                                 v
    Pinacle.r1cs                      Pinacle.wasm
  constraint system             witness generator (WASM)
 (rules the proof must        (computes witnesses from
      satisfy)                  private user inputs)
              \                                 /
               \                               /
                \                             /
                 v                           v
            2. Groth16 Ceremony (snarkjs, two-phase)
                              |
         +--------------------+----------------------+
         |                                           |
         v                                           v
   Phase 1 — Powers-of-Tau                 Phase 2 — Circuit-specific setup
  (circuit-agnostic, multi-party)        (uses Pinacle.r1cs + potXX_final.ptau)
         |                                           |
         v                                           |
  potXX_final.ptau                                  |
  universal parameters                               |
         |                                           |
         +---------------------------+--------------+
                                     v
                        pinacle_final.zkey
          (circuit-specific proving + verification parameters)
                                     |
                                     v
                         verification_key.json
       (verification parameters exported for OFF-CHAIN checking)


        3. On-chain verifier contract (snarkjs export) [intended]
                              |
                              v
                         Verifier.sol
      Solidity contract embedding the SAME verification parameters
      as pinacle_final.zkey, used for ON-CHAIN Groth16 checks


        Deploying the contracts (go run cmd/deploy/deploy.go)
                              |
                              v
     +-------------------+-------------------+------------------+
     |                   |                   |                  |
     v                   v                   v                  v
  Mimc.sol          Verifier.sol        zkLogin.sol      addresses.json
 (hash fn)       (on-chain verifier)  (ties vk + MiMC   (deployed contract
                                       + Merkle roots     addresses for
                                      + address logic)     other tools)


      Running the Pinacle Zero Knowledge Proof test
             (go run cmd/pinacle/pinacle.go)
                              |
                              v
   1. Uses Pinacle.wasm to compute a witness from private inputs
   2. Uses pinacle_final.zkey to generate a Zero-Knowledge proof
   3. Sends proof + public signals to Verifier.sol / zkLogin.sol
   4. Chain verifies the proof using on-chain verification parameters

If all components are aligned (keys, verifier, contracts),
the blockchain confirms identity/authorisation WITHOUT seeing
any of the user's private data.
```

[↑ Back to top](#top)

---

## Optional Developer Tooling

### `main.go compile` / `abigen`

Pinacle includes a Go-based build tool for developers who want to modify the smart contracts and regenerate all related artifacts.

You should only run these tools if you change:

- **Verifier.sol:** e.g., after updating the Circom circuit or generating a new proving key
- **Mimc.sol:** if switching MiMC parameters or replacing it with another hash (Poseidon, Rescue, etc.)
- **zkLogin.sol:** if the use case changes and different authorisation or identity logic is needed, for example:
  - To include additional user attributes
  - Change role/permission logic
  - Integrate the verifier into another application
  - Add new functions (e.g., revoke, update, attestations)
  - Swap in a newly generated verifier contract

The Go tooling consists of:

- `go run cmd/main.go compile` – Recompiles Solidity contracts and produces new JSON ABI + bytecode files
- `go run cmd/main.go abigen` – Regenerates Go bindings from those ABIs

These steps are **not required** for running the Pinacle ZKP demo. The repository already includes the generated JSONs and Go bindings.

> **Note:** ⚠️ On macOS, `abigen` will fail (missing `params_darwin.go`) and delete the existing bindings. 
> Unless you are intentionally modifying the contracts, you should skip both steps.


---

## License

This reference material is provided under the **MIT License**, excluding all original Pinacle source code, which remains under its own license.

[↑ Back to top](#top)