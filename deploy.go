package main

// deploy.go (DRG4FOOD reference)
//
// This is a lightly adapted version of the original PINACLE deployment
// script. It preserves the original contract behaviour while improving
// logging, diagnostics, and gas configuration for broader compatibility
// with different Ethereum-compatible nodes (e.g. GoQuorum, Geth dev nodes).

import (
	"context"
	"errors"
	"fmt"
	"math/big"
	"os"
	"path/filepath"
	"runtime"
	"sync/atomic"
	"time"

	verifier "deployer/internal/abigen/Verifier"
	"deployer/internal/abigen/mimc"
	zklogin "deployer/internal/abigen/zkLogin"
	"deployer/internal/accounts"
	"deployer/internal/addresses"
	"deployer/internal/banner"
	"deployer/internal/config"
	"deployer/internal/directory"
	"deployer/internal/ethutil"
	"deployer/internal/logger"
	mimcsponge "deployer/internal/mimc"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
)

var (
	// Find the number of CPUs the system has.
	maxProcs = runtime.NumCPU()
	// Keep track of the last processed block from events.
	LatestProcessedBlockNumber atomic.Uint64
)

func main() {
	runtime.GOMAXPROCS(maxProcs)

	// Initialize config first.
	cfg := config.NewConfig()

	// Set GOMAXPROCS to the number of CPUs available.
	logger.Logger.Info().Msgf("Setting GOMAXPROCS to %d", maxProcs)
	logger.Logger.Info().Msgf("Starting Rollup Server on %d CPU(s)", maxProcs)
	logger.Logger.Info().Msgf("Go Version: %s", runtime.Version())
	logger.Logger.Info().Msgf("OS: %s", runtime.GOOS)
	logger.Logger.Info().Msgf("Architecture: %s", runtime.GOARCH)

	// Load configuration.
	if err := cfg.LoadConfig(); err != nil {
		logger.Logger.Fatal().Err(err).Msg("Failed to load Config")
	}

	// Reload logger if production mode is set.
	if cfg.LoggerMode == "production" {
		logger.SetupLogger("production")
		logger.Logger.Info().Msg("Production logger initialized")
	}

	logger.Logger.Info().Msg("Configuration loaded successfully")

	// Print banner.
	if !cfg.DisableBanner {
		banner.PrintBanner(cfg.Version)
	}

	// Delete old accounts directory (if present) and recreate.
	if err := directory.DeleteDir(cfg.AccountsDir); err != nil && !errors.Is(err, os.ErrNotExist) {
		logger.Logger.Fatal().Err(err).Msg("Failed to delete directory")
	}
	if err := directory.CreateDirIfNotExists(cfg.AccountsDir); err != nil {
		logger.Logger.Fatal().Err(err).Msg("Failed to create directory")
	}

	// Initialize MiMC sponge.
	mimcspongeInstance, err := mimcsponge.NewMiMCSponge(mimcsponge.Seed, mimcsponge.MimcNbRounds)
	if err != nil {
		logger.Logger.Fatal().Err(err).Msg("Failed to initialize MiMC Sponge")
	}

	base := cfg.AccountsDir

	// Foodbank accounts.
	foodbanksFilename := "foodBanks"
	foodbanksPath := filepath.Join(base, fmt.Sprintf("%s.json", foodbanksFilename))

	foodbanks := accounts.NewAccounts(foodbanksFilename)
	foodbanks.SetMiMC(mimcspongeInstance) // Set MiMC for hashing addresses.
	foodbanks.CreateAccounts(cfg.AccountsNumber)
	foodbanks.SaveToFile(foodbanksPath)

	// Find the private key and unlock it.
	keyfile, err := ethutil.FindPrivateKey(cfg.GethNodeKeystore)
	if err != nil {
		logger.Logger.Fatal().Err(err).Msg("Failed to find private key in keystore")
	}

	privateKey, err := ethutil.DecryptKeyfile(keyfile, cfg.GethNodePassword)
	if err != nil {
		logger.Logger.Fatal().Err(err).Msg("Failed to decrypt private key in keystore")
	}

	// Initialize Addresses struct.
	contractAddresses := addresses.NewAddresses()

	// Create a context with timeout.
	ctx, cancel := context.WithTimeout(context.Background(), 120*time.Second)
	defer cancel()

	client, chainId, err := ethutil.NewEthClient(ctx, cfg.GethNodeUrl)
	if err != nil {
		logger.Logger.Fatal().Err(err).Msg("Failed to connect to Ethereum node")
	}
	ethclient := client.EthClient
	defer client.Close()

	// Create a new transactor.
	trOpts, err := ethutil.NewTransactorFromKeystore(privateKey, chainId)
	if err != nil {
		logger.Logger.Fatal().Err(err).Msg("Failed to create a new transactor")
	}
	trOpts.Context = ctx
	trOpts.Nonce = nil

	// Gas configuration tuned for Geth dev chain block limits; suitable for GoQuorum test deployments as well.
	trOpts.GasLimit = 11_000_000
	// Give the tx a small but non-zero tip and fee cap.
	trOpts.GasTipCap = big.NewInt(1_000_000_000) // 1 gwei tip
	trOpts.GasFeeCap = big.NewInt(2_000_000_000) // 2 gwei max fee

	// Deploy Mimc.
	mimcAddress, txMimc, _, err := mimc.DeployMimc(trOpts, ethclient)
	if err != nil {
		logger.Logger.Fatal().Err(err).Str("contract", "Mimc").Msg("Failed to deploy contract")
	}
	if _, err := bind.WaitMined(ctx, ethclient, txMimc); err != nil {
		logger.Logger.Fatal().Err(err).Str("contract", "Mimc").Msg("Failed to mine tx")
	}

	logger.Logger.Info().Str("address", mimcAddress.Hex()).Msg("Mimc")

	// Check code size at Mimc address.
	mimcCode, err := ethclient.CodeAt(ctx, mimcAddress, nil)
	if err != nil {
		logger.Logger.Fatal().Err(err).Msg("Failed to read contract code for Mimc")
	}
	logger.Logger.Info().
		Int("MimcCodeBytes", len(mimcCode)).
		Msg("Code size at Mimc address")

	contractAddresses.AddContract("mimc", mimcAddress)

	// Deploy Verifier.
	verifierAddress, txVerifier, _, err := verifier.DeployVerifier(trOpts, ethclient)
	if err != nil {
		logger.Logger.Fatal().Err(err).Str("contract", "Verifier").Msg("Failed to deploy contract")
	}
	if _, err := bind.WaitMined(ctx, ethclient, txVerifier); err != nil {
		logger.Logger.Fatal().Err(err).Str("contract", "Verifier").Msg("Failed to mine tx")
	}

	logger.Logger.Info().Str("address", verifierAddress.Hex()).Msg("Verifier")

	// Check code size at Verifier address.
	verifierCode, err := ethclient.CodeAt(ctx, verifierAddress, nil)
	if err != nil {
		logger.Logger.Fatal().Err(err).Msg("Failed to read contract code for Verifier")
	}
	logger.Logger.Info().
		Int("VerifierCodeBytes", len(verifierCode)).
		Msg("Code size at Verifier address")

	contractAddresses.AddContract("verifier", verifierAddress)

	// Extract and log foodbank addresses.
	rawFB := foodbanks.ExtractAddresses()
	logger.Logger.Info().
		Int("foodbankAddressCount", len(rawFB)).
		Msg("Extracted foodbank addresses (including nil)")

	fb := derefAddresses(rawFB)
	logger.Logger.Info().
		Int("foodbankNonNilCount", len(fb)).
		Msg("Foodbank addresses (non-nil) used for zkLogin")

	// Deploy zkLogin.
	zkLoginAddress, txZkLogin, _, err := zklogin.DeployZklogin(
		trOpts,
		ethclient,
		2,
		[]uint32{1, 1},
		[]uint32{32, 32},
		mimcAddress,
		verifierAddress,
		fb,
	)
	if err != nil {
		logger.Logger.Fatal().Err(err).Str("contract", "ZkLogin").Msg("Failed to deploy contract")
	}

	// Wait for mining and inspect receipt.
	receipt, err := bind.WaitMined(ctx, ethclient, txZkLogin)
	if err != nil {
		logger.Logger.Fatal().Err(err).Str("contract", "ZkLogin").Msg("Failed to mine tx")
	}

	// Log gas used and receipt status for zkLogin deployment.
	logger.Logger.Info().
		Str("contract", "ZkLogin").
		Str("txHash", txZkLogin.Hash().Hex()).
		Uint64("status", receipt.Status).
		Uint64("gasUsed", receipt.GasUsed).
		Msg("ZkLogin deployment receipt")

	logger.Logger.Info().Str("address", zkLoginAddress.Hex()).Msg("ZkLogin")

	// Check code size at zkLogin address.
	zkLoginCode, err := ethclient.CodeAt(ctx, zkLoginAddress, nil)
	if err != nil {
		logger.Logger.Fatal().Err(err).Msg("Failed to read contract code for zkLogin")
	}
	logger.Logger.Info().
		Int("ZkLoginCodeBytes", len(zkLoginCode)).
		Msg("Code size at zkLogin address")

	contractAddresses.AddContract("zklogin", zkLoginAddress)

	// Write the contract addresses to file.
	addressesPath := filepath.Join(cfg.AddressesDir, "addresses.json")
	contractAddresses.SaveToFile(addressesPath)

	logger.Logger.Info().Msg("Deployer finished successfully")
}

func derefAddresses(ptrs []*common.Address) []common.Address {
	addrs := make([]common.Address, 0, len(ptrs))
	for _, ptr := range ptrs {
		if ptr != nil {
			addrs = append(addrs, *ptr)
		}
	}
	return addrs
}
