# Years to Spare

A 2D action-platformer in **Godot 4.7**.

## Status

Skeleton only. The structure below runs; the gameplay is what gets built on top.

## Running

Open in Godot 4.7 and press F5. Main scene is `src/levels/logo.tscn`; the
playable level is `src/levels/level_01.tscn`.

## Structure

```
autoload/
  event_bus.gd        global signals — the only way systems talk to each other
  time_service.gd     world time: normal / stopped / slowed / rewinding
  game_state.gd       current phase, unlocked abilities
src/
  core/
    state.gd          one behaviour; returns the next state's name
    state_machine.gd  runs its State children
    time_body_2d.gd   CharacterBody2D that obeys TimeService
  components/
    health_component.gd
    age_component.gd
    time_powers.gd
  actors/
    player/           controller + Idle / Move / Air states
                      player_frames.tres  the clip library
                      player_animator.gd  state -> clip, and sprite flipping
    enemy/            base class to subclass
  world/platform.gd
  levels/level.gd
  ui/hud.gd
```

## The one rule

`Engine.time_scale` is never touched. The world advances on
`TimeService.world_delta(delta)`; the player advances on the real delta. That is
what lets the boy keep moving while everything else is frozen.

Anything the time powers should affect extends `TimeBody2D` or asks
`TimeService` for its delta. Anything else uses the raw delta.

## Where to add things

| To add | Do this |
| --- | --- |
| A player ability | New `State` script under `src/actors/player/states/`, add as a child of `StateMachine` |
| An animation for a state | Add the clip to `player_frames.tres`, then map it in `PlayerAnimator.STATE_CLIPS` |
| An enemy type | Extend `Enemy`, implement `_tick(delta)` |
| A UI reaction | Add a signal to `EventBus` and listen for it |
| A phase | Add an entry to `GameState.LEVELS` |
