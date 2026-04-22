// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {stdJson} from "forge-std/Script.sol";

import {
    AddressRegistryDeploymentLib,
    AddressRegistryDeployment
} from "../../script/helpers/AddressRegistryDeploymentLib.sol";

/// @notice Wrapper that makes the library's internal functions callable externally so vm.expectRevert works.
contract DeploymentLibCaller {
    function getDeployment(
        string memory path,
        string memory networkName
    )
        external
        returns (AddressRegistryDeployment memory)
    {
        return AddressRegistryDeploymentLib.getDeployment({path: path, networkName: networkName});
    }
}

/// @notice Tests M-40: Deployment helper rejects stale artifacts pointing to non-contract addresses.
contract DeploymentHelperValidationTest is Test {
    DeploymentLibCaller internal caller;

    function setUp() public {
        caller = new DeploymentLibCaller();
    }

    /// @notice Stale deployment artifact pointing to an EOA reverts.
    function test_deploymentHelper_revertsForEOARegistry() external {
        address eoa = makeAddr("staleEOA");
        string memory json = string.concat('{"address":"', vm.toString(eoa), '"}');

        string memory dir = "test/audit/tmp-eoa/nana-address-registry-v6/testnet/";
        vm.createDir(dir, true);
        vm.writeFile(string.concat(dir, "JBAddressRegistry.json"), json);

        vm.expectRevert("AddressRegistryDeploymentLib: registry has no code");
        caller.getDeployment({path: "test/audit/tmp-eoa/", networkName: "testnet"});

        vm.removeFile(string.concat(dir, "JBAddressRegistry.json"));
    }

    /// @notice Valid deployment artifact with a contract address is accepted.
    function test_deploymentHelper_acceptsContractRegistry() external {
        address registry = makeAddr("registryContract");
        vm.etch(registry, hex"6080604052");
        string memory json = string.concat('{"address":"', vm.toString(registry), '"}');

        string memory dir = "test/audit/tmp-contract/nana-address-registry-v6/testnet/";
        vm.createDir(dir, true);
        vm.writeFile(string.concat(dir, "JBAddressRegistry.json"), json);

        caller.getDeployment({path: "test/audit/tmp-contract/", networkName: "testnet"});

        vm.removeFile(string.concat(dir, "JBAddressRegistry.json"));
    }
}
