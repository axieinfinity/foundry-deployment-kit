import "hardhat-deploy";
import {
	HardhatUserConfig,
	NetworkUserConfig,
} from "hardhat/types";

const testnet: NetworkUserConfig = {
	chainId: 2021,
	url: "https://saigon-testnet.roninchain.com/rpc",
};

const mainnet: NetworkUserConfig = {
	chainId: 2020,
	url: "https://api.roninchain.com/rpc",
};

const config: HardhatUserConfig = {
	paths: {
		sources: "./src",
	},

	networks: {
		"ronin-testnet": testnet,
		"ronin-mainnet": mainnet,
	},
};

export default config;