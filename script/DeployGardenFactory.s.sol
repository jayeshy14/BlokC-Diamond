// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {IDiamond} from "../src/interfaces/IDiamond.sol";
import {GardenFactory} from "../src/factory/GardenFactory.sol";
import {Diamond} from "../src/Diamond.sol";
import {DiamondCutFacet} from "../src/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../src/facets/DiamondLoupeFacet.sol";
import {DiamondInit} from "../src/upgradeInitializers/DiamondInit.sol";
import {IDiamondCut} from "../src/interfaces/IDiamondCut.sol";
import {FacetRegistry} from "../src/registry/FacetRegistry.sol";

contract DeployGardenFactory is Script {
    function run() external {
        vm.startBroadcast();

        // Deploy FacetRegistry
        FacetRegistry facetRegistry = new FacetRegistry(msg.sender);
        console2.log("FacetRegistry deployed to:", address(facetRegistry));

        // Deploy GardenFactory
        GardenFactory gardenFactory = new GardenFactory();
        console2.log("GardenFactory deployed to:", address(gardenFactory));

        // Deploy DiamondCutFacet with FacetRegistry address
        DiamondCutFacet diamondCutFacet = new DiamondCutFacet(
            address(facetRegistry)
        );
        console2.log("DiamondCutFacet deployed to:", address(diamondCutFacet));

        // Deploy DiamondLoupeFacet
        DiamondLoupeFacet diamondLoupeFacet = new DiamondLoupeFacet();
        console2.log(
            "DiamondLoupeFacet deployed to:",
            address(diamondLoupeFacet)
        );

        // Deploy GardenFacet (optional)
        // GardenFacet gardenFacet = new GardenFacet();
        // console2.log("GardenFacet deployed to:", address(gardenFacet));

        // Deploy DiamondInit
        DiamondInit diamondInit = new DiamondInit();
        console2.log("DiamondInit deployed to:", address(diamondInit));

        // Register facets in FacetRegistry
        bytes4[] memory cutSelectors = new bytes4[](1);
        cutSelectors[0] = DiamondCutFacet.diamondCut.selector;
        facetRegistry.registerFacet(address(diamondCutFacet), cutSelectors);
        console2.log("DiamondCutFacet registered in FacetRegistry");

        bytes4[] memory loupeSelectors = new bytes4[](4);
        loupeSelectors[0] = DiamondLoupeFacet.facets.selector;
        loupeSelectors[1] = DiamondLoupeFacet.facetFunctionSelectors.selector;
        loupeSelectors[2] = DiamondLoupeFacet.facetAddresses.selector;
        loupeSelectors[3] = DiamondLoupeFacet.facetAddress.selector;
        facetRegistry.registerFacet(address(diamondLoupeFacet), loupeSelectors);
        console2.log("DiamondLoupeFacet registered in FacetRegistry");

        // Optional: Register GardenFacet
        // bytes4[] memory gardenSelectors = new bytes4[](1);
        // gardenSelectors[0] = bytes4(keccak256("someGardenFunction()"));
        // facetRegistry.registerFacet(address(gardenFacet), gardenSelectors);
        // console2.log("GardenFacet registered in FacetRegistry");

        // Prepare facet cuts
        IDiamondCut.FacetCut[] memory facetCuts = new IDiamondCut.FacetCut[](2); // Set to 3 if GardenFacet is included
        facetCuts[0] = IDiamond.FacetCut({
            facetAddress: address(diamondCutFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: cutSelectors
        });

        facetCuts[1] = IDiamond.FacetCut({
            facetAddress: address(diamondLoupeFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: loupeSelectors
        });

        // Optional: Add GardenFacet selectors
        // facetCuts[2] = IDiamond.FacetCut({
        //     facetAddress: address(gardenFacet),
        //     action: IDiamond.FacetCutAction.Add,
        //     functionSelectors: gardenSelectors
        // });

        // Prepare init calldata
        bytes memory initCalldata = abi.encodeWithSelector(
            DiamondInit.init.selector
        );

        // Authorize deployer
        gardenFactory.joinFactory(msg.sender, bytes32("hash"), bytes(""));
        console2.log("Deployer authorized");

        // Deploy Diamond proxy via GardenFactory
        GardenFactory.GardenProxyParams memory params = GardenFactory
            .GardenProxyParams({
                bytecode: type(Diamond).creationCode,
                deployer: msg.sender,
                factory: address(gardenFactory),
                nft: address(0), // Replace with actual NFT address if needed
                gardenId: 1,
                hash: bytes32("hash"),
                signature: bytes(""),
                facetCuts: facetCuts,
                init: address(diamondInit),
                initCalldata: initCalldata
            });

        address deployedAddress = gardenFactory.deployGardenProxy(params);
        console2.log("Diamond proxy deployed to:", address(deployedAddress));

        vm.stopBroadcast();
    }
}
