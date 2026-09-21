task.wait(3)

local Players         = game:GetService("Players")
local RunService      = game:GetService("RunService")
local UIS             = game:GetService("UserInputService")
local RS              = game:GetService("ReplicatedStorage")
local Lighting        = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local LP              = Players.LocalPlayer

do
    local t0 = os.clock()
    while type(_G.MeerkoBootWait) ~= "function" and os.clock() - t0 < 20 do task.wait(0.1) end
end
if type(_G.MeerkoBootWait)      ~= "function" then _G.MeerkoBootWait = function() end end
if type(_G.MeerkoCarpetEngaging) ~= "function" then _G.MeerkoCarpetEngaging = function() return false end end
if type(_G.MeerkoSaveSettings)   ~= "function" then _G.MeerkoSaveSettings = function() end end

local function equipCarpet() if _G.MeerkoEquipCarpet then return _G.MeerkoEquipCarpet() end end
local function scanAllPets() if _G.MeerkoScanAllPets then return _G.MeerkoScanAllPets() end return {} end

if _G.MeerkoAntiFlash        == nil then _G.MeerkoAntiFlash        = true end
if _G.MeerkoAntiBee          == nil then _G.MeerkoAntiBee          = true end
if _G.MeerkoInfJump          == nil then _G.MeerkoInfJump          = true end
if _G.MeerkoInvisDepth       == nil then _G.MeerkoInvisDepth       = 4.2  end
if _G.MeerkoInvisAngle       == nil then _G.MeerkoInvisAngle       = 180  end
if _G.MeerkoAlertMinGen      == nil then _G.MeerkoAlertMinGen      = 80e6 end
if _G.MeerkoCarpetSpeedValue == nil then _G.MeerkoCarpetSpeedValue = 140  end
if _G.MeerkoFOVEnabled       == nil then _G.MeerkoFOVEnabled       = false end

-- FOV enforcement: fully independent of every other feature toggle (it was
-- previously piggybacking on the Anti Bee heartbeat loop, so if that was
-- off, the custom FOV never applied at all and the camera just sat at the
-- game's own default -- which happened to be 70, giving the impression it
-- was "resetting" when really it just never got set in the first place).
task.spawn(function()
    while true do
        if _G.MeerkoFOVEnabled then
            local cam = workspace.CurrentCamera
            local target = tonumber(_G.MeerkoFOV) or 70
            if cam and math.abs(cam.FieldOfView - target) > 0.1 then
                cam.FieldOfView = target
            end
        end
        task.wait(0.2)
    end
end)

;(function()
    local FX = { ParticleEmitter = true, Beam = true, Trail = true, Fire = true,
        Smoke = true, Sparkles = true, Explosion = true, PointLight = true,
        SpotLight = true, SurfaceLight = true }

    local function kill(item)
        if pcall(function() item:Destroy() end) then return end
        pcall(function()
            for _, d in ipairs(item:GetDescendants()) do
                if d:IsA("BasePart") then
                    d.Transparency = 1
                    d.CanCollide = false
                    d.CanQuery = false
                    d.CastShadow = false
                    d.LocalTransparencyModifier = 1
                elseif FX[d.ClassName] then
                    d.Enabled = false
                elseif d:IsA("Sound") then
                    d.Volume = 0
                    d:Stop()
                end
            end
        end)
    end

    local function strip(char)
        if not char or _G.MeerkoAntiFlash == false then return end
        for _, item in ipairs(char:GetChildren()) do
            if item:IsA("Accessory") then kill(item) end
        end
    end

    local hooked = setmetatable({}, { __mode = "k" })
    local function hookChar(char)
        if not char or hooked[char] then return end
        hooked[char] = true
        strip(char)
        char.ChildAdded:Connect(function(c)
            if c:IsA("Accessory") and _G.MeerkoAntiFlash ~= false then
                task.defer(kill, c)
            end
        end)
    end
    local function hookPlayer(p)
        if p.Character then task.spawn(hookChar, p.Character) end
        p.CharacterAdded:Connect(hookChar)
    end
    for _, p in ipairs(Players:GetPlayers()) do pcall(hookPlayer, p) end
    Players.PlayerAdded:Connect(hookPlayer)

    workspace.DescendantAdded:Connect(function(d)
        if _G.MeerkoAntiFlash == false then return end
        if d.ClassName == "Accessory" then
            local par = d.Parent
            if par and par:FindFirstChildOfClass("Humanoid") then task.defer(kill, d) end
        end
    end)

    task.spawn(function()
        while true do
            if _G.MeerkoAntiFlash ~= false then
                for _, p in ipairs(Players:GetPlayers()) do
                    if p.Character then strip(p.Character) end
                end
                for _, m in ipairs(workspace:GetChildren()) do
                    if m:IsA("Model") and m:FindFirstChildOfClass("Humanoid") then strip(m) end
                end
            end
            task.wait(6) 
        end
    end)
end)()

;(function()
    local TeleportService = game:GetService("TeleportService")
    if _G.MeerkoCleanErrStop then pcall(_G.MeerkoCleanErrStop) end

    local _ref = cloneref or function(x) return x end
    local GS = _ref(game:GetService("GuiService"))
    local running, conns = true, {}

    task.spawn(function()
        while running do
            pcall(function() GS:ClearError() end)
            task.wait(0.1)
        end
    end)

    conns[#conns + 1] = TeleportService.TeleportInitFailed:Connect(function(plr, result, message, placeId)
        if plr ~= LP then return end
        local name = "Unknown"
        pcall(function() name = result and result.Name or tostring(result) end)
        _G.MeerkoCleanErrLast = {
            result = name, message = tostring(message or ""),
            placeId = placeId, at = os.clock(),
        }
    end)

    _G.MeerkoCleanErrStop = function()
        running = false
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        conns = {}
        _G.MeerkoCleanErrStop = nil
    end
end)()

;(function()
    local held = false
    local function hop()
        local c = LP.Character
        local hrp = c and c:FindFirstChild("HumanoidRootPart")
        local hum = c and c:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum or hum.Health <= 0 then return end
        hrp.Velocity = Vector3.new(hrp.Velocity.X, hum.JumpPower or 50, hrp.Velocity.Z)
    end
    local function on() return _G.MeerkoInfJump ~= false end
    UIS.JumpRequest:Connect(function() if on() then hop() end end)
    UIS.InputBegan:Connect(function(i, g)
        if not g and i.KeyCode == Enum.KeyCode.Space then held = true end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.KeyCode == Enum.KeyCode.Space then held = false end
    end)
    RunService.Heartbeat:Connect(function() if held and on() then hop() end end)
end)()




if _G.AntiDieDisabled == nil then _G.AntiDieDisabled = false end
task.spawn(function()
local __P = game:GetService("Players")
while not __P.LocalPlayer do task.wait() end
local okAD, errAD = pcall(function()
    local Players    = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local LP         = Players.LocalPlayer

    local _conn, _diedConn, _hbConn
    local function _harden(hum)
        pcall(function() hum.BreakJointsOnDeath = false end)
        pcall(function() hum.RequiresNeck = false end)
        pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false) end)
        pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false) end)
        pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false) end)
        pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Physics, false) end)
    end
    local function _revive(hum)
        pcall(function() hum.Health = hum.MaxHealth end)
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end)
    end
    local function _bind()
        local char = LP.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        _harden(hum)
        if _conn then pcall(function() _conn:Disconnect() end) end
        if _diedConn then pcall(function() _diedConn:Disconnect() end) end
        if _hbConn then pcall(function() _hbConn:Disconnect() end) end
        _conn = hum:GetPropertyChangedSignal("Health"):Connect(function()
            if _G.AntiDieDisabled then return end
            if hum.Health <= 0 then _revive(hum) end
        end)
        _diedConn = hum.Died:Connect(function()
            if _G.AntiDieDisabled then return end
            _revive(hum)
        end)
        local _lastHarden = 0
        _hbConn = RunService.Heartbeat:Connect(function()
            if _G.AntiDieDisabled or not hum or not hum.Parent then return end
            local now = os.clock()
            if now - _lastHarden >= 0.5 then _lastHarden = now; _harden(hum) end
            if hum.Health <= 0 then _revive(hum) end
            
            if _G.MeerkoStealHold and hum.Health < hum.MaxHealth then
                pcall(function() hum.Health = hum.MaxHealth end)
            end
            local char = hum.Parent
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if char and hrp then
                local state = hum:GetState()
                local _rag = (state == Enum.HumanoidStateType.Physics
                    or state == Enum.HumanoidStateType.Ragdoll
                    or state == Enum.HumanoidStateType.FallingDown)
                if not _rag then
                    local _et = tonumber(LP:GetAttribute("RagdollEndTime"))
                    if _et and (_et - workspace:GetServerTimeNow()) > 0 then _rag = true end
                end
                if _rag then
                    pcall(function() LP:SetAttribute("RagdollEndTime", workspace:GetServerTimeNow()) end)
                    pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end)
                    if not _G.__meerkoResetBusy and LP:GetAttribute("Stealing") ~= true then
                        pcall(function() hrp.AssemblyLinearVelocity = Vector3.zero end)
                    end
                    local cam = workspace.CurrentCamera
                    if cam and cam.CameraSubject ~= hum then
                        pcall(function() cam.CameraSubject = hum end)
                    end
                    for _, obj in ipairs(char:GetDescendants()) do
                        if obj:IsA("BallSocketConstraint") or (obj.Name and obj.Name:find("RagdollAttachment")) then
                            pcall(function() obj:Destroy() end)
                        end
                    end
                end
            end
            if hum:GetState() == Enum.HumanoidStateType.Dead then
                pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end)
            end
        end)
    end
    _bind()
    LP.CharacterAdded:Connect(function(char)
        local hum = char:WaitForChild("Humanoid", 5)
        if hum then _harden(hum) end
        task.wait(0.1)
        _bind()
    end)
