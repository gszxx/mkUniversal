--[[ MK_EDS v17.1 - Silent Aim Fire Window + Soft Corners ]]

local BOOT = { Tick = tick(), Version = "17.1.0", Build = "made by gsx" }

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local Stats = game:GetService("Stats")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
    or (function() repeat task.wait() until Players.LocalPlayer return Players.LocalPlayer end)()

local function resolveGuiParent()
    if type(gethui) == "function" then
        local ok, hui = pcall(gethui)
        if ok and typeof(hui) == "Instance" then return hui end
    end
    local ok = pcall(function() return CoreGui.Name end)
    if ok then return CoreGui end
    return LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 5)
end
local function resolveGenv()
    if type(getgenv) == "function" then
        local ok, env = pcall(getgenv)
        if ok and type(env) == "table" then return env end
    end
    return type(shared) == "table" and shared or _G
end
local GENV = resolveGenv()
local HUI = resolveGuiParent()
if GENV.__MK_EDS and type(GENV.__MK_EDS.Unload) == "function" then pcall(GENV.__MK_EDS.Unload) end

local Util = {}
function Util.clamp(v, a, b) if v < a then return a end if v > b then return b end return v end
function Util.round(v, n) local m = 10^(n or 0) return math.floor(v * m + 0.5) / m end
function Util.deepCopy(t) if type(t) ~= "table" then return t end local r = {} for k, v in pairs(t) do r[k] = Util.deepCopy(v) end return r end
function Util.colorToArray(c) return { math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255) } end
function Util.arrayToColor(a, fb) if type(a) == "table" and a[1] and a[2] and a[3] then return Color3.fromRGB(a[1], a[2], a[3]) end return fb or Color3.fromRGB(255, 255, 255) end
function Util.shade(c, a) return Color3.new(Util.clamp(c.R + a, 0, 1), Util.clamp(c.G + a, 0, 1), Util.clamp(c.B + a, 0, 1)) end
function Util.num(v, d, mi, ma) if type(v) ~= "number" or v ~= v then return d end if mi and v < mi then v = mi end if ma and v > ma then v = ma end return v end
function Util.bool(v, d) if type(v) == "boolean" then return v end return d end
function Util.formatTime(s)
    s = math.floor(s)
    local h = math.floor(s / 3600)
    local m = math.floor((s % 3600) / 60)
    local sec = s % 60
    if h > 0 then return string.format("%dh %dm %ds", h, m, sec) end
    if m > 0 then return string.format("%dm %ds", m, sec) end
    return string.format("%ds", sec)
end

local Logger = { Level = 2 }
local LOG = { ERROR = 0, WARN = 1, INFO = 2 }
function Logger.Log(l, m, msg)
    local n = LOG[l] if not n or n > Logger.Level then return end
    local s = string.format("[MK_EDS][%.2fs][%s][%s] %s", tick() - BOOT.Tick, l, m, tostring(msg))
    if l == "ERROR" or l == "WARN" then warn(s) else print(s) end
end
function Logger.Error(m, x) return Logger.Log("ERROR", m, x) end
function Logger.Warn(m, x) return Logger.Log("WARN", m, x) end
function Logger.Info(m, x) return Logger.Log("INFO", m, x) end

