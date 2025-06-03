// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "../src/interfaces/IDiamondCut.sol";
import "../src/facets/DiamondCutFacet.sol";
import "../src/facets/DiamondLoupeFacet.sol";
import "../src/facets/OwnershipFacet.sol";
import "../src/facets/Test1Facet.sol";
import "../src/facets/Test2Facet.sol";
import "../src/Diamond.sol";
import "./HelperContract.sol";
import "../src/facets/MultiplyFacet.sol";
import "../src/registry/FacetRegistry.sol";


abstract contract StateDeployDiamond is HelperContract {

    //contract types of facets to be deployed
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;
    FacetRegistry facetRegistry;


    //interfaces with Facet ABI connected to diamond address
    IDiamondLoupe ILoupe;
    IDiamondCut ICut;

    string[] facetNames;
    address[] facetAddressList;

    // deploys diamond and connects facets
    function setUp() public virtual {

        //deploy facets
        facetRegistry = new FacetRegistry(address(this));
        dCutFacet = new DiamondCutFacet(address(facetRegistry));
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();
        facetNames = ["DiamondCutFacet", "DiamondLoupeFacet", "OwnershipFacet"];

        // Register facets with the registry
        facetRegistry.registerFacet(address(dCutFacet), generateSelectors("DiamondCutFacet"));
        facetRegistry.registerFacet(address(dLoupe), generateSelectors("DiamondLoupeFacet"));
        facetRegistry.registerFacet(address(ownerF), generateSelectors("OwnershipFacet"));

        // diamod arguments
        DiamondArgs memory _args = DiamondArgs({
        owner: address(this),
        init: address(0),
        initCalldata: " "
        });

        // FacetCut with CutFacet for initialisation
        FacetCut[] memory cut0 = new FacetCut[](1);
        cut0[0] = FacetCut ({
        facetAddress: address(dCutFacet),
        action: IDiamond.FacetCutAction.Add,
        functionSelectors: generateSelectors("DiamondCutFacet")
        });


        // deploy diamond
        diamond = new Diamond(cut0, _args);

        //upgrade diamond with facets

        //build cut struct
        FacetCut[] memory cut = new FacetCut[](2);

        cut[0] = (
        FacetCut({
        facetAddress: address(dLoupe),
        action: FacetCutAction.Add,
        functionSelectors: generateSelectors("DiamondLoupeFacet")
        })
        );

        cut[1] = (
        FacetCut({
        facetAddress: address(ownerF),
        action: FacetCutAction.Add,
        functionSelectors: generateSelectors("OwnershipFacet")
        })
        );

        // initialise interfaces
        ILoupe = IDiamondLoupe(address(diamond));
        ICut = IDiamondCut(address(diamond));

        //upgrade diamond
        ICut.diamondCut(cut, address(0x0), "");

        // get all addresses
        facetAddressList = ILoupe.facetAddresses();
    }


}
abstract contract StateDeployMultiplyFacet is StateDeployDiamond {

    MultiplyFacet multiplyFacet;

    function setUp() public override virtual {
        super.setUp();

        // Deploy the multiply facet
        multiplyFacet = new MultiplyFacet();

        // Get selectors and register the multiply facet
        bytes4[] memory selectors = generateSelectors("MultiplyFacet");
        facetRegistry.registerFacet(address(multiplyFacet), selectors);

        // Add the multiply facet to the diamond
        FacetCut[] memory cut = new FacetCut[](1);
        cut[0] = FacetCut({
            facetAddress: address(multiplyFacet),   
            action: FacetCutAction.Add,
            functionSelectors: selectors
        });

        ICut.diamondCut(cut, address(0), "");
    }

}