end)
if not okAD then warn("[ANTI-DIE] BLOC EN ERREUR: " .. tostring(errAD)) end
end)

;(function()
    local Lighting = game:GetService("Lighting")
    local BAD = { Blue = true, DiscoEffect = true, BeeBlur = true,
        Flashbang = true, ColorCorrection = true }
    local function on() return _G.MeerkoAntiBee ~= false end

    local function nuke(o)
        if on() and o and o.Parent and BAD[o.Name] then pcall(function() o:Destroy() end) end
    end

    local buzz
    local function muteBuzz()
        if not on() then return end
        pcall(function()
            if not (buzz and buzz.Parent) then
                local ctl = RS:FindFirstChild("Controllers")
                local item = ctl and ctl:FindFirstChild("ItemController")
                local bee = item and item:FindFirstChild("BeeLauncherController")
                local s = bee and bee:FindFirstChild("Buzzing")
                if s and s:IsA("Sound") then buzz = s end
            end
            if buzz then
                buzz.Volume = 0
                if buzz.IsPlaying then buzz:Stop() end
            end
        end)
    end

    local guarded = {}
    local function guard(Controls, original)
        if not Controls or guarded[Controls] then return end
        local base = original or Controls.moveFunction
        if not base then return end
        local function safeMove(self, mv, rtc) return base(self, mv, rtc) end
        guarded[Controls] = safeMove
        Controls.moveFunction = safeMove
        RunService.Heartbeat:Connect(function()
            if not on() then return end
            if Controls.moveFunction ~= safeMove then Controls.moveFunction = safeMove end
        end)
    end
    local function protect()
        pcall(function()
            local cc = RS:FindFirstChild("Controllers")
            local mod = cc and cc:FindFirstChild("CharacterController")
            local m = mod and require(mod)
            if type(m) == "table" then guard(m.Controls, m.originalMoveFunction) end
        end)
        pcall(function()
            local ps = LP:WaitForChild("PlayerScripts", 5)
            local pm = ps and ps:FindFirstChild("PlayerModule")
            if pm then guard(require(pm):GetControls()) end
        end)
    end

    task.spawn(function()
        LP:WaitForChild("PlayerScripts", 8)
        _G.MeerkoBootWait()
        Lighting.DescendantAdded:Connect(nuke)
        do local n = 0
            for _, o in ipairs(Lighting:GetDescendants()) do
                n = n + 1; if n % 150 == 0 then task.wait() end
                nuke(o)
            end
        end
        protect()
        local acc = 1
        RunService.Heartbeat:Connect(function(dt)
            if not on() then return end
            local cam = workspace.CurrentCamera
            if cam and math.abs(cam.FieldOfView - 20) < 0.01 then
                cam.FieldOfView = tonumber(_G.MeerkoFOV) or 70
            end
            acc = acc + dt
            if acc < 0.5 then return end
            acc = 0
            muteBuzz()
            
        end)
    end)
    LP.CharacterAdded:Connect(function() task.delay(1, protect) end)
end)()