local Signal = { Conns = {}, Insts = {} }
function Signal.Connect(s, cb) local c = s:Connect(cb) Signal.Conns[#Signal.Conns + 1] = c return c end
function Signal.Track(i) Signal.Insts[#Signal.Insts + 1] = i return i end
function Signal.DisconnectAll()
    for _, c in ipairs(Signal.Conns) do pcall(function() c:Disconnect() end) end
    Signal.Conns = {}
    for _, i in ipairs(Signal.Insts) do pcall(function() i:Destroy() end) end
    Signal.Insts = {}
end

local Config = { File = "MK.json", Data = {}, IO = false }
Config.Defaults = {
    Hitbox = { Enabled = false, Scale = 2.0, MeleeRange = 12, BowRange = 25, TeamCheck = true, NPCMode = true,
        ShowWireframe = true, WireframeColor = { 215, 145, 165 }, ForwardDotMin = 0.0,
        EnableRayHook = true, EnableTouchHook = true, TargetArea = "Body", BreatheWireframe = true, DebugLog = false },
    SilentAim = { Enabled = false, TargetArea = "Head", ConeAngle = 45, MaxDistance = 500,
        TeamCheck = true, NPCMode = true, VisibleCheck = false, WallCheck = false, FireWindow = 0.25 },
    ESP = { Enabled = false, NPCMode = false, TeamCheck = true, FillColor = { 215, 145, 165 },
        OutlineColor = { 230, 165, 185 }, FillTransparency = 0.7, OutlineTransparency = 0.15 },
    Movement = { SpeedEnabled = false, WalkSpeed = 16, JumpEnabled = false, JumpPower = 50, InfJump = false, NoClip = false },
    Aimbot = { Enabled = false, Smoothness = 0.25, MaxDistance = 250, TeamCheck = true, IncludeNPC = true,
        LockOn = false, WallCheck = false, AutoClick = false, ClickRate = 8, FOV = 180, TargetArea = "Head" },
    Combat = { AutoAttack = false, AutoAttackRange = 20 },
    GUI = { CornerStyle = "Soft", AccentChoice = "Rose", ShowParticles = true, ShowShine = true,
        AnimationSpeed = 1.0, LogoSpin = true },
    UI = { Minimized = false, PositionX = nil, PositionY = nil },
    Keybinds = { ToggleHitbox = "None", ToggleESP = "None", ToggleSpeed = "None", ToggleAimbot = "None",
                 ToggleSilent = "None", PanicUnload = "None", ToggleMenu = "RightShift" },
}
Config.IO = type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"

local function sanitize(v, default)
    local dt = type(default)
    if dt == "number" then return Util.num(v, default) end
    if dt == "boolean" then return Util.bool(v, default) end
    if dt == "string" then return (type(v) == "string") and v or default end
    if dt == "table" then
        if type(v) ~= "table" then return Util.deepCopy(default) end
        local out = {}
        for k, d in pairs(default) do out[k] = sanitize(v[k], d) end
        return out
    end
    return default
end
function Config.Load()
    Config.Data = Util.deepCopy(Config.Defaults)
    if not Config.IO then return end
    local ok, e = pcall(isfile, Config.File)
    if not (ok and e) then return end
    local rok, raw = pcall(readfile, Config.File)
    if not (rok and raw and raw ~= "") then return end
    local dok, dec = pcall(function() return HttpService:JSONDecode(raw) end)
    if not (dok and type(dec) == "table") then return end
    for section, defaults in pairs(Config.Defaults) do Config.Data[section] = sanitize(dec[section], defaults) end
end
function Config.Save()
    if not Config.IO then return false end
    local ok, raw = pcall(function() return HttpService:JSONEncode(Config.Data) end)
    if not ok then return false end
    return (pcall(writefile, Config.File, raw))
end
function Config.Get(path, fb)
    local cur = Config.Data
    for seg in tostring(path):gmatch("[^%.]+") do
        if type(cur) ~= "table" then return fb end
        cur = cur[seg] if cur == nil then return fb end
    end
    return cur
end
function Config.Set(path, value, save)
    local segs = {}
    for s in tostring(path):gmatch("[^%.]+") do segs[#segs + 1] = s end
    if #segs == 0 then return end
    local cur = Config.Data
    for i = 1, #segs - 1 do
        if type(cur[segs[i]]) ~= "table" then cur[segs[i]] = {} end
        cur = cur[segs[i]]
    end
    cur[segs[#segs]] = value
    if save ~= false then Config.Save() end
end
Config.Load()

local Keybind = { Bindings = {}, Capture = nil }
function Keybind.Register(name, keyName, callback)
    Keybind.Bindings[name] = { key = keyName, cb = callback }
    Config.Set("Keybinds." .. name, keyName, false)
end
function Keybind.BeginCapture(name, onCaptured) Keybind.Capture = { name = name, callback = onCaptured } end
function Keybind.CancelCapture() Keybind.Capture = nil end
Signal.Connect(UserInputService.InputBegan, function(input, processed)
    if Keybind.Capture then
        local cap = Keybind.Capture
        Keybind.Capture = nil
        local key = input.KeyCode.Name
        if Keybind.Bindings[cap.name] then
            Keybind.Bindings[cap.name].key = key
            Config.Set("Keybinds." .. cap.name, key, true)
        end
        if cap.callback then cap.callback(key) end
        return
    end
    if processed then return end
    for _, b in pairs(Keybind.Bindings) do
        if b.key ~= "None" and input.KeyCode == Enum.KeyCode[b.key] then task.spawn(b.cb) end
    end
end)

local CornerPresets = {
    Sharp    = { R_Window = 6,  R_Card = 4,  R_Button = 4,  R_Input = 4,  R_Notification = 6,  R_Tab = 4,  R_Chip = 4 },
    Medium   = { R_Window = 16, R_Card = 14, R_Button = 10, R_Input = 10, R_Notification = 14, R_Tab = 10, R_Chip = 8 },
    Soft     = { R_Window = 32, R_Card = 26, R_Button = 16, R_Input = 18, R_Notification = 26, R_Tab = 18, R_Chip = 14 },
    VerySoft = { R_Window = 48, R_Card = 40, R_Button = 24, R_Input = 26, R_Notification = 40, R_Tab = 26, R_Chip = 20 },
}
local AccentPresets = {
    Rose    = { A = Color3.fromRGB(215, 145, 165), D = Color3.fromRGB(165, 100, 120), B = Color3.fromRGB(230, 165, 185), G = Color3.fromRGB(245, 195, 210), P = Color3.fromRGB(120, 70, 85) },
    Gold    = { A = Color3.fromRGB(215, 180, 105), D = Color3.fromRGB(160, 130, 60),  B = Color3.fromRGB(235, 200, 130), G = Color3.fromRGB(250, 220, 160), P = Color3.fromRGB(120, 90, 45) },
    Cyan    = { A = Color3.fromRGB(125, 195, 215), D = Color3.fromRGB(75, 130, 150),  B = Color3.fromRGB(155, 220, 235), G = Color3.fromRGB(190, 235, 245), P = Color3.fromRGB(55, 95, 110) },
    Violet  = { A = Color3.fromRGB(180, 145, 215), D = Color3.fromRGB(120, 90, 160),  B = Color3.fromRGB(205, 175, 235), G = Color3.fromRGB(225, 200, 245), P = Color3.fromRGB(85, 60, 120) },
    Emerald = { A = Color3.fromRGB(140, 205, 170), D = Color3.fromRGB(85, 145, 110),  B = Color3.fromRGB(170, 225, 195), G = Color3.fromRGB(200, 240, 215), P = Color3.fromRGB(55, 100, 75) },
    Sunset  = { A = Color3.fromRGB(230, 155, 120), D = Color3.fromRGB(170, 100, 70),  B = Color3.fromRGB(245, 180, 150), G = Color3.fromRGB(255, 205, 175), P = Color3.fromRGB(130, 75, 50) },
}

local Theme = {
    Bg = Color3.fromRGB(34, 30, 38), BgDeep = Color3.fromRGB(26, 22, 30),
    BgCard = Color3.fromRGB(44, 38, 50), BgCardLight = Color3.fromRGB(52, 45, 58),
    BgRaised = Color3.fromRGB(60, 52, 66),
    Accent = Color3.fromRGB(215, 145, 165), AccentDim = Color3.fromRGB(165, 100, 120),
    AccentBright = Color3.fromRGB(230, 165, 185), AccentGlow = Color3.fromRGB(245, 195, 210),
    AccentDeep = Color3.fromRGB(120, 70, 85),
    AuroraA = Color3.fromRGB(195, 155, 205), AuroraC = Color3.fromRGB(230, 180, 200),
    Text = Color3.fromRGB(232, 226, 232), TextDim = Color3.fromRGB(180, 172, 182),
    TextFaint = Color3.fromRGB(130, 122, 132),
    Success = Color3.fromRGB(160, 205, 175), Warning = Color3.fromRGB(235, 200, 155),
    Error = Color3.fromRGB(225, 145, 155), Info = Color3.fromRGB(165, 185, 225),
    Border = Color3.fromRGB(72, 64, 78), BorderBright = Color3.fromRGB(95, 85, 100),
    R_Window = 32, R_Card = 26, R_Button = 16, R_Input = 18,
    R_Notification = 26, R_Tab = 18, R_Chip = 14,
    AnimationSpeed = 1.0,
}
local function applyThemeFromConfig()
    local corners = CornerPresets[Config.Get("GUI.CornerStyle", "Soft")] or CornerPresets.Soft
    for k, v in pairs(corners) do Theme[k] = v end
    local ac = AccentPresets[Config.Get("GUI.AccentChoice", "Rose")] or AccentPresets.Rose
    Theme.Accent = ac.A; Theme.AccentDim = ac.D; Theme.AccentBright = ac.B; Theme.AccentGlow = ac.G; Theme.AccentDeep = ac.P
    Theme.AuroraA = Util.shade(ac.A, 0.05); Theme.AuroraC = Util.shade(ac.B, 0.03)
    Theme.AnimationSpeed = Config.Get("GUI.AnimationSpeed", 1.0)
end
applyThemeFromConfig()

local function speedScale(t)
    local s = Theme.AnimationSpeed
    if s <= 0 then s = 0.01 end
    return TweenInfo.new(t.Time / s, t.EasingStyle, t.EasingDirection)
end
local TI = {
    Fast = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    Normal = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    Smooth = TweenInfo.new(0.34, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
    Spring = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
    Shine = TweenInfo.new(0.9, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
}

local UI = { ActiveTweens = {}, Windows = {} }
function UI.tween(o, p, i) local t = TweenService:Create(o, speedScale(i or TI.Normal), p) UI.ActiveTweens[#UI.ActiveTweens + 1] = t t:Play() return t end
function UI.corner(i, r) local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, r or Theme.R_Card) c.Parent = i return c end
function UI.stroke(i, col, th, tr)
    local s = Instance.new("UIStroke")
    s.Color = col or Theme.Accent
    s.Thickness = (th or 1) * 0.75
    s.Transparency = Util.clamp((tr or 0) + 0.15, 0, 1)
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = i
    return s
end
function UI.pad(i, px, py) local p = Instance.new("UIPadding") p.PaddingTop = UDim.new(0, py or px) p.PaddingBottom = UDim.new(0, py or px) p.PaddingLeft = UDim.new(0, px) p.PaddingRight = UDim.new(0, px) p.Parent = i return p end
function UI.list(i, pad) local l = Instance.new("UIListLayout") l.Padding = UDim.new(0, pad or 6) l.SortOrder = Enum.SortOrder.LayoutOrder l.Parent = i return l end

local function makeGradient(p, c1, c2, rot)
    local g = Instance.new("UIGradient") g.Color = ColorSequence.new(c1 or Theme.BgCard, c2 or Theme.BgCardLight) g.Rotation = rot or 45 g.Parent = p return g
end
local function animateGradientOffset(g, dur, range)
    range = range or 0.4
    task.spawn(function()
        local st = tick()
        while g.Parent do
            local cycle = (tick() - st) % (dur * 2)
            local t = cycle / dur
            if t > 1 then t = 2 - t end
            g.Offset = Vector2.new(-range + range * 2 * t, 0)
            RunService.RenderStepped:Wait()
        end
    end)
end
local function auroraGradient(p, trans)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, Theme.AccentDeep), ColorSequenceKeypoint.new(0.30, Theme.Accent),
        ColorSequenceKeypoint.new(0.55, Theme.AuroraA), ColorSequenceKeypoint.new(0.75, Theme.AuroraC),
        ColorSequenceKeypoint.new(1.00, Theme.AccentDeep),
    })
    g.Rotation = 30
    if trans then g.Transparency = NumberSequence.new(trans) end
    g.Parent = p
    animateGradientOffset(g, 5, 0.5)
    return g
end
local function addShineSweep(frame)
    if not Config.Get("GUI.ShowShine", true) then return end
    local shine = Instance.new("Frame")
    shine.Name = "Shine" shine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    shine.BackgroundTransparency = 1 shine.BorderSizePixel = 0
    shine.Size = UDim2.new(0, 60, 1, 0) shine.Position = UDim2.new(-0.3, 0, 0, 0)
    shine.ZIndex = (frame.ZIndex or 1) + 1 shine.Parent = frame
    local g = Instance.new("UIGradient")
    g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.78), NumberSequenceKeypoint.new(1, 1) })
    g.Parent = shine
    UI.corner(shine, Theme.R_Card)
    task.spawn(function()
        while shine.Parent do
            shine.Position = UDim2.new(-0.3, 0, 0, 0)
            local tw = TweenService:Create(shine, speedScale(TI.Shine), { Position = UDim2.new(1.3, 0, 0, 0) })
            tw:Play() tw.Completed:Wait()
            if not shine.Parent then break end
            task.wait(math.random(30, 70) / 10)
        end
    end)
end
local function applyProps(inst, props)
    for k, v in pairs(props or {}) do
        local ok = pcall(function() inst[k] = v end)
        if not ok then Logger.Warn("UI", inst.ClassName .. " skipped " .. k) end
    end
end
function UI.Root(parent, name, props)
    local f = Instance.new("Frame")
    f.Name = name or "Frame" f.BackgroundColor3 = Theme.Bg f.BorderSizePixel = 0
    applyProps(f, props) f.Parent = parent
    return f
end
function UI.Text(parent, text, props)
    local l = Instance.new("TextLabel")
    l.Name = "Text" l.BackgroundTransparency = 1 l.Text = text or ""
    l.TextColor3 = Theme.Text l.Font = Enum.Font.Gotham l.TextSize = 13
    l.TextXAlignment = Enum.TextXAlignment.Left
    applyProps(l, props) l.Parent = parent
    return l
end
function UI.Button(parent, text, props)
    props = props or {}
    local CUSTOM = { bgColor = true, textColor = true, textSize = true, radius = true, gradient = true }
    local b = Instance.new("TextButton")
    b.Name = "Button" b.BackgroundColor3 = props.bgColor or Theme.BgRaised
    b.TextColor3 = props.textColor or Theme.Text b.TextSize = props.textSize or 12
    b.Text = text or "" b.BorderSizePixel = 0 b.Font = Enum.Font.GothamSemibold
    b.AutoButtonColor = false b.ClipsDescendants = true
    b.Size = UDim2.new(0, 100, 0, 30)
    for k, v in pairs(props) do
        if not CUSTOM[k] then
            local ok = pcall(function() b[k] = v end)
            if not ok then Logger.Warn("UI", "Button skipped " .. k) end
        end
    end
    b.Parent = parent UI.corner(b, props.radius or Theme.R_Button)
    local baseSize = b.Size
    local baseColor = b.BackgroundColor3
    if props.gradient then auroraGradient(b) end
    local hoverStroke = Instance.new("UIStroke")
    hoverStroke.Color = Theme.AccentGlow hoverStroke.Thickness = 0
    hoverStroke.Transparency = 1 hoverStroke.Parent = b
    Signal.Connect(b.MouseEnter, function()
        UI.tween(b, { BackgroundColor3 = Util.shade(baseColor, 0.08) }, TI.Normal)
        UI.tween(hoverStroke, { Thickness = 1.0, Transparency = 0.5 }, TI.Normal)
    end)
    Signal.Connect(b.MouseLeave, function()
        UI.tween(b, { BackgroundColor3 = baseColor }, TI.Normal)
        UI.tween(hoverStroke, { Thickness = 0, Transparency = 1 }, TI.Normal)
        UI.tween(b, { Size = baseSize }, TI.Fast)
    end)
    Signal.Connect(b.MouseButton1Down, function()
        UI.tween(b, { Size = UDim2.new(baseSize.X.Scale, baseSize.X.Offset - 2, baseSize.Y.Scale, baseSize.Y.Offset - 2) }, TI.Fast)
    end)
    Signal.Connect(b.MouseButton1Up, function()
        UI.tween(b, { Size = baseSize }, TI.Spring)
    end)
    return b
end

UI.Screen = (function()
    local e = HUI:FindFirstChild("MK_EDS_v17_1_Root")
    if e then e:Destroy() end
    local s = Instance.new("ScreenGui")
    s.Name = "MK_EDS_v17_1_Root" s.ResetOnSpawn = false
    s.IgnoreGuiInset = true s.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    s.DisplayOrder = 100 s.Parent = HUI
    return s
end)()
Signal.Track(UI.Screen)

UI.Particles = UI.Root(UI.Screen, "Particles", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, ZIndex = 0 })
local function spawnParticle()
    if not Config.Get("GUI.ShowParticles", true) then return end
    local sz = math.random(3, 9)
    local colors = { Theme.AccentGlow, Theme.AuroraA, Theme.AuroraC }
    local p = UI.Root(UI.Particles, "P", {
        Size = UDim2.new(0, sz, 0, sz), Position = UDim2.new(math.random(), 0, 1.15, 0),
        BackgroundColor3 = colors[math.random(#colors)], BackgroundTransparency = 0.75, ZIndex = 0,
    })
    UI.corner(p, sz / 2)
    local dur = math.random(80, 140) / 10
    UI.tween(p, { Position = UDim2.new(p.Position.X.Scale, 0, -0.15, 0) }, TweenInfo.new(dur, Enum.EasingStyle.Linear))
    task.delay(dur, function() pcall(function() p:Destroy() end) end)
end
task.spawn(function() while UI.Screen.Parent do spawnParticle() task.wait(0.4) end end)

local Notify = { Queue = {} }
Notify.Holder = UI.Root(UI.Screen, "Toasts", { Size = UDim2.new(0, 340, 1, -40), Position = UDim2.new(1, -356, 0, 20), BackgroundTransparency = 1, ZIndex = 50 })
function Notify.Push(msg, kind, dur)
    kind = kind or "info" dur = dur or 3
    local color = Theme.Info
    if kind == "success" then color = Theme.Success
    elseif kind == "warning" then color = Theme.Warning
    elseif kind == "error" then color = Theme.Error
    elseif kind == "accent" then color = Theme.AccentBright end
    local toast = UI.Root(Notify.Holder, "Toast", {
        Size = UDim2.new(1, 0, 0, 58), Position = UDim2.new(1, 400, 0, 0),
        BackgroundColor3 = Theme.BgCard, ZIndex = 51,
    })
    UI.corner(toast, Theme.R_Notification)
    UI.stroke(toast, color, 0.8, 0.55)
    makeGradient(toast, Theme.BgCard, Theme.BgCardLight, 30)
    addShineSweep(toast)
    local accent = UI.Root(toast, "Accent", { Size = UDim2.new(0, 2, 1, 0), BackgroundColor3 = color })
    UI.corner(accent, 2)
    local kindLbl = "INFO"
    if kind == "success" then kindLbl = "OK"
    elseif kind == "warning" then kindLbl = "WARN"
    elseif kind == "error" then kindLbl = "ERR"
    elseif kind == "accent" then kindLbl = "MK" end
    UI.Text(toast, kindLbl, { Position = UDim2.new(0, 16, 0, 10), Size = UDim2.new(0, 60, 0, 14), TextColor3 = color, Font = Enum.Font.GothamBold, TextSize = 10 })
    UI.Text(toast, msg, { Position = UDim2.new(0, 16, 0, 24), Size = UDim2.new(1, -32, 0, 30), TextWrapped = true, TextSize = 12, TextColor3 = Theme.Text, TextYAlignment = Enum.TextYAlignment.Top })
    local prog = UI.Root(toast, "Prog", { Size = UDim2.new(1, 0, 0, 2), Position = UDim2.new(0, 0, 1, -2), BackgroundColor3 = color, ZIndex = 52 })
    makeGradient(prog, color, Theme.AccentGlow, 0)
    table.insert(Notify.Queue, toast)
    local slot = #Notify.Queue
    UI.tween(toast, { Position = UDim2.new(0, 0, 0, (slot - 1) * 68) }, TI.Spring)
    UI.tween(prog, { Size = UDim2.new(0, 0, 0, 2) }, TweenInfo.new(dur, Enum.EasingStyle.Linear))
    task.delay(dur, function()
        if not toast or not toast.Parent then return end
        UI.tween(toast, { Position = UDim2.new(1, 400, 0, toast.Position.Y.Offset) }, TI.Normal)
        task.wait(0.22) pcall(function() toast:Destroy() end)
        for i, t in ipairs(Notify.Queue) do if t == toast then table.remove(Notify.Queue, i) break end end
        for i, t in ipairs(Notify.Queue) do
            if t.Parent then UI.tween(t, { Position = UDim2.new(0, 0, 0, (i - 1) * 68) }, TI.Normal) end
        end
    end)
end
function Notify.Clear() for _, t in ipairs(Notify.Queue) do pcall(function() t:Destroy() end) end Notify.Queue = {} end

function UI.Toggle(parent, default, onChange)
    local wrap = UI.Root(parent, "Toggle", { Size = UDim2.new(0, 46, 0, 24), BackgroundColor3 = default and Theme.Accent or Theme.BgRaised })
    UI.corner(wrap, 12)
    local grad = makeGradient(wrap, Theme.AccentDim, Theme.Accent, 45)
    grad.Transparency = NumberSequence.new(default and 0 or 1)
    local glow = Instance.new("UIStroke")
    glow.Color = Theme.AccentGlow glow.Thickness = 0.8
    glow.Transparency = default and 0.5 or 1 glow.Parent = wrap
    local knob = UI.Root(wrap, "Knob", {
        Size = UDim2.new(0, 20, 0, 20),
        Position = default and UDim2.new(1, -22, 0, 2) or UDim2.new(0, 2, 0, 2),
        BackgroundColor3 = Color3.fromRGB(250, 246, 250),
    })
    UI.corner(knob, 10)
    local state = default and true or false
    local btn = Instance.new("TextButton")
    btn.Text = "" btn.BackgroundTransparency = 1 btn.Size = UDim2.new(1, 0, 1, 0) btn.Parent = wrap
    local function set(s, fire)
        state = s and true or false
        UI.tween(wrap, { BackgroundColor3 = state and Theme.Accent or Theme.BgRaised }, TI.Normal)
        UI.tween(knob, { Position = state and UDim2.new(1, -22, 0, 2) or UDim2.new(0, 2, 0, 2) }, TI.Spring)
        grad.Transparency = NumberSequence.new(state and 0 or 1)
        UI.tween(glow, { Transparency = state and 0.5 or 1 }, TI.Normal)
        if fire and onChange then onChange(state) end
    end
    set(default, false)
    Signal.Connect(btn.MouseButton1Click, function() set(not state, true) end)
    return { frame = wrap, get = function() return state end, set = set }
end

function UI.SliderBlock(parent, label, minV, maxV, defaultV, onChange, decimals)
    decimals = decimals or 1
    local holder = UI.Root(parent, "SliderBlock", { Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1 })
    UI.Text(holder, label, { Size = UDim2.new(1, -80, 0, 16), TextColor3 = Theme.TextDim, TextSize = 11 })
    local valueLbl = UI.Text(holder, tostring(Util.round(defaultV, decimals)), {
        Size = UDim2.new(0, 70, 0, 16), Position = UDim2.new(1, -70, 0, 0),
        TextColor3 = Theme.AccentBright, TextSize = 12, Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Right,
    })
    local bar = UI.Root(holder, "Bar", { Size = UDim2.new(1, 0, 0, 6), Position = UDim2.new(0, 0, 0, 25), BackgroundColor3 = Theme.BgDeep })
    UI.corner(bar, 3)
    local fill = UI.Root(bar, "Fill", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Theme.Accent })
    UI.corner(fill, 3)
    local fg = auroraGradient(fill) fg.Rotation = 0
    local knob = UI.Root(bar, "Knob", {
        Size = UDim2.new(0, 16, 0, 16), Position = UDim2.new(0, 0, 0.5, 0),
        BackgroundColor3 = Color3.fromRGB(250, 246, 250), AnchorPoint = Vector2.new(0.5, 0.5),
    })
    UI.corner(knob, 8)
    local kg = Instance.new("UIStroke")
    kg.Color = Theme.AccentGlow kg.Thickness = 1.2 kg.Transparency = 0.4 kg.Parent = knob
    local grab = UI.Root(holder, "Grab", { Size = UDim2.new(1, 0, 0, 26), Position = UDim2.new(0, 0, 0, 15), BackgroundTransparency = 1 })
    local dragging = false
    local current = defaultV
    local function paint(pct)
        pct = Util.clamp(pct, 0, 1)
        fill.Size = UDim2.new(pct, 0, 1, 0)
        knob.Position = UDim2.new(pct, 0, 0.5, 0)
        current = minV + (maxV - minV) * pct
        valueLbl.Text = tostring(Util.round(current, decimals))
        if onChange then onChange(current) end
    end
    do
        local pct = Util.clamp((defaultV - minV) / (maxV - minV), 0, 1)
        fill.Size = UDim2.new(pct, 0, 1, 0); knob.Position = UDim2.new(pct, 0, 0.5, 0)
    end
    local function pctFromMouse(mx)
        local ax = bar.AbsolutePosition.X
        local w = bar.AbsoluteSize.X
        if w <= 0 then return nil end
        return Util.clamp((mx - ax) / w, 0, 1)
    end
    Signal.Connect(grab.InputBegan, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            local pct = pctFromMouse(i.Position.X)
            if pct then paint(pct) end
            UI.tween(knob, { Size = UDim2.new(0, 20, 0, 20) }, TI.Fast)
            UI.tween(kg, { Transparency = 0 }, TI.Fast)
        end
    end)
    Signal.Connect(UserInputService.InputChanged, function(i)
        if not dragging then return end
        if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
            local pct = pctFromMouse(i.Position.X)
            if pct then paint(pct) end
        end
    end)
    Signal.Connect(UserInputService.InputEnded, function(i)
        if not dragging then return end
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            UI.tween(knob, { Size = UDim2.new(0, 16, 0, 16) }, TI.Spring)
            UI.tween(kg, { Transparency = 0.4 }, TI.Fast)
        end
    end)
    return { frame = holder, get = function() return current end, set = function(v) local pct = Util.clamp((v - minV) / (maxV - minV), 0, 1) fill.Size = UDim2.new(pct, 0, 1, 0) knob.Position = UDim2.new(pct, 0, 0.5, 0) current = v valueLbl.Text = tostring(Util.round(v, decimals)) end }
end

function UI.Row(parent, label, control, height)
    local row = UI.Root(parent, "Row", { Size = UDim2.new(1, 0, 0, height or 30), BackgroundTransparency = 1 })
    UI.Text(row, label, { Size = UDim2.new(1, -80, 1, 0), TextSize = 12, TextColor3 = Theme.Text })
    if control and control.frame then
        control.frame.Parent = row
        control.frame.AnchorPoint = Vector2.new(1, 0.5)
        control.frame.Position = UDim2.new(1, 0, 0.5, 0)
    end
    return row
end
function UI.SectionHeader(parent, text)
    local row = UI.Root(parent, "Section", { Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1 })
    local bar = UI.Root(row, "Bar", { Size = UDim2.new(0, 3, 0, 14), Position = UDim2.new(0, 0, 0, 7), BackgroundColor3 = Theme.Accent })
    UI.corner(bar, 3); auroraGradient(bar)
    UI.Text(row, text, { Position = UDim2.new(0, 12, 0, 7), Size = UDim2.new(1, -20, 0, 14), TextColor3 = Theme.AccentBright, Font = Enum.Font.GothamBold, TextSize = 11 })
    UI.Root(row, "Line", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1), BackgroundColor3 = Theme.Border, BackgroundTransparency = 0.5 })
    return row
