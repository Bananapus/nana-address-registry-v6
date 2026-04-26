// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {stdJson} from "forge-std/Script.sol";
import {Vm} from "forge-std/Vm.sol";

import {IJBAddressRegistry} from "../../src/interfaces/IJBAddressRegistry.sol";

struct AddressRegistryDeployment {
    IJBAddressRegistry registry;
}

library AddressRegistryDeploymentLib {
    // Cheat code address, 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D.
    // forge-lint: disable-next-line(screaming-snake-case-const)
    address internal constant VM_ADDRESS = address(uint160(uint256(keccak256("hevm cheat code"))));
    // forge-lint: disable-next-line(screaming-snake-case-const)
    Vm internal constant vm = Vm(VM_ADDRESS);

    function getDeployment(string memory path) internal view returns (AddressRegistryDeployment memory deployment) {
        return getDeployment({path: path, networkName: _networkNameForChainId(block.chainid)});
    }

    /// @dev Returns the Sphinx network name for a given chain ID without deploying SphinxConstants.
    function _networkNameForChainId(uint256 chainId) internal pure returns (string memory) {
        if (chainId == 1) return "ethereum";
        if (chainId == 10) return "optimism";
        if (chainId == 8453) return "base";
        if (chainId == 42_161) return "arbitrum";
        if (chainId == 11_155_111) return "ethereum_sepolia";
        if (chainId == 11_155_420) return "optimism_sepolia";
        if (chainId == 84_532) return "base_sepolia";
        if (chainId == 421_614) return "arbitrum_sepolia";
        revert("ChainID is not (currently) supported by Sphinx.");
    }

    function getDeployment(
        string memory path,
        string memory networkName
    )
        internal
        view
        returns (AddressRegistryDeployment memory deployment)
    {
        deployment.registry = IJBAddressRegistry(
            _getDeploymentAddress({
                path: path,
                projectName: "nana-address-registry-v6",
                networkName: networkName,
                contractName: "JBAddressRegistry"
            })
        );
    }

    /// @notice Get the address of a contract that was deployed by the Deploy script.
    /// @dev Reverts if the contract was not found.
    /// @param path The path to the deployment file.
    /// @param contractName The name of the contract to get the address of.
    /// @return The address of the contract.
    function _getDeploymentAddress(
        string memory path,
        string memory projectName,
        string memory networkName,
        string memory contractName
    )
        internal
        view
        returns (address)
    {
        string memory deploymentJson =
        // forge-lint: disable-next-line(unsafe-cheatcode)
        vm.readFile(string.concat(path, projectName, "/", networkName, "/", contractName, ".json"));
        address deployed = stdJson.readAddress({json: deploymentJson, key: ".address"});
        require(deployed.code.length != 0, "AddressRegistryDeploymentLib: registry has no code");
        return deployed;
    }
}
