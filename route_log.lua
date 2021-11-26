--[[
to-do:
    add route logging to json (and route logging in general)
    implement a python script to export a jpg of the map with highlighted routes
    implement death %/win %
    add a way to export the routes to a webhost potentially
--]]
if not readfile("routes.json") then
    print("No routes.json file found, generating one from scratch")
    writefile("routes.json", "{}")
end

local json = require "json"
local vector = require "vector"
local trace = require "gamesense/trace"

local routes = json.parse(readfile("routes.json"))

local master = ui.new_checkbox("LUA", "B", "Log Routes")
local route_interpolation = ui.new_checkbox("LUA", "B", "Interpolate Routes")
local interpolation_scale = ui.new_slider("LUA", "B", "Interpolation Scale", 1, 64, 10, true, "t")
local interphelp = ui.new_label("LUA", "B", "Tip: If you're lagging decrease")
local interphelp2 = ui.new_label("LUA", "B", "the interpolation scale.")
local debug = ui.new_checkbox("LUA", "B", "Debug")
local debug_shape = ui.new_combobox("LUA", "B", "Debug Shape", {"Circle", "Square"})
local points = ui.new_slider("LUA", "B", "Points", 1, 3, 1, true)
local draw_all_logged_positions = ui.new_checkbox("LUA", "B", "Draw All Logged Positions")
local flush_on_round_end = ui.new_checkbox("LUA", "B", "Flush On Round End")
local flush_log = ui.new_button("LUA", "B", "Flush Log", function()
    routes = {}
    writefile("routes.json", json.stringify(routes))
end)

ui.set_visible(route_interpolation, false)
ui.set_visible(interpolation_scale, false)
ui.set_visible(interphelp, false)
ui.set_visible(interphelp2, false)
ui.set_visible(debug, false)
ui.set_visible(debug_shape, false)
ui.set_visible(points, false)
ui.set_visible(draw_all_logged_positions, false)
ui.set_visible(flush_on_round_end, false)
ui.set_visible(flush_log, false)

local function draw_circle_3d(x, y, z, radius, r, g, b, a, accuracy, width, outline, start_degrees, percentage, fill_r, fill_g, fill_b, fill_a)
	local accuracy = accuracy ~= nil and accuracy or 3
	local width = width ~= nil and width or 1
	local outline = outline ~= nil and outline or false
	local start_degrees = start_degrees ~= nil and start_degrees or 0
	local percentage = percentage ~= nil and percentage or 1

	local center_x, center_y
	if fill_a then
		center_x, center_y = renderer.world_to_screen(x, y, z)
	end

	local screen_x_line_old, screen_y_line_old
	for rot=start_degrees, percentage*360, accuracy do
		local rot_temp = math.rad(rot)
		local lineX, lineY, lineZ = radius * math.cos(rot_temp) + x, radius * math.sin(rot_temp) + y, z
		local screen_x_line, screen_y_line = renderer.world_to_screen(lineX, lineY, lineZ)
		if screen_x_line ~=nil and screen_x_line_old ~= nil then
			if fill_a and center_x ~= nil then
				renderer.triangle(screen_x_line, screen_y_line, screen_x_line_old, screen_y_line_old, center_x, center_y, fill_r, fill_g, fill_b, fill_a)
			end
			for i=1, width do
				local i=i-1
				renderer.line(screen_x_line, screen_y_line-i, screen_x_line_old, screen_y_line_old-i, r, g, b, a)
				renderer.line(screen_x_line-1, screen_y_line, screen_x_line_old-i, screen_y_line_old, r, g, b, a)
			end
			if outline then
				local outline_a = a/255*160
				renderer.line(screen_x_line, screen_y_line-width, screen_x_line_old, screen_y_line_old-width, 16, 16, 16, outline_a)
				renderer.line(screen_x_line, screen_y_line+1, screen_x_line_old, screen_y_line_old+1, 16, 16, 16, outline_a)
			end
		end
		screen_x_line_old, screen_y_line_old = screen_x_line, screen_y_line
	end
end

local function flush()
    routes = {}
    writefile("routes.json", json.stringify(routes))
