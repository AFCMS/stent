# stent
Adds a new arena entrance for arena_lib that can be implemented in a formspec. 

An example main menu is included.

# How to use: 

## 1. Create a map using modgen. 

Use modgen: https://content.minetest.net/packages/BuckarooBanzay/modgen/
to create a map that loads in the game.

To do that, load up a minetest world with `singlenode` mapgen and:
- a mod that adds the nodes for your game
- worldedit
- the modgen mod

Then, build a spawn location and arenas in the world at the places you want those arenas to appear in the game. Write down the coordinates of: 

- the spawn location
and for each arena,
- player spawner locations for when a player starts the match (exactly the number of max_players for each arena, and double that if there are teams)
- arena pos1 and pos2 which define arena bounds, if applicable
- any other positions your specific minigame requires

Now export the world as a mod:
set worldedit pos 1 and worldedit pos2 (`//pos1`, `//pos2`) to encompass the entirety of your builds
send the modgen command `/export`

Now, collect your new mapgen mod: it is in the world folder. It is a folder called `modgen_mod_export`. That is your mapgen mod. Copy it into your game.

Next, we will create your setup mod:

## 1. Set spawn location.

Override stent.spawn_location.

Example: 

```lua 
stent.start_location = vector.new(7,-10,0)
```


## 2. Create, setup and enable arenas in on_mods_loaded

There are three api functions to know about:

To create an arena:
`stent.create_arena(mod_name, arena_name)`

Example:
```lua
stent.create_arena("balloon_bop", "redBox", min_players, max_players, pos1, pos2)
```

To set the properties of that arena:
`stent.set_arena_props(mod_name, arena_name, props)`

`props` is a table with the properties to set. 

`props.pos1` and `props.pos2` are the arena boundary positions. Define them if applicable.
`props.min_players` and `props.max_players` are required. Set both to `1` if this is a single-player only minigame. 

`props.spawnpoints` are required, and should be the number of `max_players`. Example:
```lua
props.spawn_points = {
    vector.new(69,-7,1),
    vector.new(72,-7,0),
},
``` 
Include any other properties your minigame requires.

Example:

```lua
stent.set_arena_props("balloon_bop", "redBox", {
    -- required properties:
    min_players = 1,
    max_players = 2,
    pos1 = vector.new(77,-16,7),
    pos2 = vector.new(62,14,-8),
    spawn_points = {
        vector.new(69,-7,1),
        vector.new(72,-7,0),
    },
    -- minigame specific properties:
    balloon_spawner = vector.new(69,4,-1),
    starting_lives = 3,
    spawner_range = 2.5,
    player_die_level = -20,
    arena_radius = 15,
})
```

To set the start time of an arena:

`stent.set_load_time(mod_name,time)`

Example:
```lua
stent.set_load_time("balloon_bop",1) -- for one second start time
```

## 3. Create a main menu for your game

Override `stent.build_mainmenu_formspec(p_name, arenas_data)` to make your custom main menu.

 `p_name` is the player who views the main menu.

`arenas_data` is a table containing arena data tables with the following attributes:

It must return the formspec string.

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
You can use this to create a main menu.

See the example usage below.

## 4. Create the main menu `register_on_player_receive_fields`:

The main menu is the inventory formspec, but can also be sent by the mod, so the formname will either be an empty string or `main_menu` (`""` or `"main_menu"`).

The main menu needs to list all arenas included in arenas_data, and provide a button that allows to join an arena. Call `arena_lib.join_queue(mod, arena, p_name)` when the player presses the appropriate button, and `arena_lib.remove_player_from_queue(p_name)` to make them leave any queue.

## Example usage: 

mod.conf >

```
name = balloon_bop_init
description = Sets up balloon bop singleplayer
depends = arena_lib, stent, balloon_bop, formspec_ast
```

init.lua >

