# Combat Snake

## Direction

Plain Snake is not interesting enough on its own. This prototype is moving toward a hybrid of:

- `Combat Snake`
- `singleplayer Slither`

The goal is to keep the easy-to-read Snake movement rule, but layer in:

- a much larger arena
- camera follow
- lots of food with different values
- enemy snakes entering from the edges
- combat and auto-attacks
- upgrade choices during runs

## Core Loop

1. Move through a larger arena.
2. Eat food for score and XP.
3. Avoid crashing into walls, yourself, or enemy snakes.
4. Kill enemy snakes with weapons.
5. Dead enemy snakes burst into food.
6. Level up and choose upgrades.

## Planned Features

### Bigger Arena

- larger than the visible camera frame
- camera follows the player snake head
- keeps the run from feeling cramped

### Food

- multiple food values
- many food pickups on the board at once
- different colors / sizes for values
- food gives score and XP

### Enemy Snakes

- spawn from the edges
- move toward food and sometimes pressure the player
- die if they collide badly
- burst into food on death

### Combat

The snake becomes a moving weapon platform.

Baseline:

- simple head shot so combat exists immediately

Upgrade families:

- `Side Shots`
  - body segments fire left/right
- `Rear Shots`
  - tail fires backward
- `Beam Head`
  - head projects a beam forward
- `Orbit Bullets`
  - orbiting projectiles around the head
- `Poison Trail`
  - dropped hazard behind the snake
- `Front Fan`
  - extra angled head shots
- `Rapid Head`
  - faster head gun cadence
- `Food Magnet`
  - nearby food gets vacuumed in
- `Apple Burst`
  - eating food emits radial shots
- `Prop Breaker`
  - shots wreck trees and buildings faster
- `Boss Bounty`
  - bosses burst into richer rewards
- `Thorns`
  - enemies that cut into you get punished
- `Segment Armor`
  - body hits can burn armor instead of cutting you
- `Drill Head`
  - head bullets pierce through extra targets
- `Chain Head`
  - head bullets fork into nearby enemies
- `Harvester`
  - props and snakes spill more food/resources

### Upgrade Flow

- apples / kills give XP
- every few XP, pause and show 3 choices
- choices are run-defining upgrades, not small stat nudges

## Design Intent

This should feel less like classic Snake and more like:

- arcade movement puzzle
- survivable but dangerous arena
- run-building action game

The main reason to do it this way is to make the snake body matter as more than just a loss condition. The body should become a loadout.