end
function UI.Card(parent, height)
    local card = UI.Root(parent, "Card", { 
        Size = UDim2.new(1, 0, 0, 0), 
        AutomaticSize = Enum.AutomaticSize.Y, -- İçindeki elemanlara göre yüksekliği otomatik ayarlar
        BackgroundColor3 = Theme.BgCard, 
        ClipsDescendants = true 
    })
    UI.corner(card, Theme.R_Card) 
    UI.stroke(card, Theme.Border, 1, 0.4)
    local g = makeGradient(card, Theme.BgCard, Theme.BgCardLight, 35)
    animateGradientOffset(g, 8, 0.25)
    addShineSweep(card)
    local content = UI.Root(card, "Content", { 
        Size = UDim2.new(1, 0, 0, 0), 
        AutomaticSize = Enum.AutomaticSize.Y, -- İçerik kutusunun da otomatik büyümesini sağlar
        BackgroundTransparency = 1 
    })
    UI.list(content, 6) 
    UI.pad(content, 14)
    return content
end
function UI.InfoRow(parent, key, value)
    local row = UI.Root(parent, "InfoRow", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1 })
    UI.Text(row, key, { Size = UDim2.new(0.45, 0, 1, 0), TextSize = 11, TextColor3 = Theme.TextDim })
    return UI.Text(row, value, { Size = UDim2.new(0.55, 0, 1, 0), Position = UDim2.new(0.45, 0, 0, 0), TextSize = 11, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Right, Font = Enum.Font.GothamSemibold })
end
function UI.ChipRow(parent, options, default, onSelect)
    local row = UI.Root(parent, "ChipRow", { Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1 })
    local buttons = {}
    local current = default
    local function repaint()
        for _, pair in ipairs(buttons) do
            if pair.id == current then
                pair.btn.BackgroundColor3 = Theme.Accent; pair.btn.TextColor3 = Theme.BgDeep
            else
                pair.btn.BackgroundColor3 = Theme.BgRaised; pair.btn.TextColor3 = Theme.Text
            end
        end
    end
    for i, opt in ipairs(options) do
        local btn = UI.Button(row, opt, {
            Size = UDim2.new(0, 70, 1, 0), Position = UDim2.new(0, (i - 1) * 74, 0, 0),
            bgColor = Theme.BgRaised, textColor = Theme.Text, radius = Theme.R_Chip, textSize = 10,
        })
        table.insert(buttons, { btn = btn, id = opt })
        Signal.Connect(btn.MouseButton1Click, function()
            current = opt; repaint()
            if onSelect then onSelect(opt) end
        end)
    end
    repaint()
    return { frame = row, get = function() return current end, set = function(v) current = v repaint() end }
end

