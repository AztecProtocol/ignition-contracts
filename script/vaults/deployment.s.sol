// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {Aztec} from "src/token-vaults/token/Aztec.sol";
import {ATPFactory, IRegistry, MilestoneId} from "src/token-vaults/ATPFactory.sol";
import {MilestoneStatus, LockParams, StakerVersion} from "src/token-vaults/Registry.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {Ownable2Step} from "@oz/access/Ownable2Step.sol";
import {Math} from "@oz/utils/math/Math.sol";
import {IMATP, IATPCore} from "src/token-vaults/atps/milestone/IMATP.sol";
import {ATPType} from "src/token-vaults/atps/base/IATP.sol";
import {RevokableParams, ILATP} from "src/token-vaults/atps/linear/ILATP.sol";
import {Bogus} from "./BogusToken.sol";
import {Strings} from "@oz/utils/Strings.sol";
import {IERC20Mintable} from "src/token-vaults/token/IERC20Mintable.sol";

interface IToken is IERC20Mintable, IERC20 {
    function transferOwnership(address newOwner) external;
    function acceptOwnership() external;
    function owner() external view returns (address);
    function pendingOwner() external view returns (address);
}

contract DeploymentScript is Test {
    // @note DO NOT CHANGE THE ORDER OF THE FIELDS HERE!
    struct MATPData {
        uint256 allocation;
        address beneficiary;
        MilestoneId milestoneId;
        string name;
    }

    // @note DO NOT CHANGE THE ORDER OF THE FIELDS HERE!
    struct UnconditionalLATPData {
        uint256 allocation;
        address beneficiary;
        string name;
    }

    // @note DO NOT CHANGE THE ORDER OF THE FIELDS HERE!
    struct CollectiveData {
        MATPData[] milestones;
        UnconditionalLATPData[] unconditional;
    }

    struct MATPDataChunk {
        address[] beneficiaries;
        uint256[] allocations;
        MilestoneId[] milestoneIds;
        string[] names;
        uint256 summedAllocation;
    }

    struct UnconditionalLATPDataChunk {
        address[] beneficiaries;
        uint256[] allocations;
        string[] names;
        uint256 summedAllocation;
    }

    uint256 internal constant UNLOCK_CLIFF_DURATION = 0; // 🤷
    uint256 internal constant UNLOCK_LOCK_DURATION = 60 * 60 * 24 * 365 * 4; // 🤷

    address internal constant DEPLOYER = 0x13620833364653fa125cCDD7Cf54b9e4A22AB6d9;
    address internal constant INITIAL_OWNER = 0x2E89fe2011FdB3eb6cFdBfb3A635Ec43bEd42b2A;
    bool internal constant USE_BOGUS = false;

    address internal constant COINBASE_MPC = 0x13620833364653fa125cCDD7Cf54b9e4A22AB6d9;

    address internal constant AZTEC_TOKEN_OWNER = COINBASE_MPC;
    address internal constant ATP_FACTORY_OWNER = COINBASE_MPC;
    address internal constant REGISTRY_OWNER = COINBASE_MPC;

    uint256 internal constant MILESTONE_COUNT = 2;
    uint256 internal constant CHUNK_SIZE = 8;

    IToken internal token;
    ATPFactory internal atpFactory;
    IRegistry internal registry;

    mapping(uint256 => address) internal matpAddresses;
    mapping(uint256 => address) internal latpAddresses;

    function getInitCodeHash() public {
        // With this you can then get a salt for create2 using
        // cast create2 --init-code-hash <INIT_CODE_HASH> --starts-with 0xA27EC
        bytes memory creationCode = type(Aztec).creationCode;
        // emit log_named_bytes("creationCode", creationCode);

        // ABI-encode the constructor args
        bytes memory encodedArgs = abi.encode(INITIAL_OWNER);

        // Concatenate code + args
        bytes memory initCode = bytes.concat(creationCode, encodedArgs);

        // Compute keccak256
        bytes32 initCodeHash = keccak256(initCode);
        emit log_named_bytes32("initCodeHash", initCodeHash);
    }

    function deployToken() public {
        vm.startBroadcast();
        if (USE_BOGUS) {
            token = IToken(address(new Bogus(INITIAL_OWNER)));
        } else {
            // The deployment is using the deterministic deployer so it can be deploayed by anyone
            // it just needs to use the correct salt and params to get the correct address.
            // This salt produces `0xA27EC0006e59f245217Ff08CD52A7E8b169E62D2`
            bytes32 salt = 0x66b1f68cbd8524cb3df79c2a67d0eb5b943311b0c7b55e2a295a4c1f689c87d6;
            token = IToken(address(new Aztec{salt: salt}(INITIAL_OWNER)));
        }
        vm.stopBroadcast();

        emit log_named_address("Token", address(token));
    }

    function deployTokenAndTransferOwnership(address _owner) public {
        deployToken();
        vm.startBroadcast(INITIAL_OWNER);
        token.transferOwnership(_owner);
        vm.stopBroadcast();

        emit log_named_address("Token              ", address(token));
        emit log_named_address("Token Owner        ", token.owner());
        emit log_named_address("Token Pending Owner", token.pendingOwner());
    }

    function taskForJoe() public {
        // The task for Joe wanting to try full flow using a coinbase wallet.
        run();
        emit log("");
        emit log("");
        checkStatus(address(atpFactory));

        emit log("");
        emit log("");
        emit log("/* -------------------------------------------------------------------------- */");
        emit log("/*                                JOE START                                  */");
        emit log("/* -------------------------------------------------------------------------- */");
        emit log("");

        uint256 executeAllowedAt = registry.getExecuteAllowedAt();
        uint256 unlockStartTime = registry.getUnlockStartTime();
        address implementation = registry.getStakerImplementation(StakerVersion.wrap(0));

        // Accept ownership
        emit log("Accepting Ownership");
        {
            bytes memory cData = abi.encodeCall(Ownable2Step.acceptOwnership, ());

            emit log_named_bytes(string.concat("Token        ", Strings.toHexString(address(token))), cData);
            emit log_named_bytes(string.concat("ATP Factory  ", Strings.toHexString(address(atpFactory))), cData);
            emit log_named_bytes(string.concat("Registry     ", Strings.toHexString(address(registry))), cData);

            vm.startBroadcast(COINBASE_MPC);
            address(token).call(cData);
            address(atpFactory).call(cData);
            address(registry).call(cData);
            vm.stopBroadcast();
        }

        emit log("Setting Execute Allowed At");
        {
            bytes memory cData = abi.encodeCall(IRegistry.setExecuteAllowedAt, (executeAllowedAt - 1));

            emit log_named_bytes(string.concat("Registry     ", Strings.toHexString(address(registry))), cData);

            vm.startBroadcast(COINBASE_MPC);
            address(registry).call(cData);
            vm.stopBroadcast();
        }

        emit log("Setting Unlock Start Time");
        {
            bytes memory cData = abi.encodeCall(IRegistry.setUnlockStartTime, (unlockStartTime - 1));

            emit log_named_bytes(string.concat("Registry     ", Strings.toHexString(address(registry))), cData);

            vm.startBroadcast(COINBASE_MPC);
            address(registry).call(cData);
            vm.stopBroadcast();
        }

        emit log("Registering Staker Implementation");
        {
            bytes memory cData = abi.encodeCall(IRegistry.registerStakerImplementation, (implementation));

            emit log_named_bytes(string.concat("Registry     ", Strings.toHexString(address(registry))), cData);
            vm.startBroadcast(COINBASE_MPC);
            address(registry).call(cData);
            vm.stopBroadcast();
        }

        emit log("Setting Revoker");
        {
            bytes memory cData = abi.encodeCall(IRegistry.setRevoker, (COINBASE_MPC));

            emit log_named_bytes(string.concat("Registry     ", Strings.toHexString(address(registry))), cData);
            vm.startBroadcast(COINBASE_MPC);
            address(registry).call(cData);
            vm.stopBroadcast();
        }

        emit log("Setting Revoker Operator");
        {
            bytes memory cData = abi.encodeCall(IRegistry.setRevokerOperator, (COINBASE_MPC));

            emit log_named_bytes(string.concat("Registry     ", Strings.toHexString(address(registry))), cData);
            vm.startBroadcast(COINBASE_MPC);
            address(registry).call(cData);
            vm.stopBroadcast();
        }

        emit log("Setting Milestone Status");
        {
            bytes memory cData =
                abi.encodeCall(IRegistry.setMilestoneStatus, (MilestoneId.wrap(0), MilestoneStatus.Failed));

            emit log_named_bytes(string.concat("Registry     ", Strings.toHexString(address(registry))), cData);
            vm.startBroadcast(COINBASE_MPC);
            address(registry).call(cData);
            vm.stopBroadcast();
        }

        emit log("Revoking MATP");
        {
            bytes memory cData = abi.encodeCall(IATPCore.revoke, ());

            emit log_named_bytes(string.concat("MATP         ", Strings.toHexString(address(matpAddresses[1]))), cData);
            vm.startBroadcast(COINBASE_MPC);
            address(matpAddresses[1]).call(cData);
            vm.stopBroadcast();
        }

        assertEq(token.owner(), COINBASE_MPC);
        assertEq(atpFactory.owner(), COINBASE_MPC);
        assertEq(Ownable2Step(address(registry)).owner(), COINBASE_MPC);

        emit log("");
        emit log("/* -------------------------------------------------------------------------- */");
        emit log("/*                                JOE END                                    */");
        emit log("/* -------------------------------------------------------------------------- */");
        emit log("");
        emit log("");
        checkStatus(address(atpFactory));
    }

    function checkStatus(address _atpFactory) public {
        ATPFactory factory = ATPFactory(_atpFactory);
        IRegistry reg = factory.getRegistry();

        emit log("/* -------------------------------------------------------------------------- */");
        emit log("/*                                STATUS CHECKS                               */");
        emit log("/* -------------------------------------------------------------------------- */");
        emit log("");

        emit log(string.concat("/* ---------- REGISTRY(", Strings.toHexString(address(reg)), ") ---------- */"));
        emit log_named_address("Revoker               ", reg.getRevoker());
        emit log_named_address("Revoker Operator      ", reg.getRevokerOperator());
        emit log_named_uint("Execute Allowed At    ", reg.getExecuteAllowedAt());

        LockParams memory lockParams = reg.getGlobalLockParams();
        emit log_named_uint("Global Unlock Start   ", lockParams.startTime);
        emit log_named_uint("Global Unlock Cliff   ", lockParams.cliffDuration);
        emit log_named_uint("Global Unlock Duration", lockParams.lockDuration);

        emit log("Milestones:");
        uint256 milestoneCount = MilestoneId.unwrap(reg.getNextMilestoneId());
        for (uint96 i = 0; i < milestoneCount; i++) {
            MilestoneStatus s = reg.getMilestoneStatus(MilestoneId.wrap(i));
            string memory statusString = milestoneStatusToString(s);
            string memory outputString = string.concat("\tMilestone ", Strings.toString(i), " Status: ", statusString);
            emit log(outputString);
        }

        emit log("Implementations");
        uint256 implementationCount = StakerVersion.unwrap(reg.getNextStakerVersion());
        for (uint256 i = 0; i < implementationCount; i++) {
            address implementation = reg.getStakerImplementation(StakerVersion.wrap(i));
            emit log_named_address(string.concat("\tImplementation ", Strings.toString(i)), implementation);
        }

        (MATPDataChunk[] memory milestoneDataChunks, UnconditionalLATPDataChunk[] memory unconditionalDataChunks) =
            loadData();

        emit log("");
        emit log("/* ------------------------------MATPs-------------------------------------------- */");
        for (uint256 i = 0; i < milestoneDataChunks.length; i++) {
            // As each chunk is to be deployed, we log the data to the console
            MATPDataChunk memory chunk = milestoneDataChunks[i];

            for (uint256 j = 0; j < chunk.beneficiaries.length; j++) {
                address predictedAddress =
                    factory.predictMATPAddress(chunk.beneficiaries[j], chunk.allocations[j], chunk.milestoneIds[j]);

                IMATP atp = IMATP(predictedAddress);

                string memory s = string.concat(
                    "MATP(",
                    chunk.names[j],
                    ", ",
                    Strings.toChecksumHexString(chunk.beneficiaries[j]),
                    ", ",
                    Strings.toString(chunk.allocations[j]),
                    ", ",
                    Strings.toString(MilestoneId.unwrap(chunk.milestoneIds[j])),
                    ")"
                );

                if (atp.getBeneficiary() != chunk.beneficiaries[j]) {
                    emit log_named_address(string.concat(s, " revoked at"), predictedAddress);
                } else {
                    emit log_named_address(string.concat(s, " active at"), predictedAddress);
                }
            }
        }

        emit log("");
        emit log("/* ------------------------------LATPs-------------------------------------------- */");
        for (uint256 i = 0; i < unconditionalDataChunks.length; i++) {
            // As each chunk is to be deployed, we log the data to the console
            UnconditionalLATPDataChunk memory chunk = unconditionalDataChunks[i];

            RevokableParams memory revokableParams;

            for (uint256 j = 0; j < chunk.beneficiaries.length; j++) {
                address predictedAddress =
                    factory.predictLATPAddress(chunk.beneficiaries[j], chunk.allocations[j], revokableParams);

                ILATP atp = ILATP(predictedAddress);

                string memory s = string.concat(
                    "LATP(",
                    chunk.names[j],
                    ", ",
                    Strings.toChecksumHexString(chunk.beneficiaries[j]),
                    ", ",
                    Strings.toString(chunk.allocations[j]),
                    ")"
                );

                if (atp.getBeneficiary() != chunk.beneficiaries[j]) {
                    emit log_named_address(string.concat(s, " revoked at"), predictedAddress);
                } else {
                    emit log_named_address(string.concat(s, " active at"), predictedAddress);
                }
            }
        }
    }

    function run() public {
        /* -------------------------------------------------------------------------- */
        /*                               DEPLOY CONTRACTS                             */
        /* -------------------------------------------------------------------------- */
        deployToken();

        vm.startBroadcast(DEPLOYER);
        atpFactory = new ATPFactory(DEPLOYER, IERC20(address(token)), UNLOCK_CLIFF_DURATION, UNLOCK_LOCK_DURATION);
        vm.stopBroadcast();

        registry = atpFactory.getRegistry();

        emit log_named_address("Token          ", address(token));
        emit log_named_address("ATP Factory    ", address(atpFactory));
        emit log_named_address("Registry       ", address(registry));

        assertEq(token.owner(), DEPLOYER);
        assertEq(atpFactory.owner(), DEPLOYER);
        assertEq(Ownable2Step(address(registry)).owner(), DEPLOYER);

        /* -------------------------------------------------------------------------- */
        /*                        INITIATE OWNERSHIP TRANSFERS                        */
        /* -------------------------------------------------------------------------- */

        vm.startBroadcast(DEPLOYER);
        token.transferOwnership(AZTEC_TOKEN_OWNER);
        atpFactory.transferOwnership(ATP_FACTORY_OWNER);
        Ownable2Step(address(registry)).transferOwnership(REGISTRY_OWNER);
        vm.stopBroadcast();

        /* -------------------------------------------------------------------------- */
        /*                        CHECKING PENDING OWNERS                             */
        /* -------------------------------------------------------------------------- */
        assertEq(token.pendingOwner(), AZTEC_TOKEN_OWNER);
        assertEq(atpFactory.pendingOwner(), ATP_FACTORY_OWNER);
        assertEq(Ownable2Step(address(registry)).pendingOwner(), REGISTRY_OWNER);

        /* -------------------------------------------------------------------------- */
        /*                           CREATE MILESTONES                                */
        /* -------------------------------------------------------------------------- */

        for (uint256 i = MilestoneId.unwrap(registry.getNextMilestoneId()); i < MILESTONE_COUNT; i++) {
            vm.startBroadcast(DEPLOYER);
            registry.addMilestone();
            vm.stopBroadcast();
        }

        /* -------------------------------------------------------------------------- */
        /*                                LOAD DATA                                   */
        /* -------------------------------------------------------------------------- */

        (MATPDataChunk[] memory milestoneDataChunks, UnconditionalLATPDataChunk[] memory unconditionalDataChunks) =
            loadData();

        uint256 totalAllocations = 0;

        /* -------------------------------------------------------------------------- */
        /*                             CREATE MATP'S                                  */
        /* -------------------------------------------------------------------------- */

        uint256 matpCount = 0;

        for (uint256 i = 0; i < milestoneDataChunks.length; i++) {
            // As each chunk is to be deployed, we log the data to the console
            MATPDataChunk memory chunk = milestoneDataChunks[i];
            logMATPDataChunk(chunk);
            totalAllocations += chunk.summedAllocation;
            vm.startBroadcast(DEPLOYER);
            token.mint(address(atpFactory), chunk.summedAllocation);
            IMATP[] memory chunkAtps = atpFactory.createMATPs({
                _beneficiaries: chunk.beneficiaries,
                _allocations: chunk.allocations,
                _milestoneIds: chunk.milestoneIds
            });
            vm.stopBroadcast();
            assertEq(token.balanceOf(address(atpFactory)), 0);

            for (uint256 j = 0; j < chunkAtps.length; j++) {
                matpAddresses[matpCount] = address(chunkAtps[j]);
                matpCount++;
            }
        }

        /* -------------------------------------------------------------------------- */
        /*                            VALIDATE MATP'S                                 */
        /* -------------------------------------------------------------------------- */

        for (uint256 i = 0; i < milestoneDataChunks.length; i++) {
            MATPDataChunk memory chunk = milestoneDataChunks[i];

            for (uint256 j = 0; j < chunk.beneficiaries.length; j++) {
                IMATP atp = IMATP(matpAddresses[i * CHUNK_SIZE + j]);
                assertEq(atp.getBeneficiary(), chunk.beneficiaries[j]);
                assertEq(atp.getAllocation(), chunk.allocations[j]);
                assertEq(MilestoneId.unwrap(atp.getMilestoneId()), MilestoneId.unwrap(chunk.milestoneIds[j]));
                assertEq(token.balanceOf(address(atp)), chunk.allocations[j]);
                assertTrue(atp.getType() == ATPType.Milestone);
            }
        }

        /* -------------------------------------------------------------------------- */
        /*                       CREATE UNCONDITIONAL LATP'S                        */
        /* -------------------------------------------------------------------------- */

        uint256 latpCount = 0;

        for (uint256 i = 0; i < unconditionalDataChunks.length; i++) {
            // As each chunk is to be deployed, we log the data to the console
            UnconditionalLATPDataChunk memory chunk = unconditionalDataChunks[i];
            RevokableParams[] memory revokableParams = new RevokableParams[](chunk.beneficiaries.length);
            logUnconditionalLATPDataChunk(chunk);
            totalAllocations += chunk.summedAllocation;
            vm.startBroadcast(DEPLOYER);
            token.mint(address(atpFactory), chunk.summedAllocation);
            ILATP[] memory chunkAtps = atpFactory.createLATPs({
                _beneficiaries: chunk.beneficiaries,
                _allocations: chunk.allocations,
                _revokableParams: revokableParams
            });
            vm.stopBroadcast();
            assertEq(token.balanceOf(address(atpFactory)), 0);

            for (uint256 j = 0; j < chunkAtps.length; j++) {
                latpAddresses[latpCount] = address(chunkAtps[j]);
                latpCount++;
            }
        }

        /* -------------------------------------------------------------------------- */
        /*                            VALIDATE LATP'S                                 */
        /* -------------------------------------------------------------------------- */

        for (uint256 i = 0; i < unconditionalDataChunks.length; i++) {
            UnconditionalLATPDataChunk memory chunk = unconditionalDataChunks[i];

            for (uint256 j = 0; j < chunk.beneficiaries.length; j++) {
                ILATP atp = ILATP(latpAddresses[i * CHUNK_SIZE + j]);
                assertEq(atp.getBeneficiary(), chunk.beneficiaries[j]);
                assertEq(atp.getAllocation(), chunk.allocations[j]);
                assertEq(token.balanceOf(address(atp)), chunk.allocations[j]);
                assertTrue(atp.getType() == ATPType.Linear);
            }
        }

        emit log("Stats");
        emit log_named_uint("MATP Chunks      ", milestoneDataChunks.length);
        emit log_named_uint("Deployed MATPs   ", matpCount);
        emit log_named_uint("LATP Chunks      ", unconditionalDataChunks.length);
        emit log_named_uint("Deployed LATPs   ", latpCount);
        emit log_named_uint("Total ATPs       ", matpCount + latpCount);
        emit log_named_decimal_uint("Total Allocations", totalAllocations, 18);
    }

    function logMATPDataChunk(MATPDataChunk memory _dataChunk) internal {
        emit log("MATPDataChunk");
        for (uint256 i = 0; i < _dataChunk.beneficiaries.length; i++) {
            emit log_named_string("\tName", _dataChunk.names[i]);
            emit log_named_address("\t\tBeneficiary", _dataChunk.beneficiaries[i]);
            emit log_named_decimal_uint("\t\tAllocation", _dataChunk.allocations[i], 18);
            emit log_named_uint("\t\tMilestoneId", MilestoneId.unwrap(_dataChunk.milestoneIds[i]));
        }
    }

    function logUnconditionalLATPDataChunk(UnconditionalLATPDataChunk memory _dataChunk) internal {
        emit log("UnconditionalLATPDataChunk");
        for (uint256 i = 0; i < _dataChunk.beneficiaries.length; i++) {
            emit log_named_string("\tName", _dataChunk.names[i]);
            emit log_named_address("\t\tBeneficiary", _dataChunk.beneficiaries[i]);
            emit log_named_decimal_uint("\t\tAllocation", _dataChunk.allocations[i], 18);
        }
    }

    function loadData() internal view returns (MATPDataChunk[] memory, UnconditionalLATPDataChunk[] memory) {
        string memory path = string.concat(vm.projectRoot(), "/python/generated_data.json");
        string memory json = vm.readFile(path);
        bytes memory jsonBytes = vm.parseJson(json);
        CollectiveData memory data = abi.decode(jsonBytes, (CollectiveData));

        return (chunkMatpData(data.milestones), chunkUnconditionalLatpData(data.unconditional));
    }

    function chunkMatpData(MATPData[] memory _data) internal view returns (MATPDataChunk[] memory _dataChunks) {
        uint256 chunkCount = _data.length / CHUNK_SIZE + (_data.length % CHUNK_SIZE > 0 ? 1 : 0);

        _dataChunks = new MATPDataChunk[](chunkCount);

        for (uint256 i = 0; i < _dataChunks.length; i++) {
            uint256 offset = i * CHUNK_SIZE;
            uint256 left = Math.min(CHUNK_SIZE, _data.length - offset);

            _dataChunks[i] = MATPDataChunk({
                beneficiaries: new address[](left),
                allocations: new uint256[](left),
                milestoneIds: new MilestoneId[](left),
                names: new string[](left),
                summedAllocation: 0
            });

            for (uint256 j = 0; j < left; j++) {
                MATPData memory matpData = _data[offset + j];
                _dataChunks[i].beneficiaries[j] = matpData.beneficiary;
                _dataChunks[i].allocations[j] = matpData.allocation;
                _dataChunks[i].milestoneIds[j] = matpData.milestoneId;
                _dataChunks[i].summedAllocation += matpData.allocation;

                _dataChunks[i].names[j] = matpData.name;
            }
        }
    }

    function chunkUnconditionalLatpData(UnconditionalLATPData[] memory _data)
        internal
        view
        returns (UnconditionalLATPDataChunk[] memory _dataChunks)
    {
        uint256 chunkCount = _data.length / CHUNK_SIZE + (_data.length % CHUNK_SIZE > 0 ? 1 : 0);

        _dataChunks = new UnconditionalLATPDataChunk[](chunkCount);

        for (uint256 i = 0; i < _dataChunks.length; i++) {
            uint256 offset = i * CHUNK_SIZE;
            uint256 left = Math.min(CHUNK_SIZE, _data.length - offset);

            _dataChunks[i] = UnconditionalLATPDataChunk({
                beneficiaries: new address[](left),
                allocations: new uint256[](left),
                names: new string[](left),
                summedAllocation: 0
            });

            for (uint256 j = 0; j < left; j++) {
                UnconditionalLATPData memory latpData = _data[offset + j];
                _dataChunks[i].beneficiaries[j] = latpData.beneficiary;
                _dataChunks[i].allocations[j] = latpData.allocation;
                _dataChunks[i].summedAllocation += latpData.allocation;

                _dataChunks[i].names[j] = latpData.name;
            }
        }
    }

    function milestoneStatusToString(MilestoneStatus _status) internal pure returns (string memory) {
        string memory statusString;
        if (_status == MilestoneStatus.Pending) {
            statusString = "Pending";
        } else if (_status == MilestoneStatus.Failed) {
            statusString = "Failed";
        } else if (_status == MilestoneStatus.Succeeded) {
            statusString = "Succeeded";
        }
        return statusString;
    }
}