;(function()
    local active, conns = false, {}
    local realHRP, cloneHRP, track, hip, origT
    local stuck, restarting = false, false
    local start, stop

    local function depth()
        return 0.01 + (math.clamp(tonumber(_G.MeerkoInvisDepth) or 4.2, 0, 10) / 10) * 0.19
    end
    local function angle()
        return math.clamp(tonumber(_G.MeerkoInvisAngle) or 0, 0, 360)
    end
    local function add(c) conns[#conns + 1] = c end
    local function rewire(char, from, to)
        for _, v in ipairs(char:GetDescendants()) do
            if v:IsA("Weld") or v:IsA("Motor6D") then
                if v.Part0 == from then v.Part0 = to end
                if v.Part1 == from then v.Part1 = to end
            end
        end
    end

    stop = function()
        active, stuck = false, false
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        conns = {}
        if origT then
            for p, v in pairs(origT) do
                if p and p.Parent then pcall(function() p.LocalTransparencyModifier = v end) end
            end
            origT = nil
        end
        if track then
            pcall(function() track:AdjustSpeed(1) track:Stop(0) track:Destroy() end)
            track = nil
        end
        local char = LP.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if realHRP and realHRP:IsDescendantOf(game) and hum then
            local tmp = Instance.new("Model")
            tmp.Parent = game
            char.Parent = tmp
            realHRP.Parent = char
            char.PrimaryPart = realHRP
            char.Parent = workspace
            realHRP.CanCollide = true
            rewire(char, cloneHRP, realHRP)
            if cloneHRP then
                local at = cloneHRP.CFrame
                cloneHRP:Destroy()
                cloneHRP = nil
                realHRP.CFrame = at
            end
            hum.HipHeight = hip or 0
            tmp:Destroy()
        end
        realHRP, cloneHRP = nil, nil
        _G.MeerkoInvisActive = false
    end

    local function animTrick(char, hum)
        if not (char and hum and hum.Health > 0) then return end
        local a = Instance.new("Animation")
        a.AnimationId = "http://www.roblox.com/asset/?id=18537363391"
        local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
        track = animator:LoadAnimation(a)
        track.Priority = Enum.AnimationPriority.Action4
        track.Looped = true
        track:Play(0, 1, 0)
        a:Destroy()
        add(track.Stopped:Connect(function()
            if active then animTrick(char, hum) end
        end))
        task.defer(function()
            if not track then return end
            track.TimePosition = 0.7
            task.delay(0.1, function() if track then track:AdjustSpeed(math.huge) end end)
        end)
    end

    start = function()
        local char = LP.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hum or active then return false end

        local folder = workspace:FindFirstChild(LP.Name)
        if folder then
            for _, n in ipairs({ "DoubleRig", "Constraints" }) do
                local x = folder:FindFirstChild(n)
                if x then x:Destroy() end
            end
            add(folder.ChildAdded:Connect(function(c)
                if c.Name == "DoubleRig" or c.Name == "Constraints" then c:Destroy() end
            end))
        end
        for _, s in ipairs({ "Dead", "FallingDown", "Ragdoll" }) do
            hum:SetStateEnabled(Enum.HumanoidStateType[s], false)
        end

        hip = hum.HipHeight
        realHRP = char:FindFirstChild("HumanoidRootPart")
        if not (realHRP and realHRP.Parent) then return false end

        local tmp = Instance.new("Model")
        tmp.Parent = game
        char.Parent = tmp
        cloneHRP = realHRP:Clone()
        cloneHRP.Parent = char
        realHRP.Parent = workspace.CurrentCamera
        cloneHRP.CFrame = realHRP.CFrame
        char.PrimaryPart = cloneHRP
        char.Parent = workspace
        rewire(char, realHRP, cloneHRP)
        tmp:Destroy()

        active = true
        animTrick(char, hum)

        origT = {}
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then
                origT[p] = p.LocalTransparencyModifier
                p.LocalTransparencyModifier = 1
            end
        end
        add(char.DescendantAdded:Connect(function(d)
            if not (active and d:IsA("BasePart")) then return end
            if origT and origT[d] == nil then origT[d] = d.LocalTransparencyModifier end
            pcall(function() d.LocalTransparencyModifier = 1 end)
        end))

        add(RunService.Heartbeat:Connect(function()
            if not active or not hum.Parent then return end
            hum.Health = hum.MaxHealth
            hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
            local st = hum:GetState()
            if st == Enum.HumanoidStateType.Dead or st == Enum.HumanoidStateType.FallingDown
                or st == Enum.HumanoidStateType.Ragdoll then
                hum:ChangeState(Enum.HumanoidStateType.Running)
            end
        end))

        -- Keep the hidden root perfectly aligned with the visible character.
        -- Do not rotate it upside-down or apply a vertical offset: those were
        -- the main causes of the "head hitting the ground" / abnormal movement.
        add(RunService.PreSimulation:Connect(function()
            if not (active and realHRP and realHRP.Parent and hum.Parent and hum.Health > 0) then
                return
            end

            local base = char.PrimaryPart or char:FindFirstChild("HumanoidRootPart")
            if not (base and base:IsA("BasePart")) then return end

            -- Keep the real/hidden root slightly below the visible body,
            -- matching the original pet-on-ground placement, but do NOT
            -- rotate the character upside-down.
            local groundOffset = hum.HipHeight + (base.Size.Y / 2) - 1 + depth()
            local cf = base.CFrame - Vector3.new(0, groundOffset, 0)
            realHRP.CFrame = cf * CFrame.Angles(math.rad(angle()), 0, 0)
            realHRP.AssemblyLinearVelocity = base.AssemblyLinearVelocity
            realHRP.AssemblyAngularVelocity = base.AssemblyAngularVelocity
            realHRP.CanCollide = false

            if realHRP.Parent ~= workspace.CurrentCamera then
                realHRP.Parent = workspace.CurrentCamera
            end
        end))

        add(LP.CharacterAdded:Connect(function() if active then stop() end end))
        _G.MeerkoInvisActive = true
        return true
    end

    _G.MeerkoInvisStart, _G.MeerkoInvisStop = start, stop
    _G.MeerkoInvisToggle = function()
        if active then stop() else start() end
    end

    local armed, autoOn = false, false
    local function syncAuto()
        local want = (_G.MeerkoInvisAuto == true) and (LP:GetAttribute("Stealing") == true)
        if not want then
            armed = false
            if active and autoOn then autoOn = false pcall(stop) end
            return
        end
        if active or armed then return end
        armed = true
        task.delay(tonumber(_G.MeerkoInvisAutoDelay) or 1.5, function()
            armed = false
            if _G.MeerkoInvisAuto == true and not active
                and LP:GetAttribute("Stealing") == true then
                autoOn = true
                pcall(start)
            end
        end)
    end
    _G.MeerkoInvisSync = syncAuto
    LP:GetAttributeChangedSignal("Stealing"):Connect(syncAuto)
end)()

;(function()
    local function strip()
        local c = LP.Character
        local h = c and c:FindFirstChild("HumanoidRootPart")
        if not h or not getconnections or not getinfo then return end
        for _, s in ipairs({ "CFrame", "Position" }) do
            pcall(function()
                for _, cn in ipairs(getconnections(h:GetPropertyChangedSignal(s))) do
                    if cn.Function and cn.Enabled then
                        local ok, info = pcall(getinfo, cn.Function)
                        if ok and info and tostring(info.source) == "=ReplicatedFirst.test" then
                            pcall(function() cn:Disable() end)
                        end
                    end
                end
            end)
        end
    end
    _G.MeerkoStripAC = strip
    task.spawn(function() _G.MeerkoBootWait() while true do pcall(strip) task.wait(3) end end) 
    LP.CharacterAdded:Connect(function() task.wait(0.3) pcall(strip) end)
end)()

;(function()
    local wsConn

    _G.MeerkoSetWalkSpeed = function(enabled)
        _G.MeerkoWalkSpeedOn = enabled == true
        if wsConn then pcall(function() wsConn:Disconnect() end) wsConn = nil end
        if not _G.MeerkoWalkSpeedOn then return end

        wsConn = RunService.Heartbeat:Connect(function(dt)
            if not _G.MeerkoWalkSpeedOn then return end
            pcall(function()
                if LP:GetAttribute("Stealing") ~= true then return end

                local char = LP.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if not char or not hum or hum.Health <= 0 then return end

                -- Invisible creates a visible clone as Character.PrimaryPart while
                -- the real HumanoidRootPart is temporarily moved to the camera.
                -- Always move the active body root, never a stale HRP reference.
                local root = char.PrimaryPart or char:FindFirstChild("HumanoidRootPart")
                if not root or not root:IsA("BasePart") or not root.Parent then return end

                local move = hum.MoveDirection
                if move.Magnitude <= 0.001 then return end

                local speed = math.clamp(tonumber(_G.MeerkoWalkSpeed) or 29, 5, 32)
                local current = math.max(tonumber(hum.WalkSpeed) or 0, 0)
                local extra = math.max(speed - current, 0)
                if extra <= 0 then return end

                local step = math.min(tonumber(dt) or 0.016, 0.05)
                local delta = move.Unit * extra * step
                root.CFrame = root.CFrame + delta

                -- Keep the real root at the same position during Invisible so
                -- carried pets/items do not remain at the old position.
                if _G.MeerkoInvisActive == true then
                    local real = char:FindFirstChild("HumanoidRootPart")
                    if real and real ~= root and real:IsA("BasePart") and real.Parent then
                        real.CFrame = root.CFrame
                        real.AssemblyLinearVelocity = root.AssemblyLinearVelocity
                    end
                end
            end)
        end)
    end

    if _G.MeerkoWalkSpeedOn == nil then _G.MeerkoWalkSpeedOn = true end
    if _G.MeerkoWalkSpeedOn == true then
        task.defer(function() pcall(_G.MeerkoSetWalkSpeed, true) end)
    end
end)()

;(function()
    local conn
    _G.MeerkoSetCarpetSpeed = function(enabled)
        _G.MeerkoCarpetSpeed = enabled and true or false
        if conn then conn:Disconnect() conn = nil end
        if not _G.MeerkoCarpetSpeed then return end
        task.spawn(function() pcall(equipCarpet) end)
        conn = RunService.Heartbeat:Connect(function()
            if LP:GetAttribute("Stealing") == true then
                _G.MeerkoSetCarpetSpeed(false)
                return
            end
            local c = LP.Character
            local hum = c and c:FindFirstChildOfClass("Humanoid")
            local part = c and (c:FindFirstChild("UpperTorso")
                or c:FindFirstChild("Torso")
                or c:FindFirstChild("HumanoidRootPart"))
            if not hum or not part then return end
            if not _G.MeerkoCarpetEngaging() then pcall(equipCarpet) end
            local spd = math.clamp(tonumber(_G.MeerkoCarpetSpeedValue) or 140, 20, 400)
            local md, keepY = hum.MoveDirection, part.Velocity.Y
            if md.Magnitude > 0 then
                part.Velocity = Vector3.new(md.X * spd, keepY, md.Z * spd)
            else
                part.Velocity = Vector3.new(0, keepY, 0)
            end
        end)
    end

    UIS.InputBegan:Connect(function(i, g)
        if g or i.UserInputType ~= Enum.UserInputType.Keyboard then return end
        if i.KeyCode.Name ~= (_G.MeerkoCarpetSpeedKeyName or "Q") then return end
        if LP:GetAttribute("Stealing") == true then return end
        local on = not (_G.MeerkoCarpetSpeed == true)
        _G.MeerkoSetCarpetSpeed(on)
        if on then task.spawn(function() pcall(equipCarpet) end) end
    end)
end)()

;(function()
    local FOLDERS = { "Base", "PlotSign", "FriendPanel", "Cash", "Laser",
        "Decorations", "Skin", "Unlock", "Purchases" }
    local orig = setmetatable({}, { __mode = "k" })
    local conns, gen = {}, 0

    local function paint(o, a)
        if not o:IsA("BasePart") then return end
        if orig[o] == nil then orig[o] = (o.Transparency == a) and 0 or o.Transparency end
        local base = orig[o]
        if base >= 1 then return end
        local want = base + (1 - base) * a
        if math.abs(o.Transparency - want) > 0.01 then o.Transparency = want end
    end

    local function calm()
        while _G.MeerkoStealHold do task.wait(0.15) end
    end

    local function track(root, a, id)
        if not root or id ~= gen then return end
        paint(root, a)
        local n = 0
        for _, d in ipairs(root:GetDescendants()) do
            if id ~= gen then return end
            paint(d, a)
            n = n + 1
            if n % 250 == 0 then task.wait() end
        end
        conns[#conns + 1] = root.DescendantAdded:Connect(function(d)
            if id == gen then paint(d, a) end
        end)
    end

    local function doPlot(plot, a, id)
        if not plot or id ~= gen then return end
        for _, fname in ipairs(FOLDERS) do
            if id ~= gen then return end
            track(plot:FindFirstChild(fname), a, id)
        end
        if id ~= gen then return end
        conns[#conns + 1] = plot.ChildAdded:Connect(function(c)
            if id ~= gen then return end
            for _, fname in ipairs(FOLDERS) do
                if c.Name == fname then track(c, a, id) break end
            end
        end)
        local pods = plot:FindFirstChild("AnimalPodiums")
        if not pods then return end
        local function pod(pd)
            for _, c in ipairs(pd:GetChildren()) do
                if c.Name == "Claim" then track(c, a, id)
                elseif c.Name == "Base" then track(c:FindFirstChild("Decorations"), a, id) end
            end
        end
        for _, pd in ipairs(pods:GetChildren()) do pod(pd) end
        conns[#conns + 1] = pods.ChildAdded:Connect(function(pd)
            if id ~= gen then return end
            task.wait(0.1)
            if id == gen then pod(pd) end
        end)
    end

    local function stop()
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        conns, gen = {}, gen + 1
    end

    _G.MeerkoEnableXray = function()
        stop()
        local id = gen
        local a = math.clamp(tonumber(_G.MeerkoXrayAlpha) or 0.9, 0, 1)
        task.spawn(function()
            while id == gen and not workspace:FindFirstChild("Plots") do task.wait(0.5) end
            local plots = workspace:FindFirstChild("Plots")
            if id ~= gen or not plots then return end
            calm()
            for _, p in ipairs(plots:GetChildren()) do
                if id ~= gen then return end
                pcall(doPlot, p, a, id)
                task.wait()
                calm()
            end
            conns[#conns + 1] = plots.ChildAdded:Connect(function(p)
                if id ~= gen then return end
                task.wait(0.2)
                pcall(doPlot, p, a, id)
            end)
        end)
    end

    _G.MeerkoDisableXray = function()
        stop()
        local snap = orig
        orig = setmetatable({}, { __mode = "k" })
        for o, t in pairs(snap) do
            pcall(function() if o:IsA("BasePart") then o.Transparency = t end end)
        end
    end

    _G.MeerkoToggleXray = function()
        _G.MeerkoXray = not (_G.MeerkoXray ~= false)
        if _G.MeerkoXray then _G.MeerkoEnableXray() else _G.MeerkoDisableXray() end
        return _G.MeerkoXray
    end

    task.spawn(function()
        _G.MeerkoBootWait()
        task.wait(tonumber(_G.MeerkoXrayDelay) or 1)
        if _G.MeerkoXray ~= false then _G.MeerkoEnableXray() end
    end)
end)()

;(function()
    local function psCode(link)
        link = tostring(link or ""):match("^%s*(.-)%s*$")
        if link == "" then return nil end
        if not link:find("://", 1, true) then return link end
        return link:match("[?&]privateServerLinkCode=([^&]+)")
            or link:match("[?&]linkCode=([^&]+)")
            or link:match("[?&]code=([^&]+)")
    end

    local function kickOut()
        if _G.MeerkoKickToPS == true then
            local code = psCode(_G.MeerkoPrivateServerLink)
            if code and code ~= "" then
                local ok = pcall(function()
                    game:GetService("ExperienceService"):LaunchExperience({
                        placeId = tonumber(_G.MeerkoPrivateServerPlaceId) or game.PlaceId,
                        linkCode = code,
                    })
                end)
                if ok then return end
            end
        end
        if pcall(function() game:Shutdown() end) then return end
        pcall(function() LP:Kick("") end)
    end
    _G.MeerkoKickOut = kickOut

    task.spawn(function()
        local PG2 = LP:FindFirstChildOfClass("PlayerGui") or LP:WaitForChild("PlayerGui", 10)
        if not PG2 then return end
        local hooked = setmetatable({}, { __mode = "k" })
        local function hit(t)
            return type(t) == "string" and t:lower():find("you stole", 1, true) ~= nil
        end
        local function isText(o)
            return o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox")
        end
        local function watch(o)
            if hooked[o] then return end
            hooked[o] = true
            if _G.MeerkoAutoKickOnSteal == true and hit(o.Text) then kickOut() return end
            o:GetPropertyChangedSignal("Text"):Connect(function()
                if _G.MeerkoAutoKickOnSteal == true and hit(o.Text) then kickOut() end
            end)
        end
        local function root(g)
            g.DescendantAdded:Connect(function(d) if isText(d) then watch(d) end end)
            local n = 0
            for _, d in ipairs(g:GetDescendants()) do
                n = n + 1
                if n % 200 == 0 then task.wait() end
                if isText(d) then watch(d) end
            end
        end

        while _G.MeerkoAutoKickOnSteal ~= true do task.wait(1) end
        PG2.ChildAdded:Connect(root)
        for _, g in ipairs(PG2:GetChildren()) do root(g) end
    end)
end)()

;(function()
    local seen, snd, lastAt = {}, nil, 0

    _G.MeerkoAlertCheck = function(pets)
        if _G.MeerkoPriAlert ~= true then
            if next(seen) then seen = {} end
            return
        end
        local minGen = tonumber(_G.MeerkoAlertMinGen) or 80e6
        local live, fresh = {}, false
        for _, p in ipairs(pets) do
            if p._pri or (tonumber(p.mps) or 0) >= minGen then
                local k = tostring(p.plot) .. "_" .. tostring(p.slot)
                live[k] = true
                if not seen[k] then fresh = true end
            end
        end
        seen = live
        if not fresh or os.clock() - lastAt < 3 then return end
        lastAt = os.clock()
        pcall(function()
            local id = tostring(_G.MeerkoAlertSound or "111786441593851"):match("%d+")
            if not id then return end
            if not (snd and snd.Parent) then
                snd = Instance.new("Sound")
                snd.Name = "MeerkoAlert"
                snd.Parent = game:GetService("SoundService")
            end
            snd.SoundId = "rbxassetid://" .. id
            snd.Volume = math.clamp(tonumber(_G.MeerkoAlertVolume) or 1, 0, 10)
            snd:Play()
        end)
    end

    task.spawn(function()
        while true do
            task.wait(0.5)
            if _G.MeerkoPriAlert == true then
                local ok, pets = pcall(scanAllPets)
                if ok and type(pets) == "table" then pcall(_G.MeerkoAlertCheck, pets) end
            end
        end
    end)
end)()



pcall(function() game:GetService("Players").RespawnTime = 0 end)  

do
    local RunService = game:GetService("RunService")
    local Players    = game:GetService("Players")
    local Workspace  = game:GetService("Workspace")
    local _wfConns, _wfActive = {}, false
    local function stopWalkFling()
        _wfActive = false
        for _, c in ipairs(_wfConns) do
            if typeof(c) == "RBXScriptConnection" then pcall(function() c:Disconnect() end) end
        end
        _wfConns = {}
    end
    local function startWalkFling()
        _wfActive = true
        local ch = LP.Character
        if not ch then return end
        local rr = ch:FindFirstChild("HumanoidRootPart")
        for _, o in pairs(Workspace.CurrentCamera:GetChildren()) do
            if o.Name == "HumanoidRootPart" then rr = o break end
        end
        if not rr then return end
        table.insert(_wfConns, RunService.Stepped:Connect(function()
            if not _wfActive then return end
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP and p.Character then
                    for _, pt in ipairs(p.Character:GetChildren()) do
                        if pt:IsA("BasePart") then pt.CanCollide = false end
                    end
                end
            end
        end))
        local co = coroutine.create(function()
            if _G.invisibleStealEnabled then rr.CFrame = rr.CFrame * CFrame.new(0, 3, 0) end
            while _wfActive do
                RunService.Heartbeat:Wait()
                if not rr or not rr.Parent then break end
                local v = rr.Velocity
                rr.Velocity = v * 10000 + Vector3.new(0, 10000, 0)
                RunService.RenderStepped:Wait()
                if rr then rr.Velocity = v end
                RunService.Stepped:Wait()
                if rr then rr.Velocity = v + Vector3.new(0, 0.1, 0) end
            end
        end)
        coroutine.resume(co)
        table.insert(_wfConns, co)
    end
    _G.DropBrainrot = function()
        if _wfActive then return end
        startWalkFling()
        task.delay(0.4, stopWalkFling)
    end
    _G.stopWalkFling = stopWalkFling
end


local CARPET_NAMES = { "Flying Carpet", "Waverider", "Santa's Sleigh", "Witch's Broom", "Cupid's Wings" }
_G.__meerkoResetBusy = false
_G.MeerkoResetCooldown = tonumber(_G.MeerkoResetCooldown) or 2.5
_G.MeerkoResetFlingTime = tonumber(_G.MeerkoResetFlingTime) or 5
_G.MeerkoInstaReset = function()
    local _now = os.clock()
    if _G.__meerkoResetBusy
        and (_now - (tonumber(_G.__meerkoResetAt) or 0)) < (tonumber(_G.MeerkoResetCooldown) or 2.5) then
        return
    end
    _G.__meerkoResetBusy = true
    _G.__meerkoResetAt = _now
    task.spawn(function()
        local RunService = game:GetService("RunService")
        local _prevAntiDie = _G.AntiDieDisabled
        _G.AntiDieDisabled = true
        _G.MeerkoStealHold = false
        local _restored, _holding = false, true
        local function _restore()
            if _restored then return end
            _restored = true
            _holding = false
            _G.AntiDieDisabled = _prevAntiDie
            _G.__meerkoResetBusy = false
        end
        local _conn
        _conn = LP.CharacterAdded:Connect(function(newChar)
            if _conn then _conn:Disconnect(); _conn = nil end
            task.defer(function()
                pcall(function() newChar:WaitForChild("Humanoid", 12) end)
                RunService.Heartbeat:Wait()
                _restore()
            end)
        end)
        task.delay(8, function() if _conn then _conn:Disconnect(); _conn = nil end _restore() end)

        pcall(function()
            local char = LP.Character
            if not char then return end
            local _isCarpet = {}
            for _, n in ipairs(CARPET_NAMES) do _isCarpet[n] = true end
            pcall(equipCarpet)
            local _origChar = char
            task.spawn(function()
                local RS2 = game:GetService("RunService")
                while _holding and LP.Character == _origChar do
                    pcall(equipCarpet)
                    RS2.Heartbeat:Wait()
                end
            end)
            local bp = LP:FindFirstChild("Backpack")
            if bp then
                for _, ch in ipairs(char:GetChildren()) do
                    if ch:IsA("Tool") and not _isCarpet[ch.Name] then pcall(function() ch.Parent = bp end) end
                end
            end
            local function _flingPart()
                local c = LP.Character
                if not c then return nil end
                return c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso")
                    or c:FindFirstChild("HumanoidRootPart")
            end
            local _t0 = os.clock()
            while os.clock() - _t0 < (tonumber(_G.MeerkoResetFlingTime) or 5) do
                if LP.Character ~= _origChar then break end
                local _h = _origChar:FindFirstChildOfClass("Humanoid")
                if not _h or _h.Health <= 0 or _h:GetState() == Enum.HumanoidStateType.Dead then break end
                local part = _flingPart()
                if not part then break end
                pcall(function()
                    for _, o in ipairs(part:GetChildren()) do
                        if o:IsA("BodyPosition") or o:IsA("BodyVelocity") or o:IsA("BodyGyro")
                            or o:IsA("AlignPosition") or o:IsA("LinearVelocity") then
                            o:Destroy()
                        end
                    end
                end)
                pcall(function() part.Velocity = Vector3.new(0, 9999999, 0) end)
                RunService.Heartbeat:Wait()
            end
        end)
    end)
end

task.spawn(function()
    local _fired = false
    while true do
        if _G.MeerkoAutoClone == true then
            if not _fired
                and LP:GetAttribute("Stealing") ~= true
                and not (_G.MeerkoIsTeleporting and _G.MeerkoIsTeleporting()) then
                _fired = true
                if _G.MeerkoDoClone then pcall(_G.MeerkoDoClone) end
                if _G.MeerkoAutoCloneOneShot ~= false then
                    _G.MeerkoAutoClone = false
                    if _G.MeerkoRepaintAutoClone then pcall(_G.MeerkoRepaintAutoClone) end
                end
            end
        else
            _fired = false
        end
        task.wait(0.15)
    end
end)

_G.MeerkoAutoTPKeyName = _G.MeerkoAutoTPKeyName or "T"
_G.MeerkoAutoBuyKeyName = _G.MeerkoAutoBuyKeyName or "Y"

local function _kb(input, name)
    return type(name) == "string" and name ~= "" and input.KeyCode.Name == name
end
UIS.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if _G.MeerkoBindListening then return end   

    if _kb(input, _G.MeerkoCloneKeyName) then
        _G.MeerkoAutoClone = not (_G.MeerkoAutoClone == true)
    end
    
    if _kb(input, _G.MeerkoKickKeyName) then
        task.spawn(function()
            _G.MeerkoKickToPS = true
            if _G.MeerkoKickOut then pcall(_G.MeerkoKickOut) end
        end)
    end
    
    if _kb(input, _G.MeerkoStopTPKeyName) then
        _G.MeerkoTPStop = true
        _G.MeerkoAutoTP = false
        if _G.MeerkoRepaintAutoTP then pcall(_G.MeerkoRepaintAutoTP) end
        local ch = LP.Character
        local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
        if hrp then pcall(function() hrp.AssemblyLinearVelocity = Vector3.zero end) end
    end
    
    if _kb(input, _G.MeerkoNearestKey) then
        _G.MeerkoStealMode = (_G.MeerkoStealMode == "nearest") and "priority" or "nearest"
    end
    
    if _kb(input, _G.MeerkoDropKeyName) then
        task.spawn(function() if _G.DropBrainrot then pcall(_G.DropBrainrot) end end)
    end
    
    if _kb(input, _G.MeerkoResetKeyName) then
        task.spawn(function()
            if _G.MeerkoInstaReset then
                pcall(_G.MeerkoInstaReset)
            end
        end)
    end

    -- AUTO TELEPORT keybind
    if _kb(input, _G.MeerkoAutoTPKeyName) then
        _G.MeerkoAutoTP = not (_G.MeerkoAutoTP == true)
        if _G.MeerkoRepaintAutoTP then pcall(_G.MeerkoRepaintAutoTP) end
        pcall(_G.MeerkoSaveSettings)
    end

    -- AUTO BUY keybind
    if _kb(input, _G.MeerkoAutoBuyKeyName) then
        _G.MeerkoAutoBuy = not (_G.MeerkoAutoBuy == true)
        if _G.MeerkoRepaintAutoBuy then pcall(_G.MeerkoRepaintAutoBuy) end
        pcall(_G.MeerkoSaveSettings)
    end
end)


