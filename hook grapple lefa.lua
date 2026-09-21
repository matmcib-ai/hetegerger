local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS           = game:GetService("UserInputService")

local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

local getRemote
do
    local RS  = game:GetService("ReplicatedStorage")
    local RUN = game:GetService("RunService")

    local _netFolder
    local function _netDir()
        if _netFolder then return _netFolder end
        local pk = RS:FindFirstChild("Packages") or RS:WaitForChild("Packages", 10)
        if not pk then return nil end
        _netFolder = pk:FindFirstChild("Net") or pk:WaitForChild("Net", 10)
        return _netFolder
    end
    local _net
    local function _getNet()
        if _net then return _net end
        local dir = _netDir()
        if not dir then return nil end
        local ok, m = pcall(require, dir)
        if ok and type(m) == "table" then _net = m end
        return _net
    end
    local _queue, _hooked, _original = {}, false, nil
    local function _host()
        for _, sig in ipairs({ RUN.Heartbeat, RUN.RenderStepped, RUN.PostSimulation }) do
            local ok, conns = pcall(getconnections, sig)
            if ok then
                for _, c in ipairs(conns) do
                    local f = c.Function
                    if f and f ~= _G.__lefaSyncHost and islclosure(f) and not isexecutorclosure(f) then
                        local s = select(2, pcall(debug.info, f, "s"))
                        if type(s) == "string" and s:find("^ReplicatedStorage%.") and not s:find("ReplicatedFirst") then
                            return f
                        end
                    end
                end
            end
        end
    end
    local function _install()
        if _hooked then return true end
        if not _getNet() then return false end
        local h = _host()
        if not h then return false end
        _G.__lefaNetHost = h
        local w = function(...)
            local job = table.remove(_queue, 1)
            if job then
                local ok, r = pcall(_net[job.kind], _net, job.name)
                job.result = (ok and typeof(r) == "Instance") and r or nil
                job.done = true
            end
            return _original(...)
        end
        local ok, env = pcall(getfenv, h)
        if ok and type(env) == "table" then pcall(setfenv, w, env) end
        _original = hookfunction(h, w)
        _hooked = true
        return true
    end
    local _cache = {}
    local function _get(name, kind)
        kind = (kind == "RemoteFunction" and "RemoteFunction")
            or (kind == "UnreliableRemoteEvent" and "UnreliableRemoteEvent")
            or "RemoteEvent"
        if type(name) ~= "string" or name == "" then return nil end
        local logical = name:match("^R[EF]/(.+)$") or name:match("^URE/(.+)$") or name
        local ck = kind .. "|" .. logical
        local hit = _cache[ck]
        if hit and hit.Parent then return hit end
        _cache[ck] = nil
        if not _getNet() then return nil end
        if not _install() then return nil end
        local job = { kind = kind, name = logical }
        table.insert(_queue, job)
        local t = os.clock() + (tonumber(_G.LefaNetTimeout) or 5)
        while not job.done and os.clock() < t do RUN.Heartbeat:Wait() end
        if job.result and job.result.Parent then
            _cache[ck] = job.result
            return job.result
        end
        return nil
    end
    _G.__lefaGetRemote = _G.__lefaGetRemote or function(method, name) return _get(name, method) end
    getRemote = function(method, name) return _get(name, method) end
end

local GRAPPLE_ARG = 0.8
local _grappleUseItem, _grappleItemUse

task.spawn(function() _grappleUseItem = getRemote("RemoteEvent", "UseItem") end)
task.spawn(function() _grappleItemUse = getRemote("RemoteEvent", "75c9466d-e4c0-4b02-b26a-c3615fcc1e42") end)

local function _fireGrapple()
    local fired = false
    if not (_grappleUseItem and _grappleUseItem.Parent) then
        _grappleUseItem = getRemote("RemoteEvent", "UseItem")
    end
    if not (_grappleItemUse and _grappleItemUse.Parent) then
        _grappleItemUse = getRemote("RemoteEvent", "75c9466d-e4c0-4b02-b26a-c3615fcc1e42")
    end
    if _grappleUseItem and _grappleUseItem.Parent then
        pcall(function() _grappleUseItem:FireServer(GRAPPLE_ARG) end); fired = true
    end
    if _grappleItemUse and _grappleItemUse.Parent then
        pcall(function() _grappleItemUse:FireServer(GRAPPLE_ARG) end); fired = true
    end
    if not fired then
        local r = getRemote("RemoteEvent", "UseItem")
        if r then pcall(function() r:FireServer(GRAPPLE_ARG) end); fired = true end
    end
    return fired
end

local function fireGrapple()
    local char = LP.Character
    if not char then return false end
    if not char:FindFirstChild("Grapple Hook") then
        local bp = LP:FindFirstChild("Backpack")
        local tool = bp and bp:FindFirstChild("Grapple Hook")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if tool and hum then pcall(function() hum:EquipTool(tool) end) end
    end
    if not char:FindFirstChild("Grapple Hook") then return false end
    return _fireGrapple()
end
_G.LefaFireGrapple = _G.LefaFireGrapple or fireGrapple

