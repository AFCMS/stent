stent = {}
stent.start_location = vector.new(0,0,0) -- to override in mods.
--  Players are placed here when they join.
stent.place_spawn_schematic = function() end


local storage = minetest.get_mod_storage()

-- gets next unique (to the world) id and makes sure it will never be returned again.
local get_next_uid = function ()
    local uid = storage:get_int("id") or 0
    storage:set_int("id",uid+1)
    return uid
end

stent.set_load_time = function(mod_name, time)
    arena_lib.mods[mod_name].load_time = time
end

function stent.create_arena(mod_name, arena_name)
    arena_lib.create_arena("", mod_name, arena_name)
    arena_lib.set_entrance_type("", mod_name, arena_name, "formspec_entrace")
    arena_lib.set_entrance("", mod_name, arena_name, "add")
end

function stent.set_arena_props(mod_name, arena_name, props)
    if props.pos1 and props.pos2 then
        arena_lib.set_region("", mod_name, arena_name, pos1, pos2)
    end
    if props.min_players and props.max_players then
        arena_lib.change_players_amount("sender", mod_name, arena_name, min_players, max_players)
    end
    -- set the return point to the spawn point:
    props.custom_return_point = stent.start_location

    -- set arena properties:
    for prop_name,val in pairs(props) do
        if prop_name ~= "pos1" and prop_name ~= "pos2" and prop_name ~= "min_players" and prop_name ~= "max_players" then
            arena_lib.change_arena_property("",  mod_name, arena_name, prop_name, val)
        end
    end
    
end

function stent.enable_arena(mod_name,arena_name)
    arena_lib.enable_arena("", mod_name, arena_name, false)
end


-- Arena lib entrance registration

arena_lib.register_entrance_type("stent", "formspec_entrace", {
    -- (string) the name of the entrance. Contrary to the previous entrance field, this can be translated
    name = "formspec_entrace",
    -- must return the value that will be used by arena_lib to identify the
    -- entrance. For instance, built-in signs return their position. If nothing
    -- is returned, the adding process will be aborted. Substitute ... with any
    -- additional parameters you may need (signs use it for their position).
    -- BEWARE: arena_lib will already run general preliminar checks (e.g. the
    -- arena must exist) and then set the new entrance. Use this callback just
    -- to run entrance-specific checks and return the value that arena_lib will
    -- then store as an entrance

    on_add = function (sender, mod, arena)
        local uid = get_next_uid()
        return uid
    end,

    -- additional actions to perform when an arena entrance is removed. BEWARE:
    -- arena_lib will already run general preliminar checks (e.g. the arena must
    -- exist) and then remove the entrance. Use this callback just to run
    -- entrance-specific checks.

    on_remove = function (mod, arena)
        return
    end,
    
    -- what should happen to each entrance when the status of the associated
    -- arena changes (e.g. when someone enters, when the arena gets disabled
    -- etc.)

    on_update =function (mod, arena)
        -- TODO: send updated formspecs
        stent.refresh_formspecs()
    end,

    -- additional actions to perform when the server starts. Useful for nodes,
    -- since they don't have an on_activate callback, contrary to entities
    on_load = function (mod, arena)
        -- stent.on_load()
        -- stent.refresh_formspecs()
    end,

    editor_settings = {
        -- the name of the item representing the section
        name = "none",
        -- the image of the item representing the section
        icon = "blank.png",
        -- the description of the section, shown in the semi-transparent black
        -- bar above the hotbar
        description = "No settings for Formspec Entrance",
        -- must return a table containing the name of the items that shall be
        -- put into the editor section once opened. Max 6 entries. Contrary to a
        -- table, the function allows to dynamically change the given items
        -- according to external factors (e.g. a specific arena property)
        items = function() return {} end,
        -- called when entering the editor. Useful to reset entrance properties
        -- bound to p_name, as it's the only way the player has to know that the
        -- editor has been entered by someone
        on_enter = function (p_name, mod, arena)
            return
        end,
    },
    -- what the debug log should print (via arena_lib.print_arena_info())
    debug_output = function (entrace)
        return "debug"
    end,
})


stent.saved_arenas_data = {}

function stent.build_mainmenu_formspec(p_name, arenas_data) 
    return ""
end

stent.refresh_formspecs = function ()

    -- first, get the data needed to refresh the formspecs

    -- arena_lib.mods[yourmod].arenas
    local arenas_data = {}
    for modname, moddata in pairs(arena_lib.mods) do
        local arenas = moddata.arenas
        for arena_id, arena in pairs(arenas) do
            if arena.entrance_type == "formspec_entrace" then
                table.insert(arenas_data, {
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
                })
            end
        end
    end

    -- save this so if new players join we dont have to refresh everyone's formspecs
    stent.saved_arenas_data = arenas_data

    -- next, call the function to build the formspec, passing the data
    for _, player in pairs(minetest.get_connected_players()) do
        local p_name = player:get_player_name()
        if not(arena_lib.is_player_in_arena(p_name)) then
            local fs = stent.build_mainmenu_formspec(p_name, arenas_data)
            player:set_inventory_formspec(fs)
            minetest.show_formspec(p_name,"",fs)
        end
    end
end


-- we will set the inventory formspec to be the main menu, and automatically
-- open it. We should save the old inventory formspecs and renew them before
-- players enter the minigame, to avoid changing the gameplay and prevent
-- players from accessing the main menu while in the game. When players enter a
-- minigame, we close the main menu and reset their inventory to the default.
local old_inventory_formspecs = {}

local function set_main_menu(p_name)
    local player = minetest.get_player_by_name(p_name)
    old_inventory_formspecs[p_name] = player:get_inventory_formspec()
    if player then 
        local fs = stent.build_mainmenu_formspec(p_name,stent.saved_arenas_data)
        player:set_inventory_formspec(fs)
        minetest.show_formspec(p_name, "", fs)
    end
end

local function unset_main_menu(p_name) 
    minetest.close_formspec(p_name, "")
    local player = minetest.get_player_by_name(p_name)
    if player then
        player:set_inventory_formspec(old_inventory_formspecs[p_name])
    end
end

arena_lib.register_on_load(function(mod, arena)
    for p_name, data in pairs(arena.players) do
        unset_main_menu(p_name)
    end
end)

arena_lib.register_on_end(function(mod, arena, winners, is_forced) 
    for p_name, data in pairs(arena.players) do
        set_main_menu(p_name)
    end
end)

arena_lib.register_on_quit(function(mod, arena, p_name, is_spectator, reason) 
    set_main_menu(p_name)
end)


minetest.register_on_joinplayer(function(player, last_login)
    local p_name = player:get_player_name() 
    player:set_pos(stent.start_location)
    set_main_menu(p_name)
end)


minetest.register_on_mods_loaded(function()
    stent.refresh_formspecs()
end)