if _G.MeerkoAutoBuy == nil then _G.MeerkoAutoBuy = false end
if _G.MeerkoAutoBuyRange == nil then _G.MeerkoAutoBuyRange = 17 end
if _G.MeerkoAutoBuyHover == nil then _G.MeerkoAutoBuyHover = 9 end
_G.MeerkoRepaintAutoBuy = _G.MeerkoRepaintAutoBuy or function() end


do
    local Workspace = game:GetService("Workspace")
    local lockedPrompt, lockedPart, lockedModel
    local bodyPos, purchaseRemote

    local function resolvePurchaseRemote()
        if purchaseRemote and purchaseRemote.Parent then return purchaseRemote end
        pcall(function()
            local net = RS:FindFirstChild("Packages") and RS.Packages:FindFirstChild("Net")
            if not net then return end
            for _, v in ipairs(net:GetChildren()) do
                local nl = (v.Name or ""):lower()
                for _, kw in ipairs({ "buy", "purchase", "animal", "shop", "acquire", "conveyor" }) do
                    if nl:find(kw) then purchaseRemote = v; return end
                end
            end
        end)
        return purchaseRemote
    end

    local function firePurchase(prompt)
        if not (prompt and prompt.Parent and prompt.Enabled) then return false end
        local fired = false
        pcall(function() prompt.HoldDuration = 0 end)
        if fireproximityprompt then
            for _ = 1, 2 do
                local ok = pcall(function() fireproximityprompt(prompt) end)
                if ok then fired = true end
                task.wait()
                if not (prompt.Parent and prompt.Enabled) then break end
            end
        end
        -- Only use a discovered purchase remote when the game exposes one;
        -- do not assume an unrelated RemoteEvent's argument shape.
        local r = resolvePurchaseRemote()
        if r and prompt.Parent then
            pcall(function()
                if r:IsA("RemoteFunction") then
                    local ok = pcall(function() r:InvokeServer(prompt.Parent) end)
                    fired = fired or ok
                elseif r:IsA("RemoteEvent") then
                    local ok = pcall(function() r:FireServer(prompt.Parent) end)
                    fired = fired or ok
                end
            end)
        end
        return fired
    end

    local function partAlive()
        return lockedPart and lockedPart.Parent and lockedModel and lockedModel.Parent
    end
    local function promptAlive()
        return lockedPrompt and lockedPrompt.Parent and lockedPrompt.Enabled
    end

    local function hoverPart(char)
        return char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
    end
    local function ensureBodyPos(part)
        if bodyPos and bodyPos.Parent == part then return bodyPos end
        if bodyPos then bodyPos:Destroy() end
        local bp = Instance.new("BodyPosition")
        bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bp.P = 20000
        bp.D = 1200
        bp.Position = part.Position
        bp.Parent = part
        bodyPos = bp
        return bp
    end
    local function destroyBodyPos()
        if bodyPos then pcall(function() bodyPos:Destroy() end); bodyPos = nil end
    end

    local _promptCache, _promptCacheAt = nil, 0
    local function allPrompts()
        if _promptCache and os.clock() - _promptCacheAt < 5 then return _promptCache end
        local out, n = {}, 0
        for _, obj in ipairs(Workspace:GetDescendants()) do
            n = n + 1
            if n % 3000 == 0 then task.wait() end
            if obj:IsA("ProximityPrompt") then out[#out + 1] = obj end
        end
        _promptCache, _promptCacheAt = out, os.clock()
        return out
    end
    Workspace.DescendantAdded:Connect(function(d)
        if _G.MeerkoAutoBuy ~= true or not _promptCache then return end
        if d:IsA("ProximityPrompt") then _promptCache[#_promptCache + 1] = d end
    end)

    local function scanConveyor()
        local results = {}
        for _, obj in ipairs(allPrompts()) do
            if obj.Parent and obj.Enabled then
                local tx = (obj.ActionText or ""):lower()
                if tx:find("purchase") or tx:find("comprar") or tx:find("buy") then
                    local part = obj.Parent
                    local realPart = (part and part:IsA("Attachment") and part.Parent) or part
                    if realPart and realPart:IsA("BasePart") then
                        local model, cur = nil, realPart
                        for _ = 1, 8 do
                            if cur and cur:IsA("Model") then model = cur; break end
                            cur = cur and cur.Parent
                        end
                        results[#results + 1] = { prompt = obj, part = realPart, model = model }
                    end
                end
            end
        end
        return results
    end

    local _abRag = {
        [Enum.HumanoidStateType.Physics] = true,
        [Enum.HumanoidStateType.Ragdoll] = true,
        [Enum.HumanoidStateType.FallingDown] = true,
    }
    local _abSweep, _abHarden = 0, 0
    RunService.Heartbeat:Connect(function()
        if _G.MeerkoAutoBuy ~= true or not partAlive() then destroyBodyPos(); return end
        local char = LP.Character
        local part = char and hoverPart(char)
        if not part then destroyBodyPos(); return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        local ragged = false
        if hum then
            local now = os.clock()
            if now - _abHarden > 0.5 then
                _abHarden = now
                pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Physics, false) end)
                pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false) end)
                pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false) end)
                pcall(function() hum.BreakJointsOnDeath = false end)
            end
            ragged = _abRag[hum:GetState()] == true
            local et = tonumber(LP:GetAttribute("RagdollEndTime"))
            if et and (et - workspace:GetServerTimeNow()) > 0 then ragged = true end
            if ragged then
                pcall(function() LP:SetAttribute("RagdollEndTime", workspace:GetServerTimeNow()) end)
                pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
                pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end)
                local cam = workspace.CurrentCamera
                if cam and cam.CameraSubject ~= hum then
                    pcall(function() cam.CameraSubject = hum end)
                end
                if now - _abSweep > 0.25 then
                    _abSweep = now
                    for _, o in ipairs(char:GetDescendants()) do
                        if o:IsA("BallSocketConstraint") or o.Name == "RagdollAttachment" then
                            pcall(function() o:Destroy() end)
                        end
                    end
                end
            end
        end
        local hover = tonumber(_G.MeerkoAutoBuyHover) or 9
        if _G.__meerkoResetBusy then return end
        local goal = lockedPart.Position + Vector3.new(0, hover, 0)
        if ragged then
            pcall(function() part.AssemblyAngularVelocity = Vector3.zero end)
        end
        local bp = ensureBodyPos(part)
        bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bp.P = 20000
        bp.D = 1000
        bp.Position = goal
        if (part.Position - goal).Magnitude > (tonumber(_G.MeerkoAutoBuySnap) or 60) then
            pcall(function()
                part.CFrame = CFrame.new(goal)
                part.AssemblyLinearVelocity = Vector3.zero
                part.AssemblyAngularVelocity = Vector3.zero
            end)
        end
    end)

    RunService.Heartbeat:Connect(function()
        if _G.MeerkoAutoBuy ~= true or not partAlive() or not promptAlive() then return end
        firePurchase(lockedPrompt)
    end)

    task.spawn(function()
        while true do
            task.wait(0.1)
            if _G.MeerkoAutoBuy ~= true then
                lockedPrompt, lockedPart, lockedModel = nil, nil, nil
                destroyBodyPos()
            elseif lockedPart or lockedModel then
                if not partAlive() then lockedPrompt, lockedPart, lockedModel = nil, nil, nil end
            else
                local ok, found = pcall(scanConveyor)
                local list = (ok and found) or {}
                local char = LP.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local best, bestDist = nil, math.huge
                    local radius = tonumber(_G.MeerkoAutoBuyRange) or 17
                    for _, e in ipairs(list) do
                        if e.prompt and e.prompt.Parent and e.prompt.Enabled and e.part and e.part.Parent then
                            local d = (hrp.Position - e.part.Position).Magnitude
                            if d <= radius and d < bestDist then bestDist = d; best = e end
                        end
                    end
                    if best then
                        lockedPrompt, lockedPart, lockedModel = best.prompt, best.part, best.model or best.part.Parent
                        pcall(function() best.prompt.HoldDuration = 0 end)
                        resolvePurchaseRemote()
                        firePurchase(best.prompt)
                    end
                end
            end
        end
    end)