-- ════════════════════════════════════════════════════════════════════════════
-- WINDOW — SOFT CORNERS FIX
-- ════════════════════════════════════════════════════════════════════════════
-- Structure:
--   Window (BgDeep, UICorner R, ClipsDescendants)
--     Body (Bg, UICorner R, y=50) — the area below the titlebar
--     TitleBar (BgDeep, UICorner R, y=0, h=50) — matches window color
--     TabStrip (transparent, y=50) — no bg, buttons do their own thing
--     Content (y=58) — well inside, no corner issues
--
-- Because titlebar bg == window bg, its bottom rounded corners are
-- invisible. Because body bg != window bg but body has UICorner R, its
-- bottom corners round exactly like the window's, and its top corners
-- round against the BgDeep backdrop creating a subtle step.
-- ════════════════════════════════════════════════════════════════════════════
function UI.CreateWindow(name, title, size)
    if UI.Windows[name] then return UI.Windows[name] end
    local defaultSize = size or UDim2.new(0, 800, 0, 580)
    local minSize = UDim2.new(0, defaultSize.X.Offset, 0, 50)
    local vp = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
    local defaultPos = UDim2.new(0.5, -defaultSize.X.Offset / 2, 0.5, -defaultSize.Y.Offset / 2)
    local pos = defaultPos
    local sx, sy = Config.Get("UI.PositionX"), Config.Get("UI.PositionY")
    if type(sx) == "number" and type(sy) == "number" then
        local cx = Util.clamp(sx, -defaultSize.X.Offset + 100, vp.X - 100)
        local cy = Util.clamp(sy, 0, vp.Y - 60)
        if math.abs(cx - sx) < 300 and math.abs(cy - sy) < 300 then pos = UDim2.new(0, cx, 0, cy)
        else Config.Set("UI.PositionX", nil, false) Config.Set("UI.PositionY", nil, false) Config.Save() end
    end

    -- Window container
    local win = UI.Root(UI.Screen, name, {
        Size = defaultSize, Position = pos,
        BackgroundColor3 = Theme.BgDeep,
        BackgroundTransparency = 1,
        ZIndex = 10,
    })
    UI.corner(win, Theme.R_Window)
    win.ClipsDescendants = true

    -- Border stroke (matches window shape)
    local winStroke = Instance.new("UIStroke")
    winStroke.Color = Theme.BorderBright
    winStroke.Thickness = 1
    winStroke.Transparency = 0.55
    winStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    winStroke.Parent = win

    -- Body block (Bg color) - fills below titlebar, rounded corners matching window
    local body = UI.Root(win, "Body", {
        Size = UDim2.new(1, 0, 1, -50),
        Position = UDim2.new(0, 0, 0, 50),
        BackgroundColor3 = Theme.Bg,
        ZIndex = 0,
    })
    UI.corner(body, Theme.R_Window)
    -- Add subtle gradient to body
    local bodyGrad = auroraGradient(body, 0.92)
    bodyGrad.Rotation = 45

    -- Title bar (same color as window → its bottom rounded corners invisible)
    local titleBar = UI.Root(win, "TitleBar", {
        Size = UDim2.new(1, 0, 0, 50),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = Theme.BgDeep,
        Active = true,
        ZIndex = 11,
    })
    UI.corner(titleBar, Theme.R_Window)
    auroraGradient(titleBar, 0.78)

    -- Logo
    local logo = UI.Root(titleBar, "Logo", {
        Size = UDim2.new(0, 30, 0, 30),
        Position = UDim2.new(0, 14, 0.5, -15),
        BackgroundColor3 = Theme.Accent, ZIndex = 12,
    })
    UI.corner(logo, 12); auroraGradient(logo)
    UI.Text(logo, "MK", { Size = UDim2.new(1, 0, 1, 0), TextColor3 = Color3.fromRGB(255, 250, 252), Font = Enum.Font.GothamBold, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 13 })

    -- Optional logo spin
    if Config.Get("GUI.LogoSpin", true) then
        task.spawn(function()
            while logo.Parent do
                logo.Rotation = 0
                UI.tween(logo, { Rotation = 360 }, TweenInfo.new(12, Enum.EasingStyle.Linear))
                task.wait(12)
            end
        end)
    end

    UI.Text(titleBar, title or name, {
        Position = UDim2.new(0, 54, 0, 0), Size = UDim2.new(1, -170, 1, 0),
        Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Theme.Text,
        ZIndex = 13, TextTruncate = Enum.TextTruncate.AtEnd,
    })

    local minBtn = UI.Button(titleBar, "_", { Size = UDim2.new(0, 30, 0, 28), Position = UDim2.new(1, -84, 0, 11), bgColor = Theme.BgRaised, radius = 10, textSize = 13, ZIndex = 15 })
    local closeBtn = UI.Button(titleBar, "X", { Size = UDim2.new(0, 30, 0, 28), Position = UDim2.new(1, -46, 0, 11), bgColor = Theme.Error, radius = 10, textSize = 11, ZIndex = 15 })

    local drag = Instance.new("TextButton")
    drag.Name = "Drag" drag.Text = "" drag.BackgroundTransparency = 1
    drag.Size = UDim2.new(1, -140, 1, 0) drag.Position = UDim2.new(0, 0, 0, 0)
    drag.ZIndex = 12 drag.AutoButtonColor = false drag.Parent = titleBar

    -- Tab strip — TRANSPARENT (no bg, its bounds don't matter)
    local tabStrip = UI.Root(win, "TabStrip", {
        Size = UDim2.new(0, 170, 1, -50),
        Position = UDim2.new(0, 0, 0, 50),
        BackgroundTransparency = 1,
        ZIndex = 11,
    })

    local tabIndicator = UI.Root(tabStrip, "Indicator", {
        Size = UDim2.new(0, 3, 0, 38),
        Position = UDim2.new(0, 6, 0, 10),
        BackgroundColor3 = Theme.Accent,
        ZIndex = 13,
    })
    UI.corner(tabIndicator, 3); auroraGradient(tabIndicator)

    -- Content
    local content = UI.Root(win, "Content", {
        Size = UDim2.new(1, -182, 1, -62),
        Position = UDim2.new(0, 178, 0, 58),
        BackgroundTransparency = 1, ZIndex = 12,
    })
    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "Scroll" scroll.Size = UDim2.new(1, 0, 1, 0)
    scroll.BackgroundTransparency = 1 scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 5 scroll.ScrollBarImageColor3 = Theme.Accent
    scroll.ScrollBarImageTransparency = 0.5 scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.ElasticBehavior = Enum.ElasticBehavior.Never
    scroll.ZIndex = 12 scroll.Parent = content

    -- Drag
    local dragging, ds, sp = false, nil, nil
    Signal.Connect(drag.InputBegan, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true ds = i.Position sp = win.Position
        end
    end)
    Signal.Connect(UserInputService.InputChanged, function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - ds
            local nx = sp.X.Offset + d.X
            local ny = sp.Y.Offset + d.Y
            local vp2 = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
            nx = Util.clamp(nx, -defaultSize.X.Offset + 100, vp2.X - 100)
            ny = Util.clamp(ny, 0, vp2.Y - 50)
            win.Position = UDim2.new(0, nx, 0, ny)
        end
    end)
    Signal.Connect(UserInputService.InputEnded, function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
            dragging = false
            Config.Set("UI.PositionX", win.Position.X.Offset, false)
            Config.Set("UI.PositionY", win.Position.Y.Offset, false)
            Config.Save()
        end
    end)

    -- Minimize
    local sizeTween = nil
    local minimized = Config.Get("UI.Minimized", false) == true
    local function tweenSize(target, info)
        if sizeTween then pcall(function() sizeTween:Cancel() end) end
        sizeTween = TweenService:Create(win, speedScale(info or TI.Smooth), { Size = target })
        sizeTween:Play()
    end
    local function applyMin(m)
        m = m and true or false
        minimized = m
        Config.Set("UI.Minimized", m, false)
        Config.Save()
        if m then
            tabStrip.Visible = false
            content.Visible = false
            body.Visible = false
            tweenSize(minSize, TI.Smooth)
        else
            tweenSize(defaultSize, TI.Smooth)
            task.delay(0.25, function()
                if not minimized then
                    tabStrip.Visible = true
                    content.Visible = true
                    body.Visible = true
                end
            end)
        end
    end
    Signal.Connect(minBtn.MouseButton1Click, function() applyMin(not minimized) end)
    Signal.Connect(closeBtn.MouseButton1Click, function()
        win.Visible = false
        Notify.Push("Press " .. Config.Get("Keybinds.ToggleMenu", "RightShift") .. " to reopen", "info", 2.5)
    end)
    if minimized then
        win.Size = minSize
        tabStrip.Visible = false
        content.Visible = false
        body.Visible = false
    end
    task.spawn(function()
        local startSize = UDim2.new(0, defaultSize.X.Offset * 0.94, 0, defaultSize.Y.Offset * 0.94)
        win.Size = startSize
        win.BackgroundTransparency = 1
        if sizeTween then pcall(function() sizeTween:Cancel() end) end
        sizeTween = TweenService:Create(win, speedScale(TI.Spring), { Size = minimized and minSize or defaultSize, BackgroundTransparency = 0 })
        sizeTween:Play()
    end)

    local pages, currentPage = {}, nil
    local tabIndex = 0
    local api = {}
    local tabButtons = {}
    function api:AddTab(id, display)
        tabIndex = tabIndex + 1
        local slot = tabIndex
        local btn = UI.Button(tabStrip, display, {
            Size = UDim2.new(1, -20, 0, 38),
            Position = UDim2.new(0, 10, 0, 10 + (slot - 1) * 44),
            bgColor = Theme.BgDeep, textColor = Theme.TextDim,
            radius = Theme.R_Tab, textSize = 12, ZIndex = 12,
        })
        btn.TextXAlignment = Enum.TextXAlignment.Left
        UI.pad(btn, 12)
        tabButtons[id] = { button = btn, position = 10 + (slot - 1) * 44 }
        local page = UI.Root(scroll, "Page_" .. id, {
            Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1, Visible = false, ZIndex = 12,
        })
        page.AutomaticSize = Enum.AutomaticSize.Y
        UI.list(page, 8); UI.pad(page, 6)
        pages[id] = { page = page }
        if not currentPage then
            page.Visible = true
            currentPage = id
            btn.BackgroundColor3 = Theme.BgCard
            btn.TextColor3 = Theme.AccentBright
            tabIndicator.Position = UDim2.new(0, 6, 0, tabButtons[id].position)
        end
        Signal.Connect(btn.MouseButton1Click, function()
            for tid, p in pairs(pages) do
                p.page.Visible = false
                local tb = tabButtons[tid]
                UI.tween(tb.button, { BackgroundColor3 = Theme.BgDeep }, TI.Fast)
                UI.tween(tb.button, { TextColor3 = Theme.TextDim }, TI.Fast)
            end
            page.Visible = true
            btn.BackgroundColor3 = Theme.BgCard
            btn.TextColor3 = Theme.AccentBright
            currentPage = id
            UI.tween(tabIndicator, { Position = UDim2.new(0, 6, 0, tabButtons[id].position) }, TI.Smooth)
        end)
        return page
    end
    function api:GetWindow() return win end
    UI.Windows[name] = api
    return api
end

-- ════════════════════════════════════════════════════════════════════════════
-- TARGET AREAS
-- ════════════════════════════════════════════════════════════════════════════
local TARGET_AREAS = {
    Body    = { "UpperTorso", "Torso", "Chest" },
    Head    = { "Head" },
    Legs    = { "LowerTorso", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "LeftFoot", "RightFoot", "Left Leg", "Right Leg" },
    Arms    = { "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "LeftHand", "RightHand", "Left Arm", "Right Arm" },
    Nearest = nil, Random = nil,
}

local function getTargetPartsForCharacter(char, areaName)
    if not char then return {} end
    if areaName == "Nearest" then
        local my = LocalPlayer.Character
        local myRoot = my and my:FindFirstChild("HumanoidRootPart")
        local best, bestD = nil, math.huge
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") and myRoot then
                local d = (p.Position - myRoot.Position).Magnitude
                if d < bestD then best, bestD = p, d end
            end
        end
        return best and { best } or {}
    elseif areaName == "Random" then
        local list = {}
        for _, p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") then list[#list + 1] = p end end
        if #list > 0 then return { list[math.random(#list)] } end
        return {}
    end
    local names = TARGET_AREAS[areaName] or TARGET_AREAS.Body
    local out = {}
    for _, n in ipairs(names) do
        local p = char:FindFirstChild(n)
        if p and p:IsA("BasePart") then out[#out + 1] = p end
    end
    return out
end

local function getPrimaryTorso(char)
    for _, n in ipairs({ "UpperTorso", "Torso", "LowerTorso", "Chest" }) do
        local p = char:FindFirstChild(n)
        if p and p:IsA("BasePart") then return p end
    end
end

-- ════════════════════════════════════════════════════════════════════════════
-- HITBOX + SILENT AIM
-- ════════════════════════════════════════════════════════════════════════════
local Hitbox = {
    Enabled          = Config.Get("Hitbox.Enabled", false),
    Scale            = Config.Get("Hitbox.Scale", 2.0),
    MeleeRange       = Config.Get("Hitbox.MeleeRange", 12),
    BowRange         = Config.Get("Hitbox.BowRange", 25),
    TeamCheck        = Config.Get("Hitbox.TeamCheck", true),
    NPCMode          = Config.Get("Hitbox.NPCMode", true),
    ShowWireframe    = Config.Get("Hitbox.ShowWireframe", true),
    WireframeColor   = Util.arrayToColor(Config.Get("Hitbox.WireframeColor"), Theme.Accent),
    ForwardDotMin    = Config.Get("Hitbox.ForwardDotMin", 0.0),
    EnableRayHook    = Config.Get("Hitbox.EnableRayHook", true),
    EnableTouchHook  = Config.Get("Hitbox.EnableTouchHook", true),
    DebugLog         = Config.Get("Hitbox.DebugLog", false),
    MaxOriginDist    = 20,

    SilentAim = {
        Enabled = Config.Get("SilentAim.Enabled", false),
        TargetArea = Config.Get("SilentAim.TargetArea", "Head"),
        ConeAngle = Config.Get("SilentAim.ConeAngle", 45),
        MaxDistance = Config.Get("SilentAim.MaxDistance", 500),
        TeamCheck = Config.Get("SilentAim.TeamCheck", true),
        NPCMode = Config.Get("SilentAim.NPCMode", true),
        VisibleCheck = Config.Get("SilentAim.VisibleCheck", false),
        WallCheck = Config.Get("SilentAim.WallCheck", false),
        FireWindow = Config.Get("SilentAim.FireWindow", 0.25),
    },

    _hooked          = false,
    _oldNamecall     = nil,
    _mt              = nil,
    _rayHits         = 0,
    _raySkipped      = 0,
    _silentHits      = 0,
    _swings          = 0,
    _touchHits       = 0,
    _lastSwing       = 0,
    _swingCooldown   = 0.20,
    _touchCooldowns  = {},
    _touchCooldownT  = 0.35,
    _swingConns      = {},
    _fireWindowEnd   = 0,
    _npcCache        = {},
    _npcCacheTime    = 0,
    _npcCacheTTL     = 0.6,
    VisualFolder     = nil,
    Visuals          = {},
}

-- ═══ FIRE WINDOW: Silent aim trigger timing ═══
local function markFireWindow()
    Hitbox._fireWindowEnd = tick() + Hitbox.SilentAim.FireWindow
end

local function inFireWindow()
    return tick() < Hitbox._fireWindowEnd
end

-- Listen for attacks to open the fire window
Signal.Connect(UserInputService.InputBegan, function(input, processed)
    if processed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1
       or input.UserInputType == Enum.UserInputType.Touch then
        markFireWindow()
    end
end)

local function wireToolFire(tool)
    if not tool or not tool:IsA("Tool") then return end
    Signal.Connect(tool.Activated, function()
        markFireWindow()
        task.spawn(function()
            if Hitbox.Enabled and Hitbox.EnableTouchHook then
                -- touch-hit logic will run
            end
        end)
    end)
end

local function wireToolsForFire()
    if LocalPlayer.Character then
        local t = LocalPlayer.Character:FindFirstChildOfClass("Tool")
        if t then wireToolFire(t) end
        Signal.Connect(LocalPlayer.Character.ChildAdded, function(c)
            if c:IsA("Tool") then wireToolFire(c) end
        end)
    end
    Signal.Connect(LocalPlayer.CharacterAdded, function(c)
        task.wait(0.3)
        local t = c:FindFirstChildOfClass("Tool")
        if t then wireToolFire(t) end
        Signal.Connect(c.ChildAdded, function(ch)
            if ch:IsA("Tool") then wireToolFire(ch) end
        end)
    end)
end

local function isLocalChar(c)
    if not c then return false end
    if LocalPlayer.Character == c then return true end
    return Players:GetPlayerFromCharacter(c) == LocalPlayer
end
local function alive(c)
    local h = c:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0
end
local function hostile(plr)
    if plr == LocalPlayer then return false end
    if not Hitbox.TeamCheck then return true end
    local a, b = LocalPlayer.Team, plr.Team
    if not a or not b then return true end
    return a ~= b
end

local TORSO_NAMES = { "UpperTorso", "Torso", "LowerTorso", "Chest" }

local function scanNPCs()
    local now = tick()
    if now - Hitbox._npcCacheTime < Hitbox._npcCacheTTL then return Hitbox._npcCache end
    Hitbox._npcCacheTime = now
    local found = {}
    local function walk(c)
        for _, o in ipairs(c:GetChildren()) do
            if o:IsA("Model") and o:FindFirstChildOfClass("Humanoid")
               and Players:GetPlayerFromCharacter(o) == nil then
                found[#found + 1] = o
            elseif o:IsA("Folder") or o:IsA("Model") then walk(o) end
        end
    end
    walk(Workspace)
    Hitbox._npcCache = found
    return found
end

local function collectTargets()
    local out = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if hostile(plr) and plr.Character and alive(plr.Character) then
            out[#out + 1] = plr.Character
        end
    end
    if Hitbox.NPCMode then
        for _, npc in ipairs(scanNPCs()) do
            if alive(npc) and not isLocalChar(npc) then
                out[#out + 1] = npc
            end
        end
    end
    return out
end

local function getTorso(char)
    for _, n in ipairs(TORSO_NAMES) do
        local p = char:FindFirstChild(n)
        if p and p:IsA("BasePart") then return p end
    end
    return nil
end

-- ═══ RAYCAST HOOK (v15.3 WORKING VERSION) ═══
local function originIsPlayerFired(origin)
    if not origin then return false end
    local my = LocalPlayer.Character
    local myHRP = my and my:FindFirstChild("HumanoidRootPart")
    if myHRP and (origin - myHRP.Position).Magnitude < Hitbox.MaxOriginDist then
        return true
    end
    local cam = Workspace.CurrentCamera
    if cam and (origin - cam.CFrame.Position).Magnitude < Hitbox.MaxOriginDist then
        return true
    end
    return false
end

local function findSilentAimTarget(origin, lookDir)
    local sa = Hitbox.SilentAim
    if not sa.Enabled then return nil end
    local best, bestScore = nil, -math.huge
    local maxDist = sa.MaxDistance
    local coneHalf = math.rad(sa.ConeAngle / 2)

    local function test(char)
        if not char or not char.Parent then return end
        if not alive(char) then return end
        local player = Players:GetPlayerFromCharacter(char)
        if not sa.NPCMode and player == nil then return end
        if player and sa.TeamCheck then
            local a, b = LocalPlayer.Team, player.Team
            if a and b and a == b then return end
        end
        local parts = getTargetPartsForCharacter(char, sa.TargetArea)
        for _, part in ipairs(parts) do
            local delta = part.Position - origin
            local dist = delta.Magnitude
            if dist <= maxDist and dist > 0.5 then
                local dirUnit = delta.Unit
                local dot = lookDir:Dot(dirUnit)
                local ang = math.acos(Util.clamp(dot, -1, 1))
                if ang <= coneHalf then
                    local score = (1 - ang / coneHalf) * 1000 - dist
                    if score > bestScore then best = { char = char, part = part, dist = dist } bestScore = score end
                end
            end
        end
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then test(plr.Character) end
    end
    if sa.NPCMode then for _, npc in ipairs(scanNPCs()) do test(npc) end end
    return best
end

local function tryExtendedHit(origin, direction)
    if not origin or not direction then return nil end
    local mag = direction.Magnitude
    if mag < 0.05 then return nil end
    local dirUnit = direction.Unit

    local bestHit = nil
    local bestProj = mag

    for _, char in ipairs(collectTargets()) do
        local torso = getTorso(char)
        if torso then
            local toCenter = torso.Position - origin
            local projLen = toCenter:Dot(dirUnit)
            if projLen > 0.5 and projLen < bestProj then
                local closest = origin + dirUnit * projLen
                local dist = (closest - torso.Position).Magnitude
                local maxDim = math.max(torso.Size.X, torso.Size.Y, torso.Size.Z)
                local extRadius = (maxDim * Hitbox.Scale) * 0.5
                if dist < extRadius then
                    bestHit = {
                        Instance = torso,
                        Position = closest,
                        Normal = -dirUnit,
                        Distance = projLen,
                        Material = torso.Material,
                    }
                    bestProj = projLen
                end
            end
        end
    end

    if bestHit then Hitbox._rayHits = Hitbox._rayHits + 1 end
    return bestHit
end

function Hitbox.InstallRayHook()
    if Hitbox._hooked or not Hitbox.EnableRayHook then return false end
    if type(getrawmetatable) ~= "function"
       or type(getnamecallmethod) ~= "function"
       or type(setreadonly) ~= "function" then
        Logger.Warn("HITBOX", "No metatable hook functions — raycast hook unavailable")
        return false
    end
    local ok = pcall(function()
        local mt = getrawmetatable(game)
        if not mt or not mt.__namecall then error("no __namecall") end
        Hitbox._mt = mt
        Hitbox._oldNamecall = mt.__namecall
        setreadonly(mt, false)
        mt.__namecall = function(self, ...)
            local method = getnamecallmethod()
            if method == "Raycast" and Hitbox.Enabled and Hitbox.EnableRayHook then
                if self == Workspace or self == game:GetService("Workspace") then
                    local args = { ... }
                    local result = Hitbox._oldNamecall(self, ...)
                    if result == nil then
                        local o = args[1]
                        local d = args[2]
                        if originIsPlayerFired(o) then
                            local cam = Workspace.CurrentCamera
                            if cam then
                                local dot = d.Unit:Dot(cam.CFrame.LookVector)
                                if dot > Hitbox.ForwardDotMin then
                                    local fake = tryExtendedHit(o, d)
                                    if fake then 
                                        Hitbox._rayHits = Hitbox._rayHits + 1
                                        return fake 
                                    end
                                else
                                    Hitbox._raySkipped = Hitbox._raySkipped + 1
                                end
                            end
                        end
                    end
                    return result
                end
            end
            return Hitbox._oldNamecall(self, ...)
        end
        setreadonly(mt, true)
    end)
    if not ok then
        Logger.Warn("HITBOX", "Failed to install raycast hook")
        return false
    end
    Hitbox._hooked = true
    Logger.Info("HITBOX", "Raycast hook installed (working version)")
    return true
end

function Hitbox.UninstallRayHook()
    if not Hitbox._hooked or not Hitbox._mt then return end
    pcall(function()
        setreadonly(Hitbox._mt, false)
        Hitbox._mt.__namecall = Hitbox._oldNamecall
        setreadonly(Hitbox._mt, true)
    end)
    Hitbox._hooked = false
    Logger.Info("HITBOX", "Raycast hook removed")
end

-- ═══ FIRETOUCHINTEREST (backup for swords/spears) ═══
local function inFrontOfPlayer(char, range)
    local my = LocalPlayer.Character
    if not my then return false end
    local myRoot = my:FindFirstChild("HumanoidRootPart")
    if not myRoot then return false end
    local tgtRoot = char:FindFirstChild("HumanoidRootPart")
    if not tgtRoot then return false end
    local delta = tgtRoot.Position - myRoot.Position
    if delta.Magnitude > range then return false end
    return myRoot.CFrame.LookVector:Dot(delta.Unit) > 0.0
end

local function findNearestTarget(range)
    local best, bestDist = nil, range
    for _, char in ipairs(collectTargets()) do
        if inFrontOfPlayer(char, range) then
            local my = LocalPlayer.Character
            local myRoot = my and my:FindFirstChild("HumanoidRootPart")
            local tgtRoot = char:FindFirstChild("HumanoidRootPart")
            if myRoot and tgtRoot then
                local d = (tgtRoot.Position - myRoot.Position).Magnitude
                if d < bestDist then best = char; bestDist = d end
            end
        end
    end
    return best
end

local function doTouch(a, b)
    if not a or not b then return false end
    if type(firetouchinterest) ~= "function" then return false end
    return pcall(function()
        firetouchinterest(a, b, 1)
        task.wait()
        firetouchinterest(a, b, 0)
    end)
end

local function triggerTouchHit()
    if not Hitbox.Enabled or not Hitbox.EnableTouchHook then return end
    local now = tick()
    if now - Hitbox._lastSwing < Hitbox._swingCooldown then return end
    Hitbox._lastSwing = now
    Hitbox._swings = Hitbox._swings + 1

    local my = LocalPlayer.Character
    if not my then return end
    local tool = my:FindFirstChildOfClass("Tool")
    local weaponPart = nil
    if tool then
        weaponPart = tool:FindFirstChild("Handle") or tool:FindFirstChild("Blade") or tool:FindFirstChild("Tip")
    end
    if not weaponPart then
        weaponPart = my:FindFirstChild("RightHand") or my:FindFirstChild("Right Arm") or my:FindFirstChild("HumanoidRootPart")
    end
    if not weaponPart then return end

    local range = Hitbox.MeleeRange
    if tool then
        local n = tool.Name:lower()
        if n:find("bow") or n:find("arrow") or n:find("crossbow") then
            range = Hitbox.BowRange
        end
    end

    local target = findNearestTarget(range)
    if not target then return end
    local last = Hitbox._touchCooldowns[target]
    if last and (now - last) < Hitbox._touchCooldownT then return end
    Hitbox._touchCooldowns[target] = now

    local torso = getTorso(target)
    if not torso then return end
    local source = weaponPart
    if tool then
        local n = tool.Name:lower()
        if n:find("bow") or n:find("arrow") then
            local arrow = Workspace:FindFirstChild("Arrow") or Workspace:FindFirstChild("Projectile")
            if arrow and arrow:IsA("BasePart") then source = arrow end
        end
    end
    doTouch(source, torso)
    Hitbox._touchHits = Hitbox._touchHits + 1
end

local function unwireSwingListeners()
    for _, c in ipairs(Hitbox._swingConns) do pcall(function() c:Disconnect() end) end
    Hitbox._swingConns = {}
end

local function wireTool(tool)
    if not tool or not tool:IsA("Tool") then return end
    table.insert(Hitbox._swingConns, tool.Activated:Connect(function() task.spawn(triggerTouchHit) end))
end

local function wireSwingListeners()
    if LocalPlayer.Character then
        local tool = LocalPlayer.Character:FindFirstChildOfClass("Tool")
        if tool then wireTool(tool) end
        table.insert(Hitbox._swingConns, LocalPlayer.Character.ChildAdded:Connect(function(child)
            if child:IsA("Tool") then wireTool(child) end
        end))
    end
    table.insert(Hitbox._swingConns, LocalPlayer.CharacterAdded:Connect(function(c)
        task.wait(0.5)
        if not Hitbox.Enabled then return end
        local tool = c:FindFirstChildOfClass("Tool")
        if tool then wireTool(tool) end
        table.insert(Hitbox._swingConns, c.ChildAdded:Connect(function(child)
            if child:IsA("Tool") then wireTool(child) end
        end))
    end))
end

-- ═══ WIREFRAME VISUALS ═══
local function ensureVisualFolder()
    if Hitbox.VisualFolder and Hitbox.VisualFolder.Parent then return Hitbox.VisualFolder end
    local f = Workspace:FindFirstChild("MK_HB_Visuals")
    if f then f:Destroy() end
    f = Instance.new("Folder")
    f.Name = "MK_HB_Visuals"
    f.Parent = Workspace
    Hitbox.VisualFolder = f
    return f
end

local function createVisual(realPart)
    local v = Instance.new("Part")
    v.Name = "MK_VIS_" .. realPart.Name
    v.Size = realPart.Size * Hitbox.Scale
    v.CFrame = realPart.CFrame
    v.Anchored = true
    v.CanCollide = false
    v.CanQuery = false
    v.CanTouch = false
    v.Massless = true
    v.Transparency = 1
    v.CastShadow = false
    v.Locked = true
    v.Material = Enum.Material.Plastic
    v.Parent = ensureVisualFolder()
    local box = Instance.new("SelectionBox")
    box.Name = "MK_HB_VisBox"
    box.Adornee = v
    box.Color3 = Hitbox.WireframeColor
    box.LineThickness = 0.18
    box.SurfaceTransparency = 1
    box.Parent = v
    return { visual = v, box = box }
end

local function destroyAllVisuals()
    for _, map in pairs(Hitbox.Visuals) do
        for _, rec in pairs(map) do
            if rec.box then pcall(function() rec.box:Destroy() end) end
            if rec.visual then pcall(function() rec.visual:Destroy() end) end
        end
    end
    Hitbox.Visuals = {}
    if Hitbox.VisualFolder and Hitbox.VisualFolder.Parent then
        pcall(function() Hitbox.VisualFolder:Destroy() end)
    end
    Hitbox.VisualFolder = nil
end

local function updateVisuals()
    if not Hitbox.Enabled or not Hitbox.ShowWireframe then
        if next(Hitbox.Visuals) then destroyAllVisuals() end
        return
    end
    ensureVisualFolder()
    local liveTargets = {}
    for _, char in ipairs(collectTargets()) do
        liveTargets[char] = true
        local map = Hitbox.Visuals[char]
        if not map then map = {}; Hitbox.Visuals[char] = map end
        for _, partName in ipairs(TORSO_NAMES) do
            local realPart = char:FindFirstChild(partName)
            if realPart and realPart:IsA("BasePart") then
                local rec = map[realPart]
                if not rec or not rec.visual.Parent then
                    rec = createVisual(realPart)
                    map[realPart] = rec
                end
                pcall(function()
                    rec.visual.CFrame = realPart.CFrame
                    rec.visual.Size = realPart.Size * Hitbox.Scale
                    if rec.box and rec.box.Color3 ~= Hitbox.WireframeColor then
                        rec.box.Color3 = Hitbox.WireframeColor
                    end
                end)
                break
            end
        end
    end
    for char, map in pairs(Hitbox.Visuals) do
        if not char.Parent or not liveTargets[char] then
            for _, rec in pairs(map) do
                if rec.box then pcall(function() rec.box:Destroy() end) end
                if rec.visual then pcall(function() rec.visual:Destroy() end) end
            end
            Hitbox.Visuals[char] = nil
        else
            for realPart, rec in pairs(map) do
                if not realPart.Parent or not rec.visual.Parent then
                    if rec.box then pcall(function() rec.box:Destroy() end) end
                    if rec.visual then pcall(function() rec.visual:Destroy() end) end
                    map[realPart] = nil
                end
            end
        end
    end
end

-- ═══ START / STOP ═══
function Hitbox.Start()
    Hitbox.Enabled = true
    Config.Set("Hitbox.Enabled", true)
    Hitbox._npcCacheTime = 0

    if Hitbox.EnableRayHook then Hitbox.InstallRayHook() end
    if Hitbox.EnableTouchHook then
        wireSwingListeners()
        wireToolsForFire()
        if type(firetouchinterest) ~= "function" then
            Notify.Push("firetouchinterest missing — melee may not register", "warning", 4)
        end
    end

    Signal.Connect(RunService.Heartbeat, function()
        local ok, e = pcall(updateVisuals)
        if not ok then Logger.Error("HITBOX", "visuals: " .. tostring(e)) end
    end)

    Logger.Info("HITBOX", "Started (raycast hook + FTI backup)")
end

function Hitbox.Stop()
    Hitbox.Enabled = false
    Config.Set("Hitbox.Enabled", false)
    Hitbox.UninstallRayHook()
    unwireSwingListeners()
    destroyAllVisuals()
    Logger.Info("HITBOX", "Stopped")
end

function Hitbox.GetRayHitCount()   return Hitbox._rayHits end
function Hitbox.GetSkippedCount()  return Hitbox._raySkipped end
function Hitbox.GetSilentHits()    return Hitbox._silentHits end
function Hitbox.GetSwingCount()    return Hitbox._swings end
function Hitbox.GetTouchHitCount() return Hitbox._touchHits end

function Hitbox.SetScale(v)
    v = tonumber(v) or 2.0
    if v < 1.0 then v = 1.0 end
    if v > 2000 then v = 2000 end
    Hitbox.Scale = v
    Config.Set("Hitbox.Scale", Hitbox.Scale)
end
function Hitbox.SetMeleeRange(v) Hitbox.MeleeRange = Util.clamp(tonumber(v) or 12, 3, 200) Config.Set("Hitbox.MeleeRange", Hitbox.MeleeRange) end
function Hitbox.SetBowRange(v)   Hitbox.BowRange = Util.clamp(tonumber(v) or 25, 5, 500) Config.Set("Hitbox.BowRange", Hitbox.BowRange) end
function Hitbox.SetTeamCheck(s)  Hitbox.TeamCheck = s and true or false Config.Set("Hitbox.TeamCheck", Hitbox.TeamCheck) end
function Hitbox.SetNPCMode(s)    Hitbox.NPCMode = s and true or false Config.Set("Hitbox.NPCMode", Hitbox.NPCMode) Hitbox._npcCacheTime = 0 end
function Hitbox.SetShowWireframe(s) Hitbox.ShowWireframe = s and true or false Config.Set("Hitbox.ShowWireframe", Hitbox.ShowWireframe) if not Hitbox.ShowWireframe then destroyAllVisuals() end end
function Hitbox.SetWireframeColor(c)
    Hitbox.WireframeColor = c
    Config.Set("Hitbox.WireframeColor", Util.colorToArray(c))
    for _, map in pairs(Hitbox.Visuals) do
        for _, rec in pairs(map) do if rec.box and rec.box.Parent then rec.box.Color3 = c end end
    end
end
function Hitbox.SetForwardDotMin(v) Hitbox.ForwardDotMin = Util.clamp(tonumber(v) or 0, -1, 1) Config.Set("Hitbox.ForwardDotMin", Hitbox.ForwardDotMin) end
function Hitbox.SetEnableRayHook(s)
    Hitbox.EnableRayHook = s and true or false
    Config.Set("Hitbox.EnableRayHook", Hitbox.EnableRayHook)
    if Hitbox.Enabled then
        if Hitbox.EnableRayHook then Hitbox.InstallRayHook() else Hitbox.UninstallRayHook() end
    end
end
function Hitbox.SetEnableTouchHook(s)
    Hitbox.EnableTouchHook = s and true or false
    Config.Set("Hitbox.EnableTouchHook", Hitbox.EnableTouchHook)
    if Hitbox.Enabled then
        if Hitbox.EnableTouchHook then wireSwingListeners() else unwireSwingListeners() end
    end
end
function Hitbox.SetDebugLog(s) Hitbox.DebugLog = s and true or false Config.Set("Hitbox.DebugLog", Hitbox.DebugLog) end

-- ═══ SILENT AIM START/STOP ═══
function Hitbox.SilentStart()
    Hitbox.SilentAim.Enabled = true
    Config.Set("SilentAim.Enabled", true)
    if not Hitbox._hooked then Hitbox.InstallRayHook() end
    Logger.Info("SILENTAIM", "Enabled")
end

function Hitbox.SilentStop()
    Hitbox.SilentAim.Enabled = false
    Config.Set("SilentAim.Enabled", false)
    if not Hitbox.Enabled then Hitbox.UninstallRayHook() end
    Logger.Info("SILENTAIM", "Disabled")
end

-- ESP
local ESP = {
    Enabled = Config.Get("ESP.Enabled", false), NPCMode = Config.Get("ESP.NPCMode", false), TeamCheck = Config.Get("ESP.TeamCheck", true),
    FillColor = Util.arrayToColor(Config.Get("ESP.FillColor"), Theme.Accent),
    OutlineColor = Util.arrayToColor(Config.Get("ESP.OutlineColor"), Theme.AccentBright),
    FillTransparency = Config.Get("ESP.FillTransparency", 0.7), OutlineTransparency = Config.Get("ESP.OutlineTransparency", 0.15),
    _instances = {}, _conn = nil, _acc = 0,
}
function ESP._attach(m)
    local h = ESP._instances[m]
    if not h or not h.Parent then
        h = Instance.new("Highlight") h.Name = "MK_ESP" h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop h.Parent = m
        ESP._instances[m] = h
    end
    h.Adornee = m h.FillColor = ESP.FillColor h.OutlineColor = ESP.OutlineColor
    h.FillTransparency = ESP.FillTransparency h.OutlineTransparency = ESP.OutlineTransparency
end
function ESP._detach(m) if ESP._instances[m] then pcall(function() ESP._instances[m]:Destroy() end) end ESP._instances[m] = nil end
local function espScan()
    local f = {}
    local function walk(c)
        for _, o in ipairs(c:GetChildren()) do
            if o:IsA("Model") and o:FindFirstChildOfClass("Humanoid") and Players:GetPlayerFromCharacter(o) == nil then f[#f + 1] = o
            elseif o:IsA("Folder") or o:IsA("Model") then walk(o) end
        end
    end
    walk(Workspace) return f
end
function ESP._refresh()
    if not ESP.Enabled then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local c = plr.Character
            local ok = (not ESP.TeamCheck) or (not LocalPlayer.Team or not plr.Team) or (LocalPlayer.Team ~= plr.Team)
            if c and c:FindFirstChildOfClass("Humanoid") and ok then ESP._attach(c)
            elseif c then ESP._detach(c) end
        end
    end
    if ESP.NPCMode then for _, o in ipairs(espScan()) do ESP._attach(o) end
    else for m in pairs(ESP._instances) do if Players:GetPlayerFromCharacter(m) == nil then ESP._detach(m) end end end
end
function ESP.Start()
    if ESP._conn then return end
    ESP.Enabled = true Config.Set("ESP.Enabled", true)
    ESP._conn = Signal.Connect(RunService.Heartbeat, function(dt)
        ESP._acc = ESP._acc + dt if ESP._acc < 0.2 then return end ESP._acc = 0
        local ok, e = pcall(ESP._refresh) if not ok then Logger.Error("ESP", tostring(e)) end
    end)
end
function ESP.Stop()
    ESP.Enabled = false Config.Set("ESP.Enabled", false)
    if ESP._conn then ESP._conn:Disconnect() ESP._conn = nil end
    for m in pairs(ESP._instances) do ESP._detach(m) end ESP._instances = {}
end

-- MOVEMENT
local Movement = {
    SpeedEnabled = Config.Get("Movement.SpeedEnabled", false), WalkSpeed = Config.Get("Movement.WalkSpeed", 16),
    JumpEnabled = Config.Get("Movement.JumpEnabled", false), JumpPower = Config.Get("Movement.JumpPower", 50),
    InfJump = Config.Get("Movement.InfJump", false), NoClip = Config.Get("Movement.NoClip", false),
    _conn = nil, _noclipConn = nil, _acc = 0,
}
function Movement._apply()
    local c = LocalPlayer.Character if not c then return end
    local h = c:FindFirstChildOfClass("Humanoid") if not h then return end
    if Movement.SpeedEnabled and h.WalkSpeed ~= Movement.WalkSpeed then h.WalkSpeed = Movement.WalkSpeed end
    if Movement.JumpEnabled and h.JumpPower ~= Movement.JumpPower then h.JumpPower = Movement.JumpPower end
end
function Movement.Start()
    if Movement._conn then return end
    Movement._conn = Signal.Connect(RunService.Heartbeat, function(dt)
        Movement._acc = Movement._acc + dt if Movement._acc < 0.1 then return end Movement._acc = 0
        pcall(Movement._apply)
    end)
end
function Movement.Stop() if Movement._conn then Movement._conn:Disconnect() Movement._conn = nil end end
function Movement._noclipTick()
    if not Movement.NoClip then return end
    local c = LocalPlayer.Character if not c then return end
    for _, p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end end
end
function Movement.SetNoClip(s)
    Movement.NoClip = s and true or false Config.Set("Movement.NoClip", Movement.NoClip)
    if Movement.NoClip then
        if not Movement._noclipConn then Movement._noclipConn = Signal.Connect(RunService.Stepped, function() pcall(Movement._noclipTick) end) end
    else
        if Movement._noclipConn then Movement._noclipConn:Disconnect() Movement._noclipConn = nil end
        local c = LocalPlayer.Character if c then for _, p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = true end end end
    end
end
function Movement.SetInfJump(s) Movement.InfJump = s and true or false Config.Set("Movement.InfJump", Movement.InfJump) end
Signal.Connect(UserInputService.JumpRequest, function()
    if Movement.InfJump then local c = LocalPlayer.Character if c then local h = c:FindFirstChildOfClass("Humanoid") if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end end end
end)
function Movement.SetSpeedEnabled(s) Movement.SpeedEnabled = s and true or false Config.Set("Movement.SpeedEnabled", Movement.SpeedEnabled); if Movement.SpeedEnabled then Movement.Start() end end
function Movement.SetJumpEnabled(s) Movement.JumpEnabled = s and true or false Config.Set("Movement.JumpEnabled", Movement.JumpEnabled); if Movement.JumpEnabled then Movement.Start() end end
function Movement.SetWalkSpeed(v) Movement.WalkSpeed = Util.clamp(v, 1, 500) Config.Set("Movement.WalkSpeed", Movement.WalkSpeed) end
function Movement.SetJumpPower(v) Movement.JumpPower = Util.clamp(v, 1, 500) Config.Set("Movement.JumpPower", Movement.JumpPower) end

-- AIMBOT
local Aimbot = {
    Enabled = Config.Get("Aimbot.Enabled", false), Smoothness = Config.Get("Aimbot.Smoothness", 0.25),
    MaxDistance = Config.Get("Aimbot.MaxDistance", 250), TeamCheck = Config.Get("Aimbot.TeamCheck", true),
    IncludeNPC = Config.Get("Aimbot.IncludeNPC", true), LockOn = Config.Get("Aimbot.LockOn", false),
    WallCheck = Config.Get("Aimbot.WallCheck", false), AutoClick = Config.Get("Aimbot.AutoClick", false),
    ClickRate = Config.Get("Aimbot.ClickRate", 8), FOV = Config.Get("Aimbot.FOV", 180),
    TargetArea = Config.Get("Aimbot.TargetArea", "Head"),
    _conn = nil, _clickAcc = 0, _target = nil,
}
local function aimHostile(plr)
    if plr == LocalPlayer then return false end
    if not Aimbot.TeamCheck then return true end
    local a, b = LocalPlayer.Team, plr.Team if not a or not b then return true end
    return a ~= b
end
function Aimbot.FindTarget()
    local cam = Workspace.CurrentCamera if not cam then return nil end
    local origin = cam.CFrame.Position
    local best, bestDist = nil, Aimbot.MaxDistance
    local function test(m)
        if not m or not m.Parent then return end
        local parts = getTargetPartsForCharacter(m, Aimbot.TargetArea)
        if #parts == 0 then
            local torso = getPrimaryTorso(m)
            if torso then parts = { torso } end
        end
        for _, part in ipairs(parts) do
            local d = (part.Position - origin).Magnitude
            if d <= bestDist then
                local toT = (part.Position - origin).Unit
                local dot = cam.CFrame.LookVector:Dot(toT)
                local ang = math.deg(math.acos(Util.clamp(dot, -1, 1)))
                if ang <= Aimbot.FOV / 2 then best = part bestDist = d end
            end
        end
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if aimHostile(plr) and plr.Character then
            local h = plr.Character:FindFirstChildOfClass("Humanoid")
            if h and h.Health > 0 then test(plr.Character) end
        end
    end
    if Aimbot.IncludeNPC then
        local function walk(c)
            for _, o in ipairs(c:GetChildren()) do
                if o:IsA("Model") and Players:GetPlayerFromCharacter(o) == nil then
                    local h = o:FindFirstChildOfClass("Humanoid")
                    if h and h.Health > 0 and not isLocalChar(o) then test(o) end
                elseif o:IsA("Folder") or o:IsA("Model") then walk(o) end
            end
        end
        walk(Workspace)
    end
    return best
end
function Aimbot._tick(dt)
    if not Aimbot.Enabled then return end
    local cam = Workspace.CurrentCamera if not cam then return end
    local shouldAim = Aimbot.LockOn or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    if not shouldAim then Aimbot._target = nil return end
    local t = Aimbot.FindTarget() Aimbot._target = t
    if not t then return end
    cam.CFrame = cam.CFrame:Lerp(CFrame.new(cam.CFrame.Position, t.Position), 1 - Aimbot.Smoothness)
    if Aimbot.AutoClick then
        Aimbot._clickAcc = Aimbot._clickAcc + dt
        local iv = 1 / math.max(Aimbot.ClickRate, 1)
        if Aimbot._clickAcc >= iv then
            Aimbot._clickAcc = 0
            local c = LocalPlayer.Character
            if c then local tl = c:FindFirstChildOfClass("Tool") if tl then pcall(function() tl:Activate() end) end end
        end
    end
end
function Aimbot.Start()
    if Aimbot._conn then return end
    Aimbot.Enabled = true Config.Set("Aimbot.Enabled", true)
    Aimbot._conn = Signal.Connect(RunService.RenderStepped, function(dt)
        local ok, e = pcall(Aimbot._tick, dt) if not ok then Logger.Error("AIMBOT", tostring(e)) end
    end)
end
function Aimbot.Stop()
    Aimbot.Enabled = false Config.Set("Aimbot.Enabled", false)
    if Aimbot._conn then Aimbot._conn:Disconnect() Aimbot._conn = nil end Aimbot._target = nil
end
function Aimbot.SetSmoothness(v) Aimbot.Smoothness = Util.clamp(v, 0.01, 0.95) Config.Set("Aimbot.Smoothness", Aimbot.Smoothness) end
function Aimbot.SetDistance(v) Aimbot.MaxDistance = Util.clamp(v, 10, 1000) Config.Set("Aimbot.MaxDistance", Aimbot.MaxDistance) end
function Aimbot.SetFOV(v) Aimbot.FOV = Util.clamp(v, 10, 360) Config.Set("Aimbot.FOV", Aimbot.FOV) end
function Aimbot.SetRate(v) Aimbot.ClickRate = Util.clamp(v, 1, 30) Config.Set("Aimbot.ClickRate", Aimbot.ClickRate) end
function Aimbot.SetTeamCheck(s) Aimbot.TeamCheck = s and true or false Config.Set("Aimbot.TeamCheck", Aimbot.TeamCheck) end
function Aimbot.SetTargetArea(area) Aimbot.TargetArea = area Config.Set("Aimbot.TargetArea", area) end

-- COMBAT
local Combat = { AutoAttack = Config.Get("Combat.AutoAttack", false), Range = Config.Get("Combat.AutoAttackRange", 20), _conn = nil, _acc = 0 }
function Combat._tick(dt)
    if not Combat.AutoAttack then return end
    Combat._acc = Combat._acc + dt if Combat._acc < 0.1 then return end Combat._acc = 0
    local c = LocalPlayer.Character if not c then return end
    local my = c:FindFirstChild("HumanoidRootPart") if not my then return end
    local tl = c:FindFirstChildOfClass("Tool") if not tl then return end
    local inR = false
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local ch = plr.Character
            if ch then
                local hrp = ch:FindFirstChild("HumanoidRootPart")
                if hrp and (hrp.Position - my.Position).Magnitude <= Combat.Range then inR = true break end
            end
        end
    end
    if inR then pcall(function() tl:Activate() end) end
end
function Combat.Start() if Combat._conn then return end Combat._conn = Signal.Connect(RunService.Heartbeat, function(dt) pcall(Combat._tick, dt) end) end
function Combat.SetAutoAttack(s) Combat.AutoAttack = s and true or false Config.Set("Combat.AutoAttack", Combat.AutoAttack) if Combat.AutoAttack then Combat.Start() end end
function Combat.SetRange(v) Combat.Range = Util.clamp(v, 5, 100) Config.Set("Combat.AutoAttackRange", Combat.Range) end

-- TELEMETRY
local Telemetry = { FPS = 0, Ping = 0, Mem = 0, NPCs = 0, _acc = 0, _frames = 0, _hist = {}, _conn = nil, _slowAcc = 0 }
function Telemetry.Start()
    if Telemetry._conn then return end
    Telemetry._conn = Signal.Connect(RunService.RenderStepped, function(dt)
        Telemetry._acc = Telemetry._acc + dt Telemetry._frames = Telemetry._frames + 1
        if Telemetry._acc >= 0.5 then
            Telemetry.FPS = math.floor(Telemetry._frames / Telemetry._acc)
            Telemetry._acc = 0 Telemetry._frames = 0
            table.insert(Telemetry._hist, Telemetry.FPS)
            if #Telemetry._hist > 60 then table.remove(Telemetry._hist, 1) end
        end
    end)
    Signal.Connect(RunService.Heartbeat, function(dt)
        Telemetry._slowAcc = Telemetry._slowAcc + dt if Telemetry._slowAcc < 0.5 then return end Telemetry._slowAcc = 0
        local ok, p = pcall(function() return math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
        if ok and type(p) == "number" then Telemetry.Ping = p end
        Telemetry.Mem = math.floor(collectgarbage("count") / 1024)
        Telemetry.NPCs = #scanNPCs()
    end)
end

-- PLAYER LIST
local PlayerList = { Holder = nil, Rows = {} }
function PlayerList.Build(p) PlayerList.Holder = p end
function PlayerList.Refresh()
    if not PlayerList.Holder then return end
    for _, r in pairs(PlayerList.Rows) do pcall(function() r:Destroy() end) end PlayerList.Rows = {}
    local ps = Players:GetPlayers() table.sort(ps, function(a, b) return a.Name < b.Name end)
    for _, plr in ipairs(ps) do
        local row = UI.Root(PlayerList.Holder, "Row_" .. plr.Name, { Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = Theme.BgCard })
        UI.corner(row, 14) UI.stroke(row, Theme.Border, 1, 0.5)
        makeGradient(row, Theme.BgCard, Theme.BgCardLight, 30)
        UI.Text(row, plr.Name .. (plr == LocalPlayer and "  (you)" or ""), { Size = UDim2.new(1, -170, 1, 0), Position = UDim2.new(0, 14, 0, 0), TextSize = 12, TextColor3 = plr == LocalPlayer and Theme.AccentBright or Theme.Text, Font = Enum.Font.GothamSemibold })
        local hp = "?"
        if plr.Character then local h = plr.Character:FindFirstChildOfClass("Humanoid") if h then hp = tostring(math.floor(h.Health)) end end
        UI.Text(row, "HP " .. hp, { Size = UDim2.new(0, 55, 1, 0), Position = UDim2.new(1, -170, 0, 0), TextSize = 11, TextColor3 = Theme.TextDim, TextXAlignment = Enum.TextXAlignment.Right, Font = Enum.Font.GothamSemibold })
        local focus = UI.Button(row, "Focus", { Size = UDim2.new(0, 60, 0, 24), Position = UDim2.new(1, -110, 0.5, -12), bgColor = Theme.BgRaised, radius = 10, textSize = 11 })
        Signal.Connect(focus.MouseButton1Click, function()
            if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
    pcall(function()
        local cam = Workspace.CurrentCamera
        if cam then
        if Hitbox._hooked and Hitbox.EnableRayHook then
            -- Hook açıksa safe delay ekle
            task.spawn(function()
                task.wait()
                cam.CFrame = CFrame.new(cam.CFrame.Position, plr.Character.HumanoidRootPart.Position)
            end)
        else
            cam.CFrame = CFrame.new(cam.CFrame.Position, plr.Character.HumanoidRootPart.Position)
        end
    end
end)
            end
        end)
        if plr ~= LocalPlayer then
            local tp = UI.Button(row, "TP", { Size = UDim2.new(0, 40, 0, 24), Position = UDim2.new(1, -44, 0.5, -12), bgColor = Theme.AccentDim, radius = 10, textSize = 11 })
            Signal.Connect(tp.MouseButton1Click, function()
                local my = LocalPlayer.Character local tgt = plr.Character
                if my and tgt and tgt:FindFirstChild("HumanoidRootPart") then
                    local mh = my:FindFirstChild("HumanoidRootPart")
                    if mh then mh.CFrame = tgt.HumanoidRootPart.CFrame * CFrame.new(0, 3, 0) end
                end
            end)
        end
        PlayerList.Rows[plr] = row
    end
end
Signal.Connect(Players.PlayerAdded, function() task.wait(0.3) PlayerList.Refresh() end)
Signal.Connect(Players.PlayerRemoving, function() task.wait(0.1) PlayerList.Refresh() end)

-- ════════════════════════════════════════════════════════════════════════════
-- MAIN BUILD
-- ════════════════════════════════════════════════════════════════════════════
local Main = {}
function Main.Build()
    local win = UI.CreateWindow("MK_EDS_Main", "Medieval Kingdoms  /  MK", UDim2.new(0, 800, 0, 580))

    -- HITBOX
    local hb = win:AddTab("hitbox", "HITBOX")
    local info = UI.Card(hb, 132)
    UI.Text(info, "Hitbox v17.1", { Size = UDim2.new(1, 0, 0, 16), TextColor3 = Theme.AccentBright, TextSize = 12, Font = Enum.Font.GothamBold })
    UI.Text(info, "Raycast hook for guns (camera-safe). firetouchinterest for melee.", { Size = UDim2.new(1, 0, 0, 14), TextColor3 = Theme.Success, TextSize = 10, TextWrapped = true })
    UI.Text(info, "Target Area selects which body parts get expanded.", { Size = UDim2.new(1, 0, 0, 14), TextColor3 = Theme.TextDim, TextSize = 10, TextWrapped = true })
    UI.Text(info, "Wireframe lives in Workspace/MK_HB_Visuals (render-only).", { Size = UDim2.new(1, 0, 0, 14), TextColor3 = Theme.TextDim, TextSize = 10, TextWrapped = true })
    UI.Text(info, "If weapons still miss, enable Silent Aim or Aimbot.", { Size = UDim2.new(1, 0, 0, 14), TextColor3 = Theme.Warning, TextSize = 10, TextWrapped = true })

    UI.SectionHeader(hb, "EXPANDER")
    UI.Row(hb, "Enable Hitbox", UI.Toggle(hb, Hitbox.Enabled, function(s)
        if s then Hitbox.Start() else Hitbox.Stop() end
        Notify.Push("Hitbox " .. (s and "ON" or "OFF"), s and "accent" or "info", 1.5)
    end))
    UI.SliderBlock(hb, "Hit Scale", 1, 200, Hitbox.Scale, function(v) Hitbox.SetScale(v) end, 2)

    UI.Text(hb, "Quick Presets", { Size = UDim2.new(1, 0, 0, 16), TextColor3 = Theme.TextDim, TextSize = 11 })
    local presetRow = UI.Root(hb, "PresetRow", { Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1 })
    for i, val in ipairs({ 2, 5, 10, 25, 50, 100 }) do
        local btn = UI.Button(presetRow, tostring(val) .. "x", {
            Size = UDim2.new(0, 56, 1, 0), Position = UDim2.new(0, (i - 1) * 62, 0, 0),
            bgColor = Theme.BgRaised, textColor = Theme.Text, radius = 10, textSize = 11,
        })
        Signal.Connect(btn.MouseButton1Click, function() Hitbox.SetScale(val) Notify.Push("Scale " .. val .. "x", "accent", 1.5) end)
    end

    UI.SectionHeader(hb, "TARGET AREA")
    UI.ChipRow(hb, { "Body", "Head", "Legs", "Arms", "Nearest", "Random" }, Hitbox.TargetArea, function(v) Hitbox.SetTargetArea(v) end)

    UI.SectionHeader(hb, "RANGE")
    UI.SliderBlock(hb, "Melee Reach", 3, 50, Hitbox.MeleeRange, function(v) Hitbox.SetMeleeRange(v) end, 0)
    UI.SliderBlock(hb, "Bow Reach", 5, 200, Hitbox.BowRange, function(v) Hitbox.SetBowRange(v) end, 0)

    UI.SectionHeader(hb, "WEAPON COMPATIBILITY")
    UI.Row(hb, "Raycast Hook (guns)", UI.Toggle(hb, Hitbox.EnableRayHook, function(s) Hitbox.SetEnableRayHook(s) end))
    UI.Row(hb, "Touch Hook (melee)", UI.Toggle(hb, Hitbox.EnableTouchHook, function(s) Hitbox.SetEnableTouchHook(s) end))
    UI.SliderBlock(hb, "Forward Dot Min", -1, 1, Hitbox.ForwardDotMin, function(v) Hitbox.SetForwardDotMin(v) end, 2)

    UI.SectionHeader(hb, "COVERAGE")
    UI.Row(hb, "Team Check", UI.Toggle(hb, Hitbox.TeamCheck, function(s) Hitbox.SetTeamCheck(s) end))
    UI.Row(hb, "NPC Mode", UI.Toggle(hb, Hitbox.NPCMode, function(s) Hitbox.SetNPCMode(s) end))
    UI.Row(hb, "Debug Log", UI.Toggle(hb, Hitbox.DebugLog, function(s) Hitbox.SetDebugLog(s) end))

    UI.SectionHeader(hb, "WIREFRAME")
    UI.Row(hb, "Show Wireframe", UI.Toggle(hb, Hitbox.ShowWireframe, function(s) Hitbox.SetShowWireframe(s) end))
    UI.Row(hb, "Breathing Animation", UI.Toggle(hb, Hitbox.BreatheWireframe, function(s) Hitbox.SetBreathe(s) end))
    UI.Text(hb, "Wireframe Color", { Size = UDim2.new(1, 0, 0, 16), TextColor3 = Theme.TextDim, TextSize = 11 })
    local palette = {
        { "Rose", Color3.fromRGB(215, 145, 165) }, { "Lime", Color3.fromRGB(140, 230, 150) },
        { "Cyan", Color3.fromRGB(120, 220, 240) }, { "Gold", Color3.fromRGB(230, 200, 110) },
        { "Violet", Color3.fromRGB(190, 140, 240) }, { "White", Color3.fromRGB(240, 240, 240) },
    }
    local cRow = UI.Root(hb, "ColorRow", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1 })
    for i, p in ipairs(palette) do
        local sw = UI.Root(cRow, "Sw" .. i, { Size = UDim2.new(0, 30, 1, 0), Position = UDim2.new(0, (i - 1) * 36, 0, 0), BackgroundColor3 = p[2] })
        UI.corner(sw, Theme.R_Chip) UI.stroke(sw, Theme.Border, 1, 0.4)
        local b = Instance.new("TextButton")
        b.Text = "" b.BackgroundTransparency = 1 b.Size = UDim2.new(1, 0, 1, 0) b.Parent = sw
        Signal.Connect(b.MouseButton1Click, function() Hitbox.SetWireframeColor(p[2]) end)
    end

    UI.SectionHeader(hb, "DIAGNOSTICS")
    local rayHitLbl = UI.Text(hb, "Ray hits: 0", { Size = UDim2.new(1, 0, 0, 18), TextColor3 = Theme.TextDim, TextSize = 11 })
    local raySkipLbl = UI.Text(hb, "Camera rays skipped: 0", { Size = UDim2.new(1, 0, 0, 18), TextColor3 = Theme.TextDim, TextSize = 11 })
    local swingLbl = UI.Text(hb, "Swings: 0", { Size = UDim2.new(1, 0, 0, 18), TextColor3 = Theme.TextDim, TextSize = 11 })
    local touchLbl = UI.Text(hb, "Touch hits: 0", { Size = UDim2.new(1, 0, 0, 18), TextColor3 = Theme.TextDim, TextSize = 11 })
    local hookLbl = UI.Text(hb, "Ray hook: inactive", { Size = UDim2.new(1, 0, 0, 18), TextColor3 = Theme.TextFaint, TextSize = 10 })
    Signal.Connect(RunService.Heartbeat, function()
        if rayHitLbl and rayHitLbl.Parent then
            rayHitLbl.Text = "Ray hits: " .. tostring(Hitbox.GetRayHitCount())
            raySkipLbl.Text = "Camera rays skipped: " .. tostring(Hitbox.GetSkippedCount())
            swingLbl.Text = "Swings: " .. tostring(Hitbox.GetSwingCount())
            touchLbl.Text = "Touch hits: " .. tostring(Hitbox.GetTouchHitCount())
            hookLbl.Text = "Ray hook: " .. (Hitbox._hooked and "installed" or "inactive")
        end
    end)

    -- SILENT AIM
    local sa = win:AddTab("silent", "SILENT AIM")
    local saInfo = UI.Card(sa, 130)
    UI.Text(saInfo, "Silent Aim", { Size = UDim2.new(1, 0, 0, 16), TextColor3 = Theme.AccentBright, TextSize = 12, Font = Enum.Font.GothamBold })
    UI.Text(saInfo, "Redirects your weapon's ray toward the target during fire.", { Size = UDim2.new(1, 0, 0, 14), TextColor3 = Theme.Success, TextSize = 10, TextWrapped = true })
    UI.Text(saInfo, "Only active for Fire Window seconds after you attack.", { Size = UDim2.new(1, 0, 0, 14), TextColor3 = Theme.Success, TextSize = 10, TextWrapped = true })
    UI.Text(saInfo, "Camera occlusion is protected (backward rays skipped).", { Size = UDim2.new(1, 0, 0, 14), TextColor3 = Theme.TextDim, TextSize = 10, TextWrapped = true })
    UI.Text(saInfo, "Server-authoritative games: use Aimbot instead.", { Size = UDim2.new(1, 0, 0, 14), TextColor3 = Theme.Warning, TextSize = 10, TextWrapped = true })

    UI.SectionHeader(sa, "ENABLE")
    UI.Row(sa, "Enable Silent Aim", UI.Toggle(sa, Hitbox.SilentAim.Enabled, function(s)
        if s then Hitbox.SilentStart() else Hitbox.SilentStop() end
        Notify.Push("Silent Aim " .. (s and "ON" or "OFF"), s and "accent" or "info", 1.5)
    end))

    UI.SectionHeader(sa, "TARGET AREA")
    UI.ChipRow(sa, { "Body", "Head", "Legs", "Arms", "Nearest", "Random" }, Hitbox.SilentAim.TargetArea, function(v) Hitbox.SetSilentTargetArea(v) end)

    UI.SectionHeader(sa, "TUNING")
    UI.SliderBlock(sa, "Cone Angle (degrees)", 1, 180, Hitbox.SilentAim.ConeAngle, function(v) Hitbox.SetSilentCone(v) end, 0)
    UI.SliderBlock(sa, "Max Distance", 10, 2000, Hitbox.SilentAim.MaxDistance, function(v) Hitbox.SetSilentDistance(v) end, 0)
    UI.SliderBlock(sa, "Fire Window (seconds)", 0.05, 1.0, Hitbox.SilentAim.FireWindow, function(v) Hitbox.SetSilentFireWindow(v) end, 2)
    UI.Row(sa, "Team Check", UI.Toggle(sa, Hitbox.SilentAim.TeamCheck, function(s) Hitbox.SetSilentTeamCheck(s) end))
    UI.Row(sa, "Include NPCs", UI.Toggle(sa, Hitbox.SilentAim.NPCMode, function(s) Hitbox.SetSilentNPCMode(s) end))

    UI.SectionHeader(sa, "DIAGNOSTICS")
    local silentHitsLbl = UI.Text(sa, "Silent hits: 0", { Size = UDim2.new(1, 0, 0, 18), TextColor3 = Theme.TextDim, TextSize = 11 })
    Signal.Connect(RunService.Heartbeat, function()
        if silentHitsLbl and silentHitsLbl.Parent then
            silentHitsLbl.Text = "Silent hits: " .. tostring(Hitbox.GetSilentHits())
        end
    end)

    -- AIMBOT
    local ab = win:AddTab("aimbot", "AIMBOT")
    UI.SectionHeader(ab, "TARGETING")
    UI.Row(ab, "Enable Aimbot", UI.Toggle(ab, Aimbot.Enabled, function(s) if s then Aimbot.Start() else Aimbot.Stop() end end))
    UI.Row(ab, "Lock-On", UI.Toggle(ab, Aimbot.LockOn, function(s) Aimbot.LockOn = s Config.Set("Aimbot.LockOn", s) end))
    UI.Row(ab, "Team Check", UI.Toggle(ab, Aimbot.TeamCheck, function(s) Aimbot.SetTeamCheck(s) end))
    UI.Row(ab, "Include NPCs", UI.Toggle(ab, Aimbot.IncludeNPC, function(s) Aimbot.IncludeNPC = s Config.Set("Aimbot.IncludeNPC", s) end))
    UI.SliderBlock(ab, "Smoothness", 0.01, 0.95, Aimbot.Smoothness, function(v) Aimbot.SetSmoothness(v) end, 2)
    UI.SliderBlock(ab, "Max Distance", 10, 1000, Aimbot.MaxDistance, function(v) Aimbot.SetDistance(v) end, 0)
    UI.SliderBlock(ab, "FOV", 10, 360, Aimbot.FOV, function(v) Aimbot.SetFOV(v) end, 0)
    UI.SectionHeader(ab, "TARGET AREA")
    UI.ChipRow(ab, { "Body", "Head", "Legs", "Arms" }, Aimbot.TargetArea, function(v) Aimbot.SetTargetArea(v) end)
    UI.SectionHeader(ab, "FIRE CONTROL")
    UI.Row(ab, "Auto-Click", UI.Toggle(ab, Aimbot.AutoClick, function(s) Aimbot.AutoClick = s Config.Set("Aimbot.AutoClick", s) end))
    UI.SliderBlock(ab, "Click Rate", 1, 30, Aimbot.ClickRate, function(v) Aimbot.SetRate(v) end, 0)

    -- ESP
    local esp = win:AddTab("esp", "ESP")
    UI.SectionHeader(esp, "HIGHLIGHT RENDER")
    UI.Row(esp, "Enable ESP", UI.Toggle(esp, ESP.Enabled, function(s) if s then ESP.Start() else ESP.Stop() end end))
    UI.Row(esp, "ESP for NPCs", UI.Toggle(esp, ESP.NPCMode, function(s) ESP.NPCMode = s Config.Set("ESP.NPCMode", s) end))
    UI.Row(esp, "Team Check", UI.Toggle(esp, ESP.TeamCheck, function(s) ESP.TeamCheck = s Config.Set("ESP.TeamCheck", s) end))
    UI.SliderBlock(esp, "Fill Transparency", 0, 1, ESP.FillTransparency, function(v) ESP.FillTransparency = v Config.Set("ESP.FillTransparency", v) end, 2)

    -- MOVEMENT
    local mv = win:AddTab("movement", "MOVEMENT")
    UI.SectionHeader(mv, "SPEED")
    UI.Row(mv, "Speed Override", UI.Toggle(mv, Movement.SpeedEnabled, function(s) Movement.SetSpeedEnabled(s) end))
    UI.SliderBlock(mv, "WalkSpeed", 8, 200, Movement.WalkSpeed, function(v) Movement.SetWalkSpeed(v) end, 0)
    UI.SectionHeader(mv, "JUMP")
    UI.Row(mv, "Jump Override", UI.Toggle(mv, Movement.JumpEnabled, function(s) Movement.SetJumpEnabled(s) end))
    UI.SliderBlock(mv, "JumpPower", 30, 300, Movement.JumpPower, function(v) Movement.SetJumpPower(v) end, 0)
    UI.SectionHeader(mv, "MISC")
    UI.Row(mv, "Infinite Jump", UI.Toggle(mv, Movement.InfJump, function(s) Movement.SetInfJump(s) end))
    UI.Row(mv, "NoClip", UI.Toggle(mv, Movement.NoClip, function(s) Movement.SetNoClip(s) end))

    -- TELEPORT
    local tp = win:AddTab("teleport", "TELEPORT")
    UI.SectionHeader(tp, "QUICK ACTIONS")
    UI.Text(tp, "Click a player to teleport to their position.", { Size = UDim2.new(1, 0, 0, 14), TextColor3 = Theme.TextFaint, TextSize = 10, TextWrapped = true })
    local tpList = UI.Root(tp, "TpList", { Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1 })
    tpList.AutomaticSize = Enum.AutomaticSize.Y
    UI.list(tpList, 6)
    local function refreshTp()
        for _, c in ipairs(tpList:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                local btn = UI.Button(tpList, "→ " .. plr.Name, { Size = UDim2.new(1, 0, 0, 34), bgColor = Theme.BgCard, textColor = Theme.Text, radius = 12, textSize = 12 })
                btn.TextXAlignment = Enum.TextXAlignment.Left; UI.pad(btn, 14)
                Signal.Connect(btn.MouseButton1Click, function()
                    local my = LocalPlayer.Character local tgt = plr.Character
                    if my and tgt then
                        local mh = my:FindFirstChild("HumanoidRootPart")
                        local th = tgt:FindFirstChild("HumanoidRootPart")
                        if mh and th then
                            mh.CFrame = th.CFrame * CFrame.new(0, 3, 0)
                            Notify.Push("Teleported to " .. plr.Name, "success", 1.5)
                        end
                    end
                end)
            end
        end
    end
    refreshTp()
    Signal.Connect(Players.PlayerAdded, function() task.wait(0.5) refreshTp() end)
    Signal.Connect(Players.PlayerRemoving, function() task.wait(0.3) refreshTp() end)
    UI.SectionHeader(tp, "SELF")
    local spawnBtn = UI.Button(tp, "Respawn Character", { Size = UDim2.new(1, 0, 0, 34), bgColor = Theme.AccentDim, radius = 12, textSize = 12 })
    Signal.Connect(spawnBtn.MouseButton1Click, function()
        local c = LocalPlayer.Character
        if c then local h = c:FindFirstChildOfClass("Humanoid") if h then h.Health = 0 end end
    end)

    -- STATS
    local te = win:AddTab("stats", "STATS")
    local statsCard = UI.Root(te, "Card", { Size = UDim2.new(1, 0, 0, 110), BackgroundColor3 = Theme.BgCard })
    UI.corner(statsCard, Theme.R_Card) UI.stroke(statsCard, Theme.Border, 1, 0.4)
    makeGradient(statsCard, Theme.BgCard, Theme.BgCardLight, 35)
    local function statBox(x, lbl, color)
        UI.Text(statsCard, lbl, { Position = UDim2.new(0, x, 0, 20), Size = UDim2.new(0, 100, 0, 14), TextColor3 = Theme.TextFaint, TextSize = 10, Font = Enum.Font.GothamBold })
        return UI.Text(statsCard, "--", { Position = UDim2.new(0, x, 0, 38), Size = UDim2.new(0, 100, 0, 34), TextColor3 = color, TextSize = 26, Font = Enum.Font.GothamBold })
    end
    local fpsV = statBox(20, "FPS", Theme.AccentBright)
    local pingV = statBox(150, "PING", Theme.Info)
    local memV = statBox(280, "MEMORY", Theme.Success)
    local npcV = statBox(410, "NPCS", Theme.Warning)
    Signal.Connect(RunService.Heartbeat, function()
        if not fpsV.Parent then return end
        fpsV.Text = tostring(Telemetry.FPS) pingV.Text = tostring(Telemetry.Ping) .. "ms"
        memV.Text = tostring(Telemetry.Mem) .. "MB" npcV.Text = tostring(Telemetry.NPCs)
    end)
    local graphHolder = UI.Root(te, "Graph", { Size = UDim2.new(1, 0, 0, 140), BackgroundColor3 = Theme.BgCard })
    UI.corner(graphHolder, Theme.R_Card) UI.stroke(graphHolder, Theme.Border, 1, 0.4)
    makeGradient(graphHolder, Theme.BgCard, Theme.BgCardLight, 35)
    UI.Text(graphHolder, "FPS HISTORY", { Position = UDim2.new(0, 16, 0, 12), Size = UDim2.new(1, 0, 0, 14), TextColor3 = Theme.TextFaint, TextSize = 10, Font = Enum.Font.GothamBold })
    local canvas = UI.Root(graphHolder, "Canvas", { Size = UDim2.new(1, -32, 0, 90), Position = UDim2.new(0, 16, 0, 36), BackgroundTransparency = 1 })
    local bars = {}
    for i = 1, 60 do
        local b = UI.Root(canvas, "Bar" .. i, { Size = UDim2.new(0, 4, 0, 2), Position = UDim2.new(0, (i - 1) * 7, 1, 0), BackgroundColor3 = Theme.Accent, AnchorPoint = Vector2.new(0, 1) })
        makeGradient(b, Theme.Accent, Theme.AccentBright, 90)
        bars[i] = b
    end
    Signal.Connect(RunService.Heartbeat, function()
        if not canvas.Parent then return end
        for i = 1, 60 do
            local h = Telemetry._hist[#Telemetry._hist - 60 + i]
            if h then bars[i].Size = UDim2.new(0, 4, 0, math.max(math.min(h / 240, 1) * 90, 2)) end
        end
    end)

    -- PLAYERS
    local pl = win:AddTab("players", "PLAYERS")
    local plHolder = UI.Root(pl, "Holder", { Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1 })
    plHolder.AutomaticSize = Enum.AutomaticSize.Y
    UI.list(plHolder, 6)
    PlayerList.Build(plHolder)
    PlayerList.Refresh()
    local refreshBtn = UI.Button(pl, "Refresh Player List", { Size = UDim2.new(1, 0, 0, 34), bgColor = Theme.BgRaised, radius = 12 })
    Signal.Connect(refreshBtn.MouseButton1Click, function() PlayerList.Refresh() end)

    -- GUI
    local gu = win:AddTab("gui", "GUI")
    UI.SectionHeader(gu, "CORNER STYLE")
    UI.Text(gu, "How round the corners are across all UI elements.", { Size = UDim2.new(1, 0, 0, 14), TextColor3 = Theme.TextFaint, TextSize = 10, TextWrapped = true })
    UI.ChipRow(gu, { "Sharp", "Medium", "Soft", "VerySoft" }, Config.Get("GUI.CornerStyle", "Soft"), function(v)
        Config.Set("GUI.CornerStyle", v)
        Notify.Push("Corner style: " .. v .. " (reopen to apply)", "accent", 3)
    end)
    UI.SectionHeader(gu, "ACCENT COLOR")
    UI.ChipRow(gu, { "Rose", "Gold", "Cyan" }, Config.Get("GUI.AccentChoice", "Rose"), function(v)
        Config.Set("GUI.AccentChoice", v)
        Notify.Push("Accent: " .. v .. " (reopen to apply)", "accent", 3)
    end)
    UI.ChipRow(gu, { "Violet", "Emerald", "Sunset" }, "Violet", function(v)
        Config.Set("GUI.AccentChoice", v)
        Notify.Push("Accent: " .. v .. " (reopen to apply)", "accent", 3)
    end)
    UI.SectionHeader(gu, "EFFECTS")
    UI.Row(gu, "Particles", UI.Toggle(gu, Config.Get("GUI.ShowParticles", true), function(s) Config.Set("GUI.ShowParticles", s) end))
    UI.Row(gu, "Shine Sweep", UI.Toggle(gu, Config.Get("GUI.ShowShine", true), function(s) Config.Set("GUI.ShowShine", s) end))
    UI.Row(gu, "Logo Spin", UI.Toggle(gu, Config.Get("GUI.LogoSpin", true), function(s) Config.Set("GUI.LogoSpin", s) end))
    UI.SliderBlock(gu, "Animation Speed", 0.25, 3.0, Config.Get("GUI.AnimationSpeed", 1.0), function(v) Config.Set("GUI.AnimationSpeed", v) end, 2)

    -- INFO
    local inf = win:AddTab("info", "INFO")
    UI.SectionHeader(inf, "ACCOUNT")
    local accCard = UI.Card(inf, 158)
    for _, pair in ipairs({
        { "Username", LocalPlayer.Name }, { "Display Name", LocalPlayer.DisplayName },
        { "User ID", tostring(LocalPlayer.UserId) },
        { "Account Age", tostring(LocalPlayer.AccountAge) .. " days" },
        { "Membership", tostring(LocalPlayer.MembershipType):gsub("Enum.MembershipType.", "") },
    }) do UI.InfoRow(accCard, pair[1], pair[2]) end
    UI.SectionHeader(inf, "EXECUTOR")
    local execCard = UI.Card(inf, 190)
    local execName, execVer = "Unknown", "?"
    if type(identifyexecutor) == "function" then
        local ok, n, v = pcall(identifyexecutor)
        if ok then execName = tostring(n or "Unknown") execVer = tostring(v or "?") end
    end
    UI.InfoRow(execCard, "Executor", execName)
    UI.InfoRow(execCard, "Version", execVer)
    for _, cap in ipairs({
        { "gethui", type(gethui) == "function" }, { "getgenv", type(getgenv) == "function" },
        { "firetouchinterest", type(firetouchinterest) == "function" },
        { "getrawmetatable", type(getrawmetatable) == "function" },
        { "hookfunction", type(hookfunction) == "function" },
        { "writefile", type(writefile) == "function" },
        { "identifyexecutor", type(identifyexecutor) == "function" },
    }) do
        local v = UI.InfoRow(execCard, cap[1], cap[2] and "available" or "missing")
        v.TextColor3 = cap[2] and Theme.Success or Theme.Error
    end
    UI.SectionHeader(inf, "EXECUTION")
    local sessCard = UI.Card(inf, 92)
    UI.InfoRow(sessCard, "Loaded At", os.date("%H:%M:%S", os.time()))
    local uptimeLbl = UI.InfoRow(sessCard, "Uptime", "0s")
    local memInfoLbl = UI.InfoRow(sessCard, "Memory", "-- MB")
    local playersInfoLbl = UI.InfoRow(sessCard, "Players In Game", tostring(#Players:GetPlayers()))
    Signal.Connect(RunService.Heartbeat, function()
        if not uptimeLbl or not uptimeLbl.Parent then return end
        uptimeLbl.Text = Util.formatTime(tick() - BOOT.Tick)
        memInfoLbl.Text = string.format("%d MB", math.floor(collectgarbage("count") / 1024))
        playersInfoLbl.Text = tostring(#Players:GetPlayers())
    end)
    UI.SectionHeader(inf, "UPDATE")
    local updCard = UI.Card(inf, 92)
    UI.InfoRow(updCard, "Suite Version", "v" .. BOOT.Version)
    UI.InfoRow(updCard, "Build", BOOT.Build)
    UI.InfoRow(updCard, "Release Date", "2025")
    UI.InfoRow(updCard, "Status", "Latest")

    -- SETTINGS
    local se = win:AddTab("settings", "SETTINGS")
    UI.SectionHeader(se, "CONFIGURATION")
    local cfgRow = UI.Root(se, "CfgRow", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1 })
    local saveBtn = UI.Button(cfgRow, "Save Config", { Size = UDim2.new(0, 150, 1, 0), Position = UDim2.new(0, 0, 0, 0), bgColor = Theme.Accent, textColor = Theme.BgDeep, radius = 12, gradient = true })
    Signal.Connect(saveBtn.MouseButton1Click, function() if Config.Save() then Notify.Push("Saved", "success", 1.5) end end)
    local resetBtn = UI.Button(cfgRow, "Reset Defaults", { Size = UDim2.new(0, 150, 1, 0), Position = UDim2.new(0, 160, 0, 0), bgColor = Theme.Warning, textColor = Theme.BgDeep, radius = 12 })
    Signal.Connect(resetBtn.MouseButton1Click, function()
        Config.Data = Util.deepCopy(Config.Defaults) Config.Save()
        Notify.Push("Defaults restored", "warning", 3)
    end)
    local clearBtn = UI.Button(cfgRow, "Clear Notifications", { Size = UDim2.new(0, 160, 1, 0), Position = UDim2.new(0, 320, 0, 0), bgColor = Theme.BgRaised, radius = 12 })
    Signal.Connect(clearBtn.MouseButton1Click, function() Notify.Clear() Notify.Push("Cleared", "info", 1) end)
    UI.SectionHeader(se, "WINDOW")
    local winRow = UI.Root(se, "WinRow", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1 })
    local resetPos = UI.Button(winRow, "Reset Window to Center", { Size = UDim2.new(0, 220, 1, 0), Position = UDim2.new(0, 0, 0, 0), bgColor = Theme.Accent, textColor = Theme.BgDeep, radius = 12, gradient = true })
    Signal.Connect(resetPos.MouseButton1Click, function()
        Config.Set("UI.PositionX", nil, false) Config.Set("UI.PositionY", nil, false)
        Config.Set("UI.Minimized", false, false) Config.Save()
        local w = UI.Windows["MK_EDS_Main"]
        if w then
            local win2 = w:GetWindow()
            win2.Position = UDim2.new(0.5, -400, 0.5, -290)
            win2.Size = UDim2.new(0, 800, 0, 580)
            win2.Visible = true
        end
        Notify.Push("Window centered", "accent", 2)
    end)
    UI.SectionHeader(se, "KEYBINDS")
    UI.Text(se, "Click a key field, then press any key to bind it.", { Size = UDim2.new(1, 0, 0, 16), TextColor3 = Theme.TextFaint, TextSize = 10 })
    local kbCard = UI.Card(se)
    local kbList = {
        { name = "ToggleMenu", label = "Open/Close Menu" }, { name = "ToggleHitbox", label = "Toggle Hitbox" },
        { name = "ToggleSilent", label = "Toggle Silent Aim" }, { name = "ToggleESP", label = "Toggle ESP" },
        { name = "ToggleAimbot", label = "Toggle Aimbot" }, { name = "ToggleSpeed", label = "Toggle Speed" },
        { name = "PanicUnload", label = "Panic Unload" },
    }
    for _, kb in ipairs(kbList) do
        local row = UI.Root(kbCard, "Kb" .. kb.name, { Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1 })
        UI.Text(row, kb.label, { Size = UDim2.new(1, -110, 1, 0), TextSize = 12, TextColor3 = Theme.Text })
        local initKey = Config.Get("Keybinds." .. kb.name, "None")
        if kb.name == "ToggleMenu" and (initKey == "None" or initKey == nil) then initKey = "RightShift" end
        local kbBtn = UI.Button(row, initKey, { Size = UDim2.new(0, 100, 1, 0), Position = UDim2.new(1, -100, 0, 0), bgColor = Theme.BgRaised, radius = 12, textSize = 11 })
        Signal.Connect(kbBtn.MouseButton1Click, function()
            kbBtn.Text = "Press key..."
            kbBtn.BackgroundColor3 = Theme.Accent
            kbBtn.TextColor3 = Theme.BgDeep
            Keybind.BeginCapture(kb.name, function(captured)
                kbBtn.Text = captured
                kbBtn.BackgroundColor3 = Theme.BgRaised
                kbBtn.TextColor3 = Theme.Text
                Notify.Push(kb.label .. " → " .. captured, "accent", 1.5)
            end)
            task.delay(6, function()
                if Keybind.Capture and Keybind.Capture.name == kb.name then
                    Keybind.CancelCapture()
                    kbBtn.Text = Config.Get("Keybinds." .. kb.name, "None")
                    kbBtn.BackgroundColor3 = Theme.BgRaised
                    kbBtn.TextColor3 = Theme.Text
                end
            end)
        end)
    end
    local function toggleMenu()
        local w = UI.Windows["MK_EDS_Main"]
        if w then local win = w:GetWindow() win.Visible = not win.Visible end
    end
    Keybind.Register("ToggleMenu", Config.Get("Keybinds.ToggleMenu", "RightShift"), toggleMenu)
    Keybind.Register("ToggleHitbox", Config.Get("Keybinds.ToggleHitbox", "None"), function() if Hitbox.Enabled then Hitbox.Stop() else Hitbox.Start() end end)
    Keybind.Register("ToggleSilent", Config.Get("Keybinds.ToggleSilent", "None"), function() if Hitbox.SilentAim.Enabled then Hitbox.SilentStop() else Hitbox.SilentStart() end end)
    Keybind.Register("ToggleESP", Config.Get("Keybinds.ToggleESP", "None"), function() if ESP.Enabled then ESP.Stop() else ESP.Start() end end)
    Keybind.Register("ToggleAimbot", Config.Get("Keybinds.ToggleAimbot", "None"), function() if Aimbot.Enabled then Aimbot.Stop() else Aimbot.Start() end end)
    Keybind.Register("ToggleSpeed", Config.Get("Keybinds.ToggleSpeed", "None"), function() Movement.SetSpeedEnabled(not Movement.SpeedEnabled) end)
    Keybind.Register("PanicUnload", Config.Get("Keybinds.PanicUnload", "None"), function() Main.Unload() end)
    UI.SectionHeader(se, "DANGER ZONE")
    local unloadBtn = UI.Button(se, "Unload Suite", { Size = UDim2.new(0, 220, 0, 38), bgColor = Theme.Error, radius = 12, gradient = true })
    Signal.Connect(unloadBtn.MouseButton1Click, function() task.spawn(function() Main.Unload() end) end)
    UI.Text(se, "MK v" .. BOOT.Version .. " | " .. BOOT.Build, { Size = UDim2.new(1, 0, 0, 20), TextColor3 = Theme.TextFaint, TextSize = 10 })
end

function Main.Unload()
    Logger.Info("MAIN", "Teardown")
    pcall(Hitbox.Stop) pcall(Hitbox.SilentStop) pcall(ESP.Stop) pcall(Movement.Stop) pcall(Aimbot.Stop)
    pcall(function() if Combat._conn then Combat._conn:Disconnect() end end)
    if Movement._noclipConn then pcall(function() Movement._noclipConn:Disconnect() end) end
    Notify.Clear()
    for _, tw in ipairs(UI.ActiveTweens) do pcall(function() tw:Cancel() end) end
    UI.ActiveTweens = {}
    Signal.DisconnectAll()
    pcall(function() UI.Screen:Destroy() end)
    UI.Windows = {}
    GENV.__MK_EDS = nil
end

Signal.Connect(UserInputService.InputBegan, function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.F7 then Main.Unload()
    elseif input.KeyCode == Enum.KeyCode.F8 then
        Notify.Clear() Notify.Push("Cleared", "info", 1)
    elseif input.KeyCode == Enum.KeyCode.RightControl then
        local w = UI.Windows["MK_EDS_Main"]
        if w then local win = w:GetWindow() win.Visible = not win.Visible end
    elseif input.KeyCode == Enum.KeyCode.Zero and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        Config.Set("UI.PositionX", nil, false) Config.Set("UI.PositionY", nil, false)
        Config.Set("UI.Minimized", false, false) Config.Save()
        local w = UI.Windows["MK_EDS_Main"]
        if w then
            local win = w:GetWindow()
            win.Position = UDim2.new(0.5, -400, 0.5, -290)
            win.Size = UDim2.new(0, 800, 0, 580)
            win.Visible = true
        end
    end
end)

Telemetry.Start()
Main.Build()
if Config.Get("Hitbox.Enabled") == true then Hitbox.Start() end
if Config.Get("SilentAim.Enabled") == true then Hitbox.SilentStart() end
if Config.Get("ESP.Enabled") == true then ESP.Start() end
if Config.Get("Aimbot.Enabled") == true then Aimbot.Start() end
if Config.Get("Combat.AutoAttack") == true then Combat.Start() end
if Config.Get("Movement.SpeedEnabled") == true or Config.Get("Movement.JumpEnabled") == true then Movement.Start() end
if Config.Get("Movement.NoClip") == true then Movement.SetNoClip(true) end

Notify.Push("MK_EDS v" .. BOOT.Version .. " ready", "accent", 4)
Notify.Push("RightShift = menu", "info", 5)
Logger.Info("MAIN", "Boot complete")

GENV.__MK_EDS = {
    Version = BOOT.Version, Logger = Logger, Config = Config,
    UI = UI, Notify = Notify, Keybind = Keybind, Util = Util, Theme = Theme,
    Hitbox = Hitbox, ESP = ESP, Movement = Movement, Aimbot = Aimbot, Combat = Combat,
    Telemetry = Telemetry, PlayerList = PlayerList,
    Unload = Main.Unload,
}