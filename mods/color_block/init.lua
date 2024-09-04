local colors = {"Red", "Orange", "Yellow", "Green", "Blue"}
local map = {}
local GAME_AREA_DIST = 40
local LOBBY_SIZE = 10
local GAME_SIZE = 10
local start_game = nil
local ready = false
for i = 0, 4 do
    minetest.register_node('color_block:stone_'..i, {
        description = 'Color Block Node: ' .. colors[i+1],
        tiles = { 'color_block'.. i ..'.png' },
        is_ground_content = true
    })
end
minetest.register_node('color_block:default', {
    description = 'Color Block Default',
    tiles = { 'color_block_default.png' },
    is_ground_content = true
})

for _, node in pairs(minetest.registered_nodes) do
    minetest.override_item(node.name, {
        groups = {}
    })
end

local function win_check()
    local winner = nil
    local n_standing = 0
    for _, player in pairs(minetest:get_connected_players()) do
        local meta = player:get_meta()
        if meta:get_int("in_game") == 1 then
            winner = player:get_player_name()
            n_standing = n_standing + 1
        end
    end
    if n_standing == 1 then
        return winner
    elseif n_standing == 0 then
        return "Nobody"
    else
        return nil
    end
end

local function reset_game_area()
    local size = GAME_SIZE*2
    local min_x = -size/2
    local min_z = -size/2
    local max_x = size/2
    local max_z = size/2
    map = {}
    for  x = min_x, max_x, 2 do
        for  z = min_z, max_z, 2 do
            local pos = {x=x, y=0, z=z-GAME_AREA_DIST}
            local i = math.random(0,4)
            minetest.swap_node(pos, {name='color_block:stone_'..i})
            map[x..":"..z] = i
        end
    end
end

local function remove_all_not(color)
    local size = GAME_SIZE*2
    local min_x = -size/2
    local min_z = -size/2
    local max_x = size/2
    local max_z = size/2
    for  x = min_x, max_x, 2 do
        for  z = min_z, max_z, 2 do
                local pos = {x=x, y=0, z=z-GAME_AREA_DIST}
                local i = map[x..":"..z]
                if i ~= color then
                    minetest.swap_node(pos, {name="air"})
                end
        end
    end
end

local function end_game(winner)
    minetest.chat_send_all(winner .. " wins the game!")
    for _, player in pairs(minetest:get_connected_players()) do
        local meta = player:get_meta()
        local in_game = meta:get_int("in_game") == 1
        if in_game then
            meta:set_int("in_game", 0)
            player:set_pos({x=0, y=5, z=0})
        end
   end
   ready = false
end

local function count_in_start(n)
    minetest.chat_send_all("The game will start in " .. n .. " seconds!")
    if n > 1 then
        minetest.after(1, count_in_start, n-1)
    end
end

local function spawn_players()
    for _, player in pairs(minetest:get_connected_players()) do
         local x_shift = math.random(0, GAME_SIZE)*2-GAME_SIZE
         local z_shift = math.random(0, GAME_SIZE)*2-GAME_SIZE
         player:set_pos({x=0+x_shift, y=1, z=-GAME_AREA_DIST+z_shift})
         local meta = player:get_meta()
        meta:set_int("in_game", 1)
    end
 end

minetest.register_on_joinplayer(function(player, last_login)
    player:set_pos({x=0,y=5,z=0})
    start_game()
end)

minetest.register_globalstep(function(dtime)
    for _, player in pairs(minetest:get_connected_players()) do
        local pos = player:get_pos()
        if pos.y < -30 then
            local meta = player:get_meta()
            meta:set_int("in_game", 0)
            player:set_pos({x=0, y=4, z=0})
        end
    end
end)

local function game_loop(seconds)
    reset_game_area()
    local color = math.random(0,4)
    minetest.chat_send_all("Get to " .. colors[color+1] .. "!")
    minetest.after(seconds, remove_all_not, color)
    minetest.after(seconds+3, function()
        local winner = win_check()
        if not winner then
            game_loop(seconds-0.5)
        else
            end_game(winner)
            minetest.after(10, start_game)
        end
    end)    
end

minetest.after(1, function() 
    reset_game_area()
    for x = -LOBBY_SIZE/2, LOBBY_SIZE/2 do
        for z = -LOBBY_SIZE/2, LOBBY_SIZE/2 do
            minetest.set_node({x=x, y=0, z=z}, {name="color_block:default"})
        end
    end
end)

start_game = function()
    local n_players = #minetest.get_connected_players()
    if n_players > 1 and not ready then
        ready = true
        count_in_start(5)
        minetest.after(5, function()
            spawn_players()
            game_loop(5)
        end)
    end
    if n_players == 1 then
        minetest.chat_send_all("Waiting for more players... Invite your friends!")
    end
end