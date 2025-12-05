#!/usr/bin/env bash
set -euo pipefail

##########################################################
# PINACLE Zero-Knowledge Setup Script (DRG4FOOD-adapted)
#
# Purpose:
#   - Take a Circom circuit file (.circom)
#   - Run a Groth16 trusted setup (powers of tau + zkey)
#   - Compile the circuit to .r1cs and .wasm
#   - Produce proving/verification keys:
#       - <name>_final.zkey
#       - verification_key.json
#
# This is an adapted version of the original
# PINACLE setup script, adjusted for cross-platform use
# and clearer, reproducible execution.
##########################################################


##########################################################
#########################[COLORS] ########################
##########################################################
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# If no arguments are provided, show full usage instructions and exit
if [[ $# -eq 0 ]]; then
  echo -e "${RED}Usage: ./setup.sh --circom PATH/TO/circuit.circom --power N${NC}"
  echo -e "${RED}Example: ./setup.sh --circom circuits/Pinacle.circom --power 18${NC}"
  echo -e "${RED}Options:${NC}"
  echo -e "${RED}  --circom CIRCOM_FILE   Specify a .circom circuit file${NC}"
  echo -e "${RED}  --power N              Powers-of-tau exponent (e.g. 17, 18, 19)${NC}"
  exit 1
fi

# Initialize variables
CIRCOM_FILE=""
POWER_OF_TAU=""

# Process command-line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --circom)
      shift
      CIRCOM_FILE="${1:-}"            # safe value assignment
      ;;
    --power)
      shift
      POWER_OF_TAU="${1:-}"           # safe value assignment
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      exit 1
      ;;
  esac
  shift || true                       # avoid zsh errors when shifting at end of args
done

# --- Basic validation ------------------------------------------------------

# Validate circom file
# Require a .circom extension. Using shell globbing (not =~ regex) for macOS/zsh portability
if [[ -z "${CIRCOM_FILE}" ]]; then
  echo -e "${RED}Error: --circom flag is required.${NC}"
  exit 1
fi

if [[ ! -f "${CIRCOM_FILE}" ]]; then
  echo -e "${RED}Error: Circom file '${CIRCOM_FILE}' does not exist.${NC}"
  exit 1
fi

# Enforce .circom extension (simple glob check, not regex)
if [[ "${CIRCOM_FILE}" != *.circom ]]; then
  echo -e "${RED}Error: Circom file must have .circom extension (e.g. Pinacle.circom).${NC}"
  exit 1
fi

# Validate power of tau
if [[ -z "${POWER_OF_TAU}" ]]; then
  echo -e "${RED}Error: --power flag is required (e.g. 17, 18, 19...).${NC}"
  exit 1
fi

if ! [[ "${POWER_OF_TAU}" =~ ^[0-9]+$ ]]; then
  echo -e "${RED}Error: Power of tau must be a valid integer.${NC}"
  exit 1
fi

if ! command -v circom >/dev/null 2>&1; then
  echo -e "${RED}Error: 'circom' is not installed or not on PATH.${NC}"
  echo -e "${YELLOW}Hint: see https://docs.circom.io/getting-started/installation/${NC}"
  exit 1
fi

if ! command -v snarkjs >/dev/null 2>&1; then
  echo -e "${RED}Error: 'snarkjs' is not installed or not on PATH.${NC}"
  echo -e "${YELLOW}Hint: npm install -g snarkjs${NC}"
  exit 1
fi

# Use the provided path as-is
CIRCOM_BASENAME="$(basename "${CIRCOM_FILE}")"
CIRCOM_NAME="${CIRCOM_BASENAME%%.*}"   # e.g. Pinacle.circom -> Pinacle

ROOT_DIR="$(pwd)"
POWERS_DIR="${ROOT_DIR}/powersOfTau"
BUILD_DIR="${ROOT_DIR}/circuits/build/${CIRCOM_NAME}"
KEYS_DIR="${BUILD_DIR}/keys"

echo -e "${GREEN}Using circuit: ${CIRCOM_FILE}${NC}"
echo -e "${GREEN}Circuit name: ${CIRCOM_NAME}${NC}"
echo -e "${GREEN}Powers-of-Tau directory: ${POWERS_DIR}${NC}"
echo -e "${GREEN}Build directory: ${BUILD_DIR}${NC}"

# --- Powers of Tau ---------------------------------------------------------

mkdir -p "${POWERS_DIR}"
PTAU_FILE="${POWERS_DIR}/pot${POWER_OF_TAU}_final.ptau"

if [[ ! -f "${PTAU_FILE}" ]]; then
  echo -e "${GREEN}Starting new powers-of-tau ceremony for power ${POWER_OF_TAU}.${NC}"
  pushd "${POWERS_DIR}" >/dev/null

  snarkjs powersoftau new bn128 "${POWER_OF_TAU}" "pot${POWER_OF_TAU}_0000.ptau" -v

  echo -e "${GREEN}First contribution...${NC}"
  snarkjs powersoftau contribute "pot${POWER_OF_TAU}_0000.ptau" "pot${POWER_OF_TAU}_0001.ptau" \
    --name="First contribution" -v -e="$(uuidgen | tr -d '-' | head -c40)"

  echo -e "${GREEN}Second contribution...${NC}"
  snarkjs powersoftau contribute "pot${POWER_OF_TAU}_0001.ptau" "pot${POWER_OF_TAU}_0002.ptau" \
    --name="Second contribution" -v -e="$(uuidgen | tr -d '-' | head -c40)"

  echo -e "${GREEN}Third contribution (bellman challenge)...${NC}"
  snarkjs powersoftau export challenge "pot${POWER_OF_TAU}_0002.ptau" "challenge_0003"
  snarkjs powersoftau challenge contribute bn128 "challenge_0003" "response_0003" \
    -e="$(uuidgen | tr -d '-' | head -c40 2>/dev/null || uuidgen | tr -d '-' | head -c40)"
  snarkjs powersoftau import response "pot${POWER_OF_TAU}_0002.ptau" "response_0003" "pot${POWER_OF_TAU}_0003.ptau" \
    -n="Third contribution"

  echo -e "${GREEN}Verifying powers-of-tau...${NC}"
  snarkjs powersoftau verify "pot${POWER_OF_TAU}_0003.ptau"

  echo -e "${GREEN}Applying random beacon...${NC}"
  snarkjs powersoftau beacon "pot${POWER_OF_TAU}_0003.ptau" "pot${POWER_OF_TAU}_beacon.ptau" \
    0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f 10 \
    -n="Final Beacon"

  echo -e "${GREEN}Preparing phase 2...${NC}"
  snarkjs powersoftau prepare phase2 "pot${POWER_OF_TAU}_beacon.ptau" "pot${POWER_OF_TAU}_final.ptau" -v

  echo -e "${GREEN}Verifying final ptau...${NC}"
  snarkjs powersoftau verify "pot${POWER_OF_TAU}_final.ptau"

  echo -e "${GREEN}Cleaning intermediate ptau files...${NC}"
  rm -f pot${POWER_OF_TAU}_0000.ptau pot${POWER_OF_TAU}_0001.ptau pot${POWER_OF_TAU}_0002.ptau \
        challenge_0003 response_0003 pot${POWER_OF_TAU}_0003.ptau pot${POWER_OF_TAU}_beacon.ptau

  popd >/dev/null
else
  echo -e "${YELLOW}Powers-of-tau for power ${POWER_OF_TAU} already exists. Reusing ${PTAU_FILE}.${NC}"
fi

# --- Compile circuit -------------------------------------------------------

mkdir -p "${BUILD_DIR}"
if [[ ! -f "${BUILD_DIR}/${CIRCOM_NAME}.r1cs" ]]; then
  echo -e "${GREEN}Compiling circuit with circom...${NC}"
  pushd "${BUILD_DIR}" >/dev/null

  circom "${ROOT_DIR}/${CIRCOM_FILE}" --r1cs --wasm --sym

  echo -e "${GREEN}Circuit info:${NC}"
  snarkjs r1cs info "${CIRCOM_NAME}.r1cs"

  echo -e "${GREEN}Printing constraints (for inspection / optional debugging)...${NC}"
  snarkjs r1cs print "${CIRCOM_NAME}.r1cs" "${CIRCOM_NAME}.sym"

  popd >/dev/null
else
  echo -e "${YELLOW}Circuit already compiled at ${BUILD_DIR}/${CIRCOM_NAME}.r1cs. Skipping compile.${NC}"
fi

# --- Groth16 setup (zkey & verification key) -------------------------------

mkdir -p "${KEYS_DIR}"

FINAL_ZKEY="${KEYS_DIR}/${CIRCOM_NAME}_final.zkey"
VK_JSON="${KEYS_DIR}/verification_key.json"

if [[ ! -f "${VK_JSON}" ]]; then
  echo -e "${GREEN}Running Groth16 setup and generating proving/verification keys...${NC}"
  pushd "${KEYS_DIR}" >/dev/null

  snarkjs groth16 setup \
    "../${CIRCOM_NAME}.r1cs" \
    "${PTAU_FILE}" \
    "${CIRCOM_NAME}_0000.zkey"

  echo -e "${GREEN}First zkey contribution...${NC}"
  snarkjs zkey contribute "${CIRCOM_NAME}_0000.zkey" "${CIRCOM_NAME}_0001.zkey" \
    --name="First Contribution" -v -e="$(uuidgen | tr -d '-' | head -c40)"

  echo -e "${GREEN}Second zkey contribution...${NC}"
  snarkjs zkey contribute "${CIRCOM_NAME}_0001.zkey" "${CIRCOM_NAME}_0002.zkey" \
    --name="Second Contribution" -v -e="$(uuidgen | tr -d '-' | head -c40)"

  echo -e "${GREEN}Third zkey (bellman) contribution...${NC}"
  snarkjs zkey export bellman "${CIRCOM_NAME}_0002.zkey" "challenge_phase2_0003"
  snarkjs zkey bellman contribute bn128 "challenge_phase2_0003" "response_phase2_0003" \
    -e="$(uuidgen | tr -d '-' | head -c40)"
  snarkjs zkey import bellman "${CIRCOM_NAME}_0002.zkey" "response_phase2_0003" \
    "${CIRCOM_NAME}_0003.zkey" -n="Third Contribution"

  echo -e "${GREEN}Verifying latest zkey...${NC}"
  snarkjs zkey verify "../${CIRCOM_NAME}.r1cs" "${PTAU_FILE}" "${CIRCOM_NAME}_0003.zkey"

  echo -e "${GREEN}Applying random beacon to zkey...${NC}"
  snarkjs zkey beacon "${CIRCOM_NAME}_0003.zkey" "${CIRCOM_NAME}_final.zkey" \
    0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f 10 \
    -n="Final Beacon phase2"

  echo -e "${GREEN}Verifying final zkey...${NC}"
  snarkjs zkey verify "../${CIRCOM_NAME}.r1cs" "${PTAU_FILE}" "${CIRCOM_NAME}_final.zkey"

  echo -e "${GREEN}Exporting verification key JSON...${NC}"
  snarkjs zkey export verificationkey "${CIRCOM_NAME}_final.zkey" "verification_key.json"

  echo -e "${GREEN}Cleaning intermediate zkey files...${NC}"
  rm -f "${CIRCOM_NAME}_0000.zkey" "${CIRCOM_NAME}_0001.zkey" "${CIRCOM_NAME}_0002.zkey" \
        "challenge_phase2_0003" "response_phase2_0003" "${CIRCOM_NAME}_0003.zkey"

  popd >/dev/null
else
  echo -e "${YELLOW}Verification key already exists at ${VK_JSON}. Skipping Groth16 setup.${NC}"
fi

echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}Zero-knowledge setup completed for circuit: ${CIRCOM_NAME}${NC}"
echo -e "${GREEN}Artifacts:${NC}"
echo -e "${GREEN}- R1CS:     ${BUILD_DIR}/${CIRCOM_NAME}.r1cs${NC}"
echo -e "${GREEN}- WASM:     ${BUILD_DIR}/${CIRCOM_NAME}_js/${CIRCOM_NAME}.wasm${NC}"
echo -e "${GREEN}- ZKey:     ${FINAL_ZKEY}${NC}"
echo -e "${GREEN}- Verification key: ${VK_JSON}${NC}"
echo -e "${GREEN}You can now generate proofs and verify them with snarkjs,${NC}"
echo -e "${GREEN}or wire this verification key into on-chain verifier contracts.${NC}"
echo -e "${GREEN}============================================================${NC}"