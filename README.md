# stent
Adds a new arena entrance for arena_lib that can be implemented in a formspec. 

Override `stent.build_mainmenu_formspec(p_name, arenas_data)` to make your custom main menu.

An example main menu is included. `p_name` is the player who views the main menu.

`arenas_data` is a table containing arena data tables with the following attributes:

```lua
{
    name = arena.name,
    mod = modname,
    icon = moddata.icon,
    players_inside = #arena.players,
    max_players = arena.max_players,
    in_queue = arena.in_queue,
    in_loading = arena.in_loading,
    in_game = arena.in_game,
    in_celebration = arena.in_celebration,
    enabled = arena.enabled,
}
```

The main menu needs to list all arenas included in arenas_data, and provide a button that allows to join an arena. Call `arena_lib.join_queue(mod, arena, p_name)` when the player presses the appropriate button.

Override `stent.start_location` (a position vector) to change the place that players spawn. When players spawn, they will be stuck to a slowly-revolving entity. Use the spawn schematic to create a spawn environment for the main menu.

Override `stent.place_spawn_schematic()` to change the schematic that gets placed and where/how it gets placed. This is called once on the first joinplayer after server start.