// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/*###############################################################################

    @title GardenFactory Implementation for Diamond-1 Proxy
    @author BLOK Capital DAO

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import "../interfaces/IDiamondCut.sol";
import "../interfaces/IDiamondLoupe.sol";

library GardenFactoryStorageSlot {
    struct AddressSlot {
        address value;
    }

    struct Uint256Slot {
        uint256 value;
    }

    function getAddressSlot(
        bytes32 slot
    ) internal pure returns (AddressSlot storage pointer) {
        assembly {
            pointer.slot := slot
        }
    }

    function getUint256Slot(
        bytes32 slot
    ) internal pure returns (Uint256Slot storage pointer) {
        assembly {
            pointer.slot := slot
        }
    }
}

interface ERC1271 {
    function isValidSignature(
        bytes32 _hash,
        bytes calldata _signature
    ) external view returns (bytes4);
}

contract GardenFactory {
    struct GardenProxyParams {
        bytes bytecode;
        address deployer;
        address factory;
        address nft;
        uint256 gardenId;
        bytes32 hash;
        bytes signature;
        IDiamondCut.FacetCut[] facetCuts;
        address init;
        bytes initCalldata;
    }

    event VoteRecorded(address indexed _admin, bool inFavor);
    event GardenDeployed(
        address indexed deployer,
        address indexed contractAddress,
        uint256 id
    );
    event DeployerAuthorized(address indexed deployer);
    event DeployerRevoked(address indexed deployer);
    event VotesResetProcess(
        uint256 previousVoteCountInFavor,
        uint256 previousVoteCountAgainst,
        address[] adminsReset,
        uint256 timestamp
    );
    event ImplementationProposed(address indexed _implementation);

    // Proxy admins and factory storage
    address[] private admins;
    mapping(address => bool) private isAdmin;
    mapping(address => bool) public authorizedDeployers;
    mapping(address => uint256) public deployerId;
    mapping(address => bool) private upgradeVotes;
    mapping(address => bool) public voteInFavor;

    // Garden implementations and proxies
    mapping(address => mapping(uint256 => address)) public gardenProxyContracts;
    mapping(uint256 => address) public gardenImplementationMap;
    address[] public gardenImplementationList;

    // Storage slots
    bytes4 private constant MAGIC_VALUE = 0x1626ba7e;
    bytes32 private constant IMPLEMENTATION_SLOT =
        bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
    bytes32 private constant PROPOSED_IMPLEMENTATION_CONTRACT =
        bytes32(
            uint256(
                keccak256("eip1967.proxy.proposed.implementation.contract")
            ) - 1
        );
    bytes32 private constant GARDEN_COUNT =
        bytes32(uint256(keccak256("eip1967.proxy.garden.count")) - 1);
    bytes32 private constant USER_COUNT =
        bytes32(uint256(keccak256("eip1967.proxy.user.count")) - 1);
    bytes32 private constant VOTE_COUNT_IN_FAVOR =
        bytes32(uint256(keccak256("eip1967.proxy.vote.count.infavour")) - 1);
    bytes32 private constant VOTE_COUNT_AGAINST =
        bytes32(uint256(keccak256("eip1967.proxy.vote.count.against")) - 1);

    modifier onlyAdmin(
        address _admin,
        bytes32 hash,
        bytes memory _signature
    ) {
        require(
            _isValidSignature(_admin, hash, _signature),
            "Invalid user access"
        );
        require(isAdmin[_admin], "Caller is not an admin");
        _;
    }

    modifier _validateSignature(
        address _swa,
        bytes32 hash,
        bytes memory _signature
    ) {
        require(
            _isValidSignature(_swa, hash, _signature),
            "Invalid user access"
        );
        _;
    }

    function _isValidSignature(
        address _addr,
        bytes32 hash,
        bytes memory _signature
    ) internal view returns (bool) {
        bytes4 result = ERC1271(_addr).isValidSignature(hash, _signature);
        return result == MAGIC_VALUE;
    }

    /*#####################################
        Admin Interface
    #####################################*/

    function _getAdmin() private view returns (address[] memory) {
        return admins;
    }

    function _addAdmin(address _admin) private {
        require(_admin != address(0), "admin = zero address");
        require(!isAdmin[_admin], "Admin already added");
        isAdmin[_admin] = true;
        admins.push(_admin);
    }

    function _removeAdmin(address _admin) private {
        require(isAdmin[_admin], "Not an admin");
        isAdmin[_admin] = false;
        for (uint256 i = 0; i < admins.length; ++i) {
            if (admins[i] == _admin) {
                admins[i] = admins[admins.length - 1];
                admins.pop();
                break;
            }
        }
    }

    function addAdmin(
        address _admin,
        address _swa,
        bytes32 hash,
        bytes memory _signature
    ) external onlyAdmin(_admin, hash, _signature) {
        _addAdmin(_swa);
    }

    function removeAdmin(
        address _admin,
        address _swa,
        bytes32 hash,
        bytes memory _signature
    ) external onlyAdmin(_admin, hash, _signature) {
        _removeAdmin(_swa);
    }

    /*#####################################
        Factory Implementation Interface
    #####################################*/

    function _getFactoryImplementation() private view returns (address) {
        return
            GardenFactoryStorageSlot.getAddressSlot(IMPLEMENTATION_SLOT).value;
    }

    function _setImplementation(address _implementation) private {
        require(
            _implementation.code.length != 0,
            "implementation is not contract"
        );
        GardenFactoryStorageSlot
            .getAddressSlot(IMPLEMENTATION_SLOT)
            .value = _implementation;
    }

    function proposeUpgrade(
        address _admin,
        address _implementation,
        bytes32 hash,
        bytes memory _signature
    ) external onlyAdmin(_admin, hash, _signature) {
        require(
            _implementation != address(0),
            "Invalid implementation address"
        );
        address currentProposal = GardenFactoryStorageSlot
            .getAddressSlot(PROPOSED_IMPLEMENTATION_CONTRACT)
            .value;
        uint256 currentVoteCountInFavor = GardenFactoryStorageSlot
            .getUint256Slot(VOTE_COUNT_IN_FAVOR)
            .value;
        uint256 currentVoteCountAgainst = GardenFactoryStorageSlot
            .getUint256Slot(VOTE_COUNT_AGAINST)
            .value;

        if (currentProposal != address(0)) {
            bool hasVotes = currentVoteCountInFavor > 0 ||
                currentVoteCountAgainst > 0;
            bool noVotesYet = currentVoteCountInFavor == 0 &&
                currentVoteCountAgainst == 0;
            require(
                !(hasVotes || noVotesYet),
                "Existing proposal still active or pending voting"
            );
        }

        GardenFactoryStorageSlot
            .getAddressSlot(PROPOSED_IMPLEMENTATION_CONTRACT)
            .value = _implementation;
        _resetVotes();
        emit ImplementationProposed(_implementation);
    }

    function voteForUpgrade(
        address _admin,
        bool inFavor,
        bytes32 hash,
        bytes memory _signature
    ) external onlyAdmin(_admin, hash, _signature) {
        address _implementation = GardenFactoryStorageSlot
            .getAddressSlot(PROPOSED_IMPLEMENTATION_CONTRACT)
            .value;
        require(_implementation != address(0), "No proposed implementation");
        require(!upgradeVotes[_admin], "Already voted");

        upgradeVotes[_admin] = true;
        voteInFavor[_admin] = inFavor;

        if (inFavor) {
            uint256 inFavourCount = GardenFactoryStorageSlot
                .getUint256Slot(VOTE_COUNT_IN_FAVOR)
                .value;
            inFavourCount = inFavourCount + 1;
            GardenFactoryStorageSlot
                .getUint256Slot(VOTE_COUNT_IN_FAVOR)
                .value = inFavourCount;
        } else {
            uint256 againstCount = GardenFactoryStorageSlot
                .getUint256Slot(VOTE_COUNT_AGAINST)
                .value;
            againstCount = againstCount + 1;
            GardenFactoryStorageSlot
                .getUint256Slot(VOTE_COUNT_AGAINST)
                .value = againstCount;
        }
        emit VoteRecorded(_admin, inFavor);
    }

    function upgradeTo(
        address _admin,
        bytes32 hash,
        bytes memory _signature
    ) external onlyAdmin(_admin, hash, _signature) {
        address _implementation = GardenFactoryStorageSlot
            .getAddressSlot(PROPOSED_IMPLEMENTATION_CONTRACT)
            .value;
        uint256 voteCountInFavor = GardenFactoryStorageSlot
            .getUint256Slot(VOTE_COUNT_IN_FAVOR)
            .value;

        require(
            voteCountInFavor > admins.length / 2,
            "Not enough in-favor votes"
        );
        require(
            voteCountInFavor +
                GardenFactoryStorageSlot
                    .getUint256Slot(VOTE_COUNT_AGAINST)
                    .value ==
                admins.length,
            "Not all admins have voted"
        );

        _setImplementation(_implementation);
        GardenFactoryStorageSlot
            .getAddressSlot(PROPOSED_IMPLEMENTATION_CONTRACT)
            .value = address(0);
        _resetVotes();
    }

    function _resetVotes() private {
        uint256 previousVoteCountInFavor = GardenFactoryStorageSlot
            .getUint256Slot(VOTE_COUNT_IN_FAVOR)
            .value;
        uint256 previousVoteCountAgainst = GardenFactoryStorageSlot
            .getUint256Slot(VOTE_COUNT_AGAINST)
            .value;

        address[] memory adminsReset = new address[](admins.length);
        for (uint256 i = 0; i < admins.length; ++i) {
            address _admin = admins[i];
            upgradeVotes[_admin] = false;
            voteInFavor[_admin] = false;
            adminsReset[i] = _admin;
        }

        GardenFactoryStorageSlot.getUint256Slot(VOTE_COUNT_IN_FAVOR).value = 0;
        GardenFactoryStorageSlot.getUint256Slot(VOTE_COUNT_AGAINST).value = 0;
        emit VotesResetProcess(
            previousVoteCountInFavor,
            previousVoteCountAgainst,
            adminsReset,
            block.timestamp
        );
    }

    function admin(
        address _admin,
        bytes32 hash,
        bytes memory _signature
    )
        external
        view
        onlyAdmin(_admin, hash, _signature)
        returns (address[] memory)
    {
        return _getAdmin();
    }

    function implementation(
        address _admin,
        bytes32 hash,
        bytes memory _signature
    ) external view onlyAdmin(_admin, hash, _signature) returns (address) {
        return _getFactoryImplementation();
    }

    function resetVotes(
        address _admin,
        bytes32 hash,
        bytes memory _signature
    ) external onlyAdmin(_admin, hash, _signature) {
        _resetVotes();
    }

    function getVoteCount(
        address _admin,
        bytes32 hash,
        bytes memory _signature
    )
        external
        view
        onlyAdmin(_admin, hash, _signature)
        returns (uint256 inFavor, uint256 against)
    {
        inFavor = GardenFactoryStorageSlot
            .getUint256Slot(VOTE_COUNT_IN_FAVOR)
            .value;
        against = GardenFactoryStorageSlot
            .getUint256Slot(VOTE_COUNT_AGAINST)
            .value;
    }

    /*#####################################
        Garden Implementation Interface
    #####################################*/

    function setGardenImplementationModule(
        address _admin,
        address _implementation,
        uint256 gardenImpModule,
        bytes32 hash,
        bytes memory _signature
    ) external onlyAdmin(_admin, hash, _signature) {
        require(_admin != address(0), "Invalid address");
        require(_implementation != address(0), "Invalid address");
        gardenImplementationMap[gardenImpModule] = _implementation;
        gardenImplementationList.push(_implementation);
    }

    function getGardenImplementationModule(
        uint256 gardenImpModule
    ) external view returns (address) {
        return gardenImplementationMap[gardenImpModule];
    }

    function joinFactory(
        address swaAccount,
        bytes32 hash,
        bytes memory _signature
    ) external _validateSignature(swaAccount, hash, _signature) {
        uint256 userCount = GardenFactoryStorageSlot
            .getUint256Slot(USER_COUNT)
            .value;
        authorizedDeployers[swaAccount] = true;
        deployerId[swaAccount] = userCount + 1;
        GardenFactoryStorageSlot.getUint256Slot(USER_COUNT).value =
            userCount +
            1;
        emit DeployerAuthorized(swaAccount);
    }

    function isUserAuthorized(
        address swaAccount,
        bytes32 hash,
        bytes memory _signature
    )
        external
        view
        _validateSignature(swaAccount, hash, _signature)
        returns (bool)
    {
        return authorizedDeployers[swaAccount];
    }

    function getGardenCounts(
        address swaAccount,
        bytes32 hash,
        bytes memory _signature
    )
        external
        view
        _validateSignature(swaAccount, hash, _signature)
        returns (uint256)
    {
        return GardenFactoryStorageSlot.getUint256Slot(GARDEN_COUNT).value;
    }

    function getUserCounts(
        address swaAccount,
        bytes32 hash,
        bytes memory _signature
    )
        external
        view
        _validateSignature(swaAccount, hash, _signature)
        returns (uint256)
    {
        return GardenFactoryStorageSlot.getUint256Slot(USER_COUNT).value;
    }

    function deployGardenProxy(
        GardenProxyParams memory params
    )
        external
        _validateSignature(params.deployer, params.hash, params.signature)
        returns (address)
    {
        require(authorizedDeployers[params.deployer], "Not authorized");

        bytes32 salt = getSalt(params.deployer, params.gardenId);
        address computedAddress = getAddress(
            params.deployer,
            params.bytecode,
            params.gardenId
        );

        require(!isContract(computedAddress), "Contract already deployed");

        address deployedAddress = _deployProxy(
            params.bytecode,
            params.factory,
            params.deployer,
            params.nft,
            params.facetCuts,
            params.init,
            params.initCalldata,
            salt
        );

        gardenProxyContracts[params.deployer][
            params.gardenId
        ] = deployedAddress;

        uint256 gardenCount = GardenFactoryStorageSlot
            .getUint256Slot(GARDEN_COUNT)
            .value;
        GardenFactoryStorageSlot.getUint256Slot(GARDEN_COUNT).value =
            gardenCount +
            1;

        emit GardenDeployed(params.deployer, deployedAddress, params.gardenId);
        return deployedAddress;
    }

    function _deployProxy(
        bytes memory bytecode,
        address factory,
        address deployer,
        address nft,
        IDiamondCut.FacetCut[] memory facetCuts,
        address init,
        bytes memory initCalldata,
        bytes32 salt
    ) internal returns (address) {
        bytes memory constructorArgs = abi.encode(deployer, factory, nft);
        bytes memory initCode = abi.encodePacked(bytecode, constructorArgs);

        address deployedAddress;
        assembly {
            deployedAddress := create2(
                0,
                add(initCode, 0x20),
                mload(initCode),
                salt
            )
            if iszero(extcodesize(deployedAddress)) {
                revert(0, 0)
            }
        }

        IDiamondCut(deployedAddress).diamondCut(facetCuts, init, initCalldata);
        return deployedAddress;
    }

    function getAddress(
        address deployer,
        bytes memory bytecode,
        uint256 gardenId
    ) public view returns (address) {
        bytes32 salt = getSalt(deployer, gardenId);
        bytes32 bytecodeHash = keccak256(bytecode);
        bytes32 hash = keccak256(
            abi.encodePacked(bytes1(0xff), address(this), salt, bytecodeHash)
        );
        return address(uint160(uint(hash)));
    }

    function getSalt(
        address deployer,
        uint256 id
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(deployer, id));
    }

    function isContract(address addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }

    function getDeployedGardenProxyContract(
        address deployer,
        uint256 gardenId,
        bytes32 hash,
        bytes memory _signature
    )
        external
        view
        _validateSignature(deployer, hash, _signature)
        returns (address)
    {
        require(authorizedDeployers[deployer], "Not authorized");
        return gardenProxyContracts[deployer][gardenId];
    }
}
