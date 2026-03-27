// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {JBAddressRegistry} from "src/JBAddressRegistry.sol";

contract Create2Launcher {
    function deploy(bytes32 salt) external returns (address deployed) {
        deployed = address(new JBAddressRegistry{salt: salt}());
    }
}

contract DeployScriptPredictionTest is Test {
    address internal constant DETERMINISTIC_DEPLOYMENT_PROXY = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    function test_scriptChecksWrongCreate2Address() external {
        Create2Launcher launcher = new Create2Launcher();
        bytes32 salt = bytes32("_JBAddressRegistryV6_");
        bytes32 initCodeHash = keccak256(type(JBAddressRegistry).creationCode);

        address predictedByScript = vm.computeCreate2Address(salt, initCodeHash, DETERMINISTIC_DEPLOYMENT_PROXY);
        address predictedByLauncher = vm.computeCreate2Address(salt, initCodeHash, address(launcher));

        address deployed = launcher.deploy(salt);

        assertEq(deployed, predictedByLauncher, "CREATE2 address is derived from the deploying contract");
        assertTrue(predictedByScript != deployed, "script assumes the wrong deployer when checking deployment");
        assertEq(predictedByScript.code.length, 0, "the script probes a different address");
    }
}
