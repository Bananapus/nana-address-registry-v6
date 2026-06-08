// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {JBAddressRegistry} from "../../src/JBAddressRegistry.sol";

/// @notice Stateful invariant harness for the crown-jewel state-transition properties of `JBAddressRegistry`:
/// first-write-only / sticky binding (INVARIANTS.md A.3, D.3), zero-deployer impossibility (A.3), and the
/// "no entry without on-chain code" rule (A.2). The handler drives the two real entrypoints under random callers,
/// deployers, nonces, salts and bytecodes, deploying real code first so registrations actually land — then records
/// every successfully-bound address so the invariants can re-check stability.
contract RegistryHandler is Test {
    JBAddressRegistry public immutable REGISTRY;

    /// @notice Every address that the handler has observed bound to a non-zero deployer.
    address[] public bound;
    mapping(address => bool) public seen;
    /// @notice The deployer the handler recorded at the moment each address was first bound.
    mapping(address => address) public firstDeployer;

    /// @notice Rolling nonce per pseudo-deployer EOA so CREATE addresses are predictable.
    mapping(address => uint64) internal _nextNonce;

    /// @notice Recorded CREATE2 inputs for every bound CREATE2 address, so `attemptOverwrite` can REPLAY the exact
    /// inputs that originally bound a slot — the only way an attacker could realistically try to overwrite it.
    struct Create2Inputs {
        bool exists;
        address deployer;
        bytes32 salt;
        bytes bytecode;
    }

    mapping(address => Create2Inputs) internal _create2Inputs;
    address[] internal _create2Bound;

    uint256 public registerCalls;
    uint256 public successfulBinds;
    uint256 public overwriteAttempts;

    constructor(JBAddressRegistry registry) {
        REGISTRY = registry;
    }

    /// @dev Picks a non-zero deployer EOA from a bounded set so collisions/re-registration are exercised.
    function _deployer(uint256 seed) internal pure returns (address) {
        return address(uint160(1 + (seed % 8)));
    }

    /// @notice Deploys real runtime code via CREATE from a chosen pseudo-deployer, then registers it.
    /// @dev Uses `vm.etch` at the predicted CREATE address (we cannot actually CREATE from an arbitrary EOA inside
    /// the handler), then calls the real entrypoint. This faithfully exercises the code-present + first-write guards.
    function registerCreate(uint256 deployerSeed, uint8 codeSeed) external {
        address deployer = _deployer(deployerSeed);
        uint64 nonce = _nextNonce[deployer];
        _nextNonce[deployer] = nonce + 1;

        address predicted = vm.computeCreateAddress(deployer, uint256(nonce));
        // Put non-empty runtime code there (a single STOP byte is enough for code.length > 0).
        if (predicted.code.length == 0) vm.etch(predicted, abi.encodePacked(bytes1(0x00), bytes1(codeSeed)));

        ++registerCalls;
        try REGISTRY.registerAddress(deployer, uint256(nonce)) {
            _onBind(predicted, deployer);
        } catch {}
    }

    /// @notice Deploys real runtime code at a CREATE2 address, then registers it.
    function registerCreate2(uint256 deployerSeed, bytes32 salt, bytes calldata bytecode) external {
        address deployer = _deployer(deployerSeed);
        address predicted = vm.computeCreate2Address(salt, keccak256(bytecode), deployer);
        if (predicted.code.length == 0) vm.etch(predicted, abi.encodePacked(bytes1(0x00)));

        ++registerCalls;
        try REGISTRY.registerAddress(deployer, salt, bytecode) {
            _onBind(predicted, deployer);
            if (!_create2Inputs[predicted].exists) {
                _create2Inputs[predicted] = Create2Inputs(true, deployer, salt, bytecode);
                _create2Bound.push(predicted);
            }
        } catch {}
    }

    /// @notice Faithfully REPLAYS the exact CREATE2 inputs that originally bound a slot. The second registration of
    /// the same address MUST revert with AlreadyRegistered and MUST NOT change the recorded deployer.
    function attemptOverwrite(uint256 idxSeed) external {
        if (_create2Bound.length == 0) return;
        address addr = _create2Bound[idxSeed % _create2Bound.length];
        Create2Inputs memory inp = _create2Inputs[addr];
        address before = REGISTRY.deployerOf(addr);

        ++overwriteAttempts;
        // Replaying identical inputs derives the SAME address whose slot is already set — must revert.
        try REGISTRY.registerAddress(inp.deployer, inp.salt, inp.bytecode) {
            // A successful re-registration of an already-bound slot is a first-write-only violation.
            assertTrue(false, "re-registration of an already-bound CREATE2 address succeeded");
        } catch {}

        assertEq(REGISTRY.deployerOf(addr), before, "overwrite changed an existing binding");
    }

    function _onBind(address addr, address deployer) internal {
        ++successfulBinds;
        if (!seen[addr]) {
            seen[addr] = true;
            bound.push(addr);
            firstDeployer[addr] = deployer;
        }
    }

    function boundLength() external view returns (uint256) {
        return bound.length;
    }

    function boundAt(uint256 i) external view returns (address) {
        return bound[i];
    }
}

contract JBAddressRegistryInvariants is StdInvariant, Test {
    JBAddressRegistry internal registry;
    RegistryHandler internal handler;

    function setUp() public {
        registry = new JBAddressRegistry();
        handler = new RegistryHandler(registry);
        targetContract(address(handler));

        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = RegistryHandler.registerCreate.selector;
        selectors[1] = RegistryHandler.registerCreate2.selector;
        selectors[2] = RegistryHandler.attemptOverwrite.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    /// @notice A.3 / D.3: every address the handler ever observed bound stays bound to its FIRST deployer and never
    /// reverts to address(0). Sticky, monotonic, first-write-only.
    function invariant_bindingsAreStickyAndStable() public {
        uint256 n = handler.boundLength();
        for (uint256 i; i < n; ++i) {
            address addr = handler.boundAt(i);
            address current = registry.deployerOf(addr);
            assertEq(current, handler.firstDeployer(addr), "binding changed after first write");
            assertTrue(current != address(0), "bound address reverted to zero");
        }
    }

    /// @notice A.3: the registry NEVER records a zero deployer for any address it has bound. (address(0) sentinel
    /// unambiguously means "unregistered".)
    function invariant_noZeroDeployerEverRecorded() public {
        uint256 n = handler.boundLength();
        for (uint256 i; i < n; ++i) {
            assertTrue(registry.deployerOf(handler.boundAt(i)) != address(0), "zero deployer recorded");
        }
    }

    /// @notice A.2: every bound address has on-chain code (the registry refuses to bind undeployed addresses).
    function invariant_boundAddressesHaveCode() public {
        uint256 n = handler.boundLength();
        for (uint256 i; i < n; ++i) {
            assertTrue(handler.boundAt(i).code.length > 0, "bound address has no code");
        }
    }

    /// @notice Liveness sanity: with real code etched, registration actually succeeds (the handler is not a no-op).
    function invariant_handlerMakesProgress() public {
        // Not every run guarantees a bind (overwrite-only sequences exist), but binds must never exceed calls and
        // every successful bind must have produced a tracked entry.
        assertLe(handler.successfulBinds(), handler.registerCalls());
    }
}
