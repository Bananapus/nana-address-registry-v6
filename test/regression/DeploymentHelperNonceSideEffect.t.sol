// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {
    AddressRegistryDeploymentLib,
    AddressRegistryDeployment
} from "../../script/helpers/AddressRegistryDeploymentLib.sol";

/// @notice Wrapper that exposes the library's chain-aware overload.
contract DeploymentLibAutoCaller {
    function getDeployment(string memory path) external returns (AddressRegistryDeployment memory) {
        return AddressRegistryDeploymentLib.getDeployment(path);
    }
}

/// @notice Verifies that auto-discovering the network name has an on-chain side effect.
contract DeploymentHelperNonceSideEffectTest is Test {
    DeploymentLibAutoCaller internal caller;

    function setUp() public {
        caller = new DeploymentLibAutoCaller();
    }

    function test_getDeployment_pathOverloadConsumesCallersCreateNonce() external {
        address registry = makeAddr("registryContract");
        vm.etch(registry, hex"6080604052");

        string memory json = string.concat('{"address":"', vm.toString(registry), '"}');
        string memory dir = "test/regression/tmp-nonce/nana-address-registry-v6/anvil/";
        string memory file = string.concat(dir, "JBAddressRegistry.json");

        vm.createDir(dir, true);
        vm.writeFile(file, json);

        uint64 nonceBefore = vm.getNonce(address(caller));

        caller.getDeployment("test/regression/tmp-nonce/");

        uint64 nonceAfter = vm.getNonce(address(caller));

        assertEq(nonceAfter, nonceBefore + 1, "library should deploy SphinxConstants and consume one CREATE nonce");

        vm.removeFile(file);
    }
}