```lua
stent.start_location = vector.new(7,-10,0)
-- we load the map using modgen (see modgen_mod_export)
local mod_name = "balloon_bop"

minetest.register_on_mods_loaded(function ()

    -- create an arena:
    if not (arena_lib.get_arena_by_name(mod_name,"redBox")) then
        stent.create_arena(mod_name, "redBox")
    end

    -- set properties of an arena:
    stent.set_arena_props(mod_name, "redBox", {

        -- required properties:
        min_players = 1,
        max_players = 2,
        pos1 = vector.new(77,-16,7),
        pos2 = vector.new(62,14,-8),
        spawn_points = {
            vector.new(69,-7,1),
            vector.new(72,-7,0),
        },

        -- minigame specific properties:
        balloon_spawner = vector.new(69,4,-1),
        starting_lives = 3,
        spawner_range = 2.5,
        player_die_level = -20,
        arena_radius = 15,
    })
    -- enable an arena:
    stent.enable_arena(mod_name,"redBox")
end)



local player_menu_data = {}
-- Placeholder Main Menu Formspec
local function fs_tree_creator(p_name,arenas_data)
    local listelems = {}
    local menu_data = player_menu_data[p_name] or {}
    for i,arena_data in ipairs(arenas_data) do
        local str = "Waiting"
        if arena_data.in_queue then
            str = "Queueing"
        end
        if arena_data.in_loading then
            str = "Loading"
        end
        if arena_data.in_game then
            str = "In Progress"
        end
        if arena_data.in_celebration then
            str = "Finishing"
        end
        if arena_data.enabled == false then
            str = "Disabled"
        end
        local entry = arena_data.name .. "     " .. arena_data.players_inside .. "/" .. arena_data.max_players .. "     " .. str
        table.insert(listelems,entry)
    end
    local tree = {
        { type = "size", w = 10.5, h = 11, fixed_size = false },
        { type = "image", x = 0, y = 0, w = 10.5, h = 2.6, texture_name = "header.png" },
        { type = "button", x = 0, y = 3, w = 10.5, h = 0.8, name = "btn1", label = "Available Arenas" },
        { type = "textlist",
            x = 0, y = 3.8, w = 10.5, h = 3,
            name = "Arena_List_example",
            listelems = listelems,
            selected_idx = menu_data.selected_idx or 1,
            transparent = true},
        { type = "button", x = .3, y = 7.2, w = 3.1, h = 0.8, name = "join", label = "Join Queue" },
        { type = "button", x = 3.7, y = 7.2, w = 3.3, h = 0.8, name = "leave", label = "Leave Queue" },
        { type = "button", x = 7.1, y = 7.2, w = 3.1, h = 0.8, name = "spectate", label = "Spectate" },
    }
    return tree
end

function stent.build_mainmenu_formspec(p_name, arenas_data)
    local tree = fs_tree_creator(p_name,arenas_data)
    return formspec_ast.interpret(tree)
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= "" and formname ~= "main_menu" then return end
    local p_name = player:get_player_name()
    if fields.Arena_List_example then
        local evt = minetest.explode_textlist_event(fields.Arena_List_example)
        if evt.type == "CHG" then
            player_menu_data[p_name] = player_menu_data[p_name] or {}
            player_menu_data[p_name].selected_idx = evt.index
        end
    end
    if fields.join then
        if player_menu_data[p_name] and player_menu_data[p_name].selected_idx then
            local data = stent.saved_arenas_data[player_menu_data[p_name].selected_idx]
            local arena_id, arena = arena_lib.get_arena_by_name(data.mod,data.name)
            if arena.in_game then
                arena_lib.join_arena(data.mod, p_name, arena_id)
            else
                arena_lib.join_queue(data.mod, arena, p_name)
            end
        end
    end
    if fields.leave then
        arena_lib.remove_player_from_queue(p_name)
    end
    if fields.spectate then
        if player_menu_data[p_name] and player_menu_data[p_name].selected_idx then

            local data = stent.saved_arenas_data[player_menu_data[p_name].selected_idx]
            local arena_id, arena = arena_lib.get_arena_by_name(data.mod,data.name)
            local modref = arena_lib.mods[data.mod]

            if arena.in_game and modref.spectate_mode then
                arena_lib.join_arena(data.mod, p_name, arena_id,true)
            end

        end
    end
end)
```