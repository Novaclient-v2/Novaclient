local Library = (function()
        --[[
            Genesis-style UI library (Luau) - rebuilt 1:1 from the screen recording.

            Every size / position / colour below was measured from the 1920x1080 recording (window-relative px):
        window 684x463 | 1 px Border + 1 px Outline frame | title text at (13,13) | accent line at y 34, 3 px glow above
        inner panel (10,43)-(673,452) | sidebar 148 wide, divider at x 160 | tabs 25 tall every 35 px from y 55
        sections: 1 px Border + Outline, title cut into the top line, 8 px padding, elements 6 px apart
        toggle / keybind / colour rows 16 | button 22 | slider 25 (bar 10) | dropdown / textbox 40 (box 22) | divider 10
            Fonts: two pixel fonts rebuilt glyph-by-glyph from the recording (a Tahoma-8px style face for everything and
            the 5x8 monospace face the slider value uses), embedded below and loaded with getcustomasset.
            Tweens measured frame-by-frame at 60 fps:
        page in   0.6 s Quart Out from +17 px, fade 0.2 s Quart Out | page out 0.2 s Quart Out to -10 px + fade
        toggle    0.15 s Quad Out | dropdown list 0.25 s Quart Out | button press flash 0.15 s Quad Out
        notification slide / stack shift 0.65 s Quart Out | hover 0.25 s Quad Out

            local Library = loadstring(...)()
            local Window  = Library:Window({ Name = "genesis" })
            local Combat  = Window:Page({ Name = "Combat" })
            local Aimbot  = Combat:Section({ Name = "Aimbot", Side = 1 })
            Aimbot:Toggle({ Name = "Enable aimbot", Flag = "aim", Callback = print })
            Window:Init()
        ]]

        local cloneref = cloneref or function(o) return o end
        local function Svc(n) return cloneref(game:GetService(n)) end
        local TweenService     = Svc("TweenService")
        local UserInputService = Svc("UserInputService")
        local RunService       = Svc("RunService")
        local Players          = Svc("Players")
        local HttpService      = Svc("HttpService")
        local CoreGui          = Svc("CoreGui")
        local GuiService       = Svc("GuiService")
        local LocalPlayer      = Players.LocalPlayer

        local floor, ceil, max, min, clamp, abs = math.floor, math.ceil, math.max, math.min, math.clamp, math.abs
        local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
        local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)

        local Library = {
            Flags = {}, Items = {}, Theme = {}, ThemeObjects = setmetatable({}, { __mode = "k" }), Connections = {}, Keybinds = {},
            Notifications = {}, Popup = nil, Registry = {}, Open = true, UIBind = Enum.KeyCode.RightShift, Folder = "genesis",
        }
        Library.__index = Library

        ----------------------------------------------------------------------------------------------------
        -- theme (measured; the settings page lets you change every one of these live)
        ----------------------------------------------------------------------------------------------------
        Library.Theme = {
            ["Outline"]         = rgb(46, 47, 50),     -- 1 px light line inside every border
            ["Text"]            = rgb(255, 255, 255),
            ["Border"]          = rgb(14, 15, 18),     -- outermost 1 px line
            ["Inline"]          = rgb(29, 30, 33),     -- inner panels, sections, popups
            ["Inactive Text"]   = rgb(101, 102, 105),
            ["Hovered Element"] = rgb(63, 64, 71),
            ["Background"]      = rgb(27, 28, 31),     -- window body
            ["Element"]         = rgb(53, 54, 61),     -- buttons / boxes (top of their gradient)
            ["Accent"]          = rgb(171, 189, 255),
        }
        Library.VersionColor = rgb(255, 200, 30)   -- bumble-bee yellow for the "v2" tag
        local function VersionTag(name, ver)
            if not ver or ver == "" then return name end
            local c = Library.VersionColor
            return string.format('%s <font color="#%02X%02X%02X">%s</font>', name, math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5), ver)
        end
        local ThemeOrder = { "Outline", "Text", "Border", "Inline", "Inactive Text", "Hovered Element", "Background", "Element", "Accent" }
        local Derived = {
            AccentLine = function(t) return t["Accent"]:Lerp(t["Text"], 0.5) end,          -- title / section lines
            AccentGlow = function(t) return t["Accent"]:Lerp(BLACK, 0.82) end,             -- 3 px glow above the title line
            TabIdle    = function(t) return t["Accent"]:Lerp(t["Inline"], 0.55) end,         -- idle tab marker (dim accent blue)
            GearHover  = function(t) return t["Accent"]:Lerp(WHITE, 0.35) end,           -- settings icon on hover
            Version    = function() return Library.VersionColor end,                       -- yellow "v2" / settings icon when open
            Divider    = function(t) return t["Inline"]:Lerp(t["Text"], 0.28) end,          -- watermark dividers (grey on dark)
        }
        local function Col(key)
            if typeof(key) == "Color3" then return key end
            if Derived[key] then return Derived[key](Library.Theme) end
            return Library.Theme[key]
        end

        ----------------------------------------------------------------------------------------------------
        -- fonts (pixel fonts rebuilt from the recording; base64 TTF)
        ----------------------------------------------------------------------------------------------------
        local FONT_MAIN_B64 = "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AUMBRAFFAUYBRwFIAUkBSgFLAUwBTQFOAU8BUAFRAVIBUwFUAVUBVgFXAVgBWQFaAVsBXAFdAV4BXwd1bmkwMDIxB3VuaTAwMjIHdW5pMDAyMwd1bmkwMDI0B3VuaTAwMjUHdW5pMDAyNgd1bmkwMDI3B3VuaTAwMjgHdW5pMDAyOQd1bmkwMDJBB3VuaTAwMkIHdW5pMDAyQwd1bmkwMDJEB3VuaTAwMkUHdW5pMDAyRgd1bmkwMDMwB3VuaTAwMzEHdW5pMDAzMgd1bmkwMDMzB3VuaTAwMzQHdW5pMDAzNQd1bmkwMDM2B3VuaTAwMzcHdW5pMDAzOAd1bmkwMDM5B3VuaTAwM0EHdW5pMDAzQgd1bmkwMDNDB3VuaTAwM0QHdW5pMDAzRQd1bmkwMDNGB3VuaTAwNDAHdW5pMDA0MQd1bmkwMDQyB3VuaTAwNDMHdW5pMDA0NAd1bmkwMDQ1B3VuaTAwNDYHdW5pMDA0Nwd1bmkwMDQ4B3VuaTAwNDkHdW5pMDA0QQd1bmkwMDRCB3VuaTAwNEMHdW5pMDA0RAd1bmkwMDRFB3VuaTAwNEYHdW5pMDA1MAd1bmkwMDUxB3VuaTAwNTIHdW5pMDA1Mwd1bmkwMDU0B3VuaTAwNTUHdW5pMDA1Ngd1bmkwMDU3B3VuaTAwNTgHdW5pMDA1OQd1bmkwMDVBB3VuaTAwNUIHdW5pMDA1Qwd1bmkwMDVEB3VuaTAwNUUHdW5pMDA1Rgd1bmkwMDYwB3VuaTAwNjEHdW5pMDA2Mgd1bmkwMDYzB3VuaTAwNjQHdW5pMDA2NQd1bmkwMDY2B3VuaTAwNjcHdW5pMDA2OAd1bmkwMDY5B3VuaTAwNkEHdW5pMDA2Qgd1bmkwMDZDB3VuaTAwNkQHdW5pMDA2RQd1bmkwMDZGB3VuaTAwNzAHdW5pMDA3MQd1bmkwMDcyB3VuaTAwNzMHdW5pMDA3NAd1bmkwMDc1B3VuaTAwNzYHdW5pMDA3Nwd1bmkwMDc4B3VuaTAwNzkHdW5pMDA3QQd1bmkwMDdCB3VuaTAwN0MHdW5pMDA3RAd1bmkwMDdFAAA="
        local FONT_MONO_B64 = "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AGkAeABlAGwATQBvAG4AbwBSAGUAZwB1AGwAYQByAFAAaQB4AGUAbABNAG8AbgBvAC0AUgBlAGcAdQBsAGEAcgAtADEALgAwAFAAaQB4AGUAbABNAG8AbgBvACAAUgBlAGcAdQBsAGEAcgBWAGUAcgBzAGkAbwBuACAAMQAuADAAMAAwAFAAaQB4AGUAbABNAG8AbgBvAC0AUgBlAGcAdQBsAGEAcgAAAAIAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAAAYAAAAAMBAgEDAQQBBQEGAQcBCAEJAQoBCwEMAQ0BDgEPARABEQESARMBFAEVARYBFwEYARkBGgEbARwBHQEeAR8BIAEhASIBIwEkASUBJgEnASgBKQEqASsBLAEtAS4BLwEwATEBMgEzATQBNQE2ATcBOAE5AToBOwE8AT0BPgE/AUABQQFCAUMBRAFFAUYBRwFIAUkBSgFLAUwBTQFOAU8BUAFRAVIBUwFUAVUBVgFXAVgBWQFaAVsBXAFdAV4BXwd1bmkwMDIxB3VuaTAwMjIHdW5pMDAyMwd1bmkwMDI0B3VuaTAwMjUHdW5pMDAyNgd1bmkwMDI3B3VuaTAwMjgHdW5pMDAyOQd1bmkwMDJBB3VuaTAwMkIHdW5pMDAyQwd1bmkwMDJEB3VuaTAwMkUHdW5pMDAyRgd1bmkwMDMwB3VuaTAwMzEHdW5pMDAzMgd1bmkwMDMzB3VuaTAwMzQHdW5pMDAzNQd1bmkwMDM2B3VuaTAwMzcHdW5pMDAzOAd1bmkwMDM5B3VuaTAwM0EHdW5pMDAzQgd1bmkwMDNDB3VuaTAwM0QHdW5pMDAzRQd1bmkwMDNGB3VuaTAwNDAHdW5pMDA0MQd1bmkwMDQyB3VuaTAwNDMHdW5pMDA0NAd1bmkwMDQ1B3VuaTAwNDYHdW5pMDA0Nwd1bmkwMDQ4B3VuaTAwNDkHdW5pMDA0QQd1bmkwMDRCB3VuaTAwNEMHdW5pMDA0RAd1bmkwMDRFB3VuaTAwNEYHdW5pMDA1MAd1bmkwMDUxB3VuaTAwNTIHdW5pMDA1Mwd1bmkwMDU0B3VuaTAwNTUHdW5pMDA1Ngd1bmkwMDU3B3VuaTAwNTgHdW5pMDA1OQd1bmkwMDVBB3VuaTAwNUIHdW5pMDA1Qwd1bmkwMDVEB3VuaTAwNUUHdW5pMDA1Rgd1bmkwMDYwB3VuaTAwNjEHdW5pMDA2Mgd1bmkwMDYzB3VuaTAwNjQHdW5pMDA2NQd1bmkwMDY2B3VuaTAwNjcHdW5pMDA2OAd1bmkwMDY5B3VuaTAwNkEHdW5pMDA2Qgd1bmkwMDZDB3VuaTAwNkQHdW5pMDA2RQd1bmkwMDZGB3VuaTAwNzAHdW5pMDA3MQd1bmkwMDcyB3VuaTAwNzMHdW5pMDA3NAd1bmkwMDc1B3VuaTAwNzYHdW5pMDA3Nwd1bmkwMDc4B3VuaTAwNzkHdW5pMDA3QQd1bmkwMDdCB3VuaTAwN0MHdW5pMDA3RAd1bmkwMDdFAAA="
        -- advance widths in px (TextSize 13) so text can be measured without TextService
        local ADV_MAIN = {[" "] = 3, ["!"] = 3, ["\""] = 5, ["#"] = 8, ["$"] = 7, ["%"] = 11, ["&"] = 9, ["'"] = 3, ["("] = 5, [")"] = 5, ["*"] = 7, ["+"] = 7, [","] = 4, ["-"] = 5, ["."] = 4, ["/"] = 6, ["0"] = 8, ["1"] = 8, ["2"] = 8, ["3"] = 8, ["4"] = 8, ["5"] = 8, ["6"] = 8, ["7"] = 8, ["8"] = 8, ["9"] = 8, [":"] = 3, [";"] = 4, ["<"] = 7, ["="] = 7, [">"] = 7, ["?"] = 7, ["@"] = 11, ["A"] = 9, ["B"] = 7, ["C"] = 8, ["D"] = 8, ["E"] = 7, ["F"] = 7, ["G"] = 9, ["H"] = 8, ["I"] = 3, ["J"] = 5, ["K"] = 7, ["L"] = 7, ["M"] = 11, ["N"] = 8, ["O"] = 9, ["P"] = 7, ["Q"] = 9, ["R"] = 7, ["S"] = 7, ["T"] = 7, ["U"] = 8, ["V"] = 9, ["W"] = 11, ["X"] = 8, ["Y"] = 9, ["Z"] = 7, ["["] = 4, ["\\"] = 6, ["]"] = 4, ["^"] = 7, ["_"] = 8, ["`"] = 4, ["a"] = 7, ["b"] = 7, ["c"] = 6, ["d"] = 7, ["e"] = 7, ["f"] = 6, ["g"] = 7, ["h"] = 7, ["i"] = 3, ["j"] = 4, ["k"] = 6, ["l"] = 3, ["m"] = 11, ["n"] = 7, ["o"] = 7, ["p"] = 7, ["q"] = 7, ["r"] = 5, ["s"] = 6, ["t"] = 6, ["u"] = 7, ["v"] = 7, ["w"] = 11, ["x"] = 7, ["y"] = 7, ["z"] = 6, ["{"] = 5, ["|"] = 3, ["}"] = 5, ["~"] = 8}
        local ADV_MONO = 6

        local function b64decode(data)
            local fn = (crypt and (crypt.base64decode or crypt.base64_decode)) or base64_decode or (base64 and base64.decode)
            if fn then local ok, r = pcall(fn, data); if ok and type(r) == "string" then return r end end
            local b = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
            data = data:gsub("[^" .. b .. "=]", "")
            return (data:gsub(".", function(x)
        if x == "=" then return "" end
        local r, f = "", (b:find(x) - 1)
        for i = 6, 1, -1 do r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and "1" or "0") end
        return r
            end):gsub("%d%d%d?%d?%d?%d?%d?%d?", function(x)
        if #x ~= 8 then return "" end
        local c = 0
        for i = 1, 8 do c = c + (x:sub(i, i) == "1" and 2 ^ (8 - i) or 0) end
        return string.char(c)
            end))
        end

        local function LoadFont(name, data)
            if not (writefile and getcustomasset) then return nil end
            local ok, font = pcall(function()
        local dir = "genesis_fonts"
        if isfolder and not isfolder(dir) then makefolder(dir) end
        local ttf = dir .. "/" .. name .. ".ttf"
        writefile(ttf, b64decode(data))
        local json = dir .. "/" .. name .. ".json"
        writefile(json, HttpService:JSONEncode({ name = name, faces = { { name = "Regular", weight = 400, style = "normal", assetId = getcustomasset(ttf) } } }))
        return Font.new(getcustomasset(json), Enum.FontWeight.Regular, Enum.FontStyle.Normal)
            end)
            return ok and font or nil
        end
        -- make sure Roblox actually accepted a font (an unusable font draws nothing)
        local TextService = Svc("TextService")
        local function Bounds(font, text, size)
            local ok, v = pcall(function()
        local p = Instance.new("GetTextBoundsParams")
        p.Text, p.Font, p.Size, p.Width = text, font, size, 2000
        return TextService:GetTextBoundsAsync(p)
            end)
            return ok and typeof(v) == "Vector2" and v or nil
        end
        local function Works(font) local b = font and Bounds(font, "Ag", 13); return b ~= nil and b.X > 1 end
        -- pick the TextSize that makes a known string as wide as it was in the recording
        local function Calibrate(font, text, target, fallback)
            local best, err = fallback, math.huge
            for size = 6, 24 do
        local b = Bounds(font, text, size)
        if b and abs(b.X - target) < err then best, err = size, abs(b.X - target) end
            end
            return best
        end

        -- 1) the pixel fonts from github.com/sametexe001/luas (fs-tahoma-8px is the menu's font, ProggyClean the slider's)
        Library.FontRepo = "https://raw.githubusercontent.com/sametexe001/luas/main/fonts/"
        local function Download(file)
            if not (writefile and getcustomasset and game.HttpGet) then return nil end
            local ok, path = pcall(function()
        local dir = "genesis_fonts"
        if isfolder and not isfolder(dir) then makefolder(dir) end
        local path = dir .. "/" .. file
        if not (isfile and isfile(path)) then
            local data = game:HttpGet(Library.FontRepo .. file)
            if type(data) ~= "string" or #data < 1000 or data:sub(1, 1) == "<" then return nil end
            writefile(path, data)
        end
        return path
            end)
            return ok and path or nil
        end
        local function FromFile(name, path)
            local ok, font = pcall(function()
        local json = "genesis_fonts/" .. name .. ".json"
        writefile(json, HttpService:JSONEncode({ name = name, faces = { { name = "Regular", weight = 400, style = "normal", assetId = getcustomasset(path) } } }))
        return Font.new(getcustomasset(json), Enum.FontWeight.Regular, Enum.FontStyle.Normal)
            end)
            return ok and font or nil
        end
        Library.TextSize, Library.MonoSize, Library.TextOffset = 13, 13, 0
        Library.EmbeddedFont = false
        -- opt-in (getgenv().GenesisRepoFonts = true before loading): they render soft/too tall at the menu's sizes
        if getgenv and getgenv().GenesisRepoFonts then
            local p = Download("fs-tahoma-8px.ttf")
            local f = p and FromFile("GenesisTahoma", p)
            if f and Works(f) then
        Library.FontMain = f
        Library.TextSize = Calibrate(f, "initialize aimbot", 93, 12)
        Library.CenterText = true
            end
            local pm = Download("ProggyClean.ttf")
            local fm = pm and FromFile("GenesisProggy", pm)
            if fm and Works(fm) then
        Library.FontMono = fm
        Library.MonoSize = Calibrate(fm, "100 percent", 66, 12)
        Library.CenterText = true
            end
        end
        -- 2) the fonts rebuilt from the recording (embedded), 3) Roblox built-ins
        if not Library.FontMain then
            Library.FontMain = LoadFont("PixelSans", FONT_MAIN_B64)
            Library.EmbeddedFont = Works(Library.FontMain)
            if not Library.EmbeddedFont then
        warn("[genesis] pixel font could not be loaded - using Arimo instead")
        Library.FontMain = Font.fromEnum(Enum.Font.Arimo)
            end
        end
        if not Library.FontMono then
            Library.FontMono = LoadFont("PixelMono", FONT_MONO_B64)
            if not Works(Library.FontMono) then Library.FontMono = Font.fromEnum(Enum.Font.RobotoMono) end
        end
        -- pixel fonts only look sharp at the size where one font pixel = one screen pixel; if this Roblox build scales
        -- them differently, pick the TextSize that comes closest to the width the text had in the recording
        if not rawget(_G, "__M") then
            local function pick(font, text, targets, default)
        local best, err = default, math.huge
        for size = 9, 17 do
            local b = Bounds(font, text, size)
            if b then
                for _, t in ipairs(targets) do
                    local e = abs(b.X - t) + abs(size - default) * 0.01
                    if e < err then best, err = size, e end
                end
            end
        end
        return best
            end
            if Library.EmbeddedFont then Library.TextSize = pick(Library.FontMain, "initialize aimbot", { 91, 93 }, 13) end
            Library.MonoSize = pick(Library.FontMono, "100 percent", { 65, 66 }, 13)
        end

        -- Roblox can draw the font a little wider than its own metrics say, so measure a reference string once
        -- and scale the width table by the real ratio
        Library.WidthScale, Library.MonoScale = 1, 1
        if not rawget(_G, "__M") then
            local ref = "initialize aimbot"
            local b = Bounds(Library.FontMain, ref, Library.TextSize)
            local raw = 0
            for i = 1, #ref do raw = raw + (ADV_MAIN[ref:sub(i, i)] or 7) end
            if b and b.X > raw * 0.5 and b.X < raw * 2 then Library.WidthScale = b.X / (raw - 2) end
            local bm = Bounds(Library.FontMono, "100 percent", Library.MonoSize)
            if bm and bm.X > 30 and bm.X < 140 then Library.MonoScale = bm.X / 65 end
        end
        local function TextWidth(text, mono)
            text = tostring(text)
            if mono then return ceil(#text * ADV_MONO * Library.MonoScale) end
            local w = 0
            for i = 1, #text do w = w + (ADV_MAIN[text:sub(i, i)] or 7) end
            return ceil((w - 2) * Library.WidthScale) + 2
        end
        Library.TextWidth = TextWidth

        ----------------------------------------------------------------------------------------------------
        -- helpers
        ----------------------------------------------------------------------------------------------------
        local function New(class, props, children)
            local o = Instance.new(class)
            if o:IsA("GuiObject") then o.BorderSizePixel = 0 end
            for k, v in pairs(props or {}) do if k ~= "Parent" then o[k] = v end end
            for _, c in ipairs(children or {}) do c.Parent = o end
            if props and props.Parent then o.Parent = props.Parent end
            return o
        end
        Library.New = New

        function Library:Themed(obj, prop, key)
            self.ThemeObjects[obj] = self.ThemeObjects[obj] or {}
            self.ThemeObjects[obj][prop] = key
            obj[prop] = Col(key)
            return obj
        end
        function Library:SetTheme(key, color)
            self.Theme[key] = color
            for obj, props in pairs(self.ThemeObjects) do
        for prop, k in pairs(props) do
            if k == key or Derived[k] then obj[prop] = Col(k) end
        end
            end
            for _, fn in ipairs(self.ThemeCallbacks or {}) do pcall(fn, key, color) end
        end
        function Library:OnTheme(fn) self.ThemeCallbacks = self.ThemeCallbacks or {}; table.insert(self.ThemeCallbacks, fn) end

        local TweenStyles = {
            Page   = TweenInfo.new(0.6, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            Fade   = TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            Toggle = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            List   = TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            Press  = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            Notify = TweenInfo.new(0.65, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            Hover  = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),     -- 2nd recording: 6 frames
            Check  = TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),   -- toggle label / list rows
            Pour   = TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),   -- toggle fill pouring down from the top
            Bounce = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),    -- page switch: up from a little lower
            FlashIn  = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),   -- button click up
            FlashOut = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),  -- and back down
            Slide  = TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),   -- slider fill
            Row    = TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),   -- hotkey list rows
        }
        Library.TweenStyles = TweenStyles
        function Library:Tween(obj, info, props)
            if type(info) == "string" then info = TweenStyles[info] end
            local t = TweenService:Create(obj, info, props)
            t:Play()
            return t
        end
        -- tween a themed property towards another theme key (and remember the key so theme changes stick)
        function Library:TweenTheme(obj, prop, key, info)
            self.ThemeObjects[obj] = self.ThemeObjects[obj] or {}
            self.ThemeObjects[obj][prop] = key
            return self:Tween(obj, info or "Toggle", { [prop] = Col(key) })
        end

        function Library:Connect(signal, fn)
            local c = signal:Connect(fn)
            table.insert(self.Connections, c)
            return c
        end

        -- vertical shading every element in the recording has (top = colour, bottom = colour x 0.67)
        local function Shade(parent)
            return New("UIGradient", { Rotation = 90, Color = ColorSequence.new(WHITE, rgb(171, 171, 171)), Parent = parent })
        end

        -- text: x / y are the pixel where the first glyph pixel / cap top land (exactly as measured)
        local function Text(parent, o)
            local mono = o.Mono
            local lbl = New("TextLabel", {
        Name = o.Name or "Text", BackgroundTransparency = 1, Text = o.Text or "", FontFace = mono and Library.FontMono or Library.FontMain,
        TextSize = mono and Library.MonoSize or Library.TextSize, TextXAlignment = o.XAlign or Enum.TextXAlignment.Left,
        TextYAlignment = Library.CenterText and Enum.TextYAlignment.Center or Enum.TextYAlignment.Top,
        Position = o.Position or UDim2.fromOffset((o.X or 0) - (mono and 0 or 1), (o.Y or 0) - 2),
        Size = o.Size or UDim2.new(0, o.W or 200, 0, 13), ZIndex = o.ZIndex or 1, TextTransparency = o.TextTransparency or 0,
        TextStrokeTransparency = o.Stroke and 0 or 1, TextStrokeColor3 = BLACK, RichText = false, Parent = parent,
            })
            if o.AnchorPoint then lbl.AnchorPoint = o.AnchorPoint end
            Library:Themed(lbl, "TextColor3", o.Color or "Text")
            return lbl
        end
        Library.Text = Text

        -- 1 px Border + 1 px Outline + fill  (sections, popups, slider bar, swatches)
        local function Single(parent, o)
            local b = New("Frame", { Name = o.Name or "Box", Position = o.Position, Size = o.Size, ZIndex = o.ZIndex or 1, Parent = parent })
            Library:Themed(b, "BackgroundColor3", "Border")
            local ol = New("Frame", { Name = "Outline", Position = UDim2.fromOffset(1, 1), Size = UDim2.new(1, -2, 1, -2), ZIndex = b.ZIndex, Parent = b })
            Library:Themed(ol, "BackgroundColor3", "Outline")
            local fill = New("Frame", { Name = "Fill", Position = UDim2.fromOffset(1, 1), Size = UDim2.new(1, -2, 1, -2), ZIndex = b.ZIndex, Parent = ol })
            Library:Themed(fill, "BackgroundColor3", o.Fill or "Inline")
            if o.Shade then Shade(fill) end
            return b, fill
        end
        Library.Single = Single

        -- Border, Outline, Border, Outline, shaded fill  (buttons, dropdowns, textboxes, checkboxes)
        local function Double(parent, o)
            local b = New("Frame", { Name = o.Name or "Box", Position = o.Position, Size = o.Size, ZIndex = o.ZIndex or 1, Parent = parent })
            Library:Themed(b, "BackgroundColor3", "Border")
            local cur, layers = b, {}
            for i, key in ipairs({ "Outline", "Border", "Outline" }) do
        cur = New("Frame", { Name = "L" .. i, Position = UDim2.fromOffset(1, 1), Size = UDim2.new(1, -2, 1, -2), ZIndex = b.ZIndex, Parent = cur })
        Library:Themed(cur, "BackgroundColor3", key)
        layers[i] = cur
            end
            local fill = New("Frame", { Name = "Fill", Position = UDim2.fromOffset(1, 1), Size = UDim2.new(1, -2, 1, -2), ZIndex = b.ZIndex, Parent = cur })
            Library:Themed(fill, "BackgroundColor3", o.Fill or "Element")
            if not o.Flat then Shade(fill) end
            return b, fill, layers
        end
        Library.Double = Double

        -- accent line that fades out to the right (title bar, section headers, hotkey list)
        local function FadeLine(parent, o)
            local f = New("Frame", { Name = o.Name or "Line", Position = o.Position, Size = o.Size, ZIndex = o.ZIndex or 1, Parent = parent })
            Library:Themed(f, "BackgroundColor3", o.Color or "AccentLine")
            New("UIGradient", { Transparency = o.Transparency or NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.97) }), Parent = f })
            return f
        end

        local function Button(parent, props)
            local b = New("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Parent = parent })
            for k, v in pairs(props or {}) do b[k] = v end
            return b
        end

        local function KeyName(k)
            if k == nil then return "None" end
            if typeof(k) == "EnumItem" then
        if k.EnumType == Enum.UserInputType then
            if k == Enum.UserInputType.MouseButton1 then return "MB1" end
            if k == Enum.UserInputType.MouseButton2 then return "MB2" end
            if k == Enum.UserInputType.MouseButton3 then return "MB3" end
        end
        return k.Name
            end
            return tostring(k)
        end
        local function ToKey(v)
            if typeof(v) == "EnumItem" then return v end
            if type(v) ~= "string" or v == "None" or v == "" then return nil end
            if v == "MB1" then return Enum.UserInputType.MouseButton1 end
            if v == "MB2" then return Enum.UserInputType.MouseButton2 end
            if v == "MB3" then return Enum.UserInputType.MouseButton3 end
            local ok, k = pcall(function() return Enum.KeyCode[v] end)
            return ok and k or nil
        end

        ----------------------------------------------------------------------------------------------------
        -- screen gui
        ----------------------------------------------------------------------------------------------------
        local function Parent(gui)
            local ok = pcall(function() gui.Parent = (gethui and gethui()) or CoreGui end)
            if not ok or not gui.Parent then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
        end
        Library.Gui = New("ScreenGui", { Name = "genesis", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Global, DisplayOrder = 999 })
        pcall(function() if syn and syn.protect_gui then syn.protect_gui(Library.Gui) end end)
        Parent(Library.Gui)
        Library.Overlay = New("Frame", { Name = "Overlay", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 50, Parent = Library.Gui })

        -- GetMouseLocation includes the top bar inset but AbsolutePosition doesn't: work in AbsolutePosition space
        local function Mouse()
            local p = UserInputService:GetMouseLocation()
            local inset = Vector2.new(0, 0)
            pcall(function() inset = GuiService:GetGuiInset() end)
            return Vector2.new(p.X - inset.X, p.Y - inset.Y)
        end
        -- convert an AbsolutePosition into an offset inside the overlay (the overlay ignores the inset)
        local function ToOverlay(v)
            local o = Library.Overlay.AbsolutePosition
            return UDim2.fromOffset(v.X - o.X, v.Y - o.Y)
        end
        Library.Mouse, Library.ToOverlay = Mouse, ToOverlay

        -- close whatever popup is open when clicking elsewhere
        function Library:SetPopup(p)
            -- popups can nest (a dropdown inside the keybind menu): opening a child keeps its parent
            while self.Popup and self.Popup ~= p and (not p or p.Parent ~= self.Popup) do
        local old = self.Popup
        self.Popup = old.Parent
        pcall(old.Close, old)
        for _, c in ipairs(old.Conns or {}) do pcall(function() c:Disconnect() end) end
            end
            self.Popup = p
        end
        local function Inside(obj, pos)
            local ap, as = obj.AbsolutePosition, obj.AbsoluteSize
            return pos.X >= ap.X and pos.Y >= ap.Y and pos.X < ap.X + as.X and pos.Y < ap.Y + as.Y
        end
        Library:Connect(UserInputService.InputBegan, function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.MouseButton2 then return end
            local p = Library.Popup
            if not p then return end
            local m = Mouse()
            while p do
        for _, o in ipairs(p.Keep or {}) do if o and o.Parent and o.Visible ~= false and Inside(o, m) then Library:SetPopup(p) return end end
        p = p.Parent
            end
            Library:SetPopup(nil)
        end)

        function Library:Draggable(handle, target, onMove)
            local dragging, start, origin, moved
            self:Connect(handle.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging, start, origin, moved = true, Mouse(), target.Position, false
        end
            end)
            self:Connect(UserInputService.InputChanged, function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local d = Mouse() - start
            if d.Magnitude > 0 then moved = true end
            target.Position = UDim2.new(origin.X.Scale, origin.X.Offset + d.X, origin.Y.Scale, origin.Y.Offset + d.Y)
            if onMove then onMove() end
        end
            end)
            self:Connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if dragging and moved then self:DockMoved(target) end
            dragging = false
        end
            end)
        end

        ----------------------------------------------------------------------------------------------------
        -- docking: while the menu is open the hotkeys / watermark / esp preview sit snug around the window;
        -- once the menu closes, any of them the user dragged somewhere goes back to that spot
        ----------------------------------------------------------------------------------------------------
        Library.DockItems = {}
        function Library:Dock(frame, posFn)
            self.DockItems[frame] = { Pos = posFn, Custom = nil, Docked = true }
            if self.Open and self.MainWindow then frame.Position = posFn(self.MainWindow.Root) end
        end
        function Library:DockMoved(frame)
            local it = self.DockItems[frame]
            if it then it.Custom = frame.Position; it.Docked = false end
        end
        function Library:Undock(frame, reset)
            local it = self.DockItems[frame]
            if it and reset then it.Custom = nil end
        end
        function Library:ApplyDock(open, instant)
            local W = self.MainWindow
            if not W then return end
            for frame, it in pairs(self.DockItems) do
        if frame.Parent then
            local target
            if open then target = it.Pos(W.Root); it.Docked = true
            elseif it.Custom then target = it.Custom end
            if target then
                if instant then frame.Position = target else self:Tween(frame, "List", { Position = target }) end
            end
        else
            self.DockItems[frame] = nil
        end
            end
        end

        ----------------------------------------------------------------------------------------------------
        -- notifications (top-left stack, 29 tall, 35 px apart, coloured 2 px bar)
        ----------------------------------------------------------------------------------------------------
        function Library:Notification(text, duration, color)
            if type(text) == "table" then
        local o = text
        text, duration, color = o.Text or o.Description or o.Name or o.Title or "", o.Duration or o.Time, o.Color
            end
            text = tostring(text or "")
            duration = tonumber(duration) or 5
            local inset = 0
            pcall(function() inset = GuiService:GetGuiInset().Y end)
            local width = TextWidth(text) + 18
            local n = {}
            local box, fill = Single(self.Gui, { Name = "Notification", Size = UDim2.fromOffset(width, 29), Fill = "Background", ZIndex = 60 })
            box.Position = UDim2.fromOffset(-width - 10, inset + 2)
            fill.BackgroundTransparency = 0.1
            -- 1 px colour bar on the left; the recording gives every notification its own random colour
            local bar = New("Frame", { Name = "Bar", Position = UDim2.fromOffset(0, 0), Size = UDim2.new(0, 1, 1, 0), ZIndex = 60, Parent = fill })
            bar.BackgroundColor3 = color or Color3.fromRGB(math.random(30, 220), math.random(30, 220), math.random(30, 220))
            local lbl = Text(fill, { Text = text, X = 8, Y = 9, W = width, ZIndex = 60 })
            n.Box, n.X = box, 10
            table.insert(self.Notifications, 1, n)
            local function restack()
        for i, item in ipairs(self.Notifications) do
            item.Y = inset + 2 + (i - 1) * 35
            self:Tween(item.Box, "Notify", { Position = UDim2.fromOffset(item.X, item.Y) })
        end
            end
            restack()
            task.delay(duration, function()
        local idx = table.find(self.Notifications, n)
        if idx then table.remove(self.Notifications, idx) end
        self:Tween(box, "Notify", { Position = UDim2.fromOffset(-width - 10, n.Y or box.Position.Y.Offset) })
        restack()
        task.wait(0.65)
        box:Destroy()
            end)
            return n
        end
        Library.Notify = Library.Notification

        ----------------------------------------------------------------------------------------------------
        -- hotkey list (149 wide, title + accent line, one row per active keybind)
        ----------------------------------------------------------------------------------------------------
        function Library:HotkeyList()
            if self.HotkeyFrame then return self.HotkeyFrame end
            local box, fill = Single(self.Gui, { Name = "Hotkeys", Size = UDim2.fromOffset(149, 39), Fill = "Background", ZIndex = 40 })
            box.Position = UDim2.fromOffset(118, 545)
            Text(fill, { Text = "Hotkeys", X = 9, Y = 9, ZIndex = 40 })
            FadeLine(fill, { Name = "Glow", Position = UDim2.fromOffset(0, 25), Size = UDim2.new(1, 0, 0, 3), Color = "AccentGlow", ZIndex = 40,
        Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }) })
            FadeLine(fill, { Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 1), ZIndex = 40 })
            local rows = New("Frame", { Name = "Rows", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 0), Size = UDim2.fromScale(1, 1), ClipsDescendants = true, ZIndex = 40, Parent = fill })
            self:Draggable(box, box)
            self.HotkeyFrame = box
            -- rows slide in from the left and fade; leaving rows slide back out, then the panel shrinks (recording)
            local rowsByKb, order = {}, {}
            function self:RefreshHotkeys()
        local active = {}
        for _, kb in ipairs(self.Keybinds) do
            if kb.ShowInList and kb.Key and kb:GetState() then active[kb] = true end
        end
        -- remove rows that are no longer active
        for i = #order, 1, -1 do
            local kb = order[i]
            if not active[kb] then
                local l = rowsByKb[kb]
                rowsByKb[kb] = nil
                table.remove(order, i)
                self:Tween(l, "Fade", { TextTransparency = 1, Position = l.Position - UDim2.fromOffset(8, 0) })
                task.delay(0.2, function() l:Destroy() end)
            end
        end
        -- add new ones (in keybind order)
        for _, kb in ipairs(self.Keybinds) do
            if active[kb] and not rowsByKb[kb] then
                local l = Text(rows, { X = 8 - 8, Y = 38 + #order * 16, ZIndex = 40 })
                l.TextTransparency = 1
                rowsByKb[kb] = l
                table.insert(order, kb)
            end
        end
        local w = 149
        for i, kb in ipairs(order) do
            local l = rowsByKb[kb]
            local str = string.format("%s - %s ( %s )", kb.Name or "Keybind", KeyName(kb.Key), kb.Mode)
            l.Text = str
            l.Size = UDim2.fromOffset(TextWidth(str) + 4, 13)
            self:Tween(l, "Row", { TextTransparency = 0, Position = UDim2.fromOffset(8 - 1, 38 - 2 + (i - 1) * 16) })
            w = max(w, TextWidth(str) + 22)
        end
        self:Tween(box, "Row", { Size = UDim2.fromOffset(w, #order > 0 and (58 + (#order - 1) * 16) or 39) })
            end
            self:RefreshHotkeys()
            return box
        end

        ----------------------------------------------------------------------------------------------------
        -- panel: a floating box in the exact Hotkeys style (border + outline, UI background colour, title,
        -- accent glow + line under it, draggable). Put anything inside panel.Content (e.g. an ESP preview).
        --   local p = Library:Panel({ Title = "ESP Preview", Size = Vector2.new(219, 340), Position = Vector2.new(1340, 356) })
        --   myViewport.Parent = p.Content   -- give it BackgroundTransparency = 1 so the UI background shows
        ----------------------------------------------------------------------------------------------------
        function Library:Panel(o)
            o = o or {}
            local size = o.Size or Vector2.new(219, 340)
            local box, fill = Single(self.Gui, { Name = o.Name or o.Title or "Panel", Size = UDim2.fromOffset(size.X, size.Y), Fill = "Background", ZIndex = o.ZIndex or 40 })
            local z = box.ZIndex
            local pos = o.Position or Vector2.new(118, 545)
            box.Position = typeof(pos) == "UDim2" and pos or UDim2.fromOffset(pos.X, pos.Y)
            local title = Text(fill, { Text = o.Title or "Panel", X = 9, Y = 9, W = size.X - 20, ZIndex = z })
            FadeLine(fill, { Name = "Glow", Position = UDim2.fromOffset(0, 25), Size = UDim2.new(1, 0, 0, 3), Color = "AccentGlow", ZIndex = z,
                Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }) })
            FadeLine(fill, { Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 1), ZIndex = z })
            -- everything under the accent line; transparent so the panel's Background colour shows through
            local content = New("Frame", { Name = "Content", BackgroundTransparency = 1, ClipsDescendants = true,
                Position = UDim2.fromOffset(0, 29), Size = UDim2.new(1, 0, 1, -29), ZIndex = z, Parent = fill })
            local grab = Button(fill, { Name = "TitleDrag", Size = UDim2.new(1, 0, 0, 28), ZIndex = z + 1 })
            if o.Draggable ~= false then self:Draggable(grab, box, o.OnChanged) end
            -- resize from the right edge, bottom edge or bottom-right corner (edge lights up like the window's)
            if o.Resizable then
                local lib, minS = self, o.MinSize or Vector2.new(140, 160)
                local function grip(pos, sz, dir, hpos, hsz)
                    local h = Button(box, { Position = pos, Size = sz, ZIndex = z + 3 })
                    local hl = New("Frame", { BackgroundTransparency = 1, Position = hpos, Size = hsz, ZIndex = z + 2, Parent = box })
                    lib:Themed(hl, "BackgroundColor3", "AccentLine")
                    local held, start, s0
                    lib:Connect(h.MouseEnter, function() lib:Tween(hl, "Hover", { BackgroundTransparency = 0 }) end)
                    lib:Connect(h.MouseLeave, function() if not held then lib:Tween(hl, "Hover", { BackgroundTransparency = 1 }) end end)
                    lib:Connect(h.InputBegan, function(i)
                        if i.UserInputType == Enum.UserInputType.MouseButton1 then held, start, s0 = true, Mouse(), box.AbsoluteSize end
                    end)
                    lib:Connect(UserInputService.InputChanged, function(i)
                        if not held or i.UserInputType ~= Enum.UserInputType.MouseMovement then return end
                        local d = Mouse() - start
                        box.Size = UDim2.fromOffset(max(minS.X, s0.X + d.X * dir.X), max(minS.Y, s0.Y + d.Y * dir.Y))
                        if o.OnChanged then o.OnChanged() end
                    end)
                    lib:Connect(UserInputService.InputEnded, function(i)
                        if i.UserInputType == Enum.UserInputType.MouseButton1 and held then held = false; lib:Tween(hl, "Hover", { BackgroundTransparency = 1 }) end
                    end)
                end
                grip(UDim2.new(1, -4, 0, 0), UDim2.new(0, 4, 1, -10), Vector2.new(1, 0), UDim2.new(1, -4, 0, 2), UDim2.new(0, 2, 1, -4))
                grip(UDim2.new(0, 0, 1, -4), UDim2.new(1, -10, 0, 4), Vector2.new(0, 1), UDim2.new(0, 2, 1, -4), UDim2.new(1, -4, 0, 2))
                grip(UDim2.new(1, -10, 1, -10), UDim2.fromOffset(10, 10), Vector2.new(1, 1), UDim2.new(1, -6, 1, -6), UDim2.fromOffset(4, 4))
            end
            local P = { Frame = box, Fill = fill, Content = content, TitleLabel = title }
            function P:SetTitle(t) title.Text = t end
            function P:SetVisible(v) box.Visible = v and true or false end
            function P:Destroy() box:Destroy() end
            return P
        end

        ----------------------------------------------------------------------------------------------------
        -- ESP preview: your own character, frozen in a standing pose, as other players see it (clothing,
        -- armour, guns on your back - anything welded to you), with your ESP drawn over it.
        -- Drag inside it to spin, scroll to zoom, drag the title to move, drag the edges / corner to resize.
        -- Which of YOUR esp flags it follows: set Library.ESPPreviewFlags (names of your toggle / colour flags)
        ----------------------------------------------------------------------------------------------------
        Library.ESPPreviewFlags = {
            Box = "esp_box", BoxColor = "esp_box_color",
            Name = "esp_name", NameColor = "esp_name_color",
            Health = "esp_health",
            Distance = "esp_distance", DistanceColor = "esp_distance_color",
            Chams = "esp_chams", ChamsColor = "esp_chams_color",
        }
        -- if your flags have other names, the preview finds your ESP toggles by their label instead: it looks for the
        -- section (outside Settings) that has a "Box" toggle and reads Enabled / Box / Fill / Healthbar / Name /
        -- Distance / Weapon / Chams (+ their colour boxes and a "Fill Transparency" slider) from that section
        local AutoNames = {
            Enabled = { "enabled", "enable", "esp", "master" },
            Box = { "box", "boxes", "2d box", "bounding box" },
            Fill = { "fill", "box fill" },
            Health = { "healthbar", "health bar", "health", "hp bar", "hp" },
            Name = { "name", "names", "nametag", "nametags", "username" },
            Distance = { "distance", "dist" },
            Weapon = { "weapon", "weapons", "tool", "held item", "item" },
            Chams = { "chams", "highlight", "glow" },
        }
        local autoCache, autoCount = nil, -1
        local function lower(t) return (tostring(t):lower():gsub("^%s+", ""):gsub("%s+$", "")) end
        local function AutoESP()
            local reg = Library.Registry
            if autoCache and autoCount == #reg then return autoCache end
            autoCount, autoCache = #reg, {}
            -- the section that holds the "Box" toggle (skipping the hidden settings page)
            local anchor
            for _, r in ipairs(reg) do
                if r.Kind == "Toggle" and not r.Holder.PageHidden then
                    for _, n in ipairs(AutoNames.Box) do if lower(r.Name) == n then anchor = r.Holder break end end
                end
                if anchor then break end
            end
            if not anchor then return autoCache end
            for key, names in pairs(AutoNames) do
                for _, n in ipairs(names) do
                    for _, r in ipairs(reg) do
                        if r.Holder == anchor and r.Kind == "Toggle" and lower(r.Name) == n then autoCache[key] = r break end
                    end
                    if autoCache[key] then break end
                end
            end
            for _, r in ipairs(reg) do
                if r.Holder == anchor and r.Kind == "Slider" and lower(r.Name):find("transparen") then autoCache.FillTransparency = r break end
            end
            return autoCache
        end
        Library._AutoESP = AutoESP
        local function FlagOn(key)
            local f = Library.ESPPreviewFlags[key]
            if f == true then return true end
            local v = f and Library.Flags[f]
            if v ~= nil then
                if type(v) == "table" and v.Active ~= nil then return v.Active end
                return v == true
            end
            local r = AutoESP()[key]
            if r then return r.Get() == true end
            return key == "Enabled"   -- no master switch found: treat as on
        end
        -- colour n of the toggle's colour boxes (left to right)
        local function FlagColor(key, default, n)
            local f = Library.ESPPreviewFlags[key .. "Color"]
            if typeof(f) == "Color3" then return f end
            local v = f and Library.Flags[f]
            if type(v) == "table" and typeof(v.Color) == "Color3" then return v.Color end
            if typeof(v) == "Color3" then return v end
            local r = AutoESP()[key]
            local sw = r and r.Colors and r.Colors[n or 1]
            if sw and sw.Value then return sw.Value end
            return default
        end
        local function FlagNumber(key, default)
            local f = Library.ESPPreviewFlags[key]
            local v = f and Library.Flags[f]
            if type(v) == "number" then return v end
            local r = AutoESP()[key]
            if r then return r.Get(), r.Min, r.Max end
            return default
        end

        function Library:ESPPreview(o)
            o = o or {}
            if self.Preview then self.Preview:SetVisible(true); return self.Preview end
            local lib = self
            local function defPos()
                if o.Position then return o.Position end
                local w = lib.MainWindow and lib.MainWindow.Root
                if w then return Vector2.new(w.Position.X.Offset + w.Size.X.Offset + 4, w.Position.Y.Offset + 2) end
                return Vector2.new(1340, 356)
            end
            local defSize = o.Size or Vector2.new(163, 307)
            local function dockPos(r) return UDim2.fromOffset(r.Position.X.Offset + r.Size.X.Offset + 4, r.Position.Y.Offset + 2) end
            local panel = self:Panel({ Title = o.Title or "ESP Preview", Size = defSize,
                Position = defPos(), Resizable = true, MinSize = Vector2.new(150, 200), ZIndex = 42 })
            local z = panel.Frame.ZIndex
            local vp = New("ViewportFrame", { Name = "Viewport", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
                Ambient = rgb(170, 170, 175), LightColor = rgb(255, 255, 255), LightDirection = Vector3.new(-1, -1.4, -1.2), ZIndex = z, Parent = panel.Content })
            local cam = Instance.new("Camera")
            cam.FieldOfView = 40
            cam.Parent = vp
            vp.CurrentCamera = cam
            -- 2D esp layer drawn on top of the 3D view
            local overlay = New("Frame", { Name = "ESP", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = z + 1, Parent = panel.Content })
            local function line(name) local f = New("Frame", { Name = name, BorderSizePixel = 0, ZIndex = z + 1, Visible = false, Parent = overlay }); return f end
            local boxParts = {}
            for _, n in ipairs({ "OT", "OB", "OL", "OR", "T", "B", "L", "R" }) do boxParts[n] = line(n) end
            local hpBack, hpFill = line("HealthBack"), line("Health")
            hpBack.BackgroundColor3 = BLACK
            local function label(name)
                local l = Text(overlay, { Name = name, Size = UDim2.fromOffset(160, 13), XAlign = Enum.TextXAlignment.Center, Stroke = true, ZIndex = z + 2 })
                l.AnchorPoint = Vector2.new(0.5, 0)
                l.Visible = false
                return l
            end
            local nameL, distL, weapL = label("Name"), label("Distance"), label("Weapon")
            local fillF = New("Frame", { Name = "Fill", BorderSizePixel = 0, Visible = false, ZIndex = z, Parent = overlay })
            local hint = Text(panel.Content, { Text = "no character", Position = UDim2.new(0, 0, 0.5, -6), Size = UDim2.new(1, 0, 0, 13),
                XAlign = Enum.TextXAlignment.Center, Color = "Inactive Text", ZIndex = z + 1 })

            local model, yaw, pitch, zoom = nil, math.rad(o.Yaw or 180), math.rad(8), o.Zoom or 1.23
            local center, height = Vector3.zero, 5

            -- rebuild a still, un-animated copy: joints put back in their rest pose, everything anchored
            local function restPose(m)
                local root = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
                if not root then return end
                -- every link between two parts: Motor6Ds go to their rest pose, rigid welds keep their current offset
                local links = {}
                for _, j in ipairs(m:GetDescendants()) do
                    local p0, p1, rest
                    if j:IsA("Motor6D") then p0, p1, rest = j.Part0, j.Part1, j.C0 * j.C1:Inverse()
                    elseif j:IsA("JointInstance") then p0, p1 = j.Part0, j.Part1
                    elseif j:IsA("WeldConstraint") or j:IsA("RigidConstraint") then p0, p1 = j.Part0, j.Part1 end
                    if p0 and p1 and p0:IsDescendantOf(m) and p1:IsDescendantOf(m) then
                        rest = rest or p0.CFrame:ToObjectSpace(p1.CFrame)
                        table.insert(links, { p0, p1, rest })
                        table.insert(links, { p1, p0, rest:Inverse() })
                    end
                end
                local seen, queue = { [root] = true }, { root }
                while #queue > 0 do
                    local cur = table.remove(queue, 1)
                    for _, l in ipairs(links) do
                        if l[1] == cur and not seen[l[2]] then
                            l[2].CFrame = cur.CFrame * l[3]
                            seen[l[2]] = true
                            table.insert(queue, l[2])
                        end
                    end
                end
            end
            local function copy(char)
                local archive = {}
                local function allow(inst) if not inst.Archivable then table.insert(archive, inst); inst.Archivable = true end end
                allow(char)
                for _, d in ipairs(char:GetDescendants()) do pcall(allow, d) end
                local ok, m = pcall(function() return char:Clone() end)
                -- anything welded to you from outside your character (some games keep back-weapons in workspace)
                local extra = {}
                if ok and m then
                    for _, part in ipairs(char:GetDescendants()) do
                        if part:IsA("BasePart") then
                            for _, jt in ipairs(part:GetJoints()) do
                                local other = (jt.Part0 == part) and jt.Part1 or jt.Part0
                                local inHand = jt.Name:lower():find("grip") or part.Name == "RightHand" or part.Name == "LeftHand"
                                if other and not inHand and not other:IsDescendantOf(char) and not other:IsDescendantOf(workspace.Terrain) then
                                    local top = other
                                    while top.Parent and top.Parent ~= workspace and not top.Parent:IsA("Folder") and #top.Parent:GetDescendants() < 80 do top = top.Parent end
                                    if not extra[top] and not top:FindFirstChildOfClass("Humanoid") then
                                        extra[top] = true
                                        pcall(allow, top); for _, d in ipairs(top:GetDescendants()) do pcall(allow, d) end
                                        local c = top:Clone(); if c then c.Parent = m end
                                    end
                                end
                            end
                        end
                    end
                end
                for _, inst in ipairs(archive) do pcall(function() inst.Archivable = false end) end
                if ok and m then
                    -- leave out whatever is in your hand: tools, and anything held on by a grip weld
                    for _, d in ipairs(m:GetDescendants()) do
                        if d.Parent and (d:IsA("Tool") or d:IsA("HopperBin")) then pcall(function() d:Destroy() end) end
                    end
                    -- anything held on by a grip weld (RightGrip etc.) that is not part of the body
                    local body = { Head = true, Torso = true, UpperTorso = true, LowerTorso = true, HumanoidRootPart = true,
                        ["Right Arm"] = true, ["Left Arm"] = true, ["Right Leg"] = true, ["Left Leg"] = true,
                        RightHand = true, LeftHand = true, RightLowerArm = true, LeftLowerArm = true, RightUpperArm = true, LeftUpperArm = true }
                    for _, j in ipairs(m:GetDescendants()) do
                        if j.Parent and (j:IsA("JointInstance") or j:IsA("WeldConstraint")) and j.Name:lower():find("grip") then
                            for _, held in ipairs({ j.Part1, j.Part0 }) do
                                if held and held.Parent and held:IsDescendantOf(m) and not (body[held.Name] and held.Parent == m) then
                                    local top = held
                                    while top.Parent and top.Parent ~= m do top = top.Parent end
                                    if not top:IsA("Accessory") then pcall(function() top:Destroy() end) end
                                    break
                                end
                            end
                        end
                    end
                end
                return ok and m or nil
            end
            local function strip(m)
                for _, d in ipairs(m:GetDescendants()) do
                    if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") or d:IsA("Sound") or d:IsA("ParticleEmitter")
                        or d:IsA("Trail") or d:IsA("Beam") or d:IsA("ForceField") or d:IsA("BillboardGui") or d:IsA("Highlight") then
                        pcall(function() d:Destroy() end)
                    elseif d:IsA("BasePart") then
                        d.Anchored = true; d.CanCollide = false; d.CastShadow = false
                    elseif d:IsA("Humanoid") then
                        d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
                        local an = d:FindFirstChildOfClass("Animator")
                        if an then for _, t in ipairs(an:GetPlayingAnimationTracks()) do pcall(function() t:Stop(0) end) end; an:Destroy() end
                    end
                end
            end
            local chamsOn, chamsCol, saved = false, nil, {}
            local function applyChams()
                if not model then return end
                local on, col = FlagOn("Enabled") and FlagOn("Chams"), FlagColor("Chams", Col("Accent"))
                if on == chamsOn and col == chamsCol then return end
                chamsOn, chamsCol = on, col
                for _, d in ipairs(model:GetDescendants()) do
                    if d:IsA("BasePart") and d.Transparency < 1 then
                        saved[d] = saved[d] or { d.Color, d.Material }
                        if on then d.Color = col; d.Material = Enum.Material.ForceField
                        else d.Color, d.Material = saved[d][1], saved[d][2] end
                    end
                end
            end
            local function build()
                if model then model:Destroy(); model = nil end
                saved, chamsOn, chamsCol = {}, false, nil
                local char = LocalPlayer and LocalPlayer.Character
                if not char or not char:FindFirstChildWhichIsA("BasePart") then hint.Visible = true; return end
                local m = copy(char)
                if not m then hint.Visible = true; return end
                strip(m)
                m.PrimaryPart = m:FindFirstChild("HumanoidRootPart") or m:FindFirstChildWhichIsA("BasePart")
                pcall(function() m:PivotTo(CFrame.new()) end)
                restPose(m)
                local ok, cf, size = pcall(function() return m:GetBoundingBox() end)
                if ok then center, height = cf.Position, max(size.Y, 2) end
                m.Parent = vp
                model = m
                hint.Visible = false
                applyChams()
            end
            self.RefreshPreview = build

            -- spin (drag), zoom (wheel)
            local spinning, last = false, nil
            lib:Connect(vp.InputBegan, function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 then spinning, last = true, Mouse() end
            end)
            lib:Connect(UserInputService.InputEnded, function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then spinning = false end end)
            lib:Connect(UserInputService.InputChanged, function(i)
                if spinning and i.UserInputType == Enum.UserInputType.MouseMovement then
                    local m = Mouse(); local d = m - last; last = m
                    yaw = yaw - d.X * 0.012
                    pitch = clamp(pitch + d.Y * 0.008, math.rad(-35), math.rad(55))
                elseif i.UserInputType == Enum.UserInputType.MouseWheel and panel.Frame.Visible then
                    local m, p, sz = Mouse(), vp.AbsolutePosition, vp.AbsoluteSize
                    if m.X >= p.X and m.Y >= p.Y and m.X <= p.X + sz.X and m.Y <= p.Y + sz.Y then
                        zoom = clamp(zoom * (i.Position.Z > 0 and 0.88 or 1.14), 0.35, 2.5)
                    end
                end
            end)

            -- project a world point onto the viewport frame (the camera's own WorldToViewportPoint uses the screen)
            local function project(p, w, h)
                local l = cam.CFrame:PointToObjectSpace(p)
                if l.Z >= -0.05 then return nil end
                local f = (h / 2) / math.tan(math.rad(cam.FieldOfView) / 2)
                return Vector2.new(w / 2 + l.X * f / -l.Z, h / 2 - l.Y * f / -l.Z)
            end
            local function setRect(fr, x, y, w, h) fr.Position = UDim2.fromOffset(floor(x), floor(y)); fr.Size = UDim2.fromOffset(max(1, floor(w)), max(1, floor(h))); fr.Visible = true end
            lib:Connect(RunService.RenderStepped, function()
                if not panel.Frame.Visible then return end
                local dist = (height / 2) / math.tan(math.rad(cam.FieldOfView) / 2) * 1.25 * zoom
                local dir = Vector3.new(math.sin(yaw) * math.cos(pitch), math.sin(pitch), math.cos(yaw) * math.cos(pitch))
                cam.CFrame = CFrame.lookAt(center + dir * dist, center)
                applyChams()
                local w, h = vp.AbsoluteSize.X, vp.AbsoluteSize.Y
                local master = FlagOn("Enabled")
                local boxOn, nameOn, hpOn, distOn = master and FlagOn("Box"), master and FlagOn("Name"), master and FlagOn("Health"), master and FlagOn("Distance")
                local fillOn, weapOn = master and FlagOn("Fill"), master and FlagOn("Weapon")
                local minX, minY, maxX, maxY
                if model and (boxOn or nameOn or hpOn or distOn or fillOn or weapOn) then
                    local ok, cf, size = pcall(function() return model:GetBoundingBox() end)
                    if ok then
                        for _, sx in ipairs({ -1, 1 }) do for _, sy in ipairs({ -1, 1 }) do for _, sz in ipairs({ -1, 1 }) do
                            local p = project(cf * Vector3.new(size.X / 2 * sx, size.Y / 2 * sy, size.Z / 2 * sz), w, h)
                            if p then
                                minX, minY = min(minX or p.X, p.X), min(minY or p.Y, p.Y)
                                maxX, maxY = max(maxX or p.X, p.X), max(maxY or p.Y, p.Y)
                            end
                        end end end
                    end
                end
                local have = minX ~= nil
                for _, f in pairs(boxParts) do f.Visible = false end
                hpBack.Visible, hpFill.Visible, nameL.Visible, distL.Visible = false, false, false, false
                fillF.Visible, weapL.Visible = false, false
                if not have then return end
                local bw, bh = maxX - minX, maxY - minY
                if fillOn then
                    local t, mn, mx = FlagNumber("FillTransparency", 50)
                    mn, mx = mn or 0, mx or 100
                    local a = (mx > 1) and (t / 100) or t     -- slider in % or 0..1
                    fillF.BackgroundColor3 = FlagColor("Fill", FlagColor("Box", WHITE))
                    fillF.BackgroundTransparency = clamp(a, 0, 1)
                    setRect(fillF, minX, minY, bw + 1, bh + 1)
                end
                if boxOn then
                    local c = FlagColor("Box", WHITE)
                    for _, n in ipairs({ "OT", "OB", "OL", "OR" }) do boxParts[n].BackgroundColor3 = BLACK end
                    for _, n in ipairs({ "T", "B", "L", "R" }) do boxParts[n].BackgroundColor3 = c end
                    setRect(boxParts.OT, minX - 1, minY - 1, bw + 3, 3); setRect(boxParts.OB, minX - 1, maxY - 1, bw + 3, 3)
                    setRect(boxParts.OL, minX - 1, minY - 1, 3, bh + 3); setRect(boxParts.OR, maxX - 1, minY - 1, 3, bh + 3)
                    setRect(boxParts.T, minX, minY, bw + 1, 1); setRect(boxParts.B, minX, maxY, bw + 1, 1)
                    setRect(boxParts.L, minX, minY, 1, bh + 1); setRect(boxParts.R, maxX, minY, 1, bh + 1)
                end
                if hpOn then
                    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                    local frac = hum and clamp(hum.Health / max(hum.MaxHealth, 1), 0, 1) or 1
                    setRect(hpBack, minX - 6, minY - 1, 3, bh + 3)
                    setRect(hpFill, minX - 5, minY + bh * (1 - frac), 1, bh * frac + 1)
                    -- the healthbar's colour boxes are low / mid / high (red, yellow, green by default)
                    local lo = FlagColor("Health", Color3.fromRGB(255, 60, 60), 1)
                    local mi = FlagColor("Health", nil, 2)
                    local hi = FlagColor("Health", nil, 3) or (mi and mi) or Color3.fromRGB(80, 255, 110)
                    if mi and FlagColor("Health", nil, 3) then
                        hpFill.BackgroundColor3 = frac < 0.5 and lo:Lerp(mi, frac * 2) or mi:Lerp(hi, (frac - 0.5) * 2)
                    else
                        hpFill.BackgroundColor3 = lo:Lerp(hi, frac)
                    end
                end
                if nameOn then
                    nameL.Text = LocalPlayer.Name
                    nameL.TextColor3 = FlagColor("Name", WHITE)
                    nameL.Position = UDim2.fromOffset(floor(minX + bw / 2), floor(minY) - 15); nameL.Visible = true
                end
                if distOn then
                    distL.Text = floor(dist + 0.5) .. "m"
                    distL.TextColor3 = FlagColor("Distance", WHITE)
                    distL.Position = UDim2.fromOffset(floor(minX + bw / 2), floor(maxY) + 3); distL.Visible = true
                end
                if weapOn then
                    -- the item in your hand (it is left off the model itself)
                    local char = LocalPlayer.Character
                    local tool = char and char:FindFirstChildOfClass("Tool")
                    weapL.Text = tool and tool.Name or "none"
                    weapL.TextColor3 = FlagColor("Weapon", WHITE)
                    weapL.Position = UDim2.fromOffset(floor(minX + bw / 2), floor(maxY) + 3 + (distOn and 13 or 0)); weapL.Visible = true
                end
            end)

            -- follow the real character: rebuild after respawn and whenever gear is put on / taken off
            local pending, conns = false, {}
            local function queue()
                if pending then return end
                pending = true
                task.delay(0.5, function() pending = false; if panel.Frame.Visible then build() end end)
            end
            local function hook(char)
                for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
                conns = {}
                if not char then return end
                table.insert(conns, lib:Connect(char.DescendantAdded, function(d) if not d:IsA("Script") and not d:IsA("Sound") then queue() end end))
                table.insert(conns, lib:Connect(char.DescendantRemoving, function(d) if not d:IsA("Script") and not d:IsA("Sound") then queue() end end))
                task.delay(0.6, build)
            end
            if LocalPlayer then
                hook(LocalPlayer.Character)
                lib:Connect(LocalPlayer.CharacterAdded, hook)
            end
            function panel:Refresh() build() end
            function panel:ResetLayout()
                local pos = defPos()
                lib:Undock(panel.Frame, true)
                if lib.DockItems[panel.Frame] then lib.DockItems[panel.Frame].Docked = true end
                panel.Frame.Position = UDim2.fromOffset(pos.X, pos.Y)
                panel.Frame.Size = UDim2.fromOffset(defSize.X, defSize.Y)
                yaw, pitch, zoom = math.rad(o.Yaw or 180), math.rad(8), o.Zoom or 1.23
            end
            if not o.Position then self:Dock(panel.Frame, dockPos) end
            self.Preview = panel
            return panel
        end

        ----------------------------------------------------------------------------------------------------
        -- keybind objects (shared by Section:Keybind and Toggle:Keybind)
        ----------------------------------------------------------------------------------------------------
        local Keybind = {}
        Keybind.__index = Keybind
        function Keybind:GetState()
            if self.Mode == "Always" then return true end
            if self.Mode == "Hold" then return self.Holding == true end
            return self.Toggled == true
        end
        function Keybind:Set(key)
            self.Key = ToKey(key)
            if self.Display then self.Display() end
            if self.Flag then Library.Flags[self.Flag] = self:Value() end
            if Library.RefreshHotkeys then Library:RefreshHotkeys() end
        end
        function Keybind:SetMode(mode)
            self.Mode = mode
            if self.Flag then Library.Flags[self.Flag] = self:Value() end
            if self.OnState then self.OnState(self:GetState()) end
            if Library.RefreshHotkeys then Library:RefreshHotkeys() end
        end
        function Keybind:Value()
            local kb = self
            return setmetatable({ Key = KeyName(self.Key), Mode = self.Mode }, { __index = function(_, k)
        if k == "Active" or k == "Toggled" or k == "active" or k == "toggled" then return kb:GetState() end
            end })
        end
        local function NewKeybind(o)
            local kb = setmetatable({ Name = o.Name, Flag = o.Flag, Key = ToKey(o.Default or o.Key), Mode = o.Mode or "Toggle", Toggled = false, Holding = false,
        ShowInList = o.ShowInList ~= false, Callback = o.Callback }, Keybind)
            table.insert(Library.Keybinds, kb)
            if kb.Flag then Library.Flags[kb.Flag] = kb:Value(); Library.Items[kb.Flag] = kb end
            return kb
        end
        local function Matches(kb, input)
            if not kb.Key then return false end
            if kb.Key.EnumType == Enum.KeyCode then return input.KeyCode == kb.Key end
            return input.UserInputType == kb.Key
        end
        Library:Connect(UserInputService.InputBegan, function(input, gpe)
            if Library.Binding then return end
            if input.KeyCode == Library.UIBind and not gpe then Library:Toggle() end
            if UserInputService:GetFocusedTextBox() then return end
            for _, kb in ipairs(Library.Keybinds) do
        if Matches(kb, input) then
            if kb.Mode == "Toggle" then kb.Toggled = not kb.Toggled
            elseif kb.Mode == "Hold" then kb.Holding = true end
            if kb.OnState then kb.OnState(kb:GetState()) end
            if kb.Callback then task.spawn(kb.Callback, kb:GetState()) end
            if Library.RefreshHotkeys then Library:RefreshHotkeys() end
        end
            end
        end)
        Library:Connect(UserInputService.InputEnded, function(input)
            for _, kb in ipairs(Library.Keybinds) do
        if kb.Mode == "Hold" and Matches(kb, input) then
            kb.Holding = false
            if kb.OnState then kb.OnState(false) end
            if kb.Callback then task.spawn(kb.Callback, false) end
            if Library.RefreshHotkeys then Library:RefreshHotkeys() end
        end
            end
        end)

        -- right-click menu of a keybind: Mode dropdown + "Show in keybinds list" (244 x 78, measured)
        local function KeybindMenu(kb)
            local m = Mouse()
            local box, fill = Single(Library.Overlay, { Name = "KeybindMenu", Size = UDim2.fromOffset(244, 78), Fill = "Inline", ZIndex = 70 })
            box.Position = ToOverlay(Vector2.new(m.X - 2, m.Y + 8))
            local body = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 1, -12), ZIndex = 70, Parent = fill })
            local holder = { Frame = body, Width = 228, ZIndex = 70, Items = {} }
            local menu = { Keep = { box }, Nest = true }
            function menu.Close() box:Destroy() end
            Library:SetPopup(menu)
            local S = Library._SectionAPI(holder)
            S:Dropdown({ Name = "Mode", Items = { "Toggle", "Hold", "Always" }, Default = kb.Mode, ZIndex = 72, Keep = menu.Keep, Callback = function(v) kb:SetMode(v) end })
            S:Toggle({ Name = "Show in keybinds list", Default = kb.ShowInList, ZIndex = 72, Callback = function(v)
        kb.ShowInList = v
        if Library.RefreshHotkeys then Library:RefreshHotkeys() end
            end })
        end

        ----------------------------------------------------------------------------------------------------
        -- colour picker popup (224 x 224: SV 179x180, hue 19x180, alpha 179x19, preview 19x19)
        ----------------------------------------------------------------------------------------------------
        local function ColorPopup(anchor, state, onChange)
            -- opens beside the top-right corner of the window (inside it when there's no room on screen)
            -- right under the swatch that opened it (right edges lined up), sliding down a little as it fades in
            local ap, as = anchor.AbsolutePosition, anchor.AbsoluteSize
            local target = Vector2.new(ap.X + as.X - 224, ap.Y + as.Y + 6)
            local group = New("CanvasGroup", { Name = "ColorPicker", BackgroundTransparency = 1, GroupTransparency = 1, Size = UDim2.fromOffset(224, 224),
        Position = ToOverlay(target - Vector2.new(0, 6)), ZIndex = 80, Parent = Library.Overlay })
            local box, fill = Single(group, { Name = "Box", Size = UDim2.fromScale(1, 1), Fill = "Inline", ZIndex = 80 })
            Library:Tween(group, "List", { GroupTransparency = 0, Position = ToOverlay(target) })
            local popup = { Keep = { group, anchor }, Conns = {}, Parent = Library.Popup and Library.Popup.Nest and Library.Popup or nil }
            function popup.Close()
        Library:Tween(group, "Fade", { GroupTransparency = 1, Position = ToOverlay(target - Vector2.new(0, 6)) })
        task.delay(0.2, function() group:Destroy() end)
            end
            Library:SetPopup(popup)
            local Z = 80
            -- saturation / value square
            local svb, svf = Single(fill, { Name = "SV", Position = UDim2.fromOffset(8, 7), Size = UDim2.fromOffset(179, 180), Fill = WHITE, ZIndex = Z })
            svf.BackgroundColor3 = Color3.fromHSV(state.H, 1, 1)
            New("UIGradient", { Color = ColorSequence.new(WHITE, WHITE), Transparency = NumberSequence.new(1, 0), Parent =
        New("Frame", { Name = "White", BackgroundColor3 = WHITE, Size = UDim2.fromScale(1, 1), ZIndex = Z, Parent = svf }) })
            New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0), Parent =
        New("Frame", { Name = "Black", BackgroundColor3 = BLACK, Size = UDim2.fromScale(1, 1), ZIndex = Z, Parent = svf }) })
            local dot = New("Frame", { Name = "Cursor", BackgroundColor3 = WHITE, Size = UDim2.fromOffset(2, 2), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = Z, Parent = svf })
            -- hue bar (red at the top, through yellow / green / cyan / blue / magenta back to red)
            local hb, hf = Single(fill, { Name = "Hue", Position = UDim2.fromOffset(193, 7), Size = UDim2.fromOffset(19, 180), Fill = WHITE, ZIndex = Z })
            local keys = {}
            for i = 0, 6 do table.insert(keys, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV((i / 6) % 1, 1, 1))) end
            New("UIGradient", { Rotation = 90, Color = ColorSequence.new(keys), Parent = hf })
            local hcur = New("Frame", { Name = "Cursor", BackgroundColor3 = WHITE, Size = UDim2.new(1, 0, 0, 2), AnchorPoint = Vector2.new(0, 0.5), ZIndex = Z, Parent = hf })
            New("UIStroke", { Color = BLACK, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = hcur })
            -- alpha bar (checker behind, colour fading out to the right)
            local ab, af = Single(fill, { Name = "Alpha", Position = UDim2.fromOffset(8, 193), Size = UDim2.fromOffset(179, 19), Fill = rgb(205, 205, 205), ZIndex = Z })
            local chk = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ClipsDescendants = true, ZIndex = Z, Parent = af })
            for cx = 0, 58 do for cy = 0, 4 do
        if (cx + cy) % 2 == 1 then New("Frame", { BackgroundColor3 = rgb(160, 160, 160), Position = UDim2.fromOffset(cx * 3, cy * 3), Size = UDim2.fromOffset(3, 3), ZIndex = Z, Parent = chk }) end
            end end
            local acol = New("Frame", { Name = "Color", Size = UDim2.fromScale(1, 1), ZIndex = Z, Parent = af })
            New("UIGradient", { Transparency = NumberSequence.new(0, 1), Parent = acol })
            local acur = New("Frame", { Name = "Cursor", BackgroundColor3 = WHITE, Size = UDim2.new(0, 2, 1, 0), AnchorPoint = Vector2.new(0.5, 0), ZIndex = Z, Parent = af })
            New("UIStroke", { Color = BLACK, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = acur })
            -- preview
            local pb, pf = Single(fill, { Name = "Preview", Position = UDim2.fromOffset(193, 193), Size = UDim2.fromOffset(19, 19), Fill = WHITE, ZIndex = Z })

            local function redraw()
        local c = Color3.fromHSV(state.H, state.S, state.V)
        svf.BackgroundColor3 = Color3.fromHSV(state.H, 1, 1)
        dot.Position = UDim2.fromScale(1 - state.S, 1 - state.V)
        hcur.Position = UDim2.fromScale(0, state.H)
        acol.BackgroundColor3 = c
        acur.Position = UDim2.fromScale(state.A, 0)
        pf.BackgroundColor3 = c
        pf.BackgroundTransparency = state.A
            end
            redraw()
            local function drag(area, fn)
        local held = false
        local btn = Button(area, { Size = UDim2.fromScale(1, 1), ZIndex = Z + 1 })
        table.insert(popup.Conns, btn.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 then held = true; fn(); end
        end))
        table.insert(popup.Conns, UserInputService.InputChanged:Connect(function(i)
            if held and i.UserInputType == Enum.UserInputType.MouseMovement then fn() end
        end))
        table.insert(popup.Conns, UserInputService.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 then held = false end
        end))
            end
            local function rel(obj)
        local m = Mouse()
        local p, s = obj.AbsolutePosition, obj.AbsoluteSize
        return clamp((m.X - p.X) / s.X, 0, 1), clamp((m.Y - p.Y) / s.Y, 0, 1)
            end
            drag(svf, function() local x, y = rel(svf); state.S, state.V = 1 - x, 1 - y; redraw(); onChange() end)
            drag(hf, function() local _, y = rel(hf); state.H = min(y, 0.999); redraw(); onChange() end)
            drag(af, function() local x = rel(af); state.A = x; redraw(); onChange() end)
            return popup
        end

        ----------------------------------------------------------------------------------------------------
        -- section / element API
        ----------------------------------------------------------------------------------------------------
        -- holder = { Frame = parent frame, Width = content width, Items = {}, Relayout = fn }
        local Heights = { Toggle = 16, Button = 22, Slider = 25, Dropdown = 40, Colorpicker = 16, Keybind = 16, Textbox = 40, Divider = 10, Label = 16 }
        local function SectionAPI(holder)
            local S = { Holder = holder }
            local Z = holder.ZIndex or 1
            local function layout()
        local y = 0
        for _, it in ipairs(holder.Items) do
            if it.Visible ~= false then
                it.Frame.Position = UDim2.fromOffset(0, y)
                it.Frame.Visible = true
                y = y + it.Height + 6
            else
                it.Frame.Visible = false
            end
        end
        holder.ContentHeight = max(0, y - 6)
        if holder.Relayout then holder.Relayout() end
            end
            holder.Layout = layout
            local function item(kind, extraH)
        local f = New("Frame", { Name = kind, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, Heights[kind] + (extraH or 0)), ZIndex = Z, Parent = holder.Frame })
        local it = { Frame = f, Height = Heights[kind] + (extraH or 0), Visible = true }
        table.insert(holder.Items, it)
        local api = {}
        function api:SetVisibility(v) it.Visible = v and true or false; layout() end
        api.SetVisible = api.SetVisibility
        api.Frame = f
        return f, it, api
            end
            local function zI(o) return o.ZIndex or Z end

            -- toggle (2nd recording): 14 px box on the left, label 8 px after it; grey label off, white on
            function S:Toggle(o)
        o = o or {}
        local f, it, api = item("Toggle")
        local z = zI(o)
        f.ZIndex = z
        local value = o.Default == true
        local cb = New("Frame", { Name = "Check", Position = UDim2.fromOffset(0, 1), Size = UDim2.fromOffset(14, 14), ZIndex = z, Parent = f })
        Library:Themed(cb, "BackgroundColor3", "Border")
        local cfill = New("Frame", { Name = "Fill", Position = UDim2.fromOffset(1, 1), Size = UDim2.new(1, -2, 1, -2), ZIndex = z, Parent = cb })
        Library:Themed(cfill, "BackgroundColor3", "Element")
        Shade(cfill)
        local pour = New("Frame", { Name = "On", Size = UDim2.fromScale(1, value and 1 or 0), BackgroundTransparency = value and 0 or 1, ZIndex = z, Parent = cfill })
        Library:Themed(pour, "BackgroundColor3", "Accent")
        local pg = Shade(pour)
        local label = Text(f, { Text = o.Name or o.Title or "Toggle", X = 22, Y = 4, W = 180, Color = value and "Text" or "Inactive Text", ZIndex = z })
        local btn = Button(f, { Size = UDim2.fromScale(1, 1), ZIndex = z + 1 })
        local cursor = 0
        local hovering = false
        local function set(v, silent)
            value = v and true or false
            Library:Tween(pour, "Pour", { Size = UDim2.fromScale(1, value and 1 or 0), BackgroundTransparency = value and 0 or 1 })
            if not value then Library:TweenTheme(cfill, "BackgroundColor3", hovering and "Hovered Element" or "Element", "Check") end
            Library:TweenTheme(label, "TextColor3", value and "Text" or "Inactive Text", "Check")
            if o.Flag then Library.Flags[o.Flag] = value end
            if not silent and o.Callback then task.spawn(o.Callback, value) end
        end
        Library:Connect(btn.MouseButton1Click, function() set(not value) end)
        Library:Connect(btn.MouseEnter, function() hovering = true; if not value then Library:TweenTheme(cfill, "BackgroundColor3", "Hovered Element", "Hover") end end)
        Library:Connect(btn.MouseLeave, function() hovering = false; if not value then Library:TweenTheme(cfill, "BackgroundColor3", "Element", "Hover") end end)
        if o.Flag then Library.Flags[o.Flag] = value; Library.Items[o.Flag] = api end
        function api:Set(v) set(v) end
        function api:Get() return value end
        api.Object = api
        local reg = { Kind = "Toggle", Name = o.Name or o.Title or "", Holder = holder, Get = function() return value end, Colors = {} }
        table.insert(Library.Registry, reg)
        -- chained addons
        function api:Keybind(k)
            k = k or {}
            local kb = NewKeybind({ Name = k.Name or o.Name, Flag = k.Flag, Default = k.Default, Mode = k.Mode, Callback = k.Callback, ShowInList = k.ShowInList })
            local txt = Text(f, { Color = "Inactive Text", XAlign = Enum.TextXAlignment.Right, ZIndex = z,
                Position = UDim2.new(1, cursor - 80, 0, 2), Size = UDim2.fromOffset(80, 13) })
            local kbtn = Button(txt, { Size = UDim2.fromScale(1, 1), ZIndex = z + 2 })
            local function display() txt.Text = "[" .. KeyName(kb.Key) .. "]" end
            kb.Display = display
            display()
            cursor = cursor - TextWidth(txt.Text) - 6
            Library:Connect(kbtn.MouseButton1Click, function()
                txt.Text = "[...]"
                Library.Binding = true
                local c
                c = UserInputService.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.Keyboard or input.UserInputType.Name:find("MouseButton") then
                        c:Disconnect()
                        local key = input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode or input.UserInputType
                        if key == Enum.KeyCode.Escape or key == Enum.KeyCode.Backspace then key = nil end
                        kb:Set(key)
                        task.defer(function() Library.Binding = false end)
                    end
                end)
            end)
            Library:Connect(kbtn.MouseButton2Click, function() KeybindMenu(kb) end)
            return api
        end
        function api:Colorpicker(c)
            c = c or {}
            local sw = S._Swatch(f, c, UDim2.new(1, cursor - 24, 0, 0), z)
            cursor = cursor - 24 - 6
            -- swatches are added right-to-left, so keep them in on-screen (left-to-right) order
            table.insert(reg.Colors, 1, sw)
            return api
        end
        api.KeyPicker, api.ColorPicker = api.Keybind, api.Colorpicker
        layout()
        return api
            end

            -- button (2nd recording): 22 tall, 1 px border, outlined text; click flashes the accent
            function S:Button(o)
        o = o or {}
        local f, it, api = item("Button")
        local z = zI(o)
        local box = New("Frame", { Name = "Box", Size = UDim2.fromScale(1, 1), ZIndex = z, Parent = f })
        Library:Themed(box, "BackgroundColor3", "Border")
        local fill = New("Frame", { Name = "Fill", Position = UDim2.fromOffset(1, 1), Size = UDim2.new(1, -2, 1, -2), ZIndex = z, Parent = box })
        Library:Themed(fill, "BackgroundColor3", "Element")
        Shade(fill)
        Text(f, { Text = o.Name or o.Title or "Button", Position = UDim2.fromOffset(0, 5), Size = UDim2.new(1, 0, 0, 13), XAlign = Enum.TextXAlignment.Center, Stroke = true, ZIndex = z })
        local btn = Button(f, { Size = UDim2.fromScale(1, 1), ZIndex = z + 1 })
        local hovering = false
        Library:Connect(btn.MouseEnter, function() hovering = true; Library:TweenTheme(fill, "BackgroundColor3", "Hovered Element", "Hover") end)
        Library:Connect(btn.MouseLeave, function() hovering = false; Library:TweenTheme(fill, "BackgroundColor3", "Element", "Hover") end)
        Library:Connect(btn.MouseButton1Click, function()
            Library:TweenTheme(fill, "BackgroundColor3", "Accent", "FlashIn")
            task.delay(0.1, function() Library:TweenTheme(fill, "BackgroundColor3", hovering and "Hovered Element" or "Element", "FlashOut") end)
            if o.Callback then task.spawn(o.Callback) end
        end)
        layout()
        return api
            end

            function S:Slider(o)
        o = o or {}
        local f, it, api = item("Slider")
        local z = zI(o)
        local mn, mx = o.Min or 0, o.Max or 100
        local step = o.Decimals or o.Increment or o.Rounding or 1
        if step >= 1 and o.Rounding and o.Rounding >= 1 and o.Rounding < 10 and not o.Decimals then step = 10 ^ -o.Rounding end
        local suffix = o.Suffix or ""
        if suffix ~= "" and suffix:sub(1, 1) ~= " " and suffix:match("^%a") then suffix = " " .. suffix end
        local value = clamp(o.Default or mn, mn, mx)
        Text(f, { Text = o.Name or o.Title or "Slider", X = 0, Y = 1, W = 220, ZIndex = z })
        -- 10 px bar: 1 px border, dark track, shaded accent fill; the value sits centred on the end of the fill
        local bar = New("Frame", { Name = "Bar", Position = UDim2.fromOffset(0, 13), Size = UDim2.new(1, 0, 0, 10), ZIndex = z, Parent = f })
        Library:Themed(bar, "BackgroundColor3", "Border")
        local track = New("Frame", { Name = "Track", Position = UDim2.fromOffset(1, 1), Size = UDim2.new(1, -2, 1, -2), ZIndex = z, Parent = bar })
        Library:Themed(track, "BackgroundColor3", "Inline")
        local fillF = New("Frame", { Name = "Value", Size = UDim2.fromScale(0, 1), ZIndex = z, Parent = track })
        Library:Themed(fillF, "BackgroundColor3", "Accent")
        Shade(fillF)
        local vt = Text(track, { Mono = true, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0, 0, 0, 1), Size = UDim2.fromOffset(80, 13),
            XAlign = Enum.TextXAlignment.Center, Stroke = true, ZIndex = z + 1 })
        local function fmt(v)
            local s
            if step >= 1 then s = tostring(floor(v + 0.5)) else
                local places = max(0, ceil(-math.log10(step) - 1e-9))
                s = string.format("%." .. places .. "f", v)
            end
            return s .. suffix
        end
        local function set(v, silent)
            v = clamp(v, mn, mx)
            v = floor(v / step + 0.5) * step
            v = clamp(v, mn, mx)
            value = v
            local a = (v - mn) / max(mx - mn, 1e-9)
            Library:Tween(fillF, "Slide", { Size = UDim2.fromScale(a, 1) })
            vt.Text = fmt(v)
            -- keep the value on the end of the fill but never let it hang outside the bar
            local W, tw = track.AbsoluteSize.X, ADV_MONO * #vt.Text
            local pos = UDim2.new(a, 0, 0, 1)
            if W > 1 then pos = UDim2.new(0, floor(clamp(a * W, tw / 2 + 1, max(tw / 2 + 1, W - tw / 2 - 1))), 0, 1) end
            Library:Tween(vt, "Slide", { Position = pos })
            if o.Flag then Library.Flags[o.Flag] = v end
            if not silent and o.Callback then task.spawn(o.Callback, v) end
        end
        set(value, true)
        local btn = Button(bar, { Size = UDim2.fromScale(1, 1), ZIndex = z + 1 })
        local held = false
        local function upd()
            local m = Mouse()
            local p, s = track.AbsolutePosition, track.AbsoluteSize
            set(mn + (mx - mn) * clamp((m.X - p.X) / s.X, 0, 1))
        end
        Library:Connect(btn.InputBegan, function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then held = true; upd() end end)
        Library:Connect(UserInputService.InputChanged, function(i) if held and i.UserInputType == Enum.UserInputType.MouseMovement then upd() end end)
        Library:Connect(UserInputService.InputEnded, function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then held = false end end)
        if o.Flag then Library.Flags[o.Flag] = value; Library.Items[o.Flag] = api end
        function api:Set(v) set(v) end
        function api:Get() return value end
        table.insert(Library.Registry, { Kind = "Slider", Name = o.Name or o.Title or "", Holder = holder, Get = function() return value end, Min = mn, Max = mx })
        layout()
        return api
            end

            function S:Dropdown(o)
        o = o or {}
        local f, it, api = item("Dropdown")
        local z = zI(o)
        local items = o.Items or o.Values or o.Options or {}
        local multi = o.Multi == true
        local value = multi and {} or (o.Default or items[1])
        if multi and type(o.Default) == "table" then for _, v in ipairs(o.Default) do value[v] = true end end
        Text(f, { Text = o.Name or o.Title or "Dropdown", X = 0, Y = 1, W = 220, ZIndex = z })
        local box, fill = Double(f, { Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 22), ZIndex = z })
        local shown = Text(box, { X = 8, Y = 7, Size = UDim2.new(1, -30, 0, 13), Color = "Inactive Text", ZIndex = z })
        shown.ClipsDescendants = true
        -- arrow: 8x4 triangle (rows 8,6,4,2 px) 9 px from the right, rotates -90 while open
        local arrow = New("Frame", { Name = "Arrow", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -13, 0, 11), Size = UDim2.fromOffset(8, 8), ZIndex = z, Parent = box })
        for r = 0, 3 do
            local seg = New("Frame", { Position = UDim2.fromOffset(r, 2 + r), Size = UDim2.fromOffset(8 - 2 * r, 1), ZIndex = z, Parent = arrow })
            Library:Themed(seg, "BackgroundColor3", "Inactive Text")
        end
        local function text()
            if multi then
                local t = {}
                for _, v in ipairs(items) do if value[v] then table.insert(t, tostring(v)) end end
                return #t > 0 and table.concat(t, ", ") or ". ."
            end
            return value ~= nil and tostring(value) or ". ."
        end
        local function flag()
            if not multi then return value end
            local t = {}
            for _, v in ipairs(items) do if value[v] then table.insert(t, v) end end
            return t
        end
        local function refresh() shown.Text = text(); if o.Flag then Library.Flags[o.Flag] = flag() end end
        refresh()
        local btn = Button(box, { Size = UDim2.fromScale(1, 1), ZIndex = z + 1 })
        Library:Connect(btn.MouseEnter, function() Library:TweenTheme(fill, "BackgroundColor3", "Hovered Element", "Hover") end)
        Library:Connect(btn.MouseLeave, function() Library:TweenTheme(fill, "BackgroundColor3", "Element", "Hover") end)
        local open
        local function close()
            if not open then return end
            local o2 = open
            open = nil
            Library:Tween(arrow, "List", { Rotation = 0 })
            Library:Tween(o2.Group, "List", { GroupTransparency = 1, Position = o2.Group.Position - UDim2.fromOffset(0, 6) })
            task.delay(0.25, function() o2.Root:Destroy() end)
        end
        local function openList()
            local ap, as = box.AbsolutePosition, box.AbsoluteSize
            local h = 12 + 20 * #items
            local group = New("CanvasGroup", { Name = "DropdownList", BackgroundTransparency = 1, GroupTransparency = 1,
                Position = ToOverlay(Vector2.new(ap.X, ap.Y + as.Y + 8 - 6)), Size = UDim2.fromOffset(as.X, h), ZIndex = 90, Parent = Library.Overlay })
            -- same frame as the dropdown box itself: Border, Outline, Border, Outline, shaded Element fill
            local lb, lf = Double(group, { Size = UDim2.fromScale(1, 1), Fill = "Inline", Flat = true, ZIndex = 90 })
            local rows = {}
            local function isSel(v) return (multi and value[v]) or (not multi and v == value) end
            -- selected rows turn pure white and ease 4 px to the right; the rest sit grey at their normal spot
            local function style(i, instant)
                local l, on = rows[i], isSel(items[i])
                local x = on and 4 or 0
                if on then
                    if Library.ThemeObjects[l] then Library.ThemeObjects[l].TextColor3 = nil end
                    if instant then l.TextColor3 = WHITE else Library:Tween(l, "Check", { TextColor3 = WHITE }) end
                elseif instant then
                    Library:Themed(l, "TextColor3", "Inactive Text")
                else
                    Library:TweenTheme(l, "TextColor3", "Inactive Text", "Check")
                end
                local pos = UDim2.fromOffset(7 - 1 + x, 7 - 2 + (i - 1) * 20)
                if instant then l.Position = pos else Library:Tween(l, "Check", { Position = pos }) end
            end
            for i, v in ipairs(items) do
                local l = Text(lf, { Text = tostring(v), X = 7, Y = 7 + (i - 1) * 20, W = as.X - 28, Color = "Inactive Text", ZIndex = 90 })
                local b = Button(lf, { Position = UDim2.fromOffset(0, 2 + (i - 1) * 20), Size = UDim2.new(1, 0, 0, 20), ZIndex = 91 })
                rows[i] = l
                style(i, true)
                Library:Connect(b.MouseEnter, function() if not isSel(v) then Library:TweenTheme(l, "TextColor3", "Text", "Hover") end end)
                Library:Connect(b.MouseLeave, function() if not isSel(v) then Library:TweenTheme(l, "TextColor3", "Inactive Text", "Hover") end end)
                Library:Connect(b.MouseButton1Click, function()
                    if multi then value[v] = not value[v] else value = v end
                    for j = 1, #items do style(j) end
                    refresh()
                    if o.Callback then task.spawn(o.Callback, flag()) end
                    -- stays open: closes only when you click the dropdown again or anywhere outside it
                end)
            end
            open = { Root = group, Group = group, Keep = { group, box }, Close = close,
                Parent = Library.Popup and Library.Popup.Nest and Library.Popup or nil }
            Library:SetPopup(open)
            Library:Tween(arrow, "List", { Rotation = -90 })
            Library:Tween(group, "List", { GroupTransparency = 0, Position = ToOverlay(Vector2.new(ap.X, ap.Y + as.Y + 8)) })
        end
        Library:Connect(btn.MouseButton1Click, function()
            if open then Library:SetPopup(open.Parent) else openList() end
        end)
        if o.Flag then Library.Items[o.Flag] = api end
        function api:Set(v)
            if multi then value = {}; for _, x in ipairs(type(v) == "table" and v or { v }) do value[x] = true end else value = v end
            refresh()
            if o.Callback then task.spawn(o.Callback, flag()) end
        end
        function api:Get() return flag() end
        function api:SetValues(list)
            items = list or {}
            if not multi and value ~= nil and not table.find(items, value) then value = items[1] end
            refresh()
        end
        api.Refresh = api.SetValues
        layout()
        return api
            end

            -- colour swatch (24 x 16) used by Section:Colorpicker and Toggle:Colorpicker
            function S._Swatch(parent, c, pos, z)
        local col = c.Default or c.Color or WHITE
        local h, s, v = col:ToHSV()
        local state = { H = h, S = s, V = v, A = c.Transparency or c.Alpha or 0 }
        local sb, sf = Single(parent, { Name = "Swatch", Position = pos, Size = UDim2.fromOffset(24, 16), Fill = col, ZIndex = z })
        Shade(sf)
        local btn = Button(sb, { Size = UDim2.fromScale(1, 1), ZIndex = z + 1 })
        local obj = {}
        local function emit(silent)
            local cc = Color3.fromHSV(state.H, state.S, state.V)
            sf.BackgroundColor3 = cc
            obj.Value, obj.Transparency = cc, state.A
            if c.Flag then Library.Flags[c.Flag] = { Color = cc, Transparency = state.A } end
            if not silent and c.Callback then task.spawn(c.Callback, cc, state.A) end
        end
        emit(true)
        Library:Connect(btn.MouseButton1Click, function()
            if Library.Popup and Library.Popup.Swatch == sb then Library:SetPopup(nil) return end
            local p = ColorPopup(sb, state, emit)
            p.Swatch = sb
        end)
        function obj:Set(cc, a)
            if typeof(cc) == "table" then a = cc.Transparency; cc = cc.Color end
            state.H, state.S, state.V = cc:ToHSV()
            if a then state.A = a end
            emit()
        end
        function obj:Get() return obj.Value, obj.Transparency end
        if c.Flag then Library.Items[c.Flag] = obj end
        return obj
            end

            function S:Colorpicker(o)
        o = o or {}
        local f, it, api = item("Colorpicker")
        local z = zI(o)
        Text(f, { Text = o.Name or o.Title or "Colorpicker", X = 0, Y = 4, W = 180, ZIndex = z })
        local sw = S._Swatch(f, o, UDim2.new(1, -24, 0, 0), z)
        api.Set, api.Get = function(_, ...) sw:Set(...) end, function() return sw:Get() end
        layout()
        return api
            end
            S.ColorPicker = S.Colorpicker

            function S:Keybind(o)
        o = o or {}
        local f, it, api = item("Keybind")
        local z = zI(o)
        Text(f, { Text = o.Name or o.Title or "Keybind", X = 0, Y = 4, W = 180, ZIndex = z })
        local kb = NewKeybind({ Name = o.Name, Flag = o.Flag, Default = o.Default or o.Key, Mode = o.Mode, Callback = o.Callback, ShowInList = o.ShowInList })
        local txt = Text(f, { Position = UDim2.new(1, -120, 0, 2), Size = UDim2.fromOffset(120, 13), XAlign = Enum.TextXAlignment.Right, Color = "Inactive Text", ZIndex = z })
        local function display() txt.Text = "[" .. KeyName(kb.Key) .. "]" end
        kb.Display = display
        display()
        local btn = Button(f, { Size = UDim2.fromScale(1, 1), ZIndex = z + 1 })
        Library:Connect(btn.MouseButton1Click, function()
            txt.Text = "[...]"
            Library.Binding = true
            local c
            c = UserInputService.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.Keyboard or input.UserInputType.Name:find("MouseButton") then
                    c:Disconnect()
                    local key = input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode or input.UserInputType
                    if key == Enum.KeyCode.Escape or key == Enum.KeyCode.Backspace then key = nil end
                    kb:Set(key)
                    if o.Changed then task.spawn(o.Changed, key) end
                    task.defer(function() Library.Binding = false end)
                end
            end)
        end)
        Library:Connect(btn.MouseButton2Click, function() if not o.NoMenu then KeybindMenu(kb) end end)
        api.Keybind = kb
        function api:Set(k) kb:Set(k) end
        function api:Get() return kb:Value() end
        function api:GetState() return kb:GetState() end
        layout()
        return api
            end

            function S:Textbox(o)
        o = o or {}
        local f, it, api = item("Textbox")
        local z = zI(o)
        Text(f, { Text = o.Name or o.Title or "Textbox", X = 0, Y = 1, W = 220, ZIndex = z })
        local box, fill = Double(f, { Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 22), ZIndex = z })
        local tb = New("TextBox", { BackgroundTransparency = 1, Text = o.Default or "", PlaceholderText = o.Placeholder or ". . .", ClearTextOnFocus = false,
            FontFace = Library.FontMain, TextSize = Library.TextSize, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Library.CenterText and Enum.TextYAlignment.Center or Enum.TextYAlignment.Top,
            Position = UDim2.fromOffset(7, 5), Size = UDim2.new(1, -14, 0, 13), ClipsDescendants = true, ZIndex = z + 1, Parent = box })
        Library:Themed(tb, "TextColor3", "Text")
        Library:Themed(tb, "PlaceholderColor3", "Inactive Text")
        local function set(v, silent)
            tb.Text = tostring(v or "")
            if o.Flag then Library.Flags[o.Flag] = tb.Text end
            if not silent and o.Callback then task.spawn(o.Callback, tb.Text) end
        end
        set(tb.Text, true)
        Library:Connect(tb.FocusLost, function() set(tb.Text) end)
        if o.Flag then Library.Items[o.Flag] = api end
        api.Box = tb
        function api:Set(v) set(v) end
        function api:Get() return tb.Text end
        layout()
        return api
            end
            S.TextBox, S.Input = S.Textbox, S.Textbox

            function S:Divider()
        local f, it, api = item("Divider")
        local line = New("Frame", { Name = "Line", Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 2), ZIndex = Z, Parent = f })
        Library:Themed(line, "BackgroundColor3", "Element")
        layout()
        return api
            end

            function S:Label(o)
        if type(o) == "string" then o = { Name = o } end
        o = o or {}
        local f, it, api = item("Label")
        local l = Text(f, { Text = o.Name or o.Text or "", X = 0, Y = 4, W = 300, ZIndex = zI(o) })
        function api:Set(t) l.Text = t end
        layout()
        return api
            end
            return S
        end
        Library._SectionAPI = SectionAPI

        ----------------------------------------------------------------------------------------------------
        -- window
        ----------------------------------------------------------------------------------------------------
        local Months = { "jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec" }
        ----------------------------------------------------------------------------------------------------
        -- crosshair: five styles drawn from frames, dead centre of the screen, recolourable, optional spin
        ----------------------------------------------------------------------------------------------------
        Library.CrosshairStyles = { "Plus", "Star", "Cross", "Box", "Tri" }
        Library.CrosshairState = { Enabled = false, Style = "Plus", Color = rgb(40, 230, 60), Spin = false, Speed = 180, Scale = 1 }
        function Library:Crosshair()
            if self.CrosshairFrame then return self.CrosshairFrame end
            local st = self.CrosshairState
            -- own ScreenGui that ignores the top-bar inset, so (0.5, 0.5) is the exact centre of the camera view
            local gui = New("ScreenGui", { Name = "crosshair", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 1000 })
            pcall(function() if syn and syn.protect_gui then syn.protect_gui(gui) end end)
            Parent(gui)
            -- even-sized pivot centred on a pixel corner; every shape below uses even sizes so nothing lands on half pixels
            local root = New("Frame", { Name = "Crosshair", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(200, 200), Visible = false, Parent = gui })
            local scale = New("UIScale", { Scale = st.Scale, Parent = root })
            local parts = {}
            -- rectangle centred at (cx, cy) from the middle, w x h
            local function rect(cx, cy, w, h, rot, colour)
                local f = New("Frame", { BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, cx, 0.5, cy),
                    Size = UDim2.fromOffset(w, h), Rotation = rot or 0, BackgroundColor3 = colour or st.Color, Parent = root })
                if not colour then table.insert(parts, f) end
                return f
            end
            local Draw = {
                -- solid plus (20 x 20, 4 thick)
                Plus = function() rect(0, 0, 4, 20); rect(0, 0, 20, 4) end,
                -- stepped four-point star with a dark pin-hole in the middle
                Star = function()
                    rect(0, 0, 2, 22); rect(0, 0, 4, 18); rect(0, 0, 8, 14); rect(0, 0, 14, 8); rect(0, 0, 22, 4)
                    rect(0, 0, 2, 2, 0, rgb(10, 10, 10))
                end,
                -- four 2 px arms (18 long) with an 8 px gap, plus a 2 px centre dot
                Cross = function()
                    local L, G, T = 18, 8, 2
                    rect(0, -(G + L / 2), T, L); rect(0, G + L / 2, T, L)
                    rect(-(G + L / 2), 0, L, T); rect(G + L / 2, 0, L, T)
                    rect(0, 0, 2, 2)
                end,
                -- four corner brackets around a small thick plus
                Box = function()
                    local H, A, T = 38, 22, 2   -- half size, bracket arm length, thickness
                    for _, sx in ipairs({ -1, 1 }) do for _, sy in ipairs({ -1, 1 }) do
                        rect(sx * (H - A / 2), sy * (H - T / 2), A, T)
                        rect(sx * (H - T / 2), sy * (H - A / 2), T, A)
                    end end
                    rect(0, 0, 4, 12); rect(0, 0, 12, 4)
                end,
                -- three 2 px arms 120 degrees apart (one straight up) with a 2 px centre dot
                Tri = function()
                    local L, G = 20, 9
                    for k = 0, 2 do
                        local a = math.rad(-90 + k * 120)
                        local d = G + L / 2
                        rect(math.cos(a) * d, math.sin(a) * d, 2, L, math.deg(a) + 90)
                    end
                    rect(0, 0, 2, 2)
                end,
            }
            local function rebuild()
                for _, c in ipairs(root:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
                for k in pairs(parts) do parts[k] = nil end
                ;(Draw[st.Style] or Draw.Plus)()
            end
            local angle = 0
            self:Connect(RunService.RenderStepped, function(dt)
                if not root.Visible then return end
                if st.Spin then angle = (angle + st.Speed * dt) % 360 else angle = 0 end
                root.Rotation = angle
            end)
            local X = { Frame = root, Gui = gui }
            function X:Refresh()
                rebuild()
                root.Visible = st.Enabled
                scale.Scale = st.Scale
            end
            function X:SetColor(c) st.Color = c; for _, f in ipairs(parts) do f.BackgroundColor3 = c end end
            X:Refresh()
            self.CrosshairFrame = X
            local unload = self.OnUnload
            self.OnUnload = function() pcall(function() gui:Destroy() end); if unload then unload() end end
            return X
        end
        function Library:SetCrosshair(key, value)
            self.CrosshairState[key] = value
            local X = self:Crosshair()
            if key == "Color" then X:SetColor(value) else X:Refresh() end
        end

        function Library:Window(o)
            o = o or {}
            local lib = self
            local W = { Pages = {}, Library = self }
            local size = o.Size or Vector2.new(684, 463)
            local cam = workspace.CurrentCamera
            local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
            local root = New("Frame", { Name = "Window", Position = UDim2.fromOffset(floor((vp.X - size.X) / 2), floor((vp.Y - size.Y) / 2)),
        Size = UDim2.fromOffset(size.X, size.Y), ZIndex = 1, Parent = self.Gui })
            self:Themed(root, "BackgroundColor3", "Border")
            local outl = New("Frame", { Name = "Outline", Position = UDim2.fromOffset(1, 1), Size = UDim2.new(1, -2, 1, -2), Parent = root })
            self:Themed(outl, "BackgroundColor3", "Outline")
            local body = New("Frame", { Name = "Body", Position = UDim2.fromOffset(1, 1), Size = UDim2.new(1, -2, 1, -2), Parent = outl })
            self:Themed(body, "BackgroundColor3", "Background")
            W.Root = root
            -- body is offset by 2 px from the window; positions below are window-relative minus 2
            local function at(x, y) return UDim2.fromOffset(x - 2, y - 2) end

            -- title bar
            local drag = Button(body, { Name = "Drag", Position = at(2, 2), Size = UDim2.new(1, 0, 0, 30), ZIndex = 1 })
            self:Draggable(drag, root)
            local _logoSize = 20
            local _logo = New("ImageLabel", { Name = "Logo", BackgroundTransparency = 1, Image = "rbxassetid://79304561643201", Position = UDim2.fromOffset(11, 7), Size = UDim2.fromOffset(_logoSize, _logoSize), ZIndex = 2, Parent = body })
            local titleLbl = Text(body, { Name = "Title", Text = "", Position = UDim2.fromOffset(13 - 2 + _logoSize + 4 - 1, 7), Size = UDim2.fromOffset(300, _logoSize), ZIndex = 2 })
            titleLbl.TextSize = o.TitleSize or 12
            titleLbl.TextYAlignment = Enum.TextYAlignment.Center
            titleLbl.RichText = true
            titleLbl.Text = VersionTag(o.Name or o.Title or "genesis", o.Version)
            W.TitleLabel = titleLbl
            local d = os.date("*t")
            local dateText = o.Date or string.format("%s %d %d", Months[d.month], d.day, d.year)
            Text(body, { Name = "Date", Text = dateText, Position = UDim2.new(1, -200 - (684 - 672) + 2 - 24, 0, 11 - 2), Size = UDim2.fromOffset(200, 13),
        XAlign = Enum.TextXAlignment.Right, Color = "Inactive Text" })
            FadeLine(body, { Name = "Glow", Position = at(2, 31), Size = UDim2.new(1, 0, 0, 3), Color = "AccentGlow",
        Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.85, 1), NumberSequenceKeypoint.new(1, 1) }) })
            FadeLine(body, { Name = "AccentLine", Position = at(2, 34), Size = UDim2.new(1, 0, 0, 1),
        Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.02), NumberSequenceKeypoint.new(1, 0.96) }) })

            -- inner panel (10,43)-(673,452)
            local panel, pfill = Single(body, { Name = "Panel", Position = at(10, 43), Size = UDim2.new(1, -16, 1, -49), Fill = "Inline" })
            -- pfill origin = window (12,45)
            -- bottom bar (same height as the profile card): card on the left, page tabs spread evenly across the rest
            local BAR = 51
            local div1 = New("Frame", { Name = "Divider", Position = UDim2.new(0, 160 - 12, 1, -BAR), Size = UDim2.new(0, 1, 0, BAR), Parent = pfill })
            self:Themed(div1, "BackgroundColor3", "Border")
            local div2 = New("Frame", { Name = "Divider2", Position = UDim2.new(0, 161 - 12, 1, -BAR), Size = UDim2.new(0, 1, 0, BAR), Parent = pfill })
            self:Themed(div2, "BackgroundColor3", "Outline")
            local tabs = New("Frame", { Name = "Tabs", BackgroundTransparency = 1, Position = UDim2.new(0, 162 - 12, 1, -BAR + 1), Size = UDim2.new(1, -(162 - 12), 0, BAR - 1), Parent = pfill })

            -- user card (separator at y 400, headshot, name, role)
            local sep = New("Frame", { Name = "CardLine", Position = UDim2.new(0, 0, 1, -(452 - 400) + 1 - 1), Size = UDim2.new(1, 0, 0, 1), Parent = pfill })
            sep.Position = UDim2.new(0, 0, 1, -(451 - 400))
            self:Themed(sep, "BackgroundColor3", "Outline")
            local avatar = New("ImageLabel", { Name = "Avatar", BackgroundTransparency = 1, Position = UDim2.new(0, 21 - 12, 1, -(451 - 411)), Size = UDim2.fromOffset(30, 30), Parent = pfill })
            task.spawn(function()
        pcall(function()
            avatar.Image = Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
        end)
            end)
            local uname = "player"
            pcall(function() uname = LocalPlayer.Name end)
            Text(pfill, { Name = "User", Text = o.User or uname, Position = UDim2.new(0, 62 - 12 - 1, 1, -(451 - 414) - 2), Size = UDim2.fromOffset(140, 13) })
            Text(pfill, { Name = "Role", Text = o.Role or "admin", Position = UDim2.new(0, 62 - 12 - 1, 1, -(451 - 430) - 2), Size = UDim2.fromOffset(140, 13), Color = "Inactive Text" })

            -- content area (162,45)-(671,450)
            local content = New("Frame", { Name = "Content", BackgroundTransparency = 1, ClipsDescendants = true, Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(1, 0, 1, -BAR), Parent = pfill })

            -- settings gear (top-right corner): one-colour anti-aliased gear; accent blue, lighter on hover, yellow while Settings is open
            local gear = Button(body, { Name = "Settings", Position = UDim2.new(1, -(684 - 672) + 2 - 16, 0, 9 - 2 - 1), Size = UDim2.fromOffset(16, 16), ZIndex = 3 })
            local gparts = {}
            local gearImg
            pcall(function()
                if not (writefile and getcustomasset) then return end
                if isfolder and not isfolder("genesis_fonts") then makefolder("genesis_fonts") end
                writefile("genesis_fonts/gear.png", b64decode("iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAABCElEQVR4Xq2TTU6DMQxEp39C3IIroHIBJDbtglOw4SZcCLEAsUDdcgfuQduHXuqICLFqO5K/WJ6x4y9OAqRsWuscmAEr4LVM35ic+q7NNL/YJ1km2SbZJblKclemb0xOjdoDqvIEeOSAJ+AWeAe2ZfrG5IRac2a9/Zsi9rV29AIjusac1sECuKzqO+C7dv0Li8mpsRNzFr0D12to1RWJZ+C+TF/IqVHbcv14wg/AR1VX8DJMp29iTM4O1JqzktwMvdqmWNchXUAzD8yY6BqxGcd4HM7xC/0fjz7Es4zxpIvkIzn5KvdzWA7z72+j3/3/NJkPs3Okn0mLkeQryVvx+rMkk9KobS/yB1Ap6hgZdP9FAAAAAElFTkSuQmCC"))
                gearImg = New("ImageLabel", { Name = "Gear", BackgroundTransparency = 1, Image = getcustomasset("genesis_fonts/gear.png"),
                    Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = gear })
            end)
            if not gearImg then
                -- no getcustomasset: a simple shape version
                local body0 = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(13, 13), ZIndex = 3, Parent = gear })
                New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = body0 })
                table.insert(gparts, body0)
                for k = 0, 7 do
                    local a = math.rad(k * 45 + 22.5)
                    local t = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, math.cos(a) * 7, 0.5, math.sin(a) * 7),
                        Size = UDim2.fromOffset(4, 4), Rotation = k * 45 + 22.5, ZIndex = 3, Parent = gear })
                    New("UICorner", { CornerRadius = UDim.new(0, 1), Parent = t })
                    table.insert(gparts, t)
                end
            end
            local function gearColor(key)
                if gearImg then lib:TweenTheme(gearImg, "ImageColor3", key, "Hover") end
                for _, f in ipairs(gparts) do lib:TweenTheme(f, "BackgroundColor3", key, "Hover") end
            end
            if gearImg then self:Themed(gearImg, "ImageColor3", "Accent") end
            for _, f in ipairs(gparts) do self:Themed(f, "BackgroundColor3", "Accent") end
            W.Gear = { Color = gearColor }
            local gearHover = false
            lib:Connect(gear.MouseEnter, function() gearHover = true; if not (W.Current and W.Current.Hidden) then gearColor("GearHover") end end)
            lib:Connect(gear.MouseLeave, function() gearHover = false; if not (W.Current and W.Current.Hidden) then gearColor("Accent") end end)
            lib:Connect(gear.MouseButton1Click, function()
                if not W.SettingsPage then return end
                if W.Current == W.SettingsPage then W:Select(W.LastPage or W.Pages[1]) else W:Select(W.SettingsPage) end
            end)
            W.Content = content

            -- resize handles (edges light up in the accent colour while hovered / dragged)
            local minSize = Vector2.new(o.MinWidth or 500, o.MinHeight or 360)
            -- dragging an edge resizes; the edge shows a 2 px light accent line just inside the outline (measured)
            local function edge(name, pos, sz, dir, hpos, hsz)
        local h = Button(root, { Name = name, Position = pos, Size = sz, ZIndex = 5 })
        local hl = New("Frame", { Name = "Highlight", BackgroundTransparency = 1, Position = hpos, Size = hsz, ZIndex = 5, Parent = root })
        lib:Themed(hl, "BackgroundColor3", "AccentLine")
        local held, start, s0, p0 = false
        lib:Connect(h.MouseEnter, function() lib:Tween(hl, "Hover", { BackgroundTransparency = 0 }) end)
        lib:Connect(h.MouseLeave, function() if not held then lib:Tween(hl, "Hover", { BackgroundTransparency = 1 }) end end)
        lib:Connect(h.InputBegan, function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 then held, start, s0, p0 = true, Mouse(), root.AbsoluteSize, root.Position end
        end)
        lib:Connect(UserInputService.InputChanged, function(i)
            if not held or i.UserInputType ~= Enum.UserInputType.MouseMovement then return end
            local dd = Mouse() - start
            local nw, nh, px, py = s0.X, s0.Y, p0.X.Offset, p0.Y.Offset
            if dir.X == 1 then nw = max(minSize.X, s0.X + dd.X) end
            if dir.X == -1 then nw = max(minSize.X, s0.X - dd.X); px = p0.X.Offset + (s0.X - nw) end
            if dir.Y == 1 then nh = max(minSize.Y, s0.Y + dd.Y) end
            if dir.Y == -1 then nh = max(minSize.Y, s0.Y - dd.Y); py = p0.Y.Offset + (s0.Y - nh) end
            root.Size = UDim2.fromOffset(nw, nh)
            root.Position = UDim2.new(p0.X.Scale, px, p0.Y.Scale, py)
            for _, p in ipairs(W.Pages) do p:Relayout() end
        end)
        lib:Connect(UserInputService.InputEnded, function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 and held then held = false; lib:Tween(hl, "Hover", { BackgroundTransparency = 1 }) end
        end)
            end
            edge("Left", UDim2.fromOffset(0, 0), UDim2.new(0, 4, 1, 0), Vector2.new(-1, 0), UDim2.fromOffset(2, 2), UDim2.new(0, 2, 1, -4))
            edge("Right", UDim2.new(1, -4, 0, 0), UDim2.new(0, 4, 1, 0), Vector2.new(1, 0), UDim2.new(1, -4, 0, 2), UDim2.new(0, 2, 1, -4))
            edge("Top", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 4), Vector2.new(0, -1), UDim2.fromOffset(2, 2), UDim2.new(1, -4, 0, 2))
            edge("Bottom", UDim2.new(0, 0, 1, -4), UDim2.new(1, 0, 0, 4), Vector2.new(0, 1), UDim2.new(0, 2, 1, -4), UDim2.new(1, -4, 0, 2))

            ------------------------------------------------------------------------------------------------
            -- pages / tabs
            ------------------------------------------------------------------------------------------------
            function W:Page(p)
        p = p or {}
        local P = { Name = p.Name or "Page", Columns = { {}, {} } }
        P.Hidden = p.Hidden == true
        -- bottom-bar tab: equal share of the bar; tinted plate, centred name, accent underline when selected
        local tab = Button(tabs, { Name = P.Name, ZIndex = 2, Visible = not P.Hidden })
        local plate = New("Frame", { Name = "Plate", Position = UDim2.fromOffset(4, 6), Size = UDim2.new(1, -8, 1, -12), BackgroundTransparency = 1, ZIndex = 2, Parent = tab })
        lib:Themed(plate, "BackgroundColor3", "Accent")
        New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }), Parent = plate })
        local marker = New("Frame", { Name = "Marker", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, -7), Size = UDim2.new(1, -24, 0, 1), BorderSizePixel = 0, ZIndex = 2, Parent = tab })
        lib:Themed(marker, "BackgroundColor3", "TabIdle")
        -- same soft fade at the ends as the title-bar accent line
        New("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.85), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 0.85) }), Parent = marker })
        local label = Text(tab, { Text = P.Name, Position = UDim2.new(0, 0, 0.5, -8), Size = UDim2.new(1, 0, 0, 13), XAlign = Enum.TextXAlignment.Center, Color = "Inactive Text", ZIndex = 2 })
        P.Tab, P.Marker, P.Plate, P.Label = tab, marker, plate, label

        -- page body: a CanvasGroup so it can fade + slide as one piece
        local group = New("CanvasGroup", { Name = P.Name, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), GroupTransparency = 1, Visible = false, Parent = content })
        local scroll = New("ScrollingFrame", { Name = "Scroll", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), CanvasSize = UDim2.new(),
            ScrollBarThickness = 0, ScrollingDirection = Enum.ScrollingDirection.Y, Parent = group })
        P.Group, P.Scroll = group, scroll
        local cols = {}
        for c = 1, 2 do
            cols[c] = New("Frame", { Name = "Column" .. c, BackgroundTransparency = 1,
                Position = c == 1 and UDim2.fromOffset(8, 8) or UDim2.new(0.5, 4, 0, 8), Size = UDim2.new(0.5, -12, 1, -16), Parent = scroll })
        end
        function P:Relayout()
            local tallest = 0
            for c = 1, 2 do
                local y = 0
                for _, sec in ipairs(P.Columns[c]) do
                    sec.Box.Position = UDim2.fromOffset(0, y)
                    sec.Box.Size = UDim2.new(1, 0, 0, 12 + sec.Holder.ContentHeight + 8)
                    y = y + sec.Box.Size.Y.Offset + 8
                end
                tallest = max(tallest, y)
            end
            scroll.CanvasSize = UDim2.fromOffset(0, tallest + 8)
        end
        -- sections (1 px Border + Outline, title cut into a fading accent line)
        function P:Section(s)
            s = s or {}
            local side = (s.Side == 2 or s.Side == "Right" or s.Side == "right") and 2 or 1
            local box, sfill = Single(cols[side], { Name = s.Name or "Section", Size = UDim2.new(1, 0, 0, 40), Fill = "Inline" })
            -- sfill origin = box (2,2)
            -- header like the screenshot: a solid accent line with the title cut in ~40 px from the left
            local line = New("Frame", { Name = "Line", Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 1), Parent = sfill })
            lib:Themed(line, "BackgroundColor3", "Accent")
            local name = s.Name or "Section"
            local tw = TextWidth(name)
            local cut = New("Frame", { Name = "TitleCut", Position = UDim2.fromOffset(40 - 2 - 5, 0), Size = UDim2.fromOffset(tw + 9, 1), ZIndex = 1, Parent = sfill })
            lib:Themed(cut, "BackgroundColor3", "Inline")
            Text(box, { Name = "Title", Text = name, X = 40, Y = -2, W = tw + 4 })
            local inner = New("Frame", { Name = "Items", BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 12), Size = UDim2.new(1, -16, 1, -20), Parent = box })
            local holder = { Frame = inner, Items = {}, ContentHeight = 0, SectionName = name, PageName = P.Name, PageHidden = P.Hidden }
            local sec = { Box = box, Holder = holder }
            holder.Relayout = function() P:Relayout() end
            table.insert(P.Columns[side], sec)
            local api = SectionAPI(holder)
            function api:SetVisibility(v) box.Visible = v; P:Relayout() end
            api.Box = box
            P:Relayout()
            return api
        end
        P.AddSection = P.Section

        local function hover(on)
            if W.Current == P then return end
            lib:TweenTheme(label, "TextColor3", on and "Text" or "Inactive Text", "Hover")
        end
        lib:Connect(tab.MouseEnter, function() hover(true) end)
        lib:Connect(tab.MouseLeave, function() hover(false) end)
        lib:Connect(tab.MouseButton1Click, function() W:Select(P) end)
        table.insert(W.Pages, P)
        W:LayoutTabs()
        if not W.Current and not P.Hidden then W:Select(P, true) end
        return P
            end
            W.Tab = W.Page

            function W:LayoutTabs()
        local shown = {}
        for _, pg in ipairs(W.Pages) do if not pg.Hidden then table.insert(shown, pg) end end
        for k, pg in ipairs(shown) do
            pg.Tab.Position = UDim2.fromScale((k - 1) / #shown, 0)
            pg.Tab.Size = UDim2.fromScale(1 / #shown, 1)
        end
            end

            function W:Select(P, instant)
        local old = W.Current
        if old == P then return end
        W.Current = P
        if not P.Hidden then W.LastPage = P end
        if W.Gear then W.Gear.Color(P.Hidden and "Version" or "Accent") end
        lib:SetPopup(nil)
        if old then
            lib:TweenTheme(old.Label, "TextColor3", "Inactive Text", "Fade")
            lib:TweenTheme(old.Marker, "BackgroundColor3", "TabIdle", "Fade")
            lib:Tween(old.Plate, "Fade", { BackgroundTransparency = 1 })
            old.Group.Visible = false
            old.Group.GroupTransparency = 1
        end
        lib:TweenTheme(P.Label, "TextColor3", "Text", "Fade")
        lib:TweenTheme(P.Marker, "BackgroundColor3", "Accent", "Fade")
        lib:Tween(P.Plate, "Fade", { BackgroundTransparency = 0.9 })
        local g = P.Group
        g.Visible = true
        if instant then
            g.Position = UDim2.fromOffset(0, 0); g.GroupTransparency = 0
            P.Label.TextColor3 = Col("Text"); P.Marker.BackgroundColor3 = Col("Accent"); P.Plate.BackgroundTransparency = 0.9
        else
            g.Position = UDim2.fromOffset(0, 8)
            g.GroupTransparency = 0.6
            lib:Tween(g, "Bounce", { Position = UDim2.fromOffset(0, 0) })
            lib:Tween(g, "Fade", { GroupTransparency = 0 })
        end
            end

            ------------------------------------------------------------------------------------------------
            -- settings page (Configs + Theming), built by Init / CreateSettingsPage
            ------------------------------------------------------------------------------------------------
            function W:Init()
        if W.Initialised then return end
        W.Initialised = true
        local folder = lib.Folder .. "/configs"
        pcall(function()
            if isfolder and not isfolder(lib.Folder) then makefolder(lib.Folder) end
            if isfolder and not isfolder(folder) then makefolder(folder) end
        end)
        local function list()
            local out = {}
            pcall(function()
                for _, f in ipairs(listfiles(folder)) do
                    local n = f:match("([^/\\]+)%.json$")
                    if n then table.insert(out, n) end
                end
            end)
            return out
        end
        local Settings = W:Page({ Name = "Settings", Hidden = true })
        W.SettingsPage = Settings
        local C = Settings:Section({ Name = "Config", Side = 1 })
        local cfgList = C:Dropdown({ Name = "Configs", Items = list(), Default = list()[1] })
        local nameBox = C:Textbox({ Name = "Config name", Placeholder = "Config name" })
        local function path(n) return folder .. "/" .. n .. ".json" end
        C:Button({ Name = "Create", Callback = function()
            local n = nameBox:Get()
            if n == "" then return end
            pcall(writefile, path(n), lib:SaveConfig())
            cfgList:SetValues(list()); cfgList:Set(n)
            lib:Notification("Created config " .. n)
        end })
        C:Button({ Name = "Delete", Callback = function()
            local n = cfgList:Get()
            if not n then return end
            pcall(delfile, path(n))
            cfgList:SetValues(list())
            lib:Notification("Deleted config " .. n)
        end })
        C:Button({ Name = "Load", Callback = function()
            local n = cfgList:Get()
            if not n then return end
            local ok, data = pcall(readfile, path(n))
            if ok then lib:LoadConfig(data); lib:Notification("Loaded config " .. n) end
        end })
        C:Button({ Name = "Save", Callback = function()
            local n = cfgList:Get()
            if not n then return end
            pcall(writefile, path(n), lib:SaveConfig())
            lib:Notification("Saved config " .. n)
        end })
        local ui = C:Keybind({ Name = "UI Bind", Default = KeyName(lib.UIBind), NoMenu = true, Changed = function(k) if k then lib.UIBind = k end end })
        ui.Keybind.ShowInList = false
        table.remove(lib.Keybinds, table.find(lib.Keybinds, ui.Keybind))
        C:Button({ Name = "Unload", Callback = function() lib:Unload() end })

        -- crosshair: style, colour, size, spin
        local X = Settings:Section({ Name = "Crosshair", Side = 1 })
        local xs = lib.CrosshairState
        X:Toggle({ Name = "Enabled", Flag = "crosshair_enabled", Default = xs.Enabled, Callback = function(v) lib:SetCrosshair("Enabled", v) end })
            :Colorpicker({ Flag = "crosshair_color", Default = xs.Color, Callback = function(c) lib:SetCrosshair("Color", c) end })
        X:Dropdown({ Name = "Style", Flag = "crosshair_style", Items = lib.CrosshairStyles, Default = xs.Style, Callback = function(v) lib:SetCrosshair("Style", v) end })
        X:Slider({ Name = "Size", Flag = "crosshair_size", Min = 50, Max = 200, Default = 100, Suffix = "%", Callback = function(v) lib:SetCrosshair("Scale", v / 100) end })
        X:Toggle({ Name = "Spin", Flag = "crosshair_spin", Default = xs.Spin, Callback = function(v) lib:SetCrosshair("Spin", v) end })
        X:Slider({ Name = "Spin Speed", Flag = "crosshair_speed", Min = 10, Max = 720, Default = xs.Speed, Suffix = " deg/s", Callback = function(v) lib:SetCrosshair("Speed", v) end })

        local T = Settings:Section({ Name = "Theme", Side = 2 })
        for _, key in ipairs(ThemeOrder) do
            T:Colorpicker({ Name = key, Default = lib.Theme[key], Callback = function(c) lib:SetTheme(key, c) end })
        end
        -- ESP preview: your character with your ESP on it; drag title to move, edges / corner to resize
        local E = Settings:Section({ Name = "ESP Preview", Side = 2 })
        E:Toggle({ Name = "Show Preview", Flag = "esp_preview_show", Callback = function(v)
            if v then lib:ESPPreview() elseif lib.Preview then lib.Preview:SetVisible(false) end
        end })
        E:Button({ Name = "Refresh Character", Callback = function() if lib.RefreshPreview then lib.RefreshPreview() end end })
        E:Button({ Name = "Reset Size / Position", Callback = function() if lib.Preview then lib.Preview:ResetLayout() end end })
            end
            W.CreateSettingsPage = W.Init

            self.MainWindow = W
            self:HotkeyList()
            if o.Watermark ~= false then self:Watermark({ Name = type(o.Watermark) == "string" and o.Watermark or o.Name or "Novaclient", Version = o.Version }) end
            -- dock everything around the window: hotkeys 16 px to the left, watermark centred 15 px above
            -- (the esp preview docks 4 px to the right when it is opened)
            if self.HotkeyFrame then
                local hk = self.HotkeyFrame
                self:Dock(hk, function(r) return UDim2.fromOffset(r.Position.X.Offset - 16 - hk.Size.X.Offset, r.Position.Y.Offset) end)
            end
            if self.WatermarkFrame then
                local wm = self.WatermarkFrame
                wm.AnchorPoint = Vector2.new(0.5, 0)
                self:Dock(wm, function(r) return UDim2.fromOffset(r.Position.X.Offset + floor(r.Size.X.Offset / 2), r.Position.Y.Offset - 15 - wm.Size.Y.Offset) end)
            end
            -- docked pieces ride along when the window is dragged
            self:Connect(root:GetPropertyChangedSignal("Position"), function()
                if not self.Open then return end
                for frame, it in pairs(self.DockItems) do
                    if it.Docked and frame.Parent then frame.Position = it.Pos(root) end
                end
            end)
            return W
        end
        function Library:CreateSettingsPage(W) (W or self.MainWindow):Init() end

        ----------------------------------------------------------------------------------------------------
        -- watermark (top centre): name in the accent colour | fps | ping | uid, same frame + accent line as the window
        ----------------------------------------------------------------------------------------------------
        function Library:Watermark(o)
            if type(o) == "string" then o = { Name = o } end
            o = o or {}
            if self.WatermarkFrame then self.WatermarkFrame:Destroy() end
            -- compact bar: 20 tall, accent top line, segments split by spaced-out 1 px grey dividers
            local H = 25   -- odd inner height so centred text lands on whole pixels
            local box, fill = Single(self.Gui, { Name = "Watermark", Size = UDim2.fromOffset(200, H), Fill = "Background", ZIndex = 45 })
            box.AnchorPoint = Vector2.new(0.5, 0)
            box.Position = UDim2.new(0.5, 0, 0, 10)
            FadeLine(fill, { Name = "Line", Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 1), ZIndex = 45, Color = "Accent",
        Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.85) }) })
            local items = {}
            local function seg(text, color)
        -- centred inside a slot exactly as wide as the text measures
        local l = Text(fill, { Text = text, Position = UDim2.fromOffset(0, 0), Size = UDim2.new(0, 60, 1, 0), Color = color or "Text", ZIndex = 45 })
        l.TextXAlignment = Enum.TextXAlignment.Center
        l.TextYAlignment = Enum.TextYAlignment.Center
        table.insert(items, l)
        return l
            end
            local function divider()
        local d = New("Frame", { Name = "Divider", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(1, 12), ZIndex = 45, Parent = fill })
        self:Themed(d, "BackgroundColor3", "Divider")
        table.insert(items, d)
        return d
            end
            local name = seg("", "Accent")
            name.RichText = true
            name.Text = VersionTag(o.Name or "Novaclient", o.Version)
            divider(); local fpsL = seg("60 fps")
            divider(); local pingL = seg("0 ms")
            divider(); local uidL = seg("uid 0")
            self:Draggable(box, box)
            self.WatermarkFrame = box
            pcall(function() uidL.Text = "uid " .. tostring(LocalPlayer.UserId) end)
            -- lay the segments out by hand: [8] text [8] | [8] text [8] | ... using the width Roblox actually draws
            local PAD, GAP = 8, 8
            local function width(l)
        local b = (not rawget(_G, "__M")) and l.TextBounds.X or 0
        if b > 0 then return ceil(b) end
        return TextWidth((l.Text:gsub("<[^>]->", ""))) - 2
            end
            local function fit()
        local x = PAD
        for i, it in ipairs(items) do
            if it:IsA("TextLabel") then
                local w = width(it)
                it.Position = UDim2.fromOffset(x, 0)
                it.Size = UDim2.new(0, w, 1, 0)
                x = x + w + (items[i + 1] and GAP or 0)
            else
                it.Position = UDim2.new(0, x, 0.5, -1)   -- caps sit 1 px above the line-box centre
                x = x + 1 + GAP
            end
        end
        box.Size = UDim2.fromOffset(x + PAD + 4, H)
            end
            for _, it in ipairs(items) do
        if it:IsA("TextLabel") then self:Connect(it:GetPropertyChangedSignal("TextBounds"), fit) end
            end
            local frames, last = 0, os.clock()
            local function ping()
        local ms
        pcall(function() ms = Svc("Stats").Network.ServerStatsItem["Data Ping"]:GetValue() end)
        if not ms then pcall(function() ms = LocalPlayer:GetNetworkPing() * 1000 end) end
        return floor((ms or 0) + 0.5)
            end
            self:Connect(RunService.RenderStepped, function()
        frames = frames + 1
        local now = os.clock()
        if now - last >= 0.5 then
            fpsL.Text = floor(frames / (now - last) + 0.5) .. " fps"
            pingL.Text = ping() .. " ms"
            frames, last = 0, now
            fit()
        end
            end)
            fit()
            return box
        end


        ----------------------------------------------------------------------------------------------------
        -- configs
        ----------------------------------------------------------------------------------------------------
        function Library:SaveConfig()
            local out = {}
            for flag, v in pairs(self.Flags) do
        if typeof(v) == "Color3" then out[flag] = { __c = { v.R, v.G, v.B } }
        elseif type(v) == "table" and typeof(v.Color) == "Color3" then out[flag] = { __c = { v.Color.R, v.Color.G, v.Color.B }, a = v.Transparency }
        elseif type(v) == "table" and v.Key and v.Mode then out[flag] = { __k = v.Key, m = v.Mode }
        else out[flag] = v end
            end
            return HttpService:JSONEncode(out)
        end
        function Library:LoadConfig(json)
            local ok, data = pcall(function() return HttpService:JSONDecode(json) end)
            if not ok then return end
            for flag, v in pairs(data) do
        local it = self.Items[flag]
        if it then
            pcall(function()
                if type(v) == "table" and v.__c then it:Set(Color3.new(v.__c[1], v.__c[2], v.__c[3]), v.a)
                elseif type(v) == "table" and v.__k then it:Set(v.__k); if it.SetMode then it:SetMode(v.m) end
                else it:Set(v) end
            end)
        end
            end
        end

        function Library:Toggle(state)
            if state == nil then state = not self.Open end
            self.Open = state
            if self.MainWindow then self.MainWindow.Root.Visible = state end
            if not state then self:SetPopup(nil) end
            self:ApplyDock(state)
        end
        function Library:Unload()
            for _, c in ipairs(self.Connections) do pcall(function() c:Disconnect() end) end
            self.Gui:Destroy()
            if self.OnUnload then pcall(self.OnUnload) end
        end

        return Library

        end)()

return Library
