// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./TestStates.sol";
import "../src/registry/FacetRegistry.sol";
import "../src/facets/Test1Facet.sol";
import "../src/facets/Test2Facet.sol";

contract FacetRegistryTests is HelperContract {
    FacetRegistry public registry;
    Test1Facet public test1Facet;
    Test2Facet public test2Facet;

    function setUp() public {
        registry = new FacetRegistry(address(this));
        test1Facet = new Test1Facet();
        test2Facet = new Test2Facet();
    }

    function testConstructor() public view {
        assertEq(registry.owner(), address(this));
    }

    function testRegisterFacet() public {
        bytes4[] memory selectors = generateSelectors("Test1Facet");
        registry.registerFacet(address(test1Facet), selectors);
        
        assertTrue(registry.isFacetRegistered(address(test1Facet)));
        for (uint i = 0; i < selectors.length; i++) {
            assertTrue(registry.isSelectorRegistered(selectors[i]));
            assertEq(registry.facetSelectors(address(test1Facet), i), selectors[i]);
        }
    }

    function testRegisterFacetTwice() public {
        bytes4[] memory selectors = generateSelectors("Test1Facet");
        registry.registerFacet(address(test1Facet), selectors);
        
        vm.expectRevert(abi.encodeWithSelector(FacetAlreadyRegistered.selector, address(test1Facet)));
        registry.registerFacet(address(test1Facet), selectors);
    }

    function testUnregisterFacet() public {
        bytes4[] memory selectors = generateSelectors("Test1Facet");
        registry.registerFacet(address(test1Facet), selectors);
        
        registry.removeFacet(address(test1Facet));
        
        assertFalse(registry.isFacetRegistered(address(test1Facet)));
        for (uint i = 0; i < selectors.length; i++) {
            assertFalse(registry.isSelectorRegistered(selectors[i]));
        }
    }

    function testUnregisterNonExistentFacet() public {
        vm.expectRevert(abi.encodeWithSelector(FacetNotRegistered.selector, address(test1Facet)));
        registry.removeFacet(address(test1Facet));
    }

    function testValidateFacetCutAdd() public {
        bytes4[] memory selectors = generateSelectors("Test1Facet");
        registry.registerFacet(address(test1Facet), selectors);
        
        IDiamond.FacetCut[] memory cut = new IDiamond.FacetCut[](1);
        cut[0] = IDiamond.FacetCut({
            facetAddress: address(test1Facet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: selectors
        });
        
        // Should not revert
        registry.validateFacetCut(cut);
    }

    function testValidateFacetCutAddUnregistered() public {
        bytes4[] memory selectors = generateSelectors("Test1Facet");
        
        IDiamond.FacetCut[] memory cut = new IDiamond.FacetCut[](1);
        cut[0] = IDiamond.FacetCut({
            facetAddress: address(test1Facet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: selectors
        });
        
        vm.expectRevert(abi.encodeWithSelector(FacetNotRegistered.selector, address(test1Facet)));
        registry.validateFacetCut(cut);
    }

    function testValidateFacetCutReplace() public {
        bytes4[] memory selectors = generateSelectors("Test1Facet");
        registry.registerFacet(address(test1Facet), selectors);
        registry.registerFacet(address(test2Facet), selectors);
        
        IDiamond.FacetCut[] memory cut = new IDiamond.FacetCut[](1);
        cut[0] = IDiamond.FacetCut({
            facetAddress: address(test2Facet),
            action: IDiamond.FacetCutAction.Replace,
            functionSelectors: selectors
        });
        
        // Should not revert
        registry.validateFacetCut(cut);
    }

    function testValidateFacetCutReplaceUnregistered() public {
        bytes4[] memory selectors = generateSelectors("Test1Facet");
        registry.registerFacet(address(test1Facet), selectors);
        
        IDiamond.FacetCut[] memory cut = new IDiamond.FacetCut[](1);
        cut[0] = IDiamond.FacetCut({
            facetAddress: address(test2Facet),
            action: IDiamond.FacetCutAction.Replace,
            functionSelectors: selectors
        });
        
        vm.expectRevert(abi.encodeWithSelector(FacetNotRegistered.selector, address(test2Facet)));
        registry.validateFacetCut(cut);
    }

    function testValidateFacetCutRemove() public {
        bytes4[] memory selectors = generateSelectors("Test1Facet");
        registry.registerFacet(address(test1Facet), selectors);
        
        IDiamond.FacetCut[] memory cut = new IDiamond.FacetCut[](1);
        cut[0] = IDiamond.FacetCut({
            facetAddress: address(0),
            action: IDiamond.FacetCutAction.Remove,
            functionSelectors: selectors
        });
        
        // Should not revert as Remove action doesn't need validation
        registry.validateFacetCut(cut);
    }

    function testOnlyOwnerCanRegister() public {
        bytes4[] memory selectors = generateSelectors("Test1Facet");
        
        vm.prank(address(0x123));
        vm.expectRevert(NotAuthorized.selector);
        registry.registerFacet(address(test1Facet), selectors);
    }

    function testOnlyOwnerCanUnregister() public {
        bytes4[] memory selectors = generateSelectors("Test1Facet");
        registry.registerFacet(address(test1Facet), selectors);
        
        vm.prank(address(0x123));
        vm.expectRevert(NotAuthorized.selector);
        registry.removeFacet(address(test1Facet));
    }
} 