end

local lastupdate
local offset
local oldpos
local olderpos
local evenolderpos
local currentPos
local function doRoute()
    local me = entity.get_local_player()
    currentPos = {entity.get_origin(me)}
    local currentTick = globals.tickcount()
    if not entity.is_alive(me) then return end

    local map = globals.mapname()
    
    if not routes[map] then
        routes[map] = {}
        writefile("routes.json", json.stringify(routes))
    end

    if lastupdate == nil then
        lastupdate = currentTick
    end

    if oldpos == nil then
        oldpos = currentPos
    end

    if olderpos == nil then
        olderpos = currentPos
    end

    if evenolderpos == nil then
        evenolderpos = currentPos
    end

    if not ui.get(route_interpolation) then
        offset = 10   
    else
        offset = ui.get(interpolation_scale)
    end

    if currentTick >= lastupdate + offset then
        local velocity = vector(entity.get_prop(me, "m_vecVelocity"))
        if velocity:length2d() > 2 and (oldpos[1] ~= currentPos[1] or oldpos[2] ~= currentPos[2] or oldpos[3] ~= currentPos[3]) then
            if ui.get(debug) then
                client.log("Movement detected")
                client.log("Current Tick: " .. currentTick)
                client.log("Last Logged Position: " .. oldpos[1] .. " " .. oldpos[2] .. " " .. oldpos[3])
                client.log("Current Position X: " .. currentPos[1] .. " Y: " .. currentPos[2] .. " Z: " .. currentPos[3])
                client.log("Last update: " .. lastupdate)
            end
            lastupdate = currentTick
            evenolderpos = olderpos
            olderpos = oldpos
            oldpos = currentPos
            --routes[map].pos = currentPos

            table.insert(routes[map], {currentPos})
            writefile("routes.json", json.stringify(routes))
        end
    end
end

