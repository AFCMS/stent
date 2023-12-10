stent = {}
stent.start_location = vector.new(0,0,0) -- to override in mods.
--  Players are placed here when they join.
stent.on_load = function() end


local storage = minetest.get_mod_storage()

-- gets next unique (to the world) id and makes sure it will never be returned again.
local get_next_uid = function ()
    local uid = storage:get_int("id") or 0
    storage:set_int("id",uid+1)
    return uid
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

    on_add = function (sender, mod, arena, ...)
        local uid = get_next_uid()
        -- table.insert(stent.entrances, {
        --     entrance_uid = uid,
        --     players_inside = #arena.players,
        --     max_players = arena.max_players,
        --     in_queue = arena.in_queue,
        --     in_loading = arena.in_loading,
        --     in_game = arena.in_game,
        --     in_celebration = arena.in_celebration,
        --     enabled = arena.enabled,
        -- })
        return uid
    end,

    -- additional actions to perform when an arena entrance is removed. BEWARE:
    -- arena_lib will already run general preliminar checks (e.g. the arena must
    -- exist) and then remove the entrance. Use this callback just to run
    -- entrance-specific checks.

    on_remove = function (mod, arena)
        
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
        stent.on_load()
        stent.refresh_formspecs()
    end,

    -- editor_settings = {
    --     -- the name of the item representing the section
    --     name =,
    --     -- the image of the item representing the section
    --     icon =,
    --     -- the description of the section, shown in the semi-transparent black
    --     -- bar above the hotbar
    --     description =,
    --     -- must return a table containing the name of the items that shall be
    --     -- put into the editor section once opened. Max 6 entries. Contrary to a
    --     -- table, the function allows to dynamically change the given items
    --     -- according to external factors (e.g. a specific arena property)
    --     items =,
    --     -- called when entering the editor. Useful to reset entrance properties
    --     -- bound to p_name, as it's the only way the player has to know that the
    --     -- editor has been entered by someone
    --     on_enter = function (p_name, mod, arena)
            
    --     end,
    -- },
    -- what the debug log should print (via arena_lib.print_arena_info())
    debug_output = function (entrace)
        return "debug"
    end,
})

stent.saved_arenas_data = {}

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
            stent.build_mainmenu_formspec(p_name, arenas_data)
        end
    end
end




local first_join = true
local function do_first_join_setup()
    if first_join then
        first_join = false
        stent.place_spawn_schematic()
    end
end


-- Placeholder Main Menu Formspec
local function fs_tree_creator(arenas_data)
    local listelems = {}
    for i,arena_data in ipairs(arenas_data) do
        local str = "Queueing"
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
        { type = "image", x = 0, y = 0, w = 10.5, h = 2.6, texture_name = "stent_game_header.png" },
        { type = "button", x = 0, y = 3, w = 10.5, h = 0.8, name = "btn1", label = "Available Arenas" },
        { type = "textlist",
            x = 0, y = 3.8, w = 10.5, h = 3,
            name = "textlist1",
            listelems = listelems,
            selected_idx = 1,
            transparent = true},
        { type = "button", x = .3, y = 7.2, w = 3.1, h = 0.8, name = "join", label = "Join Queue" },
        { type = "button", x = 3.7, y = 7.2, w = 3.3, h = 0.8, name = "leave", label = "Leave Queue" },
        { type = "button", x = 7.1, y = 7.2, w = 3.1, h = 0.8, name = "spectate", label = "Spectate" },
    }
    return tree
end

function stent.build_mainmenu_formspec(p_name, arenas_data)
    local tree = fs_tree_creator(arenas_data)

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
    local player = minetest.get_player_name(p_name)
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

-- joinplayer is special. If it is the first joinplayer, then we will place the
-- schematic. We also set the player at the spawn location, attach them to the
-- slowly-spinning entity, and then do main menu stuff.

minetest.register_on_joinplayer(function(player, last_login)
    do_first_join_setup()

    local p_name = player:get_player_name() 

    player:set_pos(stent.start_location)
    player:set_attach()
    set_main_menu(p_name)
end)


-- spawn-attachment entity
minetest.register_entity("stent:spawnent",{
    initial_properties = {
        visual = "sprite",
        physical = false,
        hp_max = 32,
        textures = {"blank.png"},
        collisionbox = {-.1,-.1,-.1,.1,.1,.1},
        automatic_rotate = .26,
    },
    _timer = 0,
    on_step = function(self,dtime)
        self._timer = self._timer + dtime
        if self._timer >= 10 then
            local children = self.object:get_children() or {}
            if #children == 0 then
                self.object:remove()
            end
        end
    end,
})

