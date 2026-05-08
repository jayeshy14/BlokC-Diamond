# BlokC-Diamond

Reference implementation of the Diamond architecture I'm building at [Blok Capital](https://github.com/BLOKCapital) — a modular, multi-chain wealth management protocol.

This repository contains the open core: an EIP-2535 Diamond with a **Facet Registry** for safe upgradeability, a **Garden Factory** that uses CREATE2 for deterministic Diamond deployments, and a **Liquidity Pool Registry** to track supported DEX pools across chains.

> Standards · EIP-2535 (Diamond) · EIP-1014 (CREATE2) · ERC-1967

---

## Layout

```
src/
├── Diamond.sol                    Core Diamond proxy (EIP-2535)
├── facets/
│   ├── DiamondCutFacet.sol        Required: facet add/replace/remove
│   ├── DiamondLoupeFacet.sol      Required: introspection
│   ├── OwnershipFacet.sol         ERC-173 ownership
│   └── MultiplyFacet.sol          Example business-logic facet
├── factory/
│   └── GardenFactory.sol          CREATE2 factory deploying Garden Diamonds at deterministic addresses
├── registry/
│   ├── FacetRegistry.sol          Allow-list gate for facets eligible to be cut into a Diamond
│   └── LiquidityPoolRegistry.sol  Tracks supported DEX liquidity pools across chains
├── libraries/
│   └── LibDiamond.sol             Diamond storage + cut logic
└── upgradeInitializers/
    └── DiamondInit.sol            Per-Diamond initializer pattern
```

---

## Why a Facet Registry?

Vanilla EIP-2535 lets the Diamond owner cut any contract address as a facet at any time. That's powerful and dangerous — a malicious or buggy facet can be wired into a live Diamond in one transaction.

`FacetRegistry` adds a gate in front of every cut:

- Facets must be **pre-registered with their selectors** before they're eligible to be added
- Selectors are tracked globally to prevent collisions across facets
- Removal and replacement flow through the same checks
- Emits events for every state change so the registry is fully auditable off-chain

This version is owner-controlled for clarity; the production deployment at Blok Capital wraps the registry behind a governance module so adds/removes/replaces require a passed proposal.

## Why a Garden Factory?

Wealth-management products need **predictable addresses before deployment** — for indexing, off-chain accounting, and cross-chain message routing.

`GardenFactory`:

- Uses CREATE2 to deploy each "Garden" Diamond at an address derived from `(salt, init-code hash)`
- Each deployed Diamond starts pre-cut with a validated set of facets pulled from the `FacetRegistry`
- Deterministic addresses survive identically across chains, simplifying multi-chain rebalancing

## Why a Liquidity Pool Registry?

The Diamond's strategy facets need to know which DEX pools are safe to route through. `LiquidityPoolRegistry` tracks `(poolAddress, pairName, dexId)` tuples in a single source of truth — strategy facets read from it instead of hardcoding pool addresses.

---

## Build & test

```bash
forge install
forge build
forge test -vv
```

Test suites in `test/`:

| File | What it covers |
|------|----------------|
| `DiamondTests.t.sol` | Core Diamond cut, loupe, and ownership |
| `FacetRegistryTests.t.sol` | Register/remove/replace flows + selector collision |
| `LiquidityPoolRegistryTests.t.sol` | Pool registration across DEXes |
| `MultiplyFacetTests.t.sol` | Example facet wired through the proxy |
| `GardenFactory.t.sol` | CREATE2 deployment, deterministic addresses, initial cut |

---

## Related work

- [Prism](https://github.com/jayeshy14/Prism) — my draft ERC for a successor proxy pattern that addresses the limitations of EIP-2535 (storage collisions, no native governance, no per-call integrity checks).

## License

MIT
