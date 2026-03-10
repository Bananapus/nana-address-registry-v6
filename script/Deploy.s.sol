// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@sphinx-labs/contracts/contracts/foundry/SphinxPlugin.sol";
import {Script, stdJson, VmSafe} from "forge-std/Script.sol";

import "src/JBAddressRegistry.sol";

contract Deploy is Script, Sphinx {
    bytes32 constant ADDRESS_REGISTRY_SALT = "_JBAddressRegistryV6_";

    function configureSphinx() public override {
        // TODO: Update to contain JB Emergency Developers
        sphinxConfig.projectName = "nana-address-registry-v6";
        sphinxConfig.mainnets = ["ethereum", "optimism", "base", "arbitrum"];
        sphinxConfig.testnets = ["ethereum_sepolia", "optimism_sepolia", "base_sepolia", "arbitrum_sepolia"];
    }

    function run() public sphinx {
        // Only deploy if this bytecode is not already deployed.
        if (!_isDeployed(ADDRESS_REGISTRY_SALT, type(JBAddressRegistry).creationCode, "")) {
            new JBAddressRegistry{salt: ADDRESS_REGISTRY_SALT}();
        }
    }

    function _isDeployed(bytes32 salt, bytes memory creationCode, bytes memory arguments) internal view returns (bool) {
        address _deployedTo = vm.computeCreate2Address({
            salt: salt,
            initCodeHash: keccak256(abi.encodePacked(creationCode, arguments)),
            // Arachnid/deterministic-deployment-proxy address.
            deployer: address(0x4e59b44847b379578588920cA78FbF26c0B4956C)
        });

        // Return if code is already present at this address.
        return address(_deployedTo).code.length != 0;
    }
}
