# Car audit: reference screenshots against the in-game lineup

Source: the 56 sample screenshots in the shared Drive folder (some are the same car from two angles).
Every in-game car is a fictional paper-craft design with a made-up name; the references are used for silhouette and
proportion only, never for names, badges or liveries.

How the cars are built: each body style is a parameter set (`CarModel.STYLES`) for a folded-paper body, a cabin with
printed windows, box arches, wings and lamps. A "new look-alike" below is a new parameter set plus a new fictional car in
`Catalog.cars()`.

## Result summary

- Existing cars checked against the references: all 19.
- Close enough to keep unchanged: 13 (the silhouette and the key features match: the stance, the wing, the arches).
- New look-alike cars added: 12 (new body styles, new made-up names).
- Not replicated exactly: real badges, sponsor prints and exact livery artwork (deliberately).

## Matrix: reference to in-game car

| Ref | What it is (silhouette) | In-game match | Action |
| --- | --- | --- | --- |
| 1 | Boxy two-door saloon, rear spoiler, four lamps | Comet 1600 (escort) | Kept: matches stance and flares |
| 2, 53 | Long wedge coupe, low nose, fastback | Mirage M (m1) | New |
| 3, 15 | Short mid-engined hatch, big arches, roof wing | Lince T16 | Kept |
| 4, 23 | Boxy four-wheel-drive coupe, huge wing | Tempest S1 | Kept |
| 5, 6, 17, 39, 40 | Hill-climb specials: wide, low, huge wing, splitter | Summit Special (pikes) | New |
| 7 | Rallycross hatch, wide arches, tall wing | Lynx Turbo (wrc) | Kept |
| 8, 9 | Electric off-road buggy / SUV on big tyres | Sandhopper / Badger 4x4 | Kept |
| 10, 47 | Rear-engined berlinette, round lamps | Verbena A100 (berlinette) | New |
| 11 | Modern Rally1 hybrid hatch | Vortex R1 | Kept |
| 12, 18 | Four-door rally saloon, scoop, tall wing | Nimbus Turbo | Kept |
| 13, 30 | Short wedge with wraparound screen | Stiletto HF | Kept |
| 14, 51 | Stubby four-wheel-drive brick, big rear wing | Marmot 6R (sixr4) | New |
| 16, 19 | Four-wheel-drive coupe-hatch, scoop, wing | Celeste GT-4 (celica) | New |
| 20, 21 | Boxy off-road wagon | Badger 4x4; Drover 60 (patrol) | Drover 60 new; Badger kept |
| 22 | Long-nose fastback coupe with wide arches | Gazelle GT (capri) | New |
| 24, 27 | Rear-engined bug | Scarab 1300 (beetle) | New |
| 25, 26 | Touring coupe, quad lamps | Alder 328 (e36) | New |
| 28 | Mid-engined Group B coupe with big wing | Strega B | Kept |
| 29, 33 | Square five-door hatch | Quadra Evo | Kept |
| 31, 48, 49 | Boxy fastback / saloon, rally lamps | Comet 1600 / Ventura 60 | Kept (closest match) |
| 32 | Wedge coupe | Mirage M | New (shared) |
| 34, 50 | Hatchback coupe | Gallo V6 (gtv6) | New |
| 35 | Small two-door coupe | Ventura 60 | Kept |
| 36, 54 | Tiny box hatch with spot lamps | Pip 1300 | Kept |
| 37 | Hatch-saloon with big wing | Cormorant RS (cossie) | New |
| 38 | Hatch-saloon | Cormorant RS | New (shared) |
| 41, 43, 44, 45 | Modern hatches | Fennec R2 / Lynx Turbo | Kept |
| 42 | Square hatch with roof wing | Quadra Evo | Kept |
| 46 | Small mid-engined hatch with box arches | Rook Turbo (r5) | New |
| 52 | Long fastback GT with wing | Mirage M / Gazelle GT | New (shared) |

## Visual Diff Tables (new cars)

Each table follows the eight rows the brief asks for. "Pass" means the parameter set now matches the reference silhouette
at paper-craft fidelity (box arches, folded planes); exact curvature is not attempted.