local function doPaint()
    if ui.get(debug) then
        if oldpos == nil then
            return
        end
        local map = globals.mapname()
        local local_player = entity.get_local_player()
        if ui.get(debug_shape) == "Circle" then            
            if ui.get(points) == 1 then
                draw_circle_3d(oldpos[1], oldpos[2], oldpos[3], 14, 255, 255, 255, 255, 3, 2, false, 0, 1, 255, 255, 255, 255*0.1)
            elseif ui.get(points) == 2 then
                draw_circle_3d(oldpos[1], oldpos[2], oldpos[3], 14, 255, 255, 255, 255, 3, 2, false, 0, 1, 255, 255, 255, 255*0.1)
                draw_circle_3d(olderpos[1], olderpos[2], olderpos[3], 10, 255, 255, 255, 255, 3, 2, false, 0, 1, 255, 255, 255, 255*0.1)
                local oldX, oldY = renderer.world_to_screen(oldpos[1], oldpos[2], oldpos[3])
                local olderX, olderY = renderer.world_to_screen(olderpos[1], olderpos[2], olderpos[3])
                renderer.line(oldX, oldY, olderX, olderY, 255, 255, 255, 255)
            elseif ui.get(points) == 3 then
                draw_circle_3d(oldpos[1], oldpos[2], oldpos[3], 14, 255, 255, 255, 255, 3, 2, false, 0, 1, 255, 255, 255, 255*0.1)
                draw_circle_3d(olderpos[1], olderpos[2], olderpos[3], 10, 255, 255, 255, 255, 3, 2, false, 0, 1, 255, 255, 255, 255*0.1)
                draw_circle_3d(evenolderpos[1], evenolderpos[2], evenolderpos[3], 6, 255, 255, 255, 255, 3, 2, false, 0, 1, 255, 255, 255, 255*0.1)
                local oldX, oldY = renderer.world_to_screen(oldpos[1], oldpos[2], oldpos[3])
                local olderX, olderY = renderer.world_to_screen(olderpos[1], olderpos[2], olderpos[3])
                local evenolderposX, evenolderposY = renderer.world_to_screen(evenolderpos[1], evenolderpos[2], evenolderpos[3])
                renderer.line(oldX, oldY, olderX, olderY, 255, 255, 255, 255)
                renderer.line(olderX, olderY, evenolderposX, evenolderposY, 255, 255, 255, 255)
            end
        else
            local src = vector(oldpos[1], oldpos[2], oldpos[3])
            local dest = src - vector(0, 0, 25)
            local tr = trace.line(src, dest, {skip = local_player, mask = "MASK_SHOT"})
            local end_pos = tr.end_pos
            if tr.plane.normal == vector(0,0,0) then
                tr.plane.normal = vector(0,0,1)
                end_pos = src
            end
            local right, up = tr.plane.normal:vectors()
            local size = 14
            local upper_left = end_pos + up * size + right * size
            local upper_right = end_pos + up * size - right * size
            local bottom_right = end_pos - up * size - right * size
            local bottom_left = end_pos - up * size + right * size
            local x1, y1 = renderer.world_to_screen(upper_left:unpack())
            local x2, y2 = renderer.world_to_screen(upper_right:unpack())
            local x3, y3 = renderer.world_to_screen(bottom_right:unpack())
            local x4, y4 = renderer.world_to_screen(bottom_left:unpack())
            renderer.line(x1, y1, x2, y2, 255, 255, 255, 255)
            renderer.line(x2, y2, x3, y3, 255, 255, 255, 255)
            renderer.line(x3, y3, x4, y4, 255, 255, 255, 255)
            renderer.line(x4, y4, x1, y1, 255, 255, 255, 255)
            renderer.triangle(x1, y1, x2, y2, x3, y3, 255, 255, 255, 255*0.1)
            renderer.triangle(x1, y1, x3, y3, x4, y4, 255, 255, 255, 255*0.1)
        end

        local x1, y1 = renderer.world_to_screen(oldpos[1], oldpos[2], oldpos[3])
        local x2, y2 = renderer.world_to_screen(entity.get_origin(local_player))
        renderer.text(x1, y1, 245, 255, 255, 255, "c", nil, "Last Logged Pos")
        renderer.line(x1, y1, x2, y2, 255, 255, 255, 255)

        if ui.get(draw_all_logged_positions) then
            for i = 1, table.maxn(routes[map]), 1 do
                local x, y = renderer.world_to_screen(routes[map][i][1][1], routes[map][i][1][2], routes[map][i][1][3])
                renderer.circle(x, y, 255, 255, 255, 255, 3, 0, 360)
                if i <= table.maxn(routes[map]) - 1 then
                    local x1, y1 = renderer.world_to_screen(routes[map][i+1][1][1], routes[map][i+1][1][2], routes[map][i+1][1][3])
                    renderer.line(x, y, x1, y1, 255, 255, 255, 255)
                end
            end
        end
    end
end

ui.set_callback(flush_on_round_end, function()
    if ui.get(flush_on_round_end) then
        client.set_event_callback("round_start", flush)
    else
        client.unset_event_callback("round_start", flush)
    end
end)

ui.set_callback(master, function(self)
    if ui.get(self) then
        client.set_event_callback("setup_command", doRoute)
        client.set_event_callback("paint", doPaint)
        ui.set_visible(route_interpolation, true)
        ui.set_visible(interpolation_scale, true)
        ui.set_visible(interphelp, true)
        ui.set_visible(interphelp2, true)
        ui.set_visible(debug, true)
        ui.set_visible(debug_shape, true)
        ui.set_visible(points, true)
        ui.set_visible(draw_all_logged_positions, true)
        ui.set_visible(flush_on_round_end, true)
        ui.set_visible(flush_log, true)
    else
        client.unset_event_callback("setup_command", doRoute)
        client.unset_event_callback("paint", doPaint)
        ui.set_visible(route_interpolation, false)
        ui.set_visible(interpolation_scale, false)
        ui.set_visible(interphelp, false)
        ui.set_visible(interphelp2, false)
        ui.set_visible(debug, false)
        ui.set_visible(debug_shape, false)
        ui.set_visible(points, false)
        ui.set_visible(draw_all_logged_positions, false)
        ui.set_visible(flush_on_round_end, false)
        ui.set_visible(flush_log, false)
    end
end)
