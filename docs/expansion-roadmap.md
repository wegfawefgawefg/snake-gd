# Expansion Roadmap

## Big Direction

After the combat-snake prototype, the next expansion path is:

- chunk-based world growth
- biome-specific props and enemies
- named bosses
- segment-cutting combat where body damage matters

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