local UIC = {
    bg    = Color3.fromRGB(12, 14, 16),
    card  = Color3.fromRGB(24, 28, 32),
    track = Color3.fromRGB(36, 42, 48),
    line  = Color3.fromRGB(54, 64, 72),
    acc   = Color3.fromRGB(0, 200, 140),
    acc2  = Color3.fromRGB(96, 240, 190),
    warn  = Color3.fromRGB(230, 90, 90),
    dim   = Color3.fromRGB(128, 142, 148),
}
local UIF, UIFB = Enum.Font.Gotham, Enum.Font.GothamBold
local EASE = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function mk(class, parent, props)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do o[k] = v end
    o.Parent = parent
    return o
end
local function corner(o, r) mk("UICorner", o, { CornerRadius = UDim.new(0, r or 8) }) return o end
local function stroke(o, col) mk("UIStroke", o, { Color = col or UIC.line, Thickness = 1 }) return o end
local function tween(o, props) TweenService:Create(o, EASE, props):Play() end

local GUIHOST = (gethui and gethui()) or game:GetService("CoreGui")

for _, par in ipairs({ GUIHOST, PG }) do
    pcall(function()
        local old = par:FindFirstChild("LefaHookNetGUI")
        if old then old:Destroy() end
    end)
end

local sg = mk("ScreenGui", nil, {
    Name = "LefaHookNetGUI", ResetOnSpawn = false, IgnoreGuiInset = true,
    DisplayOrder = 999997, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
pcall(function() sg.Parent = GUIHOST end)
if not sg.Parent then pcall(function() sg.Parent = PG end) end

local panel = corner(mk("Frame", sg, {
    Name = "Panel", AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.fromOffset(220, 118),
    BackgroundColor3 = UIC.bg, BorderSizePixel = 0,
}), 12)
stroke(panel, UIC.line)
mk("UIGradient", panel, { Rotation = 90, Color = ColorSequence.new(UIC.card, UIC.bg) })

local titleBar = mk("Frame", panel, {
    Name = "TitleBar", Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1,
})
mk("TextLabel", titleBar, {
    Size = UDim2.new(1, -30, 1, 0), Position = UDim2.fromOffset(12, 0),
    BackgroundTransparency = 1, Text = "HOOK NET  —  @Lefa", Font = UIFB, TextSize = 13,
    TextColor3 = UIC.acc, TextXAlignment = Enum.TextXAlignment.Left,
})

local statusLbl = mk("TextLabel", panel, {
    Name = "Status", Size = UDim2.new(1, -24, 0, 16), Position = UDim2.fromOffset(12, 28),
    BackgroundTransparency = 1, Text = "checking tool...", Font = UIF, TextSize = 11,
    TextColor3 = UIC.dim, TextXAlignment = Enum.TextXAlignment.Left,
})

local btn = corner(mk("TextButton", panel, {
    Name = "FireBtn", Position = UDim2.fromOffset(12, 52), Size = UDim2.new(1, -24, 0, 46),
    BackgroundColor3 = UIC.acc, BorderSizePixel = 0, AutoButtonColor = false,
    Text = "ACTIVATE HOOK", Font = UIFB, TextSize = 15, TextColor3 = Color3.new(0, 0, 0),
}), 10)
stroke(btn, UIC.acc2)

do
    local dragging, dragStart, startPos = false, nil, nil
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = panel.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            panel.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

local function findGrappleTool()
    local char = LP.Character
    local bp = LP:FindFirstChild("Backpack")
    local equipped = char and char:FindFirstChild("Grapple Hook")
    local inBackpack = bp and bp:FindFirstChild("Grapple Hook")
    return equipped, inBackpack
end

task.spawn(function()
    while sg.Parent do
        local equipped, inBackpack = findGrappleTool()
        if equipped then
            statusLbl.Text = "tool: equipped"
            statusLbl.TextColor3 = UIC.acc2
        elseif inBackpack then
            statusLbl.Text = "tool: in backpack"
            statusLbl.TextColor3 = UIC.dim
        else
            statusLbl.Text = "tool: not found"
            statusLbl.TextColor3 = UIC.warn
        end
        task.wait(0.4)
    end
end)

local firing = false
btn.MouseButton1Click:Connect(function()
    if firing then return end
    firing = true

    btn.Text = "ACTIVATING..."
    tween(btn, { BackgroundColor3 = UIC.track })

    local ok, fired = pcall(fireGrapple)

    if ok and fired then
        btn.Text = "ACTIVATED ✓"
        tween(btn, { BackgroundColor3 = UIC.acc2 })
    elseif ok and not fired then
        btn.Text = "TOOL NOT FOUND"
        tween(btn, { BackgroundColor3 = UIC.warn })
    else
        btn.Text = "ERROR"
        tween(btn, { BackgroundColor3 = UIC.warn })
    end

    task.wait(0.7)
    btn.Text = "ACTIVATE HOOK"
    tween(btn, { BackgroundColor3 = UIC.acc })
    firing = false
end)

btn.MouseEnter:Connect(function()
    if not firing then tween(btn, { BackgroundColor3 = UIC.acc2 }) end
end)
btn.MouseLeave:Connect(function()
    if not firing then tween(btn, { BackgroundColor3 = UIC.acc }) end
end)
