-include .env

clean:; forge clean
deploy localhost:; forge script script/DeployRaffle.sol --rpc-url http://127.0.0.1:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast --verify $(EHTHERSCAN_API_KEY)
deploy sepolia:; forge script script/DeployRaffle.sol --rpc-url $(TESTNET_URL) --private-key $(TESTNET_PRIVATE_KEY) --broadcast --verify $(EHTHERSCAN_API_KEY)