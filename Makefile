-include .env

.PHONY: all test deploy

DEFAULT_PRIVATE_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

help:
	@echo "Usage: "
	@echo "make deploy "[ARGS=...]"

build:; forge build




#install:; forge install chainaccelorg/foundry-devops@0.0.11 --no-commit && 

test:; forge test

NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key $(DEFAULT_PRIVATE_KEY)  --broadcast

ifeq ($(findstring --network Arbitrum, $(ARGS)) ,--network Arbitrum)
#   部署到测试公网
	NETWORK_ARGS := --rpc-url $(Arbitrum_Sepolia) --private-key $(PRIVATE_KEY) --etherscan-api-key $(ETHERSCAN_API_KEY) --verify  --broadcast 
endif

#--rpc-url $(Arbitrum_Sepolia) --private-key $(PRIVATE_KEY) --broadcast 
deploy:; forge script script/DeployRaffle.s.sol:DeployRaffle $(NETWORK_ARGS)