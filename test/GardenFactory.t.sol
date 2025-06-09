// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {GardenFactory} from "../src/factory/GardenFactory.sol";
import {Diamond} from "../src/Diamond.sol";
import {DiamondCutFacet} from "../src/facets/DiamondCutFacet.sol";
import {FacetRegistry} from "../src/registry/FacetRegistry.sol";
import {IDiamond} from "../src/interfaces/IDiamond.sol";
import {DiamondLoupeFacet} from "../src/facets/DiamondLoupeFacet.sol";
import {DiamondInit} from "../src/upgradeInitializers/DiamondInit.sol";
import {IDiamondCut} from "../src/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../src/interfaces/IDiamondLoupe.sol";

contract GardenFactoryTest is Test {
    GardenFactory gardenFactory;
    FacetRegistry facetRegistry;
    DiamondCutFacet diamondCutFacet;
    DiamondLoupeFacet diamondLoupeFacet;
    // GardenFacet gardenFacet; // Optional
    DiamondInit diamondInit;
    address deployer;
    address user;

    function setUp() public {
        deployer = address(0x1);
        user = address(0x2);
        vm.startPrank(deployer);

        // Deploy FacetRegistry
        facetRegistry = new FacetRegistry(deployer);

        // Deploy GardenFactory
        gardenFactory = new GardenFactory();

        // Deploy facets
        diamondCutFacet = new DiamondCutFacet(address(facetRegistry));
        diamondLoupeFacet = new DiamondLoupeFacet();
        // gardenFacet = new GardenFacet(); // Optional
        diamondInit = new DiamondInit();

        // Register facets in FacetRegistry
        bytes4[] memory cutSelectors = new bytes4[](1);
        cutSelectors[0] = DiamondCutFacet.diamondCut.selector;
        facetRegistry.registerFacet(address(diamondCutFacet), cutSelectors);

        bytes4[] memory loupeSelectors = new bytes4[](4);
        loupeSelectors[0] = DiamondLoupeFacet.facets.selector;
        loupeSelectors[1] = DiamondLoupeFacet.facetFunctionSelectors.selector;
        loupeSelectors[2] = DiamondLoupeFacet.facetAddresses.selector;
        loupeSelectors[3] = DiamondLoupeFacet.facetAddress.selector;
        facetRegistry.registerFacet(address(diamondLoupeFacet), loupeSelectors);

        // Optional: Register GardenFacet
        // bytes4[] memory gardenSelectors = new bytes4[](1);
        // gardenSelectors[0] = bytes4(keccak256("someGardenFunction()"));
        // facetRegistry.registerFacet(address(gardenFacet), gardenSelectors);

        vm.stopPrank();
    }

    function testDeployGardenFactory() public view {
        assertTrue(
            address(gardenFactory) != address(0),
            "GardenFactory not deployed"
        );
        assertTrue(
            address(facetRegistry) != address(0),
            "FacetRegistry not deployed"
        );
    }

    function testAuthorizeDeployer() public {
        vm.startPrank(user);
        gardenFactory.joinFactory(user, bytes32("hash"), bytes(""));
        bool isAuthorized = gardenFactory.isUserAuthorized(
            user,
            bytes32("hash"),
            bytes("")
        );
        assertTrue(isAuthorized, "Deployer not authorized");
        assertEq(
            gardenFactory.getUserCounts(user, bytes32("hash"), bytes("")),
            1,
            "User count incorrect"
        );
        vm.stopPrank();
    }

    function testDeployDiamondProxy() public {
        vm.startPrank(deployer);

        // Authorize deployer
        gardenFactory.joinFactory(deployer, bytes32("hash"), bytes(""));

        // Prepare facet cuts
        IDiamondCut.FacetCut[] memory facetCuts = new IDiamondCut.FacetCut[](2); // Set to 3 if GardenFacet is included
        facetCuts[0] = IDiamond.FacetCut({
            facetAddress: address(diamondCutFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: new bytes4[](1)
        });
        facetCuts[0].functionSelectors[0] = DiamondCutFacet.diamondCut.selector;

        facetCuts[1] = IDiamond.FacetCut({
            facetAddress: address(diamondLoupeFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: new bytes4[](4)
        });
        facetCuts[1].functionSelectors[0] = DiamondLoupeFacet.facets.selector;
        facetCuts[1].functionSelectors[1] = DiamondLoupeFacet
            .facetFunctionSelectors
            .selector;
        facetCuts[1].functionSelectors[2] = DiamondLoupeFacet
            .facetAddresses
            .selector;
        facetCuts[1].functionSelectors[3] = DiamondLoupeFacet
            .facetAddress
            .selector;

        // Optional: Add GardenFacet selectors
        // facetCuts[2] = IDiamond.FacetCut({
        //     facetAddress: address(gardenFacet),
        //     action: IDiamond.FacetCutAction.Add,
        //     functionSelectors: new bytes4[](1)
        // });
        // facetCuts[2].functionSelectors[0] = bytes4(keccak256("someGardenFunction()"));

        // Prepare init calldata
        bytes memory initCalldata = abi.encodeWithSelector(
            DiamondInit.init.selector
        );

        // Deploy Diamond proxy
        GardenFactory.GardenProxyParams memory params = GardenFactory
            .GardenProxyParams({
                bytecode: type(Diamond).creationCode,
                deployer: deployer,
                factory: address(gardenFactory),
                nft: address(0),
                gardenId: 1,
                hash: bytes32("hash"),
                signature: bytes(""),
                facetCuts: facetCuts,
                init: address(diamondInit),
                initCalldata: initCalldata
            });

        address deployedAddress = gardenFactory.deployGardenProxy(params);
        assertTrue(deployedAddress != address(0), "Diamond proxy not deployed");

        // Verify facets
        IDiamondLoupe diamondLoupe = IDiamondLoupe(deployedAddress);
        address[] memory facetAddresses = diamondLoupe.facetAddresses();
        assertEq(facetAddresses.length, 2, "Incorrect number of facets"); // Update to 3 if GardenFacet is included
        assertEq(
            facetAddresses[0],
            address(diamondCutFacet),
            "DiamondCutFacet not set"
        );
        assertEq(
            facetAddresses[1],
            address(diamondLoupeFacet),
            "DiamondLoupeFacet not set"
        );
        // assertEq(facetAddresses[2], address(gardenFacet), "GardenFacet not set"); // Uncomment if using GardenFacet

        // Verify garden count
        assertEq(
            gardenFactory.getGardenCounts(deployer, bytes32("hash"), bytes("")),
            1,
            "Garden count incorrect"
        );

        // Verify deployed address
        address storedAddress = gardenFactory.getDeployedGardenProxyContract(
            deployer,
            1,
            bytes32("hash"),
            bytes("")
        );
        assertEq(
            storedAddress,
            deployedAddress,
            "Stored proxy address incorrect"
        );

        // Verify FacetRegistry
        assertTrue(
            facetRegistry.isFacetRegistered(address(diamondCutFacet)),
            "DiamondCutFacet not registered"
        );
        assertTrue(
            facetRegistry.isFacetRegistered(address(diamondLoupeFacet)),
            "DiamondLoupeFacet not registered"
        );

        vm.stopPrank();
    }
}
