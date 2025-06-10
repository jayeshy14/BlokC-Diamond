// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Script.sol";
import "../src/Diamond.sol";
import "../src/facets/DiamondCutFacet.sol";
import "../src/facets/DiamondLoupeFacet.sol";
import "../src/facets/OwnershipFacet.sol";
import "../src/upgradeInitializers/DiamondInit.sol";
import "../src/registry/FacetRegistry.sol";
import "../test/HelperContract.sol";

contract DeployScript is Script, HelperContract {
    struct DeploymentData {
        FacetRegistry registry;
        DiamondCutFacet cutFacet;
        DiamondLoupeFacet loupeFacet;
        OwnershipFacet ownershipFacet;
        DiamondInit init;
        Diamond diamond;
    }

    function run() external {
        //read env variables and choose EOA for transaction signing
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.envAddress("PUBLIC_KEY");

        vm.startBroadcast(deployerPrivateKey);

        DeploymentData memory deploymentData;

        // Deploy registry first
        deploymentData.registry = new FacetRegistry(deployerAddress);

        // Deploy facets
        deploymentData.cutFacet = new DiamondCutFacet(
            address(deploymentData.registry)
        );
        deploymentData.loupeFacet = new DiamondLoupeFacet();
        deploymentData.ownershipFacet = new OwnershipFacet();
        deploymentData.init = new DiamondInit();

        // Register initial facets
        deploymentData.registry.registerFacet(
            address(deploymentData.cutFacet),
            generateSelectors("DiamondCutFacet")
        );
        deploymentData.registry.registerFacet(
            address(deploymentData.loupeFacet),
            generateSelectors("DiamondLoupeFacet")
        );
        deploymentData.registry.registerFacet(
            address(deploymentData.ownershipFacet),
            generateSelectors("OwnershipFacet")
        );

        // Diamond arguments
        DiamondArgs memory _args = DiamondArgs({
            owner: deployerAddress,
            init: address(deploymentData.init),
            initCalldata: abi.encodeWithSignature("init()")
        });

        // Create facet cuts
        FacetCut[] memory cut = new FacetCut[](3);
        cut[0] = FacetCut({
            facetAddress: address(deploymentData.cutFacet),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("DiamondCutFacet")
        });

        cut[1] = FacetCut({
            facetAddress: address(deploymentData.loupeFacet),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("DiamondLoupeFacet")
        });

        cut[2] = FacetCut({
            facetAddress: address(deploymentData.ownershipFacet),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("OwnershipFacet")
        });

        // Deploy diamond
        deploymentData.diamond = new Diamond(cut, _args);

        // Log deployed addresses
        console.log(
            "facetRegistry deployed at:",
            address(deploymentData.registry)
        );
        console.log("diamond deployed at:", address(deploymentData.diamond));

        vm.stopBroadcast();
    }
}