end

if _G.MeerkoFaceAway == nil then _G.MeerkoFaceAway = false end
if _G.MeerkoFaceAwayNearest == nil then _G.MeerkoFaceAwayNearest = false end

do
    local Workspace = game:GetService("Workspace")
    local function getRoot(pl)
        local c = pl and pl.Character
        return c and c:FindFirstChild("HumanoidRootPart")
    end
    local function findNearest(myRoot)
        local best, bestD = nil, math.huge
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= LP then
                local r = getRoot(pl)
                if r then
                    local d = (r.Position - myRoot.Position).Magnitude
                    if d < bestD then best, bestD = pl, d end
                end
            end
        end
        return best
    end
    local function getPlotAtPosition(pos)
        local plots = Workspace:FindFirstChild("Plots")
        if not plots then return nil end
        local best, bestD = nil, math.huge
        for _, plot in ipairs(plots:GetChildren()) do
            local pp
            if plot:IsA("Model") then
                pp = (plot.PrimaryPart and plot.PrimaryPart.Position) or plot:GetPivot().Position
            else
                pp = plot.Position
            end
            if pp then
                local dx, dz = pos.X - pp.X, pos.Z - pp.Z
                local d = math.sqrt(dx * dx + dz * dz)
                if d < bestD then bestD, best = d, plot end
            end
        end
        return (best and bestD < 72) and best or nil
    end
    local function getPlotOwner(plot)
        if not plot then return nil end
        local sign = plot:FindFirstChild("PlotSign")
        local lbl = sign
            and sign:FindFirstChild("SurfaceGui")
            and sign.SurfaceGui:FindFirstChild("Frame")
            and sign.SurfaceGui.Frame:FindFirstChild("TextLabel")
        if lbl then
            local nick = (lbl.Text and lbl.Text:match("^(.-)'")) or lbl.Text
            if nick and nick ~= "" then
                for _, pl in ipairs(Players:GetPlayers()) do
                    if pl.DisplayName == nick or pl.Name == nick then return pl end
                end
            end
        end
        return nil
    end
    local _ownerCache, _ownerAt = nil, 0
    local function resolveTarget(myRoot)
        if _G.MeerkoFaceAwayNearest == true then
            return findNearest(myRoot)
        end
        if os.clock() - _ownerAt > 0.5 then
            _ownerAt = os.clock()
            local owner = getPlotOwner(getPlotAtPosition(myRoot.Position))
            _ownerCache = (owner ~= LP) and owner or nil
        end
        return _ownerCache
    end
    local _faceWasOn, _stealSince = false, nil
    local function faceActive()
        if _G.MeerkoFaceAway ~= true then
            _stealSince = nil
            return false
        end
        if LP:GetAttribute("Stealing") ~= true then
            _stealSince = nil
            return false
        end
        if not _stealSince then
            _stealSince = os.clock()
            return false
        end
        return (os.clock() - _stealSince) >= (tonumber(_G.MeerkoFaceAwayDelay) or 2)
    end
    local function faceAwayStep()
        local char = LP.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not faceActive() then
            if _faceWasOn then
                _faceWasOn = false
                if hum then pcall(function() hum.AutoRotate = true end) end
            end
            return
        end
        _faceWasOn = true
        local myRoot = getRoot(LP)
        if not myRoot then return end
        if hum and hum.AutoRotate then pcall(function() hum.AutoRotate = false end) end
        local tRoot = getRoot(resolveTarget(myRoot))
        if not tRoot then return end
        local flat = Vector3.new(
            tRoot.Position.X - myRoot.Position.X,
            0,
            tRoot.Position.Z - myRoot.Position.Z
        )
        if flat.Magnitude < 0.05 then return end
        myRoot.CFrame = CFrame.lookAt(myRoot.Position, myRoot.Position + Vector3.new(-flat.Z, 0, flat.X).Unit)
        local av = myRoot.AssemblyAngularVelocity
        if av.Y ~= 0 then
            myRoot.AssemblyAngularVelocity = Vector3.new(av.X, 0, av.Z)
        end
    end
    RunService.RenderStepped:Connect(faceAwayStep)
    RunService.Heartbeat:Connect(faceAwayStep)
