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
local routes = json.parse(readfile("routes.json"))

local master = ui.new_checkbox("LUA", "B", "Log Routes")
local route_interpolation = ui.new_checkbox("LUA", "B", "Interpolate Routes")
local interpolation_scale = ui.new_slider("LUA", "B", "Interpolation Scale", 1, 64, 10, true, "t")
local interphelp = ui.new_label("LUA", "B", "Tip: If you're lagging decrease")
local interphelp2 = ui.new_label("LUA", "B", "the interpolation scale.")
local debug = ui.new_checkbox("LUA", "B", "Debug")

ui.set_visible(route_interpolation, false)
ui.set_visible(interpolation_scale, false)
ui.set_visible(interphelp, false)
ui.set_visible(interphelp2, false)


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


local lastupdate
local offset
local oldpos
local currentPos
local function doRoute()
    local me = entity.get_local_player()
    currentPos = {entity.get_origin(me)}
    local currentTick = globals.tickcount()

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

    if not ui.get(route_interpolation) then
        offset = 10   
    else
        offset = ui.get(interpolation_scale)
    end

    if currentTick >= lastupdate + offset then
        if oldpos[1] ~= currentPos[1] or oldpos[2] ~= currentPos[2] or oldpos[3] ~= currentPos[3] then
            if ui.get(debug) then
                client.log("Movement detected")
                client.log("Current Tick: " .. currentTick)
                client.log("Last Logged Position: " .. oldpos[1] .. " " .. oldpos[2] .. " " .. oldpos[3])
                client.log("Current Position X: " .. currentPos[1] .. " Y: " .. currentPos[2] .. " Z: " .. currentPos[3])
                client.log("Last update: " .. lastupdate)
            end
            lastupdate = currentTick
            oldpos = currentPos
            routes[map].pos = currentPos
            writefile("routes.json", json.stringify(routes))
        end
    end
end

local function doPaint()
    if ui.get(debug) then
        if oldpos == nil then
            return
        end
        local x1, y1 = renderer.world_to_screen(oldpos[1], oldpos[2], oldpos[3])
        local x2, y2 = renderer.world_to_screen(currentPos[1], currentPos[2], currentPos[3])
        renderer.text(x1, y1, 245, 255, 255, 255, "c", nil, "Last Logged Pos")
        draw_circle_3d(oldpos[1], oldpos[2], oldpos[3], 14, 255, 255, 255, 255, 3, 2, false, 0, 1, 255, 255, 255, 255*0.1)
        renderer.line(x1, y1, x2, y2, 255, 255, 255, 255)
    end
end

ui.set_callback(master, function(self)
    if ui.get(master) then
        client.set_event_callback("setup_command", doRoute)
        client.set_event_callback("paint", doPaint)
        ui.set_visible(route_interpolation, true)
        ui.set_visible(interpolation_scale, true)
        ui.set_visible(interphelp, true)
        ui.set_visible(interphelp2, true)
    else
        client.unset_event_callback("setup_command", doRoute)
        client.unset_event_callback("paint", doPaint)
        ui.set_visible(route_interpolation, false)
        ui.set_visible(interpolation_scale, false)
        ui.set_visible(interphelp, false)
        ui.set_visible(interphelp2, false)
    end
end)