### Scarab 1300 (beetle) vs refs 24, 27
| Feature | Reference | Game model | Action |
| --- | --- | --- | --- |
| Silhouette | Short, round, high roof, tiny nose | L 3.75, roof 0.62, nose 0.46 | Pass |
| Body angles | Soft, compound curves | Folded planes, steep rear fastback (back 0.78) | Approximate |
| Wheels and arches | Round arches, small wheels | wr 0.34, box flares | Pass |
| Glasshouse | Tall, small, rounded | cab 0.62, short bonnet | Pass |
| Lights | Round, high on the wings | Round lamps | Pass |
| Grille and intakes | None at the front | Plain nose | Pass |
| Doors, handles, mirrors | Two doors, wing mirrors | Standard | Pass |
| Aero and rally parts | Rear lid spoiler, bumper bars | Ducktail, chrome bumpers | Pass |

### Alder 328 (e36) vs refs 25, 26
| Feature | Reference | Game model | Action |
| --- | --- | --- | --- |
| Silhouette | Compact coupe, short deck | L 4.2, deck 0.75 | Pass |
| Body angles | Crisp creases, shark nose | Folded planes | Pass |
| Wheels and arches | Flush arches | arches off | Pass |
| Glasshouse | Even glass, gentle C-pillar | cab 0.52, back 0.45 | Pass |
| Lights | Four round lamps | Quad lamps | Pass |
| Grille and intakes | Twin-kidney | Plain nose (not replicated) | Skipped on purpose |
| Doors, handles, mirrors | Two doors | Standard | Pass |
| Aero and rally parts | Boot-lip spoiler | boot | Pass |

### Gazelle GT (capri) vs ref 22
| Feature | Reference | Game model | Action |
| --- | --- | --- | --- |
| Silhouette | Very long nose, short cabin | bon 1.55, cab 0.46 | Pass |
| Body angles | Fastback with a ducktail | back 0.7, ducktail | Pass |
| Wheels and arches | Bolt-on flares | arches on | Pass |
| Glasshouse | Low, long | cab_r -1.0 | Pass |
| Lights | Rectangular | rect | Pass |
| Grille and intakes | Wide, shallow | Plain | Approximate |
| Doors, handles, mirrors | Two long doors | Standard | Pass |
| Aero and rally parts | Ducktail | ducktail | Pass |

### Cormorant RS (cossie) vs refs 37, 38
| Feature | Reference | Game model | Action |
| --- | --- | --- | --- |
| Silhouette | Hatch-saloon, wide stance | L 4.4, W 1.8 | Pass |
| Body angles | Sloping rear glass | back 0.5 | Pass |
| Wheels and arches | Flared arches | arches on | Pass |
| Glasshouse | Even, raked | rake 0.48 | Pass |
| Lights | Rectangular, aux pod | rect + pod | Pass |
| Grille and intakes | Slim | Plain | Approximate |
| Doors, handles, mirrors | Four doors | Standard | Pass |
| Aero and rally parts | Tall wing | big | Pass |

### Summit Special (pikes) vs refs 5, 6, 17, 39, 40
| Feature | Reference | Game model | Action |
| --- | --- | --- | --- |
| Silhouette | Very wide, low, long | W 2.1, low 0.5, L 4.5 | Pass |
| Body angles | Aero-sculpted | Folded planes | Approximate |
| Wheels and arches | Huge flared arches | arches on | Pass |
| Glasshouse | Small, low | cab 0.44 | Pass |
| Lights | Quad | quad | Pass |
| Grille and intakes | Bonnet vents, splitter | scoop + louvres | Pass |
| Doors, handles, mirrors | Two doors | Standard | Pass |
| Aero and rally parts | Enormous rear wing | huge | Pass |

### Verbena A100 (berlinette) vs refs 10, 47
| Feature | Reference | Game model | Action |
| --- | --- | --- | --- |
| Silhouette | Small, swooping fastback | L 3.8, back 0.82 | Pass |
| Body angles | Smooth, flared haunches | arches on | Approximate |
| Wheels and arches | Rounded, wide rear | arches on | Pass |
| Glasshouse | Low, wraps to the tail | cab 0.45 | Pass |
| Lights | Big round lamps, pair on the nose | round + pod | Pass |
| Grille and intakes | Small lower intake | Plain | Approximate |
| Doors, handles, mirrors | Two doors | Standard | Pass |
| Aero and rally parts | None | none | Pass |