end

do
    local TweenService = game:GetService("TweenService")
    -- Meerko Extras palette matched to the reference image:
    -- dark charcoal panels + teal/green accent + light Gotham typography.
    local C = {
        bg = Color3.fromRGB(12,14,16),
        card = Color3.fromRGB(24,28,32),
        line = Color3.fromRGB(60,65,68),
        acc = Color3.fromRGB(0,200,140),
        txt = Color3.fromRGB(233,238,238),
        dim = Color3.fromRGB(128,135,138),
        track = Color3.fromRGB(44,49,53),
        acc2 = Color3.fromRGB(0,200,140),
    }
    local FB, FR = Enum.Font.GothamBold, Enum.Font.Gotham
    local EASE = TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    local function tw(o, p) TweenService:Create(o, EASE, p):Play() end
    local function mk(cls, parent, props)
        local o = Instance.new(cls)
        for k, v in pairs(props or {}) do o[k] = v end
        o.Parent = parent
        return o
    end
    local function corner(o, r) mk("UICorner", o, { CornerRadius = UDim.new(0, r or 4) }) return o end

    local host = (gethui and gethui()) or game:GetService("CoreGui")
    pcall(function()
        local old = host:FindFirstChild("MeerkoExtras")
        if old then old:Destroy() end
    end)
    local sg = mk("ScreenGui", nil, {
        Name = "MeerkoExtras", ResetOnSpawn = false, IgnoreGuiInset = true,
        DisplayOrder = 999997, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    pcall(function() sg.Parent = host end)
    if not sg.Parent then sg.Parent = LP:WaitForChild("PlayerGui") end

    local function makeDrag(frame, handle, keyX, keyY)
        local on, from, base, tracked
        handle.InputBegan:Connect(function(i)
            if i.UserInputType ~= Enum.UserInputType.MouseButton1 and i.UserInputType ~= Enum.UserInputType.Touch then return end
            on, from, base = true, i.Position, frame.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then
                    on = false
                    if keyX then _G[keyX] = frame.Position.X.Offset end
                    if keyY then _G[keyY] = frame.Position.Y.Offset end
                    pcall(_G.MeerkoSaveSettings)
                end
            end)
        end)
        handle.InputChanged:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then tracked = i end
        end)
        UIS.InputChanged:Connect(function(i)
            if not on or i ~= tracked then return end
            local d = i.Position - from
            frame.Position = UDim2.fromOffset(base.X.Offset + d.X, base.Y.Offset + d.Y)
        end)
    end

    local _ord = 0
    local function nextOrd() _ord = _ord + 1 return _ord end
    local _toggleRepaints = {}

    local function toggle(parent, label, get, set)
        local card = corner(mk("Frame", parent, {
            Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = C.card, BorderSizePixel = 0, LayoutOrder = nextOrd(),
        }), 4)
        mk("TextLabel", card, {
            Size = UDim2.new(1, -60, 1, 0), Position = UDim2.fromOffset(12, 0),
            BackgroundTransparency = 1, Text = label, Font = FR, TextSize = 12,
            TextColor3 = C.txt, TextXAlignment = Enum.TextXAlignment.Left,
        })
        local pill = corner(mk("Frame", card, {
            Size = UDim2.fromOffset(38, 18), Position = UDim2.new(1, -48, 0.5, -9),
            BackgroundColor3 = C.track, BorderSizePixel = 0,
        }), 9)
        local knob = corner(mk("Frame", pill, {
            Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(2, 2),
            BackgroundColor3 = C.dim, BorderSizePixel = 0,
        }), 7)
        local hit = mk("TextButton", card, { Size = UDim2.fromScale(1,1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Active = true })
        local _last
        local function paint(instant)
            local v = get() and true or false
            if v == _last and not instant then return end
            _last = v
            local pc = v and C.acc or C.track
            local kc = v and C.bg or C.dim
            local kp = UDim2.fromOffset(v and 22 or 2, 2)
            if instant then pill.BackgroundColor3, knob.BackgroundColor3, knob.Position = pc, kc, kp
            else tw(pill, { BackgroundColor3 = pc }); tw(knob, { BackgroundColor3 = kc, Position = kp }) end
        end
        hit.MouseButton1Click:Connect(function() set(); paint(); pcall(_G.MeerkoSaveSettings) end)
        paint(true)
        _toggleRepaints[#_toggleRepaints + 1] = paint
    end

    local function slider(parent, label, min, max, get, set, step)
        step = step or 1
        local card = corner(mk("Frame", parent, {
            Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = C.card, BorderSizePixel = 0, LayoutOrder = nextOrd(),
        }), 4)
        mk("TextLabel", card, {
            Size = UDim2.new(1, -60, 0, 14), Position = UDim2.fromOffset(12, 6),
            BackgroundTransparency = 1, Text = label, Font = FR, TextSize = 11,
            TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left,
        })
        local val = mk("TextLabel", card, {
            Size = UDim2.fromOffset(48, 14), Position = UDim2.new(1, -56, 0, 6),
            BackgroundTransparency = 1, Font = Enum.Font.Code, TextSize = 12, TextColor3 = C.acc2,
            TextXAlignment = Enum.TextXAlignment.Right,
        })
        local track = corner(mk("TextButton", card, {
            Size = UDim2.new(1, -24, 0, 6), Position = UDim2.fromOffset(12, 30),
            BackgroundColor3 = C.track, Text = "", AutoButtonColor = false, BorderSizePixel = 0,
        }), 3)
        local fill = corner(mk("Frame", track, { Size = UDim2.new(0,0,1,0), BackgroundColor3 = C.acc, BorderSizePixel = 0 }), 3)
        local function refresh()
            local v = math.clamp(tonumber(get()) or min, min, max)
            local rel = (v - min) / math.max(max - min, 1e-6)
            fill.Size = UDim2.new(rel, 0, 1, 0)
            val.Text = step < 1 and string.format("%.2f", v) or tostring(math.floor(v + 0.5))
        end
        local function apply(x)
            local rel = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
            set(math.clamp(math.floor((min + (max - min) * rel) / step + 0.5) * step, min, max))
            refresh()
        end
        local sliding = false
        track.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then sliding = true; apply(i.Position.X) end
        end)
        UIS.InputChanged:Connect(function(i)
            if sliding and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then apply(i.Position.X) end
        end)
        UIS.InputEnded:Connect(function(i)
            if sliding and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then sliding = false; pcall(_G.MeerkoSaveSettings) end
        end)
        refresh()
    end

    local function input(parent, label, hint, get, set)
        local card = corner(mk("Frame", parent, {
            Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = C.card, BorderSizePixel = 0, LayoutOrder = nextOrd(),
        }), 4)
        mk("TextLabel", card, {
            Size = UDim2.new(1, -20, 0, 12), Position = UDim2.fromOffset(12, 6),
            BackgroundTransparency = 1, Text = label, Font = FR, TextSize = 10,
            TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left,
        })
        local box = mk("TextBox", card, {
            Size = UDim2.new(1, -20, 0, 18), Position = UDim2.fromOffset(12, 22),
            BackgroundTransparency = 1, Font = FB, TextSize = 12, TextColor3 = C.txt,
            TextXAlignment = Enum.TextXAlignment.Left, PlaceholderText = hint, PlaceholderColor3 = C.line,
            ClearTextOnFocus = false, Text = tostring(get() or ""), TextTruncate = Enum.TextTruncate.AtEnd,
        })
        box.FocusLost:Connect(function() set(box.Text); pcall(_G.MeerkoSaveSettings) end)
    end

    local function keybind(parent, labelTxt, getName, setName)
        local card = corner(mk("Frame", parent, {
            Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = C.card, BorderSizePixel = 0, LayoutOrder = nextOrd(),
        }), 4)
        mk("TextLabel", card, {
            Size = UDim2.new(1, -104, 1, 0), Position = UDim2.fromOffset(12, 0),
            BackgroundTransparency = 1, Text = labelTxt, Font = FR, TextSize = 12,
            TextColor3 = C.txt, TextXAlignment = Enum.TextXAlignment.Left,
        })
        local btn = corner(mk("TextButton", card, {
            Size = UDim2.fromOffset(84, 22), Position = UDim2.new(1, -96, 0.5, -11),
            BackgroundColor3 = C.track, Text = "", Font = FB, TextSize = 11,
            TextColor3 = C.txt, AutoButtonColor = false, Active = true,
        }), 4)
        local listening, conn = false, nil
        local function repaint()
            if listening then btn.Text = "..."; return end
            local k = getName()
            btn.Text = (type(k) == "string" and k ~= "") and k or "NONE"
        end
        local function stop()
            listening = false
            _G.MeerkoBindListening = false
            if conn then conn:Disconnect(); conn = nil end
            tw(btn, { BackgroundColor3 = C.track })
            repaint()
        end
        btn.MouseButton1Click:Connect(function()
            if listening then stop(); return end
            listening = true
            _G.MeerkoBindListening = true
            tw(btn, { BackgroundColor3 = C.line })
            repaint()
            conn = UIS.InputBegan:Connect(function(inp)
                if inp.UserInputType ~= Enum.UserInputType.Keyboard then return end
                local kn = inp.KeyCode.Name
                if kn == "Escape" or kn == "Backspace" or kn == "Delete" then setName(nil) else setName(kn) end
                stop()
                pcall(_G.MeerkoSaveSettings)
            end)
        end)
        btn.MouseButton2Click:Connect(function()
            if listening then stop(); return end
            setName(nil); repaint(); pcall(_G.MeerkoSaveSettings)
        end)
        repaint()
    end

    local function action(parent, label, fn)
        local card = corner(mk("Frame", parent, {
            Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = C.card, BorderSizePixel = 0, LayoutOrder = nextOrd(),
        }), 4)
        local btn = mk("TextButton", card, {
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = label,
            Font = FB, TextSize = 12, TextColor3 = C.acc, AutoButtonColor = false, Active = true,
        })
        btn.MouseEnter:Connect(function() tw(card, { BackgroundColor3 = C.track }) end)
        btn.MouseLeave:Connect(function() tw(card, { BackgroundColor3 = C.card }) end)
        btn.MouseButton1Click:Connect(fn)
    end

    local function makeSub(titleText, sx, sy, keyX, keyY)
        local frame = corner(mk("Frame", sg, {
            Name = titleText, Active = true, BackgroundColor3 = C.bg, BorderSizePixel = 0,
            Size = UDim2.fromOffset(248, 380), Visible = false,
            Position = UDim2.fromOffset(tonumber(_G[keyX]) or sx, tonumber(_G[keyY]) or sy),
        }), 6)
        mk("UIStroke", frame, { Thickness = 1, Transparency = 0.4, Color = C.acc })
        local head = mk("TextLabel", frame, {
            Position = UDim2.fromOffset(14, 12), Size = UDim2.new(1, -52, 0, 18),
            BackgroundTransparency = 1, Text = titleText, Font = FB, TextSize = 13,
            TextColor3 = C.txt, TextXAlignment = Enum.TextXAlignment.Left,
        })
        local close = corner(mk("TextButton", frame, {
            Size = UDim2.fromOffset(24, 20), Position = UDim2.new(1, -32, 0, 11),
            BackgroundColor3 = C.card, Text = "X", Font = FB, TextSize = 11,
            TextColor3 = C.txt, AutoButtonColor = false, Active = true,
        }), 4)
        close.MouseButton1Click:Connect(function() frame.Visible = false end)
        local list = mk("ScrollingFrame", frame, {
            Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 1, -48),
            BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
            ScrollBarImageColor3 = C.line, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        })
        mk("UIListLayout", list, { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center })
        mk("UIPadding", list, { PaddingTop = UDim.new(0,4), PaddingBottom = UDim.new(0,10), PaddingLeft = UDim.new(0,12), PaddingRight = UDim.new(0,12) })
        makeDrag(frame, head, keyX, keyY)
        return frame, list
    end

    local featFrame, featList = makeSub("FEATURES", 560, 250, "_meerko_fX", "_meerko_fY")
    local keysFrame, keysList = makeSub("KEYBINDS", 560, 250, "_meerko_kX", "_meerko_kY")

    local main = corner(mk("Frame", sg, {
        Name = "Main", Active = true, BackgroundColor3 = C.bg, BorderSizePixel = 0,
        Size = UDim2.fromOffset(240, 0), AutomaticSize = Enum.AutomaticSize.Y,
        Position = UDim2.fromOffset(tonumber(_G._meerko_exX) or 300, tonumber(_G._meerko_exY) or 250),
    }), 6)
    mk("UIStroke", main, { Thickness = 1, Transparency = 0.4, Color = C.acc })
    mk("UIListLayout", main, { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center })
    mk("UIPadding", main, { PaddingTop = UDim.new(0,12), PaddingBottom = UDim.new(0,12), PaddingLeft = UDim.new(0,12), PaddingRight = UDim.new(0,12) })
    local mHead = mk("TextLabel", main, {
        Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Text = "MEERKO EXTRAS",
        Font = FB, TextSize = 12, TextColor3 = C.txt, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = nextOrd(),
    })
    makeDrag(main, mHead, "_meerko_exX", "_meerko_exY")

    local navRow = mk("Frame", main, { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, LayoutOrder = nextOrd() })
    mk("UIListLayout", navRow, { Padding = UDim.new(0, 8), FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center })
    local function navBtn(txt)
        local b = corner(mk("TextButton", navRow, {
            Size = UDim2.fromOffset(100, 28), BackgroundColor3 = C.card, Text = txt,
            Font = FB, TextSize = 11, TextColor3 = C.txt, AutoButtonColor = false, Active = true,
        }), 4)
        b.MouseEnter:Connect(function() tw(b, { BackgroundColor3 = C.track }) end)
        b.MouseLeave:Connect(function() tw(b, { BackgroundColor3 = C.card }) end)
        return b
    end
    local featBtn = navBtn("FEATURES")
    local keysBtn = navBtn("KEYBINDS")
    featBtn.MouseButton1Click:Connect(function() keysFrame.Visible = false; featFrame.Visible = not featFrame.Visible end)
    keysBtn.MouseButton1Click:Connect(function() featFrame.Visible = false; keysFrame.Visible = not keysFrame.Visible end)

    toggle(main, "AUTO INVIS ON STEAL",
        function() return _G.MeerkoInvisAuto == true end,
        function() _G.MeerkoInvisAuto = not (_G.MeerkoInvisAuto == true); if _G.MeerkoInvisSync then pcall(_G.MeerkoInvisSync) end end)
    slider(main, "Invis Depth", 0, 10, function() return _G.MeerkoInvisDepth end, function(v) _G.MeerkoInvisDepth = v end, 0.1)
    slider(main, "Invis Rotation", 0, 360, function() return _G.MeerkoInvisAngle end, function(v) _G.MeerkoInvisAngle = v end, 1)
    toggle(main, "AUTO KICK ON STEAL",
        function() return _G.MeerkoAutoKickOnSteal == true end,
        function() _G.MeerkoAutoKickOnSteal = not (_G.MeerkoAutoKickOnSteal == true) end)
    toggle(main, "AUTO BUY",
        function() return _G.MeerkoAutoBuy == true end,
        function()
            _G.MeerkoAutoBuy = not (_G.MeerkoAutoBuy == true)
            if _G.MeerkoRepaintAutoBuy then pcall(_G.MeerkoRepaintAutoBuy) end
            pcall(_G.MeerkoSaveSettings)
        end)

    -- ============================================================
    -- WALK SPEED: 24 / 29 buttons
    -- Two large buttons, evenly split across the card width, with
    -- the active speed highlighted in the teal accent colour.
    -- ============================================================
    if _G.MeerkoWalkSpeed == nil then _G.MeerkoWalkSpeed = 24 end
    if _G.MeerkoWalkSpeedOn == nil then _G.MeerkoWalkSpeedOn = true end
    do
        local card = corner(mk("Frame", main, {
            Size = UDim2.new(1, 0, 0, 54), BackgroundColor3 = C.card,
            BorderSizePixel = 0, LayoutOrder = nextOrd(),
        }), 4)

        mk("TextLabel", card, {
            Size = UDim2.new(1, -20, 0, 14), Position = UDim2.fromOffset(10, 7),
            BackgroundTransparency = 1, Text = "WALKSPEED", Font = FB, TextSize = 11,
            TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left,
        })

        -- Container row: stretches across the card with 8px side padding,
        -- buttons split via UIListLayout so both stay perfectly even.
        local row = mk("Frame", card, {
            Size = UDim2.new(1, -16, 0, 26), Position = UDim2.fromOffset(8, 24),
            BackgroundTransparency = 1,
        })
        mk("UIListLayout", row, {
            Padding = UDim.new(0, 8),
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            SortOrder = Enum.SortOrder.LayoutOrder,
        })

        local btns = {}
        local function paintSpeeds()
            local cur = tonumber(_G.MeerkoWalkSpeed) or 24
            local on  = _G.MeerkoWalkSpeedOn ~= false
            for v, b in pairs(btns) do
                local active = on and (v == cur)
                b.BackgroundColor3 = active and C.acc or C.track
                b.TextColor3     = active and C.bg  or C.txt
            end
        end

        local function speedButton(txt)
            local v = tonumber(txt) or 24
            -- 0.5 scale width minus half of the 8px gap => perfectly even split
            local b = corner(mk("TextButton", row, {
                Size = UDim2.new(0.5, -4, 1, 0),
                BackgroundColor3 = C.track, Text = txt,
                Font = FB, TextSize = 14, TextColor3 = C.txt,
                AutoButtonColor = false, BorderSizePixel = 0,
                LayoutOrder = v,
            }), 4)
            b.MouseEnter:Connect(function()
                if not ((_G.MeerkoWalkSpeedOn ~= false) and ((tonumber(_G.MeerkoWalkSpeed) or 24) == v)) then
                    tw(b, { BackgroundColor3 = C.line })
                end
            end)
            b.MouseLeave:Connect(function() paintSpeeds() end)
            b.MouseButton1Click:Connect(function()
                _G.MeerkoWalkSpeed = v
                _G.MeerkoWalkSpeedOn = true
                if _G.MeerkoSetWalkSpeed then pcall(_G.MeerkoSetWalkSpeed, true) end
                paintSpeeds()
                pcall(_G.MeerkoSaveSettings)
            end)
            btns[v] = b
            return b
        end

        speedButton("24")
        speedButton("29")
        paintSpeeds()

        -- Keep the buttons visually in sync if anything else changes the value.
        _toggleRepaints[#_toggleRepaints + 1] = paintSpeeds
    end

    action(main, "KICK", function()
        task.spawn(function() if _G.MeerkoKickOut then pcall(_G.MeerkoKickOut) end end)
    end)

    toggle(featList, "ANTI FLASH",             function() return _G.MeerkoAntiFlash ~= false end,      function() _G.MeerkoAntiFlash = not (_G.MeerkoAntiFlash ~= false) end)
    toggle(featList, "ANTI BEE",               function() return _G.MeerkoAntiBee ~= false end,        function() _G.MeerkoAntiBee = not (_G.MeerkoAntiBee ~= false) end)
    toggle(featList, "INF JUMP",               function() return _G.MeerkoInfJump ~= false end,        function() _G.MeerkoInfJump = not (_G.MeerkoInfJump ~= false) end)
    toggle(featList, "ANTI DIE",               function() return _G.AntiDieDisabled ~= true end,       function() _G.AntiDieDisabled = (_G.AntiDieDisabled ~= true) end)
    toggle(featList, "WALK SPEED",             function() return _G.MeerkoWalkSpeedOn ~= false end,    function() if _G.MeerkoSetWalkSpeed then _G.MeerkoSetWalkSpeed(_G.MeerkoWalkSpeedOn == false) end end)
    toggle(featList, "CARPET SPEED",           function() return _G.MeerkoCarpetSpeed == true end,     function() if _G.MeerkoSetCarpetSpeed then _G.MeerkoSetCarpetSpeed(not (_G.MeerkoCarpetSpeed == true)) end end)
    toggle(featList, "XRAY BASES",             function() return _G.MeerkoXray ~= false end,           function() if _G.MeerkoToggleXray then _G.MeerkoToggleXray() end end)
    toggle(featList, "AUTO KICK ON STEAL",     function() return _G.MeerkoAutoKickOnSteal == true end, function() _G.MeerkoAutoKickOnSteal = not (_G.MeerkoAutoKickOnSteal == true) end)
    toggle(featList, "KICK TO PRIVATE SERVER", function() return _G.MeerkoKickToPS == true end,        function() _G.MeerkoKickToPS = not (_G.MeerkoKickToPS == true) end)
    toggle(featList, "PRIORITY ALERT",         function() return _G.MeerkoPriAlert == true end,        function() _G.MeerkoPriAlert = not (_G.MeerkoPriAlert == true) end)
    toggle(featList, "FACE AWAY",              function() return _G.MeerkoFaceAway == true end,        function() _G.MeerkoFaceAway = not (_G.MeerkoFaceAway == true) end)
    toggle(featList, "FACE AWAY: NEAREST",     function() return _G.MeerkoFaceAwayNearest == true end, function() _G.MeerkoFaceAwayNearest = not (_G.MeerkoFaceAwayNearest == true) end)
    toggle(featList, "FOV",                    function() return _G.MeerkoFOVEnabled == true end,      function() _G.MeerkoFOVEnabled = not (_G.MeerkoFOVEnabled == true) end)
    slider(featList, "FOV Value", 50, 120, function() return tonumber(_G.MeerkoFOV) or 70 end, function(v) _G.MeerkoFOV = v end, 1)
    slider(featList, "Auto Buy Range", 5, 40, function() return _G.MeerkoAutoBuyRange end, function(v) _G.MeerkoAutoBuyRange = v end, 1)
    slider(featList, "Auto Buy Float", 0, 20, function() return _G.MeerkoAutoBuyHover end, function(v) _G.MeerkoAutoBuyHover = v end, 1)
    slider(featList, "Carpet Speed", 20, 400, function() return _G.MeerkoCarpetSpeedValue end, function(v) _G.MeerkoCarpetSpeedValue = v end, 5)
    slider(featList, "Alert Min M/s", 0, 500, function() return (tonumber(_G.MeerkoAlertMinGen) or 80e6)/1e6 end, function(v) _G.MeerkoAlertMinGen = v * 1e6 end, 5)
    input(featList, "PRIVATE SERVER LINK", "paste link or share code", function() return _G.MeerkoPrivateServerLink end, function(v) _G.MeerkoPrivateServerLink = (v or ""):match("^%s*(.-)%s*$") end)
    input(featList, "ALERT SOUND ID", "111786441593851", function() return _G.MeerkoAlertSound end, function(v) _G.MeerkoAlertSound = (v or ""):match("%d+") or "111786441593851" end)

    keybind(keysList, "AUTO CLONE",             function() return _G.MeerkoCloneKeyName end,   function(k) _G.MeerkoCloneKeyName = k end)
    keybind(keysList, "KICK TO PRIVATE SERVER", function() return _G.MeerkoKickKeyName end,    function(k) _G.MeerkoKickKeyName = k end)
    keybind(keysList, "STOP TP",                function() return _G.MeerkoStopTPKeyName end,  function(k) _G.MeerkoStopTPKeyName = k end)
    keybind(keysList, "PRIORITY / NEAREST",     function() return _G.MeerkoNearestKey end,     function(k) _G.MeerkoNearestKey = k end)
    keybind(keysList, "DROP BRAINROT",          function() return _G.MeerkoDropKeyName end,    function(k) _G.MeerkoDropKeyName = k end)
    keybind(keysList, "INSTA RESET",            function() return _G.MeerkoResetKeyName end,   function(k) _G.MeerkoResetKeyName = k end)
    keybind(keysList, "AUTO TELEPORT",          function() return _G.MeerkoAutoTPKeyName end,  function(k) _G.MeerkoAutoTPKeyName = k end)
    keybind(keysList, "AUTO BUY",               function() return _G.MeerkoAutoBuyKeyName end, function(k) _G.MeerkoAutoBuyKeyName = k end)

    task.spawn(function()
        while sg.Parent do
            for _, r in ipairs(_toggleRepaints) do pcall(r) end
            task.wait(0.3)
        end
    end)
end