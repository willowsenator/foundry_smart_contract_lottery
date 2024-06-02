-include .env
.PHONY: all test deploy

help:
	@echo "Usage:"
	@echo "  make deploy [ARGS=...]"

build:; forge build

install:; forge install Cyfrin/foundry-devops@0.2.0 --no-commit && forge install transmissions11/solmate@v6 --no-commit &&  forge install foundry-rs/forge-std@v1.8.0 --no-commit && forge install smartcontractkit/chainlink-brownie-contracts@1.1.1 --no-commit

test:; forge test

NETWORK_ARGS := --rpc-url http://127.0.0.1:8545 --account anvilkey --broadcast

# if --network sepolia is used, then use sepolia stuff, otherwise use the anvil stuff
ifeq ($(findstring --network sepolia,$(ARGS)),--network sepolia)
	NETWORK_ARGS := --rpc-url $(SEPOLIA_RPC_URL) --account sepoliakey --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
endif

deploy:
	@forge script script/DeployRaffle.s.sol:DeployRaffle $(NETWORK_ARGS)