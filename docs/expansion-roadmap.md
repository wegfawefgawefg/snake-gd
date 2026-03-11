# Expansion Roadmap

## Big Direction

After the combat-snake prototype, the next expansion path is:

- chunk-based world growth
- biome-specific props and enemies
- named bosses
- segment-cutting combat where body damage matters

This roadmap is intentionally bigger than the current prototype. It represents where the idea could go, not a promise that this specific Godot repo should keep absorbing features forever.

## Current Prototype Status

Already in:

- chunked world generation around the player
- biome-specific chunk colors
- orchard / forest / city / swamp / desert / carnival / end biomes
- food with multiple XP values
- enemy snakes and named bosses
- body-cutting on enemy snakes
- `split_on_cut` on some enemies and bosses
- destructible trees / buildings / rocks / swamp pools
- biome events like raids, blooms, surges, and parades
- simple crafting resources and recipes
- a growing upgrade pool for player weapons

Still not in:

- true infinite persistence / long-distance world streaming
- full AI food competition between snakes
- true biome-specific enemy factions beyond the current archetypes
- deeper boss phases and custom boss attack scripts
- player body-part HP and head-only death rules
- caravans, shrines, or longer world events
- inventory / stash / meta progression
- a proper endgame spectacle or full Ender Dragon fight

## Practical Takeaway

The concept proved itself. The current codebase proved less compelling as a long-term foundation.

So the likely real path from here would be:

1. keep this repo as the design/reference sandbox
2. steal the best ideas from it
3. rewrite it in a faster, more explicit C+- architecture if the project ever becomes serious

## Next Upgrade Ideas

- chain lightning head
- mortar apples
- dash bite
- thorns on body contact
- turret segment
- shield segment
- parasite rounds
- freeze trail
- drill ram
- scavenger vacuum
- armor segments
- beam splitter
- clown minefield
- dragon meteor breath

## World

### Chunks

- generate chunks around the player
- keep chunk ownership simple and deterministic
- biome comes from chunk coordinate, not hand-authored maps

### Biomes

- orchard
  - trees
  - more apples
  - fruit-heavy bosses
- forest
  - clutter
  - ambush snakes
- city
  - buildings
  - soldier snakes
- swamp
  - poison terrain
  - rot hazards
- desert
  - sparse food
  - hardier enemies

## Combat Direction

- head hits kill snakes
- body hits cut snakes
- tail section can die or split
- some enemies should be `split_on_cut`
- bosses should survive body damage longer and force head kills

## Props

- trees that burst apples
- buildings that break into bigger food rewards
- swamp pools as hazards
- later: crates, rocks, shrines

## Bosses

Named bosses should have:

- visible name
- unique color
- unique movement / pressure pattern
- biome tie-in

Examples:

- Orchard King
- Warden Coil
- Spiral Maw
- Ashmouth
