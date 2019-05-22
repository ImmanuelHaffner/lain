
--[[

     Licensed under GNU General Public License v2
      * (c) 2016, Luke Bonham
      * (c) 2015, unknown

--]]

local awful        = require("awful")
local capi         = { client = client }

local math         = { floor  = math.floor }
local string       = { format = string.format }

local pairs        = pairs
local screen       = screen

local setmetatable = setmetatable

-- Quake-like Dropdown application spawn
local quake = {}

-- If you have a rule like "awful.client.setslave" for your terminals,
-- ensure you use an exception for QuakeDD. Otherwise, you may
-- run into problems with focus.

function quake:compute_size()
    -- get client area of screen
    local geom
    if not self.overlap then
        geom = screen[self.screen].workarea
    else
        geom = screen[self.screen].geometry
    end

    local width, height = self.width, self.height

    -- if width or height given in percentage (i.e. <= 1), compute absolute values
    if width  <= 1 then width = math.floor(geom.width * width) - 2 * self.border end
    if height <= 1 then height = math.floor(geom.height * height) - 2 * self.border end

    -- compute anchor (left/right, top/bottom)
    local x, y
    if     self.horiz == "left"  then x = geom.x
    elseif self.horiz == "right" then x = geom.width + geom.x - width
    else   x = geom.x + (geom.width - width)/2 end
    if     self.vert == "top"    then y = geom.y
    elseif self.vert == "bottom" then y = geom.height + geom.y - height
    else   y = geom.y + (geom.height - height)/2 end

    -- set and return computed geometry of the quake
    self.geometry[self.screen] = { x = x, y = y, width = width, height = height }
    return self.geometry[self.screen]
end

function quake:new(config)
    local conf = config or {}

    conf.app        = conf.app       or "xterm"    -- application to spawn
    conf.name       = conf.name      or "QuakeDD"  -- window name
    conf.argname    = conf.argname   or "-name %s" -- how to specify window name
    conf.extra      = conf.extra     or ""         -- extra arguments
    conf.border     = conf.border    or 1          -- client border width
    conf.followtag  = conf.followtag or false      -- spawn on currently focused screen
    conf.overlap    = conf.overlap   or false      -- overlap wibox
    conf.screen     = conf.screen    or awful.screen.focused()
    conf.settings   = conf.settings

    -- If width or height <= 1 this is a proportion of the workspace
    conf.height     = conf.height    or 0.25       -- height
    conf.width      = conf.width     or 1          -- width
    conf.vert       = conf.vert      or "top"      -- top, bottom or center
    conf.horiz      = conf.horiz     or "left"     -- left, right or center
    conf.geometry   = {}                           -- internal use
    self.visible = true

    local dropdown = setmetatable(conf, { __index = quake })

    capi.client.connect_signal("unmanage", function(c)
        if c.instance == dropdown.name and c.screen == dropdown.screen then
            dropdown.visible = false
        end
     end)

    return dropdown
end

function quake:toggle()
    if self.followtag then self.screen = awful.screen.focused() end

    -- First, we locate the client
    local client = nil
    local i = 0
    for c in awful.client.iterate(function (c)
        -- c.name may be changed!
        return c.instance == self.name
    end, nil, self.screen)
    do
        i = i + 1
        if i == 1 then
            client = c
        else
            -- Additional matching clients, let's remove the sticky bit
            -- which may persist between awesome restarts. We don't close
            -- them as they may be valuable. They will just turn into
            -- normal clients.
            c.sticky = false
            c.ontop = false
            c.above = false
        end
    end

    if not client then
        -- The client does not exist, we spawn it
        local geom = self:compute_size()
        cmd = string.format("%s %s %s", self.app, string.format(self.argname, self.name), self.extra)
        awful.spawn(cmd, {
            tags = self.screen.selected_tags,
            hidden = false,
            floating = true,
            border_width = self.border,
            size_hints_honor = false,
            x = geom.x,
            y = geom.y,
            width = geom.width,
            height = geom.height,
            sticky = false,
            ontop = true,
            above = true,
            skip_taskbar = true,
            focus = true,
            callback = function (c)
                c:raise()
            end
        })
        self.visible = true
        return
    else
        -- If the quake is on a different tag, just move it.
        if self.visible then
            local move_to_tag = true
            for i, t in pairs(self.screen.selected_tags) do
                for ci, ct in pairs(client:tags()) do
                    if ct == t then
                        move_to_tag = false
                        break
                    end
                end
            end
            if move_to_tag then
                client:tags(self.screen.selected_tags)
                capi.client.focus = client
                client:raise()
                return
            end
        end

        -- Toggle display
        self.visible = not self.visible
        if self.visible then
            client.hidden = false
            client:raise()
            client:tags(self.screen.selected_tags)
            capi.client.focus = client
        else
            client.hidden = true
        end
    end
end

return setmetatable(quake, { __call = function(_, ...) return quake:new(...) end })