### Gallo V6 (gtv6) vs refs 34, 50
| Feature | Reference | Game model | Action |
| --- | --- | --- | --- |
| Silhouette | Wedge hatchback coupe | L 4.2, deck 0.3 | Pass |
| Body angles | Long, low nose | nose 0.42 | Pass |
| Wheels and arches | Subtle flares | arches on | Pass |
| Glasshouse | Wraparound, large hatch | back 0.62 | Pass |
| Lights | Rectangular | rect + pod | Pass |
| Grille and intakes | Shield grille | Plain | Approximate |
| Doors, handles, mirrors | Two doors | Standard | Pass |
| Aero and rally parts | Small lip | small | Pass |

### Mirage M (m1) vs refs 2, 32, 52, 53
| Feature | Reference | Game model | Action |
| --- | --- | --- | --- |
| Silhouette | Low wedge, long nose | nose 0.2, low 0.45 | Pass |
| Body angles | Sharp flat planes | Folded planes | Pass |
| Wheels and arches | Wide arches | arches on | Pass |
| Glasshouse | Small, set back | cab_f 0.4 | Pass |
| Lights | Pop-up | popup | Pass |
| Grille and intakes | Slim, vented rear | louvres | Pass |
| Doors, handles, mirrors | Two doors | Standard | Pass |
| Aero and rally parts | Ducktail | ducktail | Pass |

### Rook Turbo (r5) vs ref 46
| Feature | Reference | Game model | Action |
| --- | --- | --- | --- |
| Silhouette | Short hatch, heavy rear | L 3.6, deck 0.12 | Pass |
| Body angles | Boxy with huge rear flares | arches on | Pass |
| Wheels and arches | Wide rear arches | arches on | Pass |
| Glasshouse | Upright | cab 0.62 | Pass |
| Lights | Rectangular + pod | rect + pod | Pass |
| Grille and intakes | Side intakes | louvres | Pass |
| Doors, handles, mirrors | Two doors | Standard | Pass |
| Aero and rally parts | Roof spoiler | roof | Pass |

### Marmot 6R (sixr4) vs refs 14, 51
| Feature | Reference | Game model | Action |
| --- | --- | --- | --- |
| Silhouette | Short, tall, square | L 3.4, cab 0.64 | Pass |
| Body angles | Slab sides, flared | arches on | Pass |
| Wheels and arches | Wide | arches on | Pass |
| Glasshouse | Upright, near-vertical | rake 0.3 | Pass |
| Lights | Row of round spot lamps | round + pod | Pass |
| Grille and intakes | Low intake | louvres | Approximate |
| Doors, handles, mirrors | Two doors | Standard | Pass |
| Aero and rally parts | Large rear wing | big | Pass |

### Celeste GT-4 (celica) vs refs 16, 19
| Feature | Reference | Game model | Action |
| --- | --- | --- | --- |
| Silhouette | Coupe-hatch | L 4.3, back 0.6 | Pass |
| Body angles | Rounded, sloping nose | nose 0.4 | Approximate |
| Wheels and arches | Flared | arches on | Pass |
| Glasshouse | Wraparound, fastback | cab 0.5 | Pass |
| Lights | Round pair | rect | Approximate |
| Grille and intakes | Bonnet scoop | scoop | Pass |
| Doors, handles, mirrors | Two doors | Standard | Pass |
| Aero and rally parts | Tall wing | big | Pass |

### Drover 60 (patrol) vs refs 20, 21
| Feature | Reference | Game model | Action |
| --- | --- | --- | --- |
| Silhouette | Tall boxy wagon | low 0.8, L 4.5 | Pass |
| Body angles | Slab sides, upright | back 0.03 | Pass |
| Wheels and arches | Big tyres, flares | wr 0.47 | Pass |
| Glasshouse | Tall, five side windows | cab 0.7, cab_r -2.1 | Pass |
| Lights | Round, spot lamps on the bar | round + pod | Pass |
| Grille and intakes | Flat | Plain | Pass |
| Doors, handles, mirrors | Four doors | Standard | Pass |
| Aero and rally parts | Roof rack, bull bar | chrome bumpers (roof rack not added) | Partial |

## Not done

- Exact grille shapes from reference artwork (shapes are now per style: oval, kidney, shield, mesh, bars, slim, none).
- Roof racks: Drover 60 / Badger 4x4 (full rack, spare wheel, kit), Otter Estate (rails), Beetle (light rack). Bull bars: Drover 60, Badger 4x4, Mule truck.
- Per-car liveries drawn from the reference artwork (deliberately avoided).
- A pixel-level check from front, side and rear camera angles for every car; the checks above are silhouette and
  proportion checks by parameter, plus a lineup render.
