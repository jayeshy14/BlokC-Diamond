// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IDiamond } from "../interfaces/IDiamond.sol";

error FacetNotRegistered(address facet);
error FacetAlreadyRegistered(address facet);
error NotAuthorized();

contract FacetRegistry {
    address public immutable owner;
    mapping(address => bool) public isFacetRegistered;
    mapping(address => bytes4[]) public facetSelectors;
    mapping(bytes4 => bool) public isSelectorRegistered;

    event FacetRegistered(address indexed facet, bytes4[] selectors);
    event FacetUnregistered(address indexed facet);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address _owner) {
        owner = _owner;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotAuthorized();
        _;
    }

    function registerFacet(address _facet, bytes4[] calldata _selectors) external onlyOwner {
        if (isFacetRegistered[_facet]) revert FacetAlreadyRegistered(_facet);
        
        isFacetRegistered[_facet] = true;
        facetSelectors[_facet] = _selectors;
        
        for (uint i = 0; i < _selectors.length; i++) {
            isSelectorRegistered[_selectors[i]] = true;
        }
        
        emit FacetRegistered(_facet, _selectors);
    }

    function unregisterFacet(address _facet) external onlyOwner {
        if (!isFacetRegistered[_facet]) revert FacetNotRegistered(_facet);
        
        bytes4[] memory selectors = facetSelectors[_facet];
        for (uint i = 0; i < selectors.length; i++) {
            isSelectorRegistered[selectors[i]] = false;
        }
        
        delete isFacetRegistered[_facet];
        delete facetSelectors[_facet];
        
        emit FacetUnregistered(_facet);
    }

    function validateFacetCut(IDiamond.FacetCut[] calldata _diamondCut) external view {
        for (uint i = 0; i < _diamondCut.length; i++) {
            address facet = _diamondCut[i].facetAddress;
            bytes4[] memory selectors = _diamondCut[i].functionSelectors;
            IDiamond.FacetCutAction action = _diamondCut[i].action;

            if (action == IDiamond.FacetCutAction.Add) {
                if (!isFacetRegistered[facet]) revert FacetNotRegistered(facet);
                for (uint j = 0; j < selectors.length; j++) {
                    if (!isSelectorRegistered[selectors[j]]) revert FacetNotRegistered(facet);
                }
            } else if (action == IDiamond.FacetCutAction.Replace) {
                if (!isFacetRegistered[facet]) revert FacetNotRegistered(facet);
                for (uint j = 0; j < selectors.length; j++) {
                    if (!isSelectorRegistered[selectors[j]]) revert FacetNotRegistered(facet);
                }
            }
            // Remove action doesn't need validation as it's removing existing functions
        }
    }
}