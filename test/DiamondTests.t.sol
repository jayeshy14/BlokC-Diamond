// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./TestStates.sol";

// test proper deployment of diamond
contract TestDeployDiamond is StateDeployDiamond {

    // Helper function to filter out supportsInterface selector
    function filterSupportsInterface(bytes4[] memory selectors) internal pure returns (bytes4[] memory) {
        bytes4[] memory filtered = new bytes4[](selectors.length);
        uint256 count = 0;
        
        for (uint256 i = 0; i < selectors.length; i++) {
            if (selectors[i] != 0x01ffc9a7) { // supportsInterface selector
                filtered[count] = selectors[i];
                count++;
            }
        }
        
        // Resize array to actual size
        bytes4[] memory result = new bytes4[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = filtered[i];
        }
        
        return result;
    }

    function testHasThreeFacets() public view {
        assertEq(facetAddressList.length, 3);
    }

    function testFacetsHaveCorrectSelectors() public {
        for (uint i = 0; i < facetAddressList.length; i++) {
            bytes4[] memory fromLoupeFacet = ILoupe.facetFunctionSelectors(facetAddressList[i]);
            bytes4[] memory fromGenSelectors =  generateSelectors(facetNames[i]);
            assertTrue(sameMembers(fromLoupeFacet, fromGenSelectors));
        }
    }

    function testSelectorsAssociatedWithCorrectFacet() public {
        for (uint i = 0; i < facetAddressList.length; i++) {
            bytes4[] memory fromGenSelectors = generateSelectors(facetNames[i]);
            for (uint j = 0; j < fromGenSelectors.length; j++) {
                address facetAddress = ILoupe.facetAddress(fromGenSelectors[j]);
                assertEq(facetAddress, facetAddressList[i], "Facet address mismatch");
            }
        }
    }

    function testFacetAddresses() public view {
        address[] memory addresses = ILoupe.facetAddresses();
        assertEq(addresses.length, 3);
        for (uint i = 0; i < addresses.length; i++) {
            assertTrue(containsElement(facetAddressList, addresses[i]));
        }
    }

    function testFacetFunctionSelectors() public {
        for (uint i = 0; i < facetAddressList.length; i++) {
            bytes4[] memory selectors = ILoupe.facetFunctionSelectors(facetAddressList[i]);
            bytes4[] memory expectedSelectors = generateSelectors(facetNames[i]);
            assertTrue(sameMembers(selectors, expectedSelectors));
        }
    }

    function testFacetAddress() public view {
        bytes4[] memory allSelectors = getAllSelectors(address(diamond));
        for (uint i = 0; i < allSelectors.length; i++) {
            address facet = ILoupe.facetAddress(allSelectors[i]);
            assertTrue(containsElement(facetAddressList, facet));
        }
    }

    function testFacets() public {
        Facet[] memory facets = ILoupe.facets();
        assertEq(facets.length, 3);
        for (uint i = 0; i < facets.length; i++) {
            assertTrue(containsElement(facetAddressList, facets[i].facetAddress));
            bytes4[] memory expectedSelectors = generateSelectors(facetNames[i]);
            assertTrue(sameMembers(facets[i].functionSelectors, expectedSelectors));
        }
    }

    function testDiamondCutAdd() public {
        // Deploy a new facet
        Test1Facet test1Facet = new Test1Facet();
        
        // Get selectors from the new facet and filter out supportsInterface
        bytes4[] memory newSelectors = filterSupportsInterface(generateSelectors("Test1Facet"));
        
        // Register the facet with the registry
        facetRegistry.registerFacet(address(test1Facet), newSelectors);
        
        // Filter out any selectors that already exist in the diamond
        bytes4[] memory existingSelectors = getAllSelectors(address(diamond));
        bytes4[] memory selectorsToAdd = new bytes4[](newSelectors.length);
        uint256 addCount = 0;
        
        for (uint i = 0; i < newSelectors.length; i++) {
            bool exists = false;
            for (uint j = 0; j < existingSelectors.length; j++) {
                if (newSelectors[i] == existingSelectors[j]) {
                    exists = true;
                    break;
                }
            }
            if (!exists) {
                selectorsToAdd[addCount] = newSelectors[i];
                addCount++;
            }
        }
        
        // Resize the array to actual size
        bytes4[] memory finalSelectors = new bytes4[](addCount);
        for (uint i = 0; i < addCount; i++) {
            finalSelectors[i] = selectorsToAdd[i];
        }
        
        // Create cut only if there are selectors to add
        if (finalSelectors.length > 0) {
            FacetCut[] memory cut = new FacetCut[](1);
            cut[0] = FacetCut({
                facetAddress: address(test1Facet),
                action: FacetCutAction.Add,
                functionSelectors: finalSelectors
            });

            // Add facet
            ICut.diamondCut(cut, address(0), "");

            // Verify facet was added
            address[] memory addresses = ILoupe.facetAddresses();
            assertTrue(containsElement(addresses, address(test1Facet)));
        }
    }

    function testDiamondCutReplace() public {
        // First add a facet that we can replace
        Test1Facet test1Facet = new Test1Facet();
        bytes4[] memory initialSelectors = filterSupportsInterface(generateSelectors("Test1Facet"));
        
        // Register the initial facet
        facetRegistry.registerFacet(address(test1Facet), initialSelectors);
        
        // Add the initial facet
        FacetCut[] memory addCut = new FacetCut[](1);
        addCut[0] = FacetCut({
            facetAddress: address(test1Facet),
            action: FacetCutAction.Add,
            functionSelectors: initialSelectors
        });
        ICut.diamondCut(addCut, address(0), "");
        
        // Now deploy the replacement facet
        Test2Facet test2Facet = new Test2Facet();
        
        // Register the replacement facet
        facetRegistry.registerFacet(address(test2Facet), initialSelectors);
        
        // Create cut for replacement
        FacetCut[] memory replaceCut = new FacetCut[](1);
        replaceCut[0] = FacetCut({
            facetAddress: address(test2Facet),
            action: FacetCutAction.Replace,
            functionSelectors: initialSelectors
        });

        // Replace facet
        ICut.diamondCut(replaceCut, address(0), "");

        // Verify facet was replaced
        for (uint i = 0; i < initialSelectors.length; i++) {
            assertEq(ILoupe.facetAddress(initialSelectors[i]), address(test2Facet));
        }
    }

    function testDiamondCutRemove() public {
        // First add a facet that we can remove
        Test1Facet test1Facet = new Test1Facet();
        bytes4[] memory selectorsToAdd = filterSupportsInterface(generateSelectors("Test1Facet"));
        
        // Register the facet
        facetRegistry.registerFacet(address(test1Facet), selectorsToAdd);
        
        // Add the facet
        FacetCut[] memory addCut = new FacetCut[](1);
        addCut[0] = FacetCut({
            facetAddress: address(test1Facet),
            action: FacetCutAction.Add,
            functionSelectors: selectorsToAdd
        });
        ICut.diamondCut(addCut, address(0), "");
        
        // Now remove it
        FacetCut[] memory removeCut = new FacetCut[](1);
        removeCut[0] = FacetCut({
            facetAddress: address(0),
            action: FacetCutAction.Remove,
            functionSelectors: selectorsToAdd
        });

        // Remove facet
        ICut.diamondCut(removeCut, address(0), "");

        // Verify selectors were removed
        for (uint i = 0; i < selectorsToAdd.length; i++) {
            assertEq(ILoupe.facetAddress(selectorsToAdd[i]), address(0));
        }
    }
}