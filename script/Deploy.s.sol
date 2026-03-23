// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Sphinx} from "@sphinx-labs/contracts/contracts/foundry/SphinxPlugin.sol";
import {Script} from "forge-std/Script.sol";

import {JBAddressRegistry} from "src/JBAddressRegistry.sol";

contract Deploy is Script, Sphinx {
    bytes32 constant ADDRESS_REGISTRY_SALT = "_JBAddressRegistryV6_";

    function configureSphinx() public override {
        // TODO: Update to contain JB Emergency Developers
        sphinxConfig.projectName = "nana-address-registry-v6";
        sphinxConfig.mainnets = ["ethereum", "optimism", "base", "arbitrum"];
        sphinxConfig.testnets = ["ethereum_sepolia", "optimism_sepolia", "base_sepolia", "arbitrum_sepolia"];
    }

    function run() public sphinx {
        new JBAddressRegistry{salt: ADDRESS_REGISTRY_SALT}();
    }
}
