local _RP, _RW = print, warn
_G.MeerkoStealWhy = "boot"
_G.MeerkoStealLog = {}
_G.MeerkoStealSay = function(msg)
    msg = tostring(msg)
    _G.MeerkoStealWhy = msg
    local L = _G.MeerkoStealLog
    local now = os.clock()
    local last = L[#L]
    if last and last.msg == msg then
        last.n = last.n + 1
        last.t = now
    else
        L[#L + 1] = { msg = msg, t = now, t0 = now, n = 1 }
        while #L > 8 do table.remove(L, 1) end
    end
    if _G.MeerkoStealDebug then
        if now - (_G._mkLastSay or 0) >= (tonumber(_G.MeerkoStealDebugGap) or 0.5) then
            _G._mkLastSay = now
            pcall(_RP, "[steal] " .. msg)
        end
    end
end

_G.MeerkoScanProfile = function(mode)
    if mode == "fast" then
        _G.MeerkoScanMode     = "fast"
        _G.MeerkoPanelScanGap = tonumber(_G.MeerkoFastPanelGap)    or 0.12
        _G.MeerkoRepickGap    = tonumber(_G.MeerkoFastRepickGap)   or 0.10
        _G.MeerkoInRangeGap   = tonumber(_G.MeerkoFastInRangeGap)  or 0.10
        _G.MeerkoWatchdogTick = tonumber(_G.MeerkoFastWatchdogTick) or 0.15
        _G.MeerkoSyncScanGap  = tonumber(_G.MeerkoFastSyncGap)     or 0.05
        _G.MeerkoAutoTPPoll   = tonumber(_G.MeerkoFastTPPoll)      or 0.03
    else
        _G.MeerkoScanMode     = "normal"
        _G.MeerkoPanelScanGap = tonumber(_G.MeerkoNormPanelGap)    or 0.6
        _G.MeerkoRepickGap    = tonumber(_G.MeerkoNormRepickGap)   or 0.5
        _G.MeerkoInRangeGap   = tonumber(_G.MeerkoNormInRangeGap)  or 0.3
        _G.MeerkoWatchdogTick = tonumber(_G.MeerkoNormWatchdogTick) or 0.3
        _G.MeerkoSyncScanGap  = tonumber(_G.MeerkoNormSyncGap)     or 0.25
        _G.MeerkoAutoTPPoll   = tonumber(_G.MeerkoNormTPPoll)      or 0.05
    end
    if _G.MeerkoStealSay then _G.MeerkoStealSay("scan profile -> " .. tostring(_G.MeerkoScanMode)) end
end
_G.MeerkoScanProfile("fast")
task.delay(tonumber(_G.MeerkoFastWindow) or 60, function()
    if _G.MeerkoScanMode == "fast" then _G.MeerkoScanProfile("normal") end
end)
local print = function() end
local warn  = function() end
_G.MeerkoInvisAuto = false
_G.MeerkoAutoKickOnSteal = false
_G.MeerkoAutoBuy = false
if _G.MeerkoStealMode == nil then _G.MeerkoStealMode = "priority" end
if _G.MeerkoAutoTP == nil then _G.MeerkoAutoTP = true end

-- TP safety: prefer a slightly slower, more stable route over hard misses/deaths.
if _G.MeerkoTPSafeMode == nil then _G.MeerkoTPSafeMode = true end
if _G.MeerkoTPSafeSpeed == nil then _G.MeerkoTPSafeSpeed = 300 end
if _G.MeerkoTPSafeVerticalSpeed == nil then _G.MeerkoTPSafeVerticalSpeed = 110 end
if _G.MeerkoTPReachTolerance == nil then _G.MeerkoTPReachTolerance = 4.5 end
if _G.MeerkoTPRetryCount == nil then _G.MeerkoTPRetryCount = 2 end
if _G.MeerkoTPRetryDelay == nil then _G.MeerkoTPRetryDelay = 0.08 end
if _G.MeerkoVoidRecover == nil then _G.MeerkoVoidRecover = true end

if not game:IsLoaded() then game.Loaded:Wait() end

--[[ Net env-spoof: DISABLED (Elite parity) ------------------------------------
     This used to require ReplicatedStorage.Packages.Net and then write into the
     game module's own environment:
         env.getfenv                  = <our function>
         setreadonly(env.debug, false)
         env.debug.getmemorycategory  = function() return "--" end
     re-applied 80x over 8 seconds.

     That is the loudest signal in this script, and it is self-defeating. The
     Net wrapper calls debug.getmemorycategory() to identify its caller. Legit
     game code returns a real script category; this returned the literal "--",
     which is not a valid category -- so anything validating the returned value
     against a known set sees "--" and flags immediately. Leaving env.debug
     writable via setreadonly is independently checkable (table.isfrozen).

     Elite never requires the module at all, so it never meets this check.
     Meerko no longer needs it either: the grapple now resolves the UseItem
     RemoteEvent structurally and calls FireServer on the raw Instance, which
     never enters the Net wrapper.

     Set _G.MeerkoNetSpoofEnable = true to restore the old behaviour.
--------------------------------------------------------------------------- ]]
do
    local RS = game:GetService("ReplicatedStorage")
    local _spoofOk = false
    local function _applySpoof()
        if _G.MeerkoNetSpoofEnable ~= true then return false end
        local ok = pcall(function()
            local Net = require(RS:WaitForChild("Packages"):WaitForChild("Net"))
            local og = getfenv
            if type(og) ~= "function" then return end
            for _, fname in ipairs({ "RemoteEvent", "RemoteFunction", "UnreliableRemoteEvent" }) do
                local f = rawget(Net, fname)
                if type(f) == "function" then
                    local env = og(f)
                    if type(env) == "table" then
                        env.getfenv = function() return og(f) end
                        if type(env.debug) == "table" then
                            if setreadonly then pcall(setreadonly, env.debug, false) end
                            env.debug.getmemorycategory = function() return "--" end
                        end
                    end
                end
            end
            _spoofOk = true
        end)
        return ok and _spoofOk
    end
    _G.MeerkoNetSpoof = _applySpoof
    _G.MeerkoNetSpoofReady = function() return _spoofOk end
    if _G.MeerkoNetSpoofEnable == true then
        _applySpoof()
        task.spawn(function()
            for _ = 1, 80 do
                if _applySpoof() then end
                task.wait(0.1)
            end
        end)
    end
end

pcall(function() if setfpscap then setfpscap(9999) end end)


task.spawn(function()
    local Workspace = game:GetService("Workspace")
    local LocalPlayer = game:GetService("Players").LocalPlayer
    if not Workspace.StreamingEnabled then return end
    local plots
    local t0 = os.clock()
    repeat plots = Workspace:FindFirstChild("Plots"); if not plots then task.wait(0.1) end
    until plots or (os.clock() - t0) > 25
    if not plots then return end
    local function plotPos(plot)
        local ok, pv = pcall(function() return plot:GetPivot().Position end)
        if ok and pv and pv.Magnitude > 1 then return pv end
        if plot.PrimaryPart then return plot.PrimaryPart.Position end
        local bp = plot:FindFirstChildWhichIsA("BasePart", true)
        return bp and bp.Position or nil
    end
    local pending = 0
    for _, plot in ipairs(plots:GetChildren()) do
        local pos = plotPos(plot)
        if pos then
            pending = pending + 1
            task.spawn(function()
                pcall(function() LocalPlayer:RequestStreamAroundAsync(pos) end)
                pending = pending - 1
            end)
        end
    end
    local sw = os.clock()
    while pending > 0 and os.clock() - sw < 10 do task.wait(0.05) end
end)

_G.MeerkoBootDelay = tonumber(_G.MeerkoBootDelay) or 6
if _G.MeerkoWaitForTools == nil then _G.MeerkoWaitForTools = true end
_G.MeerkoToolWait = tonumber(_G.MeerkoToolWait) or 35
do
    local _bootT0 = os.clock()
    local _BOOT_TOOLS = {
        "Flying Carpet", "Waverider", "Santa's Sleigh", "Witch's Broom", "Cupid's Wings",
        "Grapple Hook", "Grappling Hook", "Grapple", "Hook", "Web Slinger", "Grapple Gun", "GrappleHook",
    }
    local function _hasTool(n)
        local plr = game:GetService("Players").LocalPlayer
        if not plr then return false end
        local char = plr.Character
        local bp = plr:FindFirstChild("Backpack")
        local t = (char and char:FindFirstChild(n)) or (bp and bp:FindFirstChild(n))
        return t ~= nil and t:IsA("Tool")
    end
    local function _toolsReady()
        if type(_G.MeerkoCarpetTool) == "string" and _G.MeerkoCarpetTool ~= "" and _hasTool(_G.MeerkoCarpetTool) then return true end
        for _, n in ipairs(_BOOT_TOOLS) do
            if _hasTool(n) then return true end
        end
        return false
    end
    _G.MeerkoToolsReady = _toolsReady
    _G.MeerkoBootWait = function()
        local d = tonumber(_G.MeerkoBootDelay) or 8
        while os.clock() - _bootT0 < d do task.wait(0.25) end
        if _G.MeerkoWaitForTools == false then return end
        local cap = tonumber(_G.MeerkoToolWait) or 30
        local t0 = os.clock()
        while os.clock() - t0 < cap do
            local ok, ready = pcall(_toolsReady)
            if ok and ready then
                task.wait(0.35)
                return
            end
            task.wait(0.2)
        end
        warn("[MeerkoTP] tools never loaded within " .. cap .. "s, continuing anyway")
    end
end

_G.MeerkoPriVersion = _G.MeerkoPriVersion or 0
if type(_G.MeerkoPriorityDefault) ~= "table" then _G.MeerkoPriorityDefault = {} end
if type(_G.SHARED_PRIORITY_ITEMS) ~= "table" then _G.SHARED_PRIORITY_ITEMS = {} end

if LPH_OBFUSCATED == nil then
    local env = getfenv()
    env["LPH_NO_" .. "VIRTUALIZE"] = function(...) return ... end
    env["LPH_JIT_" .. "MAX"]       = function(...) return ... end
end

do
    local _HS = game:GetService("HttpService")
    local _TS = game:GetService("TeleportService")
    local fileData, tpData
    if readfile then
        pcall(function()
            local raw = readfile("SideTP.json")
            if type(raw) == "string" and #raw > 0 then fileData = _HS:JSONDecode(raw) end
        end)
    end
    pcall(function()
        local td = _TS:GetLocalPlayerTeleportData()
        if td and td.SideTP then tpData = td.SideTP end
    end)
    local merged = {}
    if type(tpData) == "table" then for k, v in pairs(tpData) do merged[k] = v end end
    if type(fileData) == "table" then for k, v in pairs(fileData) do merged[k] = v end end

    if type(merged.tpDelay) == "number" then _G._stp_tpDelay = merged.tpDelay end
    if type(merged.tpVelocity) == "number" then _G.TPVelocity = math.clamp(merged.tpVelocity, 200, 750) end
    if type(merged.climbSpeed) == "number" then _G.MeerkoClimb = math.clamp(merged.climbSpeed, 100, 250) end
    if type(merged.cframeSpeed) == "number" then _G.MeerkoCFrameSpeed = math.clamp(merged.cframeSpeed, 100, 900) end
    if type(merged.walkSpeed) == "number" then _G.MeerkoWalkSpeed = math.clamp(merged.walkSpeed, 16, 29) end
    if type(merged.carpetTool) == "string" then _G.MeerkoCarpetTool = merged.carpetTool end
    if type(merged.landingDelay) == "number" then _G.LandingDelay = math.clamp(merged.landingDelay, 0.05, 0.75) end
    if type(merged.closeSpeed) == "number" then _G.MeerkoCloseSpeed = math.clamp(merged.closeSpeed, 20, 400) end
    if type(merged.tpSafeMode) == "boolean" then _G.MeerkoTPSafeMode = merged.tpSafeMode end
    if type(merged.tpSafeSpeed) == "number" then _G.MeerkoTPSafeSpeed = math.clamp(merged.tpSafeSpeed, 180, 400) end
    if type(merged.tpSafeVerticalSpeed) == "number" then _G.MeerkoTPSafeVerticalSpeed = math.clamp(merged.tpSafeVerticalSpeed, 60, 160) end
    if type(merged.tpRetryCount) == "number" then _G.MeerkoTPRetryCount = math.clamp(merged.tpRetryCount, 0, 4) end
    if type(merged.tpKey) == "string" then _G._stp_tpKeyName = merged.tpKey end
    if type(merged.nearestKey) == "string" then _G.MeerkoNearestKey = merged.nearestKey end
    if type(merged.prioritySoundID) == "string" then _G.MeerkoPrioritySoundID = merged.prioritySoundID end
    _G.MeerkoStealMode = "priority"
    _G._stealUserOff = false
    if type(merged.priorityList) == "table" then
        local clean = {}
        for _, v in ipairs(merged.priorityList) do
            if type(v) == "string" and v ~= "" then clean[#clean + 1] = v end
        end
        if #clean > 0 then
            local L = _G.SHARED_PRIORITY_ITEMS
            table.clear(L)
            for i = 1, #clean do L[i] = clean[i] end
            _G.MeerkoPriVersion = _G.MeerkoPriVersion + 1
        end
    end
    if type(merged.priorityDefault) == "table" then
        local d = {}
        for _, v in ipairs(merged.priorityDefault) do
            if type(v) == "string" and v ~= "" then d[#d + 1] = v end
        end
        if #d > 0 then _G.MeerkoPriorityDefault = d end
    end
    if type(merged.invisAuto) == "boolean" then _G.MeerkoInvisAuto = merged.invisAuto end
    if type(merged.invisDepth) == "number" then _G.MeerkoInvisDepth = math.clamp(merged.invisDepth, 0, 10) end
    if type(merged.invisAngle) == "number" then _G.MeerkoInvisAngle = math.clamp(merged.invisAngle, 0, 360) end
    if type(merged.autoTp) == "boolean" then _G.MeerkoAutoTP = merged.autoTp end
    if type(merged.autoBuy) == "boolean" then _G.MeerkoAutoBuy = merged.autoBuy end
    if type(merged.autoBuyRange) == "number" then _G.MeerkoAutoBuyRange = math.clamp(merged.autoBuyRange, 5, 40) end
    if type(merged.autoBuyHover) == "number" then _G.MeerkoAutoBuyHover = math.clamp(merged.autoBuyHover, 0, 20) end
    if type(merged.panelX) == "number" then _G._stp_panelX = merged.panelX end
    if type(merged.panelY) == "number" then _G._stp_panelY = merged.panelY end
    if type(merged.panelPos) == "table" then _G._stp_pos = merged.panelPos end
    if type(merged.autoKickOnSteal) == "boolean" then _G.MeerkoAutoKickOnSteal     = merged.autoKickOnSteal end
    if type(merged.resetKey)        == "string"  then _G.MeerkoResetKeyName        = merged.resetKey end
    if type(merged.cloneKey)        == "string"  then _G.MeerkoCloneKeyName        = merged.cloneKey end
    if type(merged.carpetSpeedKey)  == "string"  then _G.MeerkoCarpetSpeedKeyName  = merged.carpetSpeedKey end
    if type(merged.kickKey)         == "string"  then _G.MeerkoKickKeyName         = merged.kickKey end
    if type(merged.stopTpKey)       == "string"  then _G.MeerkoStopTPKeyName       = merged.stopTpKey end
    if type(merged.dropKey)         == "string"  then _G.MeerkoDropKeyName         = merged.dropKey end
    if type(merged.goSpeed)      == "number"  then _G.MeerkoGoSpeed            = math.clamp(merged.goSpeed, 80, 600) end
    if type(merged.kickToPS)     == "boolean" then _G.MeerkoKickToPS           = merged.kickToPS end
    if type(merged.psLink)       == "string"  then _G.MeerkoPrivateServerLink  = merged.psLink end
    if type(merged.priAlert)     == "boolean" then _G.MeerkoPriAlert           = merged.priAlert end
    if type(merged.alertSound)   == "string"  then _G.MeerkoAlertSound         = merged.alertSound end
    if type(merged.alertMinGen)  == "number"  then _G.MeerkoAlertMinGen        = merged.alertMinGen end
    if type(merged.walkSpeedOn)  == "boolean" then _G.MeerkoWalkSpeedOn        = merged.walkSpeedOn end
    if type(merged.xray)         == "boolean" then _G.MeerkoXray               = merged.xray end
    if type(merged.antiFlash)    == "boolean" then _G.MeerkoAntiFlash          = merged.antiFlash end
    if type(merged.faceAway)        == "boolean" then _G.MeerkoFaceAway        = merged.faceAway end
    if type(merged.faceAwayNearest) == "boolean" then _G.MeerkoFaceAwayNearest = merged.faceAwayNearest end
    if type(merged.faceAwayDelay)   == "number"  then _G.MeerkoFaceAwayDelay   = merged.faceAwayDelay end
    if type(merged.antiBee)      == "boolean" then _G.MeerkoAntiBee            = merged.antiBee end
    if type(merged.infJump)      == "boolean" then _G.MeerkoInfJump            = merged.infJump end
    if type(merged.antiDie)      == "boolean" then _G.AntiDieDisabled          = not merged.antiDie end
    if type(merged.carpetSpeedValue) == "number" then _G.MeerkoCarpetSpeedValue = merged.carpetSpeedValue end
    if type(merged.exX) == "number" then _G._meerko_exX = merged.exX end
    if type(merged.exY) == "number" then _G._meerko_exY = merged.exY end
    if type(merged.fX)  == "number" then _G._meerko_fX  = merged.fX  end
    if type(merged.fY)  == "number" then _G._meerko_fY  = merged.fY  end
    if type(merged.kX)  == "number" then _G._meerko_kX  = merged.kX  end
    if type(merged.kY)  == "number" then _G._meerko_kY  = merged.kY  end

    _G.MeerkoAutoTP = true
    if writefile then
        pcall(function()
            local t = type(fileData) == "table" and fileData or {}
            t.autoTp = true
            writefile("SideTP.json", _HS:JSONEncode(t))
        end)
    end
end

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local RS         = game:GetService("ReplicatedStorage")

local LP = Players.LocalPlayer

if _G.MeerkoNoZeroVel == nil then _G.MeerkoNoZeroVel = false end
function _vzOK()
    if _G.MeerkoNoZeroVel == true then return false end
    if _G.MeerkoZeroWhileStealing ~= true and LP:GetAttribute("Stealing") == true then return false end
    return true
end
function _vzL(p)
    if p and _vzOK() then
        p.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    end
end
function _vzA(p)
    if p and _vzOK() then
        p.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    end
end

_BLOCKING_MACHINE_TYPES = {
    Fuse     = true,
    Duel     = true,
    Trade    = true,
    Crafting = true,
}
function _MeerkoIsFusing(animalData)
    if type(animalData) ~= "table" then return false end
    local m = animalData.Machine
    if type(m) ~= "table" then return false end
    return _BLOCKING_MACHINE_TYPES[m.Type] == true
end

do
local RS = game:GetService("ReplicatedStorage")
local _netFolder = RS:WaitForChild("Packages"):WaitForChild("Net")
local _net, _spoofed
-- Requiring the Net module is now opt-in. Without it _get() returns nil and
-- callers fall back to structural resolution / the UI path, same as Elite.
local function _getNet()
    if _G.MeerkoNetSpoofEnable ~= true then return nil end
    if _net then return _net end
    local ok, m = pcall(require, _netFolder)
    if ok and type(m) == "table" then _net = m end
    return _net
end
local function _spoofFn(Net, fname)
    local f = rawget(Net, fname)
    if type(f) ~= "function" then return end
    local og = getfenv
    if type(og) ~= "function" then return end
    local env = og(f)
    if type(env) ~= "table" then return end
    env.getfenv = function() return og(f) end
    if type(env.debug) == "table" then
        if setreadonly then pcall(setreadonly, env.debug, false) end
        env.debug.getmemorycategory = function() return "--" end
    end
end
local function _spoof()
    if _G.MeerkoNetSpoofEnable ~= true then return false end
    if _G.MeerkoNetSpoof then return _G.MeerkoNetSpoof() end
    if _spoofed then return true end
    local Net = _getNet()
    if not Net then return false end
    pcall(function()
        _spoofFn(Net, "RemoteEvent")
        _spoofFn(Net, "RemoteFunction")
        _spoofFn(Net, "UnreliableRemoteEvent")
    end)
    _spoofed = true
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
    local Net = _getNet()
    if not Net then return nil end
    _spoof()
    local ok, inst = pcall(function()
        if kind == "RemoteFunction" then return Net:RemoteFunction(logical) end
        if kind == "UnreliableRemoteEvent" then return Net:UnreliableRemoteEvent(logical) end
        return Net:RemoteEvent(logical)
    end)
    if ok and typeof(inst) == "Instance" then
        _cache[ck] = inst
        return inst
    end
    return nil
end
_G.MeerkoNet = {
    RemoteEvent = function(_, name) return _get(name, "RemoteEvent") end,
    RemoteFunction = function(_, name) return _get(name, "RemoteFunction") end,
    UnreliableRemoteEvent = function(_, name) return _get(name, "UnreliableRemoteEvent") end,
}
_G.MeerkoGetRemote = _get
_G.Resolve = _get
_G.__secureGetRemote = function(method, name) return _get(name, method) end
do
    local _dummy = Instance.new("RemoteEvent")
    local _rawFire = (clonefunction and clonefunction(_dummy.FireServer)) or _dummy.FireServer
    _G.RawFire = function(name, ...)
        local r = _get(name)
        if not r then return false end
        _rawFire(r, ...)
        return true
    end
end
end

do
local _xchan
local _lastTry, _attempts = 0, 0
local _deepScans, _lastDeep = 0, 0
local _mod

local MAX_ATTEMPTS, RETRY_GAP = 40, 0.5
local BOOT_T0, BOOT_BURST, BOOT_GAP = os.clock(), 3.0, 0.10
local MAX_DEEP, DEEP_GAP = 3, 1.5

local RS_SYNC = game:GetService("ReplicatedStorage")
local _mask_sc
local function _getMask()
    if _mask_sc and _mask_sc.Parent then return _mask_sc end
    local c = RS_SYNC:FindFirstChild("Controllers")
    _mask_sc = c and c:FindFirstChild("PlotController")
    return _mask_sc
end
local secure_call = _G.secure_call
if type(secure_call) ~= "function" then
    local LAYERS = 2
    local TEMPLATE do
        local lines = {
            "return function(__renv, __func, ...)",
            "\tsetfenv(0, __renv)",
            ("\tlocal function l%d(...) return __func(...) end"):format(LAYERS),
        }
        for c = LAYERS - 1, 1, -1 do
            lines[#lines + 1] = ("\tlocal function l%d(...) return l%d(...) end"):format(c, c + 1)
        end
        lines[#lines + 1] = "\treturn l1(...)"
        lines[#lines + 1] = "end"
        TEMPLATE = table.concat(lines, string.char(10))
    end
    local _gti = getthreadidentity or get_thread_identity or getidentity
    local _sti = setthreadidentity or set_thread_identity or setidentity
    local _sentinel
    secure_call = function(func, mask, ...)
        if type(func) ~= "function" or typeof(mask) ~= "Instance" then return nil end
        if not (_gti and _sti and getrenv and loadstring and setfenv) then return nil end
        local renv = getrenv()
        if not _sentinel then
            local ok, env = pcall(getsenv, mask)
            if not ok or type(env) ~= "table" then
                env = setmetatable({ script = mask, _G = {}, shared = {} }, { __index = renv, __newindex = renv })
            end
            local loader = loadstring(TEMPLATE, "=" .. mask:GetFullName())
            if not loader then return nil end
            setfenv(loader, env)
            _sentinel = loader()
        end
        local level = _gti()
        local changed = {}
        local okU, snap = pcall(debug.getupvalues, func)
        if okU and type(snap) == "table" then
            for i, v in pairs(snap) do
                if typeof(v) == "Instance" and v:IsA("LuaSourceContainer") then
                    if pcall(debug.setupvalue, func, i, mask) then changed[i] = v end
                end
            end
        end
        _sti(2)
        local co, args = coroutine.create(_sentinel), table.pack(renv, func, ...)
        local response, err
        while true do
            local r = table.pack(coroutine.resume(co, table.unpack(args, 1, args.n)))
            if not r[1] then err = r[2] break end
            if coroutine.status(co) == "dead" then response = table.pack(table.unpack(r, 2, r.n)) break end
            args = table.pack(coroutine.yield(table.unpack(r, 2, r.n)))
        end
        _sti(level)
        for i, orig in pairs(changed) do pcall(debug.setupvalue, func, i, orig) end
        if err or not response then return nil end
        return table.unpack(response, 1, response.n)
    end
    _G.secure_call = secure_call
end
local _syncMod_sc, _nextTry_sc = nil, 0
local function _getSyncMod()
    if _syncMod_sc then return _syncMod_sc end
    local p = RS_SYNC:FindFirstChild("Packages")
    local m = p and p:FindFirstChild("Synchronizer")
    if not m then return nil end
    local ok, mod = pcall(require, m)
    if ok and type(mod) == "table" then _syncMod_sc = mod end
    return _syncMod_sc
end
_G.__secureChans = function()
    if os.clock() < _nextTry_sc then return _xchan end
    local sync = _getSyncMod()
    if not sync then _nextTry_sc = os.clock() + 0.1; return _xchan end
    if type(sync.GetAllChannels) ~= "function" then _nextTry_sc = os.clock() + 0.1; return _xchan end
    local mask = _getMask()
    if not mask then _nextTry_sc = os.clock() + 0.1; return _xchan end
    local ok, reg = pcall(secure_call, sync.GetAllChannels, mask)
    if ok and type(reg) == "table" then
        _xchan = reg; _nextTry_sc = os.clock() + 1.5
        _G.MeerkoSyncDiag = "GetAllChannels (secure_call) - undetect/instant"
    else
        _nextTry_sc = os.clock() + 0.1
    end
    return _xchan
end

local function _retryGap()
    if (os.clock() - BOOT_T0) < BOOT_BURST then return BOOT_GAP end
    return RETRY_GAP
end

local function _channelCount(t)
    if type(t) ~= "table" then return 0 end
    local ok, hits = pcall(function()
        local h, n = 0, 0
        for _, v in next, t do
            n = n + 1
            if type(v) == "table" and type(rawget(v, "CacheTable")) == "table" then
                h = h + 1
            end
            
            if n >= 50 then break end
        end
        return h
    end)
    return (ok and hits) or 0
end

local function _module()
    if _mod then return _mod end
    local ok, m = pcall(function()
        return require(game:GetService("ReplicatedStorage").Packages.Synchronizer)
    end)
    if ok and type(m) == "table" then _mod = m; return _mod end
    local ok2, m2 = pcall(function()
        local pkgs = game:GetService("ReplicatedStorage"):FindFirstChild("Packages")
        local sync = pkgs and pkgs:FindFirstChild("Synchronizer")
        if not sync then return nil end
        return require(sync)
    end)
    if ok2 and type(m2) == "table" then _mod = m2 end
    return _mod
end

local function _probe(mod)
    local gu = (debug and debug.getupvalue) or getupvalue
    if type(gu) ~= "function" then return nil, 0, nil end
    local best, bestN, where = nil, 0, nil
    local function consider(t, tag)
        local n = _channelCount(t)
        if n > bestN then best, bestN, where = t, n, tag end
    end
    local cands = {
        { mod.Get, 10, 4, "Get/10/4" },
        { mod.GetAllChannels, 10, 1, "GetAll/10/1" },
        { mod.Wait, 10, 1, "Wait/10/1" },
    }
    for _, c in ipairs(cands) do
        if type(c[1]) == "function" then
            local o, u = pcall(gu, c[1], c[2])
            if o and type(u) == "table" then
                consider(rawget(u, c[3]), c[4])
                if bestN > 0 then return best, bestN, where end
            end
        end
    end
    for _, fn in ipairs({ mod.Get, mod.GetAllChannels, mod.Wait, mod.WaitAndCall, mod.GetTableFromChannel }) do
        if type(fn) == "function" then
            for i = 8, 12 do
                local o, u = pcall(gu, fn, i)
                if o and type(u) == "table" then
                    consider(u, "up" .. i)
                    for j = 1, 4 do consider(rawget(u, j), "up" .. i .. "/" .. j) end
                    if bestN > 0 then return best, bestN, where end
                end
            end
        end
    end
    local ok, up = pcall(gu, mod.Get, 9)
    if ok and type(up) == "table" then
        consider(rawget(up, 3), "Get/9/3")
        if bestN > 0 then return best, bestN, where end
        consider(up, "Get/9")
        if bestN > 0 then return best, bestN, where end
    end
    return best, bestN, where
end

local function _deepScan(mod)
    local gu = (debug and debug.getupvalue) or getupvalue
    if type(gu) ~= "function" then return nil, 0, nil end
    local best, bestN, where = nil, 0, nil
    local function consider(t, tag)
        local n = _channelCount(t)
        if n > bestN then best, bestN, where = t, n, tag end
    end
    for fname, fn in next, mod do
        if type(fn) == "function" then
            for i = 1, 24 do
                local o, u = pcall(gu, fn, i)
                if not o then break end
                if type(u) == "table" then
                    consider(u, tostring(fname) .. "/" .. i)
                    for j = 1, 4 do
                        consider(rawget(u, j), tostring(fname) .. "/" .. i .. "/" .. j)
                    end
                end
            end
        end
    end
    return best, bestN, where
end

local _gcFound, _gcFoundN, _gcState = nil, 0, "idle"

local function _gcScanOnce()
    if type(getgc) ~= "function" then return end
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return end
    local live, nLive = {}, 0
    for _, p in ipairs(plots:GetChildren()) do live[p.Name] = true; nLive = nLive + 1 end
    if nLive == 0 then return end

    local best, bestN = nil, 0
    pcall(function()
        local gc = getgc(true)
        for i = 1, #gc do
            local t = gc[i]
            if type(t) == "table" then
                pcall(function()
                    
                    local pk = 0
                    for k in next, t do
                        if type(k) == "string" and live[k] then pk = pk + 1; if pk >= 2 then break end end
                    end
                    if pk < 2 then return end
                    local hits, seen = 0, 0
                    for k, v in next, t do
                        seen = seen + 1
                        if type(k) == "string" and live[k]
                            and type(v) == "table" and type(rawget(v, "CacheTable")) == "table" then
                            hits = hits + 1
                        end
                        if seen >= 64 then break end
                    end
                    if hits > bestN and hits >= 2 then best, bestN = t, hits end
                end)
                if bestN >= nLive then break end
            end
        end
    end)
    if best and bestN > _gcFoundN then _gcFound, _gcFoundN = best, bestN end
end

local _gcLastScan = 0
local _gcRescans = 0
local function _gcChans()
    if _gcFound then
        local _pl = workspace:FindFirstChild("Plots")
        local _nLive = _pl and #_pl:GetChildren() or 0
        if _G.MeerkoSyncRescan == true and _gcFoundN < _nLive
            and _gcRescans < (tonumber(_G.MeerkoSyncMaxRescan) or 20)
            and (os.clock() - _gcLastScan) >= (tonumber(_G.MeerkoSyncRescanGap) or 3) then
            _gcLastScan = os.clock()
            _gcRescans = _gcRescans + 1
            _gcScanOnce()
        end
        return _gcFound, _gcFoundN, "getgc/plot-key+CacheTable"
    end
    if os.clock() - _gcLastScan < (tonumber(_G.MeerkoSyncScanGap) or 0.2) then return nil, 0, nil end
    _gcLastScan = os.clock()
    _gcScanOnce()
    if _gcFound then return _gcFound, _gcFoundN, "getgc/plot-key+CacheTable" end
    return nil, 0, nil
end

local function _apiChans(mod)
    if type(mod) ~= "table" then return nil, 0, nil end
    local fn = rawget(mod, "GetAllChannels")
    if type(fn) ~= "function" then return nil, 0, nil end
    local function _accept(reg, tag)
        if type(reg) ~= "table" then return nil, 0, nil end
        local n = _channelCount(reg)
        if n > 0 then return reg, n, tag end
        return nil, 0, nil
    end
    local mask = _getMask()
    if _G.MeerkoAllowSecureSyncCall and mask and type(secure_call) == "function" then
        for _, form in ipairs({ "self", "plain" }) do
            local ok, reg = pcall(function()
                if form == "self" then return secure_call(fn, mask, mod) end
                return secure_call(fn, mask)
            end)
            if ok then
                local r, n, t = _accept(reg, "GetAllChannels/secure_call(" .. form .. ")")
                if r then return r, n, t end
            end
        end
    end
    if _G.MeerkoAllowRawSyncCall then
        for _, form in ipairs({ "self", "plain" }) do
            local ok, reg = pcall(function()
                if form == "self" then return fn(mod) end
                return fn()
            end)
            if ok then
                local r, n, t = _accept(reg, "GetAllChannels/RAW(" .. form .. ")")
                if r then return r, n, t end
            end
        end
    end
    return nil, 0, nil
end

local _xchan2, _nextTry2, _attempts2 = nil, 0, 0
local _xchan2Until = 0
local function _chans()
    if _xchan2 then
        local now = os.clock()
        if now < _xchan2Until then return _xchan2 end
        if _channelCount(_xchan2) > 0 then _xchan2Until = now + 2 return _xchan2 end
    end
    if os.clock() < _nextTry2 then return _xchan2 end
    _attempts2 = _attempts2 + 1

    local best, n, where = _gcChans()

    if (not best or n == 0) and _attempts2 <= 400
        and (_G.MeerkoAllowUpvalueProbe or _G.MeerkoAllowSecureSyncCall or _G.MeerkoAllowRawSyncCall) then
        local mod = _getSyncMod()
        if mod then
            if _G.MeerkoAllowUpvalueProbe then
                best, n, where = _probe(mod)
                if (not best or n == 0) and os.clock() - _lastDeep > 1 then
                    _lastDeep = os.clock()
                    _deepScans = _deepScans + 1
                    best, n, where = _deepScan(mod)
                end
            end
            if not best or n == 0 then best, n, where = _apiChans(mod) end
        end
    end
    if best and n > 0 then
        _xchan2 = best
        _G.MeerkoSyncDiag = string.format("rawget/CacheTable scoring via %s - %d channels", tostring(where), n)
        return _xchan2
    end
    _nextTry2 = os.clock() + 0.1
    return _xchan2
end
_G.__secureChans = _chans

_G.MeerkoSyncAll=function()return _chans()end
_G.MeerkoSyncGet=function(idx)
local t=_chans()
if not t or idx==nil then return nil end
local ok,cd=pcall(rawget,t,idx)
if ok and type(cd)=="table" then return cd end
local ok2,cd2=pcall(function() return t[idx] end)
if ok2 and type(cd2)=="table" then return cd2 end
return nil
end
_G.sProp=function(ch,key)
if type(ch)~="table" or key==nil then return nil end
local ct=rawget(ch,"CacheTable")
if type(ct)~="table" then
local okC,c2=pcall(function() return ch.CacheTable end)
if okC and type(c2)=="table" then ct=c2 end
end
if type(ct)~="table" then return nil end
local v=rawget(ct,key)
if v~=nil then return v end
local okV,v2=pcall(function() return ct[key] end)
if okV then return v2 end
return nil
end
_G._meerkoRawCT=function(plotName)
local c=_G.MeerkoSyncGet(plotName)
if not c then return nil end
return rawget(c,"CacheTable")
end
local _AD,_MD,_TD
local function _data()
if _AD then return true end
local ok=pcall(function()
local d=game:GetService("ReplicatedStorage"):WaitForChild("Datas")
_AD=require(d:WaitForChild("Animals"))
_MD=require(d:WaitForChild("Mutations"))
_TD=require(d:WaitForChild("Traits"))
end)
return ok and _AD~=nil
end
_G._meerkoGen=function(index,mutation,traits)
if not _data() then return 0 end
local info=_AD[index]
if not info or not info.Generation then return 0 end
local mult=1
if mutation and mutation~="None" and mutation~="" then
local m=_MD[mutation]
if m and m.Modifier then mult=mult+m.Modifier end
end
if type(traits)=="table" then
for _,tr in ipairs(traits)do
local t=_TD[tr]
if t and t.MultiplierModifier then mult=mult+t.MultiplierModifier end
end
end
return info.Generation*mult
end
_G._meerkoAnimShim=setmetatable({GetGeneration=function(_,index,mutation,traits)return _G._meerkoGen(index,mutation,traits)end},{
__index=function(_,k)
local ok,real=pcall(function()return require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Animals"))end)
if ok and type(real)=="table" then return rawget(real,k) end
return nil
end})
_G.Meerko_GetPlotChannel=function(plotName)return _G.MeerkoSyncGet(plotName)end
_G.Meerko_GetAllPlots=function()return _G.MeerkoSyncAll() or {} end
_G.Meerko_GetPlotAnimalList=function(plotName)
local ct=_G._meerkoRawCT(plotName)
local al=ct and ct.AnimalList
return type(al)=="table" and al or nil
end
end

_G.MeerkoSyncAll  = _G.MeerkoSyncAll
_G.MeerkoSyncGet  = _G.MeerkoSyncGet
_G.MeerkoRawCT    = _G._meerkoRawCT
_G.MeerkoGen      = _G._meerkoGen
_G.MeerkoAnimShim = _G._meerkoAnimShim
_G.stealthGet    = function(n) return _G.MeerkoSyncGet(n) end
_G.SyncInt       = {_cache={},_data=nil}

task.spawn(function() for _=1,150 do if _G.MeerkoSyncAll() then break end task.wait(0.04) end end)

_G.MeerkoGetSyncData = _G.MeerkoGetSyncData or function(plot)
    local plotName = type(plot) == "string" and plot or (plot and plot.Name)
    if not plotName then return nil end
    local Pkgs = game:GetService("ReplicatedStorage"):FindFirstChild("Packages")
    local Sync = Pkgs and Pkgs:FindFirstChild("Synchronizer")
    if not Sync then return nil end
    local okMod, mod = pcall(require, Sync)
    if not okMod or type(mod) ~= "table" then return nil end

    local okT, data = pcall(function() return _G.MeerkoRawCT(plotName) end)
    if okT and type(data) == "table" then return data end

    local okC, ch = pcall(function() return _G.MeerkoSyncGet(plotName) end)
    if okC and ch then
        local synth = { __channel = ch }
        pcall(function() local ct = rawget(ch, "CacheTable"); if type(ct)=="table" then synth.AnimalList = ct.AnimalList; synth.Owner = ct.Owner end end)
        return synth
    end
    return nil
end


_mkNextModTry = 0
function loadModules()
    if AnimalsData then return true end
    if os.clock() < _mkNextModTry then return false end
    _mkNextModTry = os.clock() + (tonumber(_G.MeerkoModRetry) or 3)
    pcall(function()
        local Datas = RS:FindFirstChild("Datas") or RS:WaitForChild("Datas", 5)
        if Datas then
            local a = Datas:FindFirstChild("Animals") or Datas:WaitForChild("Animals", 5)
            if a then AnimalsData = require(a) end
        end
    end)
    AnimalsShared = _G.MeerkoAnimShim
    if not NumberUtils then
        pcall(function()
            local Utils = RS:FindFirstChild("Utils")
            local n = Utils and Utils:FindFirstChild("NumberUtils")
            if n then NumberUtils = require(n) end
        end)
    end
    return AnimalsData ~= nil
end

function loadNet() return false end

function getRemote(method, name)
    return _G.__secureGetRemote(method, name)
end
_G.MeerkoGetRemote = getRemote

GRAPPLE_ARG = 0.8

--[[ Grapple: Elite method ----------------------------------------------------
     Old Meerko method: require ReplicatedStorage.Packages.Net, spoof getfenv +
     debug.getmemorycategory inside it, ask it for "UseItem", then blind-fire
     both candidate remotes with a bare constant (0.8) and no target.

     Elite method (implemented below):
       * resolve UseItem by INSTANCE STRUCTURE, never requiring the Net module
         (no getfenv / setreadonly / debug tampering = no detection surface)
       * gate on the tool's own cooldown (Tool.Enabled) before firing
       * fire (amount, position) with a real raycast target, amount scaled to
         distance, instead of a constant with no target
       * quiet mode: mute the hook's Sounds/Beams, drop the server-side
         FlightPower, and hold velocity down so the pull does not fight the TP
       * invalidate + re-resolve automatically if FireServer errors

     Set _G.MeerkoGrappleLegacy = true to restore the old blind-fire path.
--------------------------------------------------------------------------- ]]

do
local _WSg = game:GetService("Workspace")

-- Net children are named "<prefix>/<64 hex>". Exactly one leaf hash is claimed
-- by two instances (a RemoteEvent + RemoteFunction pair); UseItem is the slot
-- immediately before that anchor. Cached per JobId since hashes reroll per server.
function _grappleResolveUseItem()
    local c = _G.__MeerkoUseItem
    if c and _G.__MeerkoUseItemJob == game.JobId
        and c.Parent and c.ClassName == "RemoteEvent" then
        return c
    end
    _G.__MeerkoUseItem    = nil
    _G.__MeerkoUseItemJob = game.JobId
    local pkgs = RS:FindFirstChild("Packages")
    local Net  = pkgs and pkgs:FindFirstChild("Net")
    if not Net then return nil end
    local slots, byLeaf = {}, {}
    for i, ch in ipairs(Net:GetChildren()) do
        local pre, rest = string.match(ch.Name, "^([%a_]+)/(.+)$")
        if pre and #rest == 64 and string.match(rest, "^%x+$") then
            slots[i] = ch
            byLeaf[rest] = byLeaf[rest] or {}
            table.insert(byLeaf[rest], { slot = i, class = ch.ClassName })
        end
    end
    local anchor, dual = nil, 0
    for _, list in pairs(byLeaf) do
        if #list > 1 then
            dual = dual + 1
            for _, e in ipairs(list) do
                if e.class == "RemoteEvent" then anchor = e.slot end
            end
        end
    end
    if dual ~= 1 or not anchor then return nil end
    local t = slots[anchor - 1]
    if t and t.ClassName == "RemoteEvent" and t.Parent == Net then
        _G.__MeerkoUseItem = t
        return t
    end
    return nil
end
_G.MeerkoResolveUseItem = _grappleResolveUseItem

function _grappleInvalidate()
    _G.__MeerkoUseItem, _G.__MeerkoUseItemJob = nil, nil
end
_G.MeerkoGrappleInvalidate = _grappleInvalidate

task.spawn(function() _grappleUseItem = getRemote("RemoteEvent", "UseItem") end)
task.spawn(function() _grappleItemUse = getRemote("RemoteEvent", "75c9466d-e4c0-4b02-b26a-c3615fcc1e42") end)
function _grappleRemoteGet()
    return _grappleResolveUseItem()
        or (_grappleUseItem and _grappleUseItem.Parent and _grappleUseItem)
        or (_grappleItemUse and _grappleItemUse.Parent and _grappleItemUse)
        or getRemote("RemoteEvent", "UseItem")
end
_G.MeerkoGrappleRemote = _grappleRemoteGet

local _gMuteCache = setmetatable({}, { __mode = "k" })
local function _gCollectMutes(tool)
    local e = _gMuteCache[tool]
    if e and (os.clock() - e.t) < 8 and tool.Parent then return e end
    local snd, bm = {}, {}
    pcall(function()
        local scanned = 0
        for _, s in ipairs(tool:GetDescendants()) do
            scanned = scanned + 1
            if scanned > 500 then break end
            if s:IsA("Sound") then snd[#snd + 1] = s
            elseif s:IsA("Beam") then bm[#bm + 1] = s end
        end
    end)
    e = { t = os.clock(), snd = snd, bm = bm }
    _gMuteCache[tool] = e
    return e
end

local function _gMuteAndStopPull(tool, hrp)
    if tool and tool.Parent then
        local e = _gCollectMutes(tool)
        for _, s in ipairs(e.snd) do
            if s.Parent then pcall(function() s.Volume = 0; s:Stop() end) end
        end
        for _, b in ipairs(e.bm) do
            if b.Parent then pcall(function() b.Enabled = false; b.Attachment0 = nil end) end
        end
    end
    if hrp and hrp.Parent then
        local fp = hrp:FindFirstChild("FlightPower")
        if fp then pcall(function() fp:Destroy() end) end
        -- never fight velMoveThrough / cframeStepThrough while a TP is running
        if not isTeleporting and not _G.MeerkoTPBusy then
            _vzL(hrp)
            _vzA(hrp)
        end
    end
end

-- one hold loop at a time; re-firing the hook just extends the existing one so
-- the 0.3s in-TP fire cadence cannot stack Heartbeat connections
local _gHoldUntil, _gHoldConn = 0, nil
local function _gHoldNoPull(tool, hrp, seconds)
    _gHoldUntil = os.clock() + seconds
    if _gHoldConn then return end
    local last = 0
    _gHoldConn = RunService.Heartbeat:Connect(function()
        local now = os.clock()
        if now - last >= 0.03 then
            last = now
            _gMuteAndStopPull(tool, hrp)
        end
        if now > _gHoldUntil then
            if _gHoldConn then _gHoldConn:Disconnect(); _gHoldConn = nil end
            _gMuteAndStopPull(tool, hrp)
        end
    end)
end

function _grappleToolReady(tool, waitS)
    if not tool or not tool.Parent then return false end
    local t0 = os.clock()
    while true do
        local ok, en = pcall(function() return tool.Enabled end)
        if not ok or en ~= false then return true end
        if os.clock() - t0 > (tonumber(waitS) or 0) then return false end
        RunService.Heartbeat:Wait()
        if not tool.Parent then return false end
    end
end
_G.MeerkoToolReady = _grappleToolReady

function _grappleDo(tool, pos, target, char)
    if not tool or not pos then return false end
    if typeof(pos) == "Instance" then pos = pos.Position end
    if typeof(pos) == "CFrame"   then pos = pos.Position end
    if typeof(pos) ~= "Vector3" then
        _G.MeerkoGrappleWhy = "bad target position"
        return false
    end
    char = char or LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        _G.MeerkoGrappleWhy = "no hrp"
        return false
    end
    if not _grappleToolReady(tool, tonumber(_G.MeerkoGrappleCooldownWait) or 0.35) then
        _G.MeerkoGrappleWhy = "hook on cooldown (Enabled=false)"
        return false
    end
    local r = _grappleRemoteGet()
    if not r then
        _G.MeerkoGrappleWhy = "unresolved"
        return false
    end
    local mag = (pos - hrp.Position).Magnitude
    local amt = math.clamp(mag / 120, 0, 2)
    local quiet = (_G.MeerkoGrappleQuiet ~= false)
    if quiet then _gMuteAndStopPull(tool, hrp) end
    local ok, err = pcall(function() r:FireServer(amt, pos) end)
    if not ok then
        _grappleInvalidate()
        r = _grappleRemoteGet()
        if r then
            ok, err = pcall(function() r:FireServer(amt, pos) end)
        end
    end
    if quiet then
        _gMuteAndStopPull(tool, hrp)
        _gHoldNoPull(tool, hrp, tonumber(_G.MeerkoGrappleQuietFor) or 0.6)
    end
    _G.MeerkoGrappleWhy = ok and "ok" or tostring(err)
    return ok and true or false
end
_G.MeerkoGrappleDo = _grappleDo

local function _grappleLegacyFire()
    local fired = false
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
    _G.MeerkoGrappleWhy = fired and "ok (legacy)" or "legacy: no remote"
    return fired
end

local _GFAN  = { 9, 10, 11, 12, 13, 14, 16, 18, 21, 24, 28, 32, 36, 40, 45 }
local _GFAN2 = { 11, 14, 18, 24, 32, 42, 48 }
local _GCOMPASS = {
    Vector3.new( 1, 0,  0), Vector3.new(-1, 0,  0),
    Vector3.new( 0, 0,  1), Vector3.new( 0, 0, -1),
    Vector3.new( 0.7, 0,  0.7), Vector3.new( 0.7, 0, -0.7),
    Vector3.new(-0.7, 0,  0.7), Vector3.new(-0.7, 0, -0.7),
}

-- _fireGrapple()            -> pick a target in front / around and hook it
-- _fireGrapple(vec3)        -> aim toward that point, still snapped to real geometry
-- _fireGrapple(vec3, true)  -> hook exactly that point (must be 10-50 studs out)
function _fireGrapple(value, exact)
    if _G.MeerkoGrappleLegacy == true then return _grappleLegacyFire() end

    local char = LP.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    if LP:GetAttribute("Stealing") and _G.MeerkoNoGrappleWhileCarrying == true then
        _G.MeerkoGrappleWhy = "refused: carrying a brainrot"
        return false
    end

    local tool = char:FindFirstChild("Grapple Hook") or (findGrapple())
    if tool and tool.Parent ~= char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then return false end
        pcall(function() hum:EquipTool(tool) end)
        local t0 = os.clock()
        repeat
            RunService.Heartbeat:Wait()
            char = LP.Character
            tool = char and (char:FindFirstChild("Grapple Hook") or (findGrapple()))
        until (tool and tool.Parent == char) or os.clock() - t0 > 0.5
        hrp = char and char:FindFirstChild("HumanoidRootPart")
    end
    if not tool or not hrp then return false end

    local par = RaycastParams.new()
    par.FilterType = Enum.RaycastFilterType.Exclude
    par.FilterDescendantsInstances = { char }

    if exact and typeof(value) == "Vector3" then
        local m = (value - hrp.Position).Magnitude
        if m < 10 or m > 50 then return false end
        local target
        local hit = _WSg:Raycast(hrp.Position, value - hrp.Position, par)
        if hit then target = hit.Instance end
        if not target then
            local okb, parts = pcall(function() return _WSg:GetPartBoundsInRadius(value, 6) end)
            if okb and parts then
                for _, p in ipairs(parts) do
                    if p:IsA("BasePart") and not p:IsDescendantOf(char) then target = p; break end
                end
            end
        end
        if not target then return false end
        return _grappleDo(tool, value, target, char)
    end

    local dest
    if typeof(value) == "Vector3" then dest = value
    elseif typeof(value) == "Instance" and value:IsA("BasePart") then dest = value.Position end

    local dir
    if dest then
        local d = dest - hrp.Position
        dir = Vector3.new(d.X, 0, d.Z)
    end
    if not dir or dir.Magnitude < 1 then
        local lv = hrp.CFrame.LookVector
        dir = Vector3.new(lv.X, 0, lv.Z)
    end
    if dir.Magnitude < 0.01 then return false end
    dir = dir.Unit

    local pos, target, bestM
    for _, d in ipairs(_GFAN) do
        local origin = hrp.Position + dir * d + Vector3.new(0, 3, 0)
        local hit = _WSg:Raycast(origin, Vector3.new(0, -60, 0), par)
        if hit then
            local m = (hit.Position - hrp.Position).Magnitude
            if m >= 10 and m <= 50 and (not bestM or m < bestM) then
                pos, target, bestM = hit.Position, hit.Instance, m
            end
        end
    end
    if not pos then
        for _, d in ipairs(_GFAN2) do
            local hit = _WSg:Raycast(hrp.Position, dir * d, par)
            if hit then
                local m = (hit.Position - hrp.Position).Magnitude
                if m >= 10 and m <= 50 and (not bestM or m < bestM) then
                    pos, target, bestM = hit.Position, hit.Instance, m
                end
            end
        end
    end
    if not pos then
        for _, cd in ipairs(_GCOMPASS) do
            for _, d in ipairs(_GFAN) do
                local origin = hrp.Position + cd * d + Vector3.new(0, 3, 0)
                local hit = _WSg:Raycast(origin, Vector3.new(0, -70, 0), par)
                if hit then
                    local m = (hit.Position - hrp.Position).Magnitude
                    if m >= 10 and m <= 50 and (not bestM or m < bestM) then
                        pos, target, bestM = hit.Position, hit.Instance, m
                    end
                end
            end
        end
    end
    if not pos or not target then
        _G.MeerkoGrappleWhy = "no anchor within 10-50 studs"
        return false
    end
    return _grappleDo(tool, pos, target, char)
end
_G.MeerkoFireGrappleBoth = _fireGrapple

function fireGrapple(value, exact)
    local char = LP.Character
    if not char then return false end
    return _fireGrapple(value, exact)
end
_G.MeerkoFireGrapple = fireGrapple
_G.MeerkoGrappleReady = function()
    return findGrapple() ~= nil and _grappleRemoteGet() ~= nil
end
end
-- === end Elite-method grapple ==============================================

CARPET_SPEED = 280
INBASE_SPEED = 450
SKY_CLONE_WAIT = 0.35
CARPET_NAMES = { "Flying Carpet", "Waverider", "Santa's Sleigh", "Witch's Broom", "Cupid's Wings" }
function findTool(name)
    local char = LP.Character
    local bp = LP:FindFirstChild("Backpack")
    return (char and char:FindFirstChild(name)) or (bp and bp:FindFirstChild(name))
end
GRAPPLE_NAMES = { "Grapple Hook", "Grappling Hook", "Grapple", "Hook", "Web Slinger", "Grapple Gun", "GrappleHook" }
function findGrapple()
    for _, n in ipairs(GRAPPLE_NAMES) do
        local t = findTool(n)
        if t and t:IsA("Tool") then return t, n end
    end
    return nil
end
function listTools()
    local out, char, bp = {}, LP.Character, LP:FindFirstChild("Backpack")
    if char then for _, t in ipairs(char:GetChildren()) do if t:IsA("Tool") then out[#out + 1] = t.Name end end end
    if bp then for _, t in ipairs(bp:GetChildren()) do if t:IsA("Tool") then out[#out + 1] = t.Name end end end
    return table.concat(out, ", ")
end
_lastCarpetName = nil
function equipCarpet()
    local char = LP.Character
    if not char then return nil end
    if _lastCarpetName then
        local t = char:FindFirstChild(_lastCarpetName)
        if t and t.Parent == char then return _lastCarpetName end
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return nil end
    for _, n in ipairs(CARPET_NAMES) do
        local t = findTool(n)
        if t and t:IsA("Tool") then
            if t.Parent ~= char then pcall(function() hum:EquipTool(t) end) end
            _lastCarpetName = n
            return n
        end
    end
    return nil
end
function setCarpetTool(name)
    if type(name) ~= "string" or name == "" then return end
    _G.MeerkoCarpetTool = name
    for i = #CARPET_NAMES, 1, -1 do
        if CARPET_NAMES[i] == name then table.remove(CARPET_NAMES, i) end
    end
    table.insert(CARPET_NAMES, 1, name)
end
_G.MeerkoSetCarpetTool = setCarpetTool
if type(_G.MeerkoCarpetTool) == "string" and _G.MeerkoCarpetTool ~= "" then
    setCarpetTool(_G.MeerkoCarpetTool)
end
_carpetEngaging = false
function carpetEngage(force)
    if not force then
        local c = LP.Character
        if c then
            for _, n in ipairs(CARPET_NAMES) do
                local t = c:FindFirstChild(n)
                if t and t:IsA("Tool") then
                    _G.TPEngage = "carpet=" .. tostring(n)
                    return n
                end
            end
        end
    end
    if _carpetEngaging then
        local _tw = os.clock()
        repeat RunService.Heartbeat:Wait() until (not _carpetEngaging) or os.clock() - _tw > 6
        local c = LP.Character
        if c then
            for _, n in ipairs(CARPET_NAMES) do
                local t = c:FindFirstChild(n)
                if t and t:IsA("Tool") then return n end
            end
        end
    end
    _carpetEngaging = true
    local _t0 = os.clock()
    while not findTool("Grapple Hook") and os.clock() - _t0 < 5 do
        RunService.Heartbeat:Wait()
    end
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not char or not hum then _carpetEngaging = false; return nil end

    if not char:FindFirstChild("Grapple Hook") then
        local g = findTool("Grapple Hook")
        if g then pcall(function() hum:EquipTool(g) end) end
    end
    local _te = os.clock()
    while not (LP.Character and LP.Character:FindFirstChild("Grapple Hook")) and os.clock() - _te < 1.5 do
        local c = LP.Character
        local h2 = c and c:FindFirstChildOfClass("Humanoid")
        local g = findTool("Grapple Hook")
        if g and h2 then pcall(function() h2:EquipTool(g) end) end
        RunService.Heartbeat:Wait()
    end
    if LP.Character and LP.Character:FindFirstChild("Grapple Hook") then
        _fireGrapple()
    end
    task.wait(0.05)
    local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if h then pcall(function() h:UnequipTools() end) end
    task.wait(0.05)
    local cn
    local _tc = os.clock()
    repeat
        cn = equipCarpet()
        local c = LP.Character
        if cn and c and c:FindFirstChild(cn) then break end
        RunService.Heartbeat:Wait()
    until os.clock() - _tc > 0.5
    _G.TPEngage = "carpet=" .. tostring(cn)
    _carpetEngaging = false
    return cn
end

_G.MeerkoEquipCarpet = equipCarpet
_G.MeerkoCarpetEngaging = function() return _carpetEngaging end

if _G.MeerkoKeepCarpet == nil then _G.MeerkoKeepCarpet = true end
LP.CharacterAdded:Connect(function(c)
    if _G.MeerkoKeepCarpet == false then return end
    task.spawn(function()
        c:WaitForChild("Humanoid", 10)
        task.wait(tonumber(_G.MeerkoCarpetRespawnDelay) or 0.6)
        if _G.MeerkoKeepCarpet == false then return end
        if _carpetEngaging or LP.Character ~= c then return end
        if LP:GetAttribute("Stealing") == true then return end
        for _, n in ipairs(CARPET_NAMES) do
            if c:FindFirstChild(n) then return end
        end
        pcall(equipCarpet)
    end)
end)

PET_PRIORITY_TIERS = {
    [1] = { pets = {"Headless Horseman"}, threshold = 0 },
    [2] = { pets = {"Signore Carapace"}, threshold = 0 },
    [3] = { pets = {"John Pork"}, threshold = 0 },
    [4] = { pets = {"Strawberry Elephant"}, threshold = 0 },
    [5] = { pets = {"Arcadragon"}, threshold = 5e9 },
    [6] = { pets = {"Elefanto Frigo"}, threshold = 10e9 },
    [7] = { pets = {"Meowl"}, threshold = 5e9 },
    [8] = { pets = {"Skibidi Toilet"}, threshold = 5e9 },
    [9] = { pets = {"Love Love Bear"}, threshold = 0 },
    [10] = { pets = {"Antonio"}, threshold = 0 },
    [11] = { pets = {"Pancake and Syrup"}, threshold = 0 },
    [12] = { pets = {"Griffin"}, threshold = 0 },
    [13] = { pets = {"Globa Steppa","La Supreme Combinasion","Fishino Clownino","Dragon Gingerini","Tirilikalika Tirilikalako"}, threshold = 5e9 },
    [14] = { pets = {"Ginger Gerat","Pet"}, threshold = 10e9 },
    [15] = { pets = {"Hydra Bunny","Digi Narwhal","Kalika Bros"}, threshold = 3e9 },
    [16] = { pets = {"Hydra Dragon Cannelloni","Dragon Cannelloni","Bunny and Eggy"}, threshold = 3e9 },
    [17] = { pets = {"Ketupat Bros","Rosey and Teddy","La Casa Boo","Fragola la la"}, threshold = 3e9 },
    [18] = { pets = {"Fragola La La La","Cerberus","Guest 666","Los Hackers"}, threshold = 1e9 },
    [19] = { pets = {"Garama and Madunung","Spooky and Pumpky","Reinito Sleighito","Burguro And Fryuro","Cooki and Milki","Fragrama and Chocrama","La Food Combinasion","Los Amigos","Foxini Lanternini","Capitano Moby","Fortunu and Cashuru","Los Sekolahs","Celestial Pegasus"}, threshold = 750e6 },
    [20] = { pets = {"La Secret Combinasion","Sammyni Fattini","Cloverat Clapat","Popcuru and Fizzuru"}, threshold = 1e9 },
}

TIER_LOOKUP = {}
for tier, data in pairs(PET_PRIORITY_TIERS) do
    for _, name in ipairs(data.pets) do TIER_LOOKUP[name] = tier end
end

LOCKED_TIERS = { [1]=true, [2]=true, [3]=true, [4]=true }

DIRECT_THRESHOLDS = {
    [3] = { [4] = 10e9 },
    [4] = {},
    [5] = { [6] = math.huge },
    [6] = { [9] = math.huge, [10] = math.huge, [12] = 15e9 },
    [10] = { [12] = 20e9 },
    [11] = { [12] = 10e9 },
}

MUTATION_PRIORITY = {
    ["Galaxy"]=1,["Candy"]=1,["Yin Yang"]=1,["YinYang"]=1,["Divine"]=1,
    ["Cursed"]=1,["Lava"]=1,["Radioactive"]=1,["Cyber"]=1,["Rainbow"]=1,["Bloodrot"]=2,
}

MUTATED_BEATS_GRIFFIN = {
    ["Fishino Clownino"]=true,["Globa Steppa"]=true,
    ["La Supreme Combinasion"]=true,["Tirilikalika Tirilikalako"]=true,
}

function getMutPrio(m)
    if not m or m == "" or m == "None" then return 0 end
    if MUTATION_PRIORITY[m] then return MUTATION_PRIORITY[m] end
    local n = tostring(m):lower():gsub("[%s%-_]","")
    if n == "bloodrot" then return 2 end
    if n == "yinyang" or n == "galaxy" or n == "candy" or n == "divine"
        or n == "cursed" or n == "lava" or n == "radioactive" or n == "cyber"
        or n == "rainbow" then return 1 end
    return 0
end

function getCumThreshold(hi, lo)
    if DIRECT_THRESHOLDS[hi] and DIRECT_THRESHOLDS[hi][lo] then return DIRECT_THRESHOLDS[hi][lo] end
    if LOCKED_TIERS[hi] then return math.huge end
    local total = 0
    for t = hi + 1, lo do
        local td = PET_PRIORITY_TIERS[t]
        if td and td.threshold > 0 then total = total + td.threshold end
    end
    return total
end

function _normName(s)
    return tostring(s):lower():gsub("[%s%-_'%.]", "")
end
_priCacheVer, _priCache = -1, {}
function _priLookup()
    local ver = _G.MeerkoPriVersion or 0
    if _priCacheVer ~= ver then
        table.clear(_priCache)
        local plist = _G.SHARED_PRIORITY_ITEMS
        if type(plist) == "table" then
            for i = #plist, 1, -1 do _priCache[_normName(plist[i])] = i end
        end
        _priCacheVer = ver
    end
    return _priCache
end
_G.MeerkoPriLookup = _priLookup
function _priIndexOf(name)
    if not name then return nil end
    return _priLookup()[_normName(name)]
end

function petOutranks(aName, bName, aMut, bMut, aMPS, bMPS)
    local iA = _priIndexOf(aName)
    local iB = _priIndexOf(bName)
    if iA ~= nil and iB ~= nil then return iA < iB end
    if (iA ~= nil) ~= (iB ~= nil) then return iA ~= nil end
    return (aMPS or 0) > (bMPS or 0)
end

function getPlotChannel(plotName)
    local channel
    pcall(function() channel = _G.MeerkoSyncGet(plotName) end)
    return channel
end

function channelGet(channel, key)
    if not channel then return nil end
    local v
    pcall(function()
        local ct = rawget(channel, "CacheTable")
        if type(ct) == "table" then v = ct[key] end
    end)
    if v ~= nil then return v end
    pcall(function()
        local d = rawget(channel, "Data")
        if type(d) == "table" then v = d[key] end
    end)
    if v ~= nil then return v end
    pcall(function() v = rawget(channel, key) end)
    return v
end

function isMyPlot(channel)
    if not channel then return false end
    local owner = channelGet(channel, "Owner")
    if not owner then return false end
    local result = false
    pcall(function()
        if typeof(owner) == "Instance" and owner:IsA("Player") then
            result = owner.UserId == LP.UserId
        elseif type(owner) == "table" and owner.UserId then
            result = owner.UserId == LP.UserId
        elseif typeof(owner) == "Instance" then
            result = owner == LP
        elseif type(owner) == "string" then
            
            result = owner:lower() == LP.Name:lower()
                or owner:lower() == (LP.DisplayName or LP.Name):lower()
        end
    end)
    return result
end

function ownerInGame(channel)
    if not channel then return false end
    local owner = channelGet(channel, "Owner")
    if not owner then return false end
    local inGame = false
    pcall(function()
        if typeof(owner) == "Instance" and owner:IsA("Player") then
            inGame = Players:FindFirstChild(owner.Name) ~= nil
        elseif type(owner) == "number" then
            inGame = Players:GetPlayerByUserId(owner) ~= nil
        elseif type(owner) == "table" and owner.Name then
            inGame = Players:FindFirstChild(tostring(owner.Name)) ~= nil
        elseif typeof(owner) == "Instance" and owner.Name then
            inGame = Players:FindFirstChild(owner.Name) ~= nil
        elseif type(owner) == "string" then
            
            if Players:FindFirstChild(owner) then
                inGame = true
            else
                local lo = owner:lower()
                for _, pl in ipairs(Players:GetPlayers()) do
                    if pl.Name:lower() == lo or (pl.DisplayName or ""):lower() == lo then inGame = true break end
                end
            end
        end
    end)
    return inGame
end

_petModelCache = setmetatable({}, { __mode = "v" })
_genCache = {}
-- read the brainrot's own overhead "$3.5M/s" label when the data lookup comes up empty
local _MPS_SUFFIX = { K = 1e3, M = 1e6, B = 1e9, T = 1e12, Q = 1e15 }
function _worldMPS(plot, slot)
    local podiums = plot and plot:FindFirstChild("AnimalPodiums")
    local podium = podiums and podiums:FindFirstChild(tostring(slot))
    if not podium then return nil end
    local best = nil
    for _, d in ipairs(podium:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("TextButton") then
            local txt = d.Text
            if type(txt) == "string" and txt ~= "" then
                local num, suf = txt:match("%$%s*([%d%.]+)%s*([KMBTQ]?)%s*/s")
                if num then
                    local v = tonumber(num)
                    if v then
                        v = v * (_MPS_SUFFIX[suf] or 1)
                        if not best or v > best then best = v end
                    end
                end
            end
        end
    end
    return best
end
function getPetPosition(plot, slot, strict)
    local podiums = plot:FindFirstChild("AnimalPodiums")
    if not podiums then return nil end
    local podium = podiums:FindFirstChild(tostring(slot))
    if not podium then return nil end

    
    local key = plot.Name .. "\0" .. tostring(slot)
    local cached = _petModelCache[key]
    if cached and cached.Parent and cached:IsDescendantOf(podium) then
        local ok, cf = pcall(function() return cached:GetBoundingBox() end)
        if ok then return cf.Position end
    end
    _petModelCache[key] = nil

    for _, desc in ipairs(podium:GetDescendants()) do
        if desc:IsA("Model") and desc.Name ~= "Claim" and desc.Name ~= "Base" and desc.Name ~= "Decorations" then
            if desc:FindFirstChildWhichIsA("MeshPart", true) then
                local ok, cf = pcall(function() return desc:GetBoundingBox() end)
                if ok then
                    _petModelCache[key] = desc
                    return cf.Position
                end
            end
        end
    end

    if strict then return nil end
    local ok, cf = pcall(function() return podium:GetPivot() end)
    if ok then return cf.Position end
    return podium.Position
end

function scanAllPets()
    local pets = {}
    if not loadModules() then return pets end

    local Plots = workspace:FindFirstChild("Plots")
    if not Plots then return pets end

    local _mkSeen, _mkUse, _mkTotal = 0, 0, 0
    local _mkTags = {}
    for _, plot in ipairs(Plots:GetChildren()) do
        _mkTotal = _mkTotal + 1
        local channel = getPlotChannel(plot.Name)
        if not channel then _mkTags[#_mkTags + 1] = "nochan" continue end
        _mkSeen = _mkSeen + 1
        if isMyPlot(channel) then _G.MeerkoMyPlot = plot.Name _mkTags[#_mkTags + 1] = "MINE" continue end
        if _G.MeerkoMyPlot == plot.Name then _mkTags[#_mkTags + 1] = "MINE" continue end
        if not _G.MeerkoMyPlot and channelGet(channel, "Owner") == nil then _mkTags[#_mkTags + 1] = "noowner?" continue end
        if _G.MeerkoRequireOwner ~= false and not ownerInGame(channel) then _mkTags[#_mkTags + 1] = "left" continue end
        _mkUse = _mkUse + 1

        local animalList = channelGet(channel, "AnimalList")
        if not animalList then _mkTags[#_mkTags + 1] = "nolist" continue end
        local _mkPlotN = 0

        for slot, animalData in pairs(animalList) do
            if type(animalData) ~= "table" then continue end
            local animalName = animalData.Index
            if not animalName then continue end
            local animalInfo = AnimalsData and AnimalsData[animalName]
            if not animalInfo and _G.MeerkoRequireKnown == true then continue end
            if _MeerkoIsFusing(animalData) then continue end

            local mutation = animalData.Mutation or "None"

            local genValue
            local _gk = plot.Name .. "\0" .. tostring(slot)
            local _gc = _genCache[_gk]
            if _gc and _gc.n == animalName and _gc.m == animalData.Mutation and _gc.t == animalData.Traits then
                genValue = _gc.g
            else
                genValue = 0
                pcall(function()
                    genValue = AnimalsShared:GetGeneration(animalName, animalData.Mutation, animalData.Traits, nil)
                end)
                if genValue and genValue > 0 then
                    _genCache[_gk] = { n = animalName, m = animalData.Mutation, t = animalData.Traits, g = genValue }
                end
            end
            if (not genValue or genValue <= 0) and _G.MeerkoWorldMPS ~= false then
                local wm = _worldMPS(plot, slot)
                if wm and wm > 0 then genValue = wm end
            end

            local displayName = (animalInfo and animalInfo.DisplayName) or animalName

            local pos = getPetPosition(plot, slot, (_G.MeerkoRequireOwner == false) or (_G.MeerkoRequireModel == true))

            if pos then
                if genValue >= (tonumber(_G.MeerkoMinMPS) or 0) then
                    table.insert(pets, {
                        name = displayName,
                        index = animalName,
                        mps = genValue,
                        mutation = mutation,
                        traits = type(animalData.Traits) == "table" and animalData.Traits or {},
                        position = pos,
                        plot = plot.Name,
                        slot = tostring(slot),
                    })
                    _mkPlotN = _mkPlotN + 1
                end
            end
        end
        _mkTags[#_mkTags + 1] = tostring(_mkPlotN)
    end

    _G.MeerkoScanInfo = string.format("plots %d scanned of %d  pets %d  [%s]  %s", _mkUse, _mkTotal, #pets, table.concat(_mkTags, " "), tostring(_G.MeerkoScanMode))
    local _priLk = _priLookup()
    for _, p in ipairs(pets) do
        p._pri = _priLk[_normName(p.name)] or (p.index and _priLk[_normName(p.index)]) or nil
    end

    local mode = _G.MeerkoStealMode
    if mode == "highest" then
        table.sort(pets, function(a, b) return (a.mps or 0) > (b.mps or 0) end)
        return pets
    end

    table.sort(pets, function(a, b)
        local ia, ib = a._pri, b._pri
        if ia and ib then
            if ia ~= ib then return ia < ib end
            return (a.mps or 0) > (b.mps or 0)
        end
        if (ia ~= nil) ~= (ib ~= nil) then return ia ~= nil end
        return (a.mps or 0) > (b.mps or 0)
    end)

    return pets
end
_G.MeerkoScanAllPets = scanAllPets  

function scanForTP()
    local full = scanAllPets()
    if type(full) ~= "table" then full = {} end
    if _G.MeerkoScanTiered and _G.MeerkoUseTiered ~= false then
        local ok, tiered = pcall(_G.MeerkoScanTiered)
        if ok and type(tiered) == "table" and #tiered > 0 then
            local seen = {}
            for _, p in ipairs(full) do
                if p and p.plot and p.slot ~= nil then
                    seen[tostring(p.plot) .. "_" .. tostring(p.slot)] = true
                end
            end
            for _, p in ipairs(tiered) do
                if p and p.plot and p.slot ~= nil then
                    local uid = tostring(p.plot) .. "_" .. tostring(p.slot)
                    if not seen[uid] then
                        seen[uid] = true
                        full[#full + 1] = p
                    end
                end
            end
        end
    end
    return full
end

function _petUid(p)
    if not p then return nil end
    return tostring(p.plot) .. "_" .. tostring(p.slot)
end
function _pickPetOnFoot(pets, myPos)
    if not pets or #pets == 0 then return nil end
    local best
    if _G.MeerkoStealMode == "nearest" and myPos then
        local bestD = math.huge
        for _, p in ipairs(pets) do
            if not p.conveyor and p.position then
                local d = (p.position - myPos).Magnitude
                if d < bestD then bestD = d; best = p end
            end
        end
    else
        for _, p in ipairs(pets) do
            if not p.conveyor then best = p; break end
        end
    end
    return best or pets[1]
end
function _findTPSyncedPet(pets)
    local uid = _G.MeerkoStealTargetUID
    if type(uid) ~= "string" or uid == "" then return nil end
    for _, p in ipairs(pets) do
        if _petUid(p) == uid then return p end
    end
    return nil
end
function _clearTPSync()
    _G.MeerkoTPSyncActive = false
    _G.MeerkoStealTargetUID = nil
    _G.MeerkoStealTarget = nil
end
function _armTPSync(pet)
    if not pet then return end
    _G.MeerkoStealTargetUID = _petUid(pet)
    _G.MeerkoStealTarget = pet
    _G.MeerkoTPSyncActive = true
    local gen = (_G._MeerkoTPSyncGen or 0) + 1
    _G._MeerkoTPSyncGen = gen
    task.delay(12, function()
        if _G._MeerkoTPSyncGen == gen then _clearTPSync() end
    end)
end
_G.MeerkoClearTPSync = _clearTPSync
function _findStealTarget(pets)
    if not _G.MeerkoTPSyncActive then return nil end
    return _findTPSyncedPet(pets)
end
function _publishStealTarget(pet)
    if not pet then return end
    _G.MeerkoStealTargetUID = _petUid(pet)
    _G.MeerkoStealTarget = pet
end

MK_UPPER = {
    B = {{coord=Vector3.new(-487.921448,16.850713,-75.768013),facing="NORTH"},{coord=Vector3.new(-332.379730,16.850722,-75.762100),facing="NORTH"},{coord=Vector3.new(-487.134918,16.850713,-18.094154),facing="SOUTH"},{coord=Vector3.new(-316.300171,16.850713,-17.845898),facing="SOUTH"}},
    C = {{coord=Vector3.new(-330.765381,16.850713,31.424425),facing="NORTH"},{coord=Vector3.new(-502.989349,16.850713,31.172430),facing="NORTH"},{coord=Vector3.new(-489.077087,16.850713,89.010147),facing="SOUTH"},{coord=Vector3.new(-330.908936,16.850713,88.930145),facing="SOUTH"}},
    D = {{coord=Vector3.new(-331.264893,16.850713,138.209167),facing="NORTH"},{coord=Vector3.new(-487.935181,16.850713,138.026321),facing="NORTH"},{coord=Vector3.new(-487.774933,16.850713,195.882538),facing="SOUTH"},{coord=Vector3.new(-330.799133,16.850575,196.022354),facing="SOUTH"}},
}
MK_LOWER = {
    B = {{coord=Vector3.new(-335.725586,-3.048217,-74.984589),facing="NORTH"},{coord=Vector3.new(-503.214233,-3.048217,-75.043137),facing="NORTH"},{coord=Vector3.new(-483.619385,-3.718430,-18.844337),facing="SOUTH"},{coord=Vector3.new(-316.147095,-3.048218,-18.818844),facing="SOUTH"}},
    C = {{coord=Vector3.new(-335.985413,-3.048218,32.051426),facing="NORTH"},{coord=Vector3.new(-503.277008,-3.048217,31.956175),facing="NORTH"},{coord=Vector3.new(-483.749390,-3.048218,88.147003),facing="SOUTH"},{coord=Vector3.new(-315.793823,-3.048217,88.163979),facing="SOUTH"}},
    D = {{coord=Vector3.new(-335.476654,-3.048218,139.001083),facing="NORTH"},{coord=Vector3.new(-503.710083,-3.048218,138.989883),facing="NORTH"},{coord=Vector3.new(-315.654938,-3.048218,195.302444),facing="SOUTH"},{coord=Vector3.new(-483.859253,-3.048218,195.269043),facing="SOUTH"}},
}
UPPER_Y_THRESHOLD = 7
TALL_PETS = { ["La Secret Combinasion"]=true, ["La Jolly Grande"]=true }
TALL_OFFSET = 3

BASES_LOW = {
    [1] = Vector3.new(-476.52, -2, 220.94090270996094),
    [2] = Vector3.new(-476.52, -2, 113.77315521240234),
    [3] = Vector3.new(-476.52, -2, 6.178487777709961),
    [4] = Vector3.new(-476.52, -2, -101.07275390625),
    [5] = Vector3.new(-342.66, -2, 221.44737243652344),
    [6] = Vector3.new(-342.66, -2, 113.41409301757812),
    [7] = Vector3.new(-342.66, -2, 6.249461650848389),
    [8] = Vector3.new(-342.66, -2, -99.73458862304688),
}
BASES_HIGH = {
    [1] = Vector3.new(-479.51, 18, 220.94090270996094),
    [2] = Vector3.new(-479.51, 18, 113.77315521240234),
    [3] = Vector3.new(-479.51, 18, 6.178487777709961),
    [4] = Vector3.new(-479.51, 18, -101.07275390625),
    [5] = Vector3.new(-339.48, 18, 221.44737243652344),
    [6] = Vector3.new(-339.48, 18, 113.41409301757812),
    [7] = Vector3.new(-339.48, 18, 6.249461650848389),
    [8] = Vector3.new(-339.48, 18, -99.73458862304688),
}
FRONT_Y_LOW   = -3.048217
FRONT_Y_HIGH  = 16.850713
COLUMN_SPLIT_X = -410
FRONT_Z_CLAMP  = 18
SIDE_NEAR_Z    = 45

function getClosestBaseIdx(pos)
    local closest, dist = 1, math.huge
    for i = 1, 8 do
        local b = BASES_LOW[i]
        local d = (pos.X - b.X)^2 + (pos.Z - b.Z)^2
        if d < dist then dist = d; closest = i end
    end
    return closest
end

function buildFrontCandidate(idx, isUpper, playerZ)
    local base = isUpper and BASES_HIGH[idx] or BASES_LOW[idx]
    local frontY = isUpper and FRONT_Y_HIGH or FRONT_Y_LOW
    local frontZ = math.clamp(playerZ - base.Z, -FRONT_Z_CLAMP, FRONT_Z_CLAMP) + base.Z
    local coord = Vector3.new(base.X, frontY, frontZ)
    local faceDir = (idx <= 4) and Vector3.new(-1, 0, 0) or Vector3.new(1, 0, 0)
    return coord, faceDir
end

function plotSides(coordTable, idx)
    local base = BASES_LOW[idx]
    local isWest = idx <= 4
    local out = {}
    for _, coords in pairs(coordTable) do
        for _, data in ipairs(coords) do
            if ((data.coord.X < COLUMN_SPLIT_X) == isWest)
               and math.abs(data.coord.Z - base.Z) < SIDE_NEAR_Z then
                out[#out + 1] = data
            end
        end
    end
    return out
end

function _floor1LaserSolid(plotName)
    local solid = false
    pcall(function()
        local Plots = workspace:FindFirstChild("Plots")
        local plot = Plots and Plots:FindFirstChild(plotName)
        if not plot then return end
        for _, d in ipairs(plot:GetDescendants()) do
            if d:IsA("BasePart") and (d.Name == "LaserHitbox" or d.Name == "Laser")
                and d.CanCollide and d.Position.Y <= 9 then
                solid = true
                break
            end
        end
    end)
    return solid
end

function isPlotUnlocked(plotName)
    local ok, res = pcall(function()
        local channel = getPlotChannel(plotName)
        if not channel then return false end
        if channelGet(channel, "BlockEndTimeFirstFloor") ~= nil then return false end
        return not _floor1LaserSolid(plotName)
    end)
    return ok and (res == true)
end

function findClosest(petPos, coordTable)
    local best, bestKey, bestDist = nil, nil, math.huge
    for skyKey, coords in pairs(coordTable) do
        for _, data in ipairs(coords) do
            local c = data.coord
            local d = math.sqrt((petPos.X - c.X)^2 + (petPos.Z - c.Z)^2)
            if d < bestDist then bestDist = d; best = data; bestKey = skyKey end
        end
    end
    return best, bestKey
end

do
_vizParts = {}
_vizGen = 0

function _vizEnsure()
    if _vizFolder and _vizFolder.Parent then return end
    _vizFolder = Instance.new("Folder")
    -- was "MeerkoPathViz": Workspace is readable by the game's own LocalScripts,
    -- so a self-identifying name is a free detection. Cleanup is by reference.
    _vizFolder.Name = "Effects"
    _vizFolder.Parent = workspace
    _vizAnchor = Instance.new("Part")
    _vizAnchor.Name = "Anchor"
    _vizAnchor.Anchored = true; _vizAnchor.CanCollide = false; _vizAnchor.CanQuery = false
    _vizAnchor.CanTouch = false; _vizAnchor.Transparency = 1; _vizAnchor.Size = Vector3.one
    _vizAnchor.CFrame = CFrame.new()
    _vizAnchor.Parent = _vizFolder
end
clearViz = function()
    if _vizFolder then pcall(function() _vizFolder:Destroy() end) end
    _vizFolder, _vizAnchor = nil, nil
    table.clear(_vizParts)
end
local function _ghost(cf, size, color, op)
    _vizEnsure()
    local a = Instance.new("BoxHandleAdornment")
    a.Adornee = _vizAnchor
    a.AlwaysOnTop = true
    a.ZIndex = 0
    pcall(function() a.Shading = Enum.AdornShading.XRayShaded end)
    a.Color3 = color
    a.Transparency = 1 - op
    a.Size = size
    a.CFrame = cf
    a.Parent = _vizAnchor
end
local function _neon(cf, size, color, ball, transp)
    _vizEnsure()
    local p = Instance.new("Part")
    p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
    p.Material = Enum.Material.Neon; p.Color = color
    p.Transparency = transp or 0
    if ball then p.Shape = Enum.PartType.Ball end
    p.Size = size; p.CFrame = cf; p.Parent = _vizFolder
end
function vizLine(a, b, color)
    local d = b - a
    if d.Magnitude < 0.05 then return end
    _neon(CFrame.lookAt((a + b) * 0.5, b), Vector3.new(0.25, 0.25, d.Magnitude), color, false, 0)
end
function vizDot(pos, color, sz)
    _neon(CFrame.new(pos), Vector3.new(sz, sz, sz), color, true, 0)
end
vizPath = function(fromPos, waypoints)
    if _G.MeerkoShowPath ~= true then return end
    if #waypoints == 0 then return end
    local COL = Color3.fromRGB(255, 195, 45)
    local prev = fromPos
    for _, wp in ipairs(waypoints) do
        vizLine(prev, wp, COL)
        prev = wp
    end
    vizDot(waypoints[#waypoints], COL, 1.6)
end
end

MK_SPEED = 125
MK_ARRIVE = 3
_STRIP_OK = (type(getconnections) == "function")
function _climbCap()
    local v = math.clamp(tonumber(_G.MeerkoClimb) or 200, 100, 250)
    if not _STRIP_OK then v = 55 end
    return v
end

function vZero(hrp)
    if hrp then _vzL(hrp); _vzA(hrp) end
end


function _setFlightVel(hrp, vel)
    local char = hrp and hrp.Parent
    local part = (char and (char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso"))) or hrp
    if part then part.AssemblyLinearVelocity = vel end
end

function velMoveThrough(hrp, waypoints, speedOverride, allowJump, quickStart)
    if not hrp or not hrp.Parent or #waypoints == 0 then return end
    local _runSpeed = speedOverride or (_G.TPVelocity and math.clamp(_G.TPVelocity, 200, 750)) or CARPET_SPEED
    vizPath(hrp.Position, waypoints)
    local wpIdx = 1
    local done = false
    local conn
    local function finish()
        if done then return end
        done = true
        if hrp and hrp.Parent then
            _vzL(hrp)
            _vzA(hrp)
            local _, y = hrp.CFrame:ToEulerAnglesYXZ()
            hrp.CFrame = CFrame.new(waypoints[#waypoints]) * CFrame.Angles(0, y, 0)
        end
        if conn then conn:Disconnect() end
    end
    local lastDist, stall = math.huge, 0

    local _stStart = os.clock()
    local _lastJump = 0

    local _routeLen = 0
    do
        local _p = hrp.Position
        for _, wp in ipairs(waypoints) do
            _routeLen = _routeLen + (_p - wp).Magnitude
            _p = wp
        end
    end
    local _mayJump = _routeLen >= (tonumber(_G.MeerkoJumpMinDist) or 100)

    local _ = quickStart

    conn = RunService.Heartbeat:Connect(LPH_NO_VIRTUALIZE(function()
        if not hrp or not hrp.Parent or done then
            if conn then conn:Disconnect() end
            return
        end
        if _G.MeerkoTPStop then finish() return end
        equipCarpet()
        if _mayJump and _G.MeerkoJumpEachStep ~= false then
            local _now = os.clock()
            if _now - _lastJump >= (tonumber(_G.MeerkoJumpGap) or 0.2) then
                _lastJump = _now
                local _jh = hrp.Parent and hrp.Parent:FindFirstChildOfClass("Humanoid")
                if _jh then
                    pcall(function() _jh:ChangeState(Enum.HumanoidStateType.Jumping) end)
                    pcall(function() _jh.Jump = true end)
                end
            end
        end
        local target = waypoints[wpIdx]
        local diff = target - hrp.Position
        local mag = diff.Magnitude
        local _spd = _runSpeed
        if wpIdx < #waypoints and mag < 26 then
            local nxt = waypoints[wpIdx + 1]
            local b = nxt - target
            if mag > 0.1 and b.Magnitude > 0.1 and diff.Unit:Dot(b.Unit) < 0.9 then
                _spd = math.min(_spd, 240)
            end
        end
        local _arr = math.max(MK_ARRIVE, _spd / 60 * 1.25)
        if mag < _arr then
            wpIdx = wpIdx + 1
            if wpIdx > #waypoints then finish() return end
            lastDist, stall = math.huge, 0
            if _G.MeerkoZeroEachStep ~= false and _vzOK() then
                pcall(function()
                    local _v = hrp.AssemblyLinearVelocity
                    local _keepY = (_G.MeerkoZeroStepKeepY == false) and 0 or math.max(_v.Y, 0)
                    hrp.AssemblyLinearVelocity = Vector3.new(0, _keepY, 0)
                    hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                end)
            end
            if _mayJump and _G.MeerkoJumpEachStep ~= false then
                local _wh = hrp.Parent and hrp.Parent:FindFirstChildOfClass("Humanoid")
                if _wh then
                    _lastJump = os.clock()
                    pcall(function() _wh:ChangeState(Enum.HumanoidStateType.Jumping) end)
                    pcall(function() _wh.Jump = true end)
                end
            end
            target = waypoints[wpIdx]
            diff = target - hrp.Position
            mag = diff.Magnitude
        end

        if mag > lastDist - 0.05 then stall = stall + 1 else stall = 0 end
        lastDist = mag
        if stall >= (tonumber(_G.MeerkoStallFrames) or 18) then finish() return end

        if mag >= 0.1 then
            local dir = diff.Unit
            if (allowJump or diff.Y > 10) and diff.Y > 5 and wpIdx < #waypoints then
                local hum = hrp.Parent and hrp.Parent:FindFirstChildOfClass("Humanoid")
                if hum then
                    local st = hum:GetState()
                    if st ~= Enum.HumanoidStateType.Jumping and st ~= Enum.HumanoidStateType.Freefall then
                        pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
                        pcall(function() hum.Jump = true end)
                    end
                end
            end
            local _sp = _spd
            if _G.MeerkoTPSafeMode ~= false then
                _sp = math.min(_sp, tonumber(_G.MeerkoTPSafeSpeed) or 300)
            end
            local _mc = _climbCap()
            local _vCap = tonumber(_G.MeerkoTPSafeVerticalSpeed) or 110
            if dir.Y > 0 and dir.Y * _sp > math.min(_mc, _vCap) then
                _sp = math.min(_mc, _vCap) / dir.Y
            elseif dir.Y < 0 and math.abs(dir.Y * _sp) > _vCap then
                _sp = _vCap / math.abs(dir.Y)
            end
            _setFlightVel(hrp, Vector3.new(dir.X * _sp, dir.Y * _sp, dir.Z * _sp))
        end
    end))

    local totalDist = 0
    do
        local prev = hrp.Position
        for _, wp in ipairs(waypoints) do
            totalDist = totalDist + (prev - wp).Magnitude
            prev = wp
        end
    end
    local timeout = totalDist / math.min(MK_SPEED, _runSpeed) + (tonumber(_G.MeerkoFlightGrace) or 2)
    local elapsed = 0
    while not done and elapsed < timeout do
        task.wait(0.05)
        elapsed = elapsed + 0.05
        if not (hrp and hrp.Parent) then break end
    end
    finish()
    vZero(hrp)
end

_OTHER_CLONES = {}
do
    local _MY_CLONE = tostring(LP.UserId) .. "_Clone"
    local _seen = {}
    local function _isOtherClone(inst)
        if not inst then return false end
        local n = inst.Name
        if n == _MY_CLONE then return false end
        if n:match("^%d+_Clone$") then return true end
        if not n:find("lone", 1, true) then return false end
        if not inst:IsA("Model") then return false end
        if inst == LP.Character then return false end
        if not inst:FindFirstChild("HumanoidRootPart") then return false end
        if not inst:FindFirstChildOfClass("Humanoid") then return false end
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl.Character == inst then return false end
        end
        return true
    end
    local function _neutralize(inst)
        if not inst or _seen[inst] then return end
        _seen[inst] = true
        _OTHER_CLONES[#_OTHER_CLONES + 1] = inst
        local function declaw(d)
            if d:IsA("BasePart") and d.CanCollide then pcall(function() d.CanCollide = false end) end
        end
        for _, d in ipairs(inst:GetDescendants()) do declaw(d) end
        inst.DescendantAdded:Connect(declaw)
        inst.Destroying:Connect(function()
            _seen[inst] = nil
            for i = #_OTHER_CLONES, 1, -1 do
                if _OTHER_CLONES[i] == inst then table.remove(_OTHER_CLONES, i); break end
            end
        end)
    end
    local function _scan(inst)
        if _isOtherClone(inst) then _neutralize(inst) end
    end
    for _, c in ipairs(workspace:GetChildren()) do _scan(c) end
    workspace.ChildAdded:Connect(function(c)
        _scan(c)
        task.defer(function() if c and c.Parent == workspace then _scan(c) end end)
    end)
end

do
    local _pSeen = setmetatable({}, { __mode = "k" })
    local function _declaw(d)
        if d:IsA("BasePart") and d.CanCollide then pcall(function() d.CanCollide = false end) end
    end
    local function _declawChar(char)
        if not char then return end
        for _, d in ipairs(char:GetDescendants()) do _declaw(d) end
        if not _pSeen[char] then
            _pSeen[char] = true
            char.DescendantAdded:Connect(_declaw)
        end
    end
    local function _hookPlayer(pl)
        if pl == LP then return end
        if pl.Character then _declawChar(pl.Character) end
        pl.CharacterAdded:Connect(function(c) task.wait(0.15); _declawChar(c) end)
    end
    for _, pl in ipairs(Players:GetPlayers()) do _hookPlayer(pl) end
    Players.PlayerAdded:Connect(_hookPlayer)
    task.spawn(function()
        _G.MeerkoBootWait()
        while true do
            task.wait(3)
            local myHrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            for _, pl in ipairs(Players:GetPlayers()) do
                if pl ~= LP and pl.Character then
                    local h = pl.Character:FindFirstChild("HumanoidRootPart")
                    if not myHrp or (h and (h.Position - myHrp.Position).Magnitude <= 150) then
                        for _, d in ipairs(pl.Character:GetDescendants()) do _declaw(d) end
                        task.wait() 
                    end
                end
            end
        end
    end)
end

local _len
do
local _DIRS = { Vector3.new(1,0,0), Vector3.new(-1,0,0), Vector3.new(0,0,1), Vector3.new(0,0,-1) }
local _STRUCT = { ["structure base home"] = true, ["Wall"] = true, ["Floor"] = true, ["Roof"] = true }
local _SKIP_NAME = { ["DeliveryHitbox"]=true, ["StealHitbox"]=true, ["LaserHitbox"]=true,
    ["AnimalTarget"]=true, ["Multiplier"]=true, ["Laser"]=true, ["Hitbox"]=true,
    ["Spawn"]=true, ["MainRoot"]=true, ["SecondFloor"]=true, ["ThirdFloor"]=true, ["Slope"]=true }
local function _blocks(inst)
    if not inst then return false end
    if _SKIP_NAME[inst.Name] then return false end
    if inst.CanCollide then return true end
    local _par = inst.Parent
    if _par and (_par.Name == "ObstacleVolumes" or _par.Name == "ObstacleVolume") then return false end
    if _STRUCT[inst.Name] then return true end
    local s = inst.Size
    if s and math.max(s.X * s.Y, s.X * s.Z, s.Y * s.Z) > 150 then return true end
    return false
end
local function _blocksWide(inst)
    if not inst then return false end
    if _SKIP_NAME[inst.Name] then return false end
    if inst.CanCollide then return true end
    local _par = inst.Parent
    if _par and (_par.Name == "ObstacleVolumes" or _par.Name == "ObstacleVolume") then return false end
    if _STRUCT[inst.Name] then return true end
    local s = inst.Size
    if s and math.max(s.X * s.Y, s.X * s.Z, s.Y * s.Z) > 30 then return true end
    return false
end
local function _block(origin, target, blockFn)
    blockFn = blockFn or _blocks
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.IgnoreWater = true
    local skip = {}
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl.Character then skip[#skip + 1] = pl.Character end
    end
    for _, cl in ipairs(_OTHER_CLONES) do skip[#skip + 1] = cl end
    local o = origin
    for _ = 1, 16 do
        rp.FilterDescendantsInstances = skip
        local d = target - o
        if d.Magnitude < 0.05 then return nil end
        local res = workspace:Raycast(o, d, rp)
        if not res then return nil end
        if blockFn(res.Instance) then return res end
        skip[#skip + 1] = res.Instance
        o = res.Position + d.Unit * 0.3
    end
    return nil
end
local function _clear(a, b) return _block(a, b) == nil end
local function _clearDist(origin, dir, maxD)
    local res = _block(origin, origin + dir.Unit * maxD)
    if not res then return maxD end
    return (res.Position - origin).Magnitude
end
function _len(pts)
    local s, prev = 0, pts[1]
    for k = 2, #pts do s = s + (pts[k] - prev).Magnitude; prev = pts[k] end
    return s
end
local function _pull(pts)
    if #pts <= 2 then return pts end
    local out = { pts[1] }
    local i = 1
    while i < #pts do
        local j = #pts
        while j > i + 1 and not _clear(out[#out], pts[j]) do j = j - 1 end
        out[#out + 1] = pts[j]
        i = j
    end
    return out
end
local function _stages(toPos)
    local st = {}
    for _, dr in ipairs(_DIRS) do
        local cd = _clearDist(toPos, dr, 46)
        if cd >= 12 then st[#st + 1] = toPos + dr * math.min(cd - 5, 38) end
    end
    return st
end
local function _routeClear(pts)
    for i = 1, #pts - 1 do
        if not _clear(pts[i], pts[i + 1]) then return false end
    end
    return true
end
local function _peakY(pts)
    local m = -math.huge
    for _, p in ipairs(pts) do if p.Y > m then m = p.Y end end
    return m
end
local function _starts(fromPos)
    local pts = { fromPos }
    if _block(fromPos, fromPos + Vector3.new(0, 40, 0)) then
        for _, dr in ipairs(_DIRS) do
            local cd = _clearDist(fromPos, dr, 40)
            if cd >= 12 then pts[#pts + 1] = fromPos + dr * math.min(cd - 5, 34) end
        end
    end
    return pts
end

local function _candidates(sp, stage, toPos)
    local list = {}
    local function add(mid)
        if mid then list[#list + 1] = { sp, mid, stage, toPos }
        else list[#list + 1] = { sp, stage, toPos } end
    end
    add(nil)
    add(Vector3.new(stage.X, sp.Y, stage.Z))
    add(Vector3.new(sp.X, stage.Y, sp.Z))
    local dir = Vector3.new(stage.X - sp.X, 0, stage.Z - sp.Z)
    if dir.Magnitude > 0.1 then
        dir = dir.Unit
        local perp = Vector3.new(-dir.Z, 0, dir.X)
        for _, off in ipairs({ 20, -20, 40, -40 }) do
            add(sp + perp * off)
        end
    end
    return list
end

local PathfindingService = game:GetService("PathfindingService")
local _CLEARANCE = 16
local function _clearWideRay(a, b)
    return _block(a, b, _blocksWide) == nil
end

local _SWEEP_R = 4
local _ENDPOINT_SLACK = 6
local _canSphere = nil
local function _sweepBlockFn(inst)
    if _G.MeerkoStrictSweep == false then return _blocks(inst) end
    return _blocksWide(inst)
end
local function _sweepDir(a, b)
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.IgnoreWater = true
    local skip = {}
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl.Character then skip[#skip + 1] = pl.Character end
    end
    for _, cl in ipairs(_OTHER_CLONES) do skip[#skip + 1] = cl end
    local o = a
    for _ = 1, 24 do
        rp.FilterDescendantsInstances = skip
        local d = b - o
        if d.Magnitude < 0.05 then return false end
        local res
        local ok = pcall(function() res = workspace:Spherecast(o, _SWEEP_R, d, rp) end)
        if not ok then _canSphere = false; return nil end
        if not res then return false end
        if _sweepBlockFn(res.Instance) then return true end
        skip[#skip + 1] = res.Instance
        local adv = (res.Distance or 0) - 0.05
        if adv > 0 then o = o + d.Unit * math.min(adv, d.Magnitude) end
    end
    return true
end
local function _sweepBlocked(a, b, slackA, slackB)
    if _canSphere == nil then
        _canSphere = pcall(function()
            workspace:Spherecast(Vector3.new(0, 10000, 0), 1, Vector3.new(0, -1, 0), RaycastParams.new())
        end)
    end
    if not _canSphere then return nil end
    local d = b - a
    local len = d.Magnitude
    if len < 0.1 then return false end
    local u = d / len
    local a2 = a + u * math.min(slackA or _ENDPOINT_SLACK, len * 0.4)
    local b2 = b - u * math.min(slackB or _ENDPOINT_SLACK, len * 0.4)
    local fwd = _sweepDir(a2, b2)
    if fwd == nil then return nil end
    if fwd then return true end
    local rev = _sweepDir(b2, a2)
    if rev == nil then return nil end
    return rev
end

local function _clearWide(a, b, slackA, slackB)
    if not _clear(a, b) then return false end
    local sw = _sweepBlocked(a, b, slackA, slackB)
    if sw ~= nil then return not sw end
    local d = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
    if d.Magnitude < 0.1 then
        local ox = Vector3.new(_CLEARANCE, 0, 0)
        local oz = Vector3.new(0, 0, _CLEARANCE)
        return _clearWideRay(a + ox, b + ox) and _clearWideRay(a - ox, b - ox)
            and _clearWideRay(a + oz, b + oz) and _clearWideRay(a - oz, b - oz)
    end
    local perp = Vector3.new(-d.Z, 0, d.X).Unit * _CLEARANCE
    local up = Vector3.new(0, _CLEARANCE, 0)
    return _clearWideRay(a + perp, b + perp)
        and _clearWideRay(a - perp, b - perp)
        and _clearWideRay(a + up, b + up)
        and _clearWideRay(a - up, b - up)
end

local function _crestClear(a, b)
    if not _clear(a, b) then return false end
    local cl = tonumber(_G.MeerkoCrestClearance) or 6
    local d = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
    if d.Magnitude < 0.1 then
        return true
    end
    local perp = Vector3.new(-d.Z, 0, d.X).Unit * cl
    return _clearWideRay(a + perp, b + perp)
        and _clearWideRay(a - perp, b - perp)
        and _clearWideRay(a + Vector3.new(0, cl, 0), b + Vector3.new(0, cl, 0))
end

local function _pullWide(pts)
    if #pts <= 2 then return pts end
    local out = { pts[1] }
    local i = 1
    local n = #pts
    while i < n do
        local j = n
        while j > i + 1 do
            local a, b = out[#out], pts[j]
            local sA = (i == 1) and _ENDPOINT_SLACK or 0
            local sB = (j == n) and _ENDPOINT_SLACK or 0
            if _clearWide(a, b, sA, sB) then break end
            j = j - 1
        end
        out[#out + 1] = pts[j]
        i = j
    end
    return out
end

local function _pushOffWalls(pts)
    if #pts <= 2 then return pts end
    local MARGIN = 8
    local MAX_PUSH = 12
    local out = { pts[1] }
    for i = 2, #pts - 1 do
        local p = pts[i]
        local shift = Vector3.zero
        for _, dr in ipairs(_DIRS) do
            local res = _block(p, p + dr * MARGIN, _blocks)
            if res then
                local dist = (res.Position - p).Magnitude
                if dist < MARGIN then
                    shift = shift - dr * (MARGIN - dist)
                end
            end
        end
        do
            local resUp = _block(p, p + Vector3.new(0, MARGIN, 0), _blocks)
            if resUp then
                local dist = (resUp.Position - p).Magnitude
                if dist < 4 then shift = shift + Vector3.new(0, -(4 - dist), 0) end
            end
        end
        if shift.Magnitude > 0.1 then
            if shift.Magnitude > MAX_PUSH then shift = shift.Unit * MAX_PUSH end
            local moved = p + shift
            if _clear(out[#out], moved) then
                out[#out + 1] = moved
            else
                out[#out + 1] = p
            end
        else
            out[#out + 1] = p
        end
    end
    out[#out + 1] = pts[#pts]
    return out
end


do
local _vxFloor, _vxSqrt = math.floor, math.sqrt
local _vxMin, _vxMax = math.min, math.max
local function _vxAbs(n) return n < 0 and -n or n end

local _vxOverlap = OverlapParams.new()
_vxOverlap.FilterType = Enum.RaycastFilterType.Exclude
_vxOverlap.RespectCanCollide = true

local _vxCast = RaycastParams.new()
_vxCast.FilterType = Enum.RaycastFilterType.Exclude
_vxCast.RespectCanCollide = true
_vxCast.IgnoreWater = true

local _vxOrigin
local _vxDimX, _vxDimY, _vxDimZ = 0, 0, 0
local _vxSz, _vxInflate = 4, 2.5
local _vxSolid = {}
local _vxHeight = 5

local function _vxWorld(sz, x, y, z)
    local h = sz * 0.5
    return Vector3.new(_vxOrigin.X + x * sz + h, _vxOrigin.Y + y * sz + h, _vxOrigin.Z + z * sz + h)
end
local function _vxKey(x, y, z) return x + y * 1024 + z * 1048576 end

local function _vxIsSolid(x, y, z)
    if x < 0 or y < 0 or z < 0 or x >= _vxDimX or y >= _vxDimY or z >= _vxDimZ then return true end
    local k = _vxKey(x, y, z)
    local c = _vxSolid[k]
    if c ~= nil then return c end
    local h = _vxSz * 0.5
    local cx = _vxOrigin.X + x * _vxSz + h
    local cy = _vxOrigin.Y + y * _vxSz + h
    local cz = _vxOrigin.Z + z * _vxSz + h
    local sxz = _vxSz + _vxInflate
    local vy = _vxHeight > _vxSz and _vxHeight or _vxSz
    local vcy = cy - h + vy * 0.5
    local parts = workspace:GetPartBoundsInBox(CFrame.new(cx, vcy, cz), Vector3.new(sxz, vy, sxz), _vxOverlap)
    local solid = #parts > 0
    _vxSolid[k] = solid
    return solid
end

local function _vxSegClear(from, to, radius, height, sample)
    local dir = to - from
    local mag = dir.Magnitude
    if mag < 0.05 then return true end
    if workspace:Raycast(from, dir, _vxCast) then return false end
    local r = radius > 1 and radius or 1
    if workspace:Blockcast(CFrame.new(from), Vector3.new(r * 2, height, r * 2), dir, _vxCast) ~= nil then return false end
    local n = _vxFloor(mag)
    if sample ~= false and n >= 2 then
        local step = dir / n
        local torso = Vector3.new(r * 2, 3, r * 2)
        for i = 1, n - 1 do
            local pt = from + step * i
            if #workspace:GetPartBoundsInBox(CFrame.new(pt), torso, _vxOverlap) > 0 then return false end
        end
    end
    return true
end

local _vxNeigh = {}
do
    for dx = -1, 1 do
        for dy = -1, 1 do
            for dz = -1, 1 do
                if dx ~= 0 or dy ~= 0 or dz ~= 0 then
                    local nz = (dx ~= 0 and 1 or 0) + (dy ~= 0 and 1 or 0) + (dz ~= 0 and 1 or 0)
                    local kd = dx + dy * 1024 + dz * 1048576
                    _vxNeigh[#_vxNeigh + 1] = { dx, dy, dz, _vxSqrt(dx * dx + dy * dy + dz * dz), nz, kd }
                end
            end
        end
    end
end

local function _vxNoCorner(cx, cy, cz, off)
    if off[5] < 2 then return true end
    if off[1] ~= 0 and _vxIsSolid(cx + off[1], cy, cz) then return false end
    if off[2] ~= 0 and _vxIsSolid(cx, cy + off[2], cz) then return false end
    if off[3] ~= 0 and _vxIsSolid(cx, cy, cz + off[3]) then return false end
    return true
end

local function _vxSnapGoal(goalPos, x, y, z)
    if not _vxIsSolid(x, y, z) then return x, y, z end
    for r = 1, 16 do
        for dx = -r, r do
            for dy = -r, r do
                for dz = -r, r do
                    if _vxMax(_vxAbs(dx), _vxAbs(dy), _vxAbs(dz)) == r then
                        local nx, ny, nz = x + dx, y + dy, z + dz
                        if not _vxIsSolid(nx, ny, nz) and (_vxWorld(_vxSz, nx, ny, nz) - goalPos).Magnitude <= 8 then
                            return nx, ny, nz
                        end
                    end
                end
            end
        end
    end
    return x, y, z
end
local function _vxSnapStart(pos, x, y, z)
    if not _vxIsSolid(x, y, z) then return x, y, z end
    for r = 1, 16 do
        for dx = -r, r do
            for dy = -r, r do
                for dz = -r, r do
                    if _vxMax(_vxAbs(dx), _vxAbs(dy), _vxAbs(dz)) == r then
                        local nx, ny, nz = x + dx, y + dy, z + dz
                        if not _vxIsSolid(nx, ny, nz) and not workspace:Raycast(pos, _vxWorld(_vxSz, nx, ny, nz) - pos, _vxCast) then
                            return nx, ny, nz
                        end
                    end
                end
            end
        end
    end
    return x, y, z
end

local function _vxPush(h, f, key)
    local i = #h + 1
    h[i] = { f, key }
    while i > 1 do
        local p = _vxFloor(i * 0.5)
        if h[p][1] <= h[i][1] then break end
        h[p], h[i] = h[i], h[p]
        i = p
    end
end
local function _vxPop(h)
    local n = #h
    if n == 0 then return nil end
    local top = h[1]
    h[1] = h[n]
    h[n] = nil
    n -= 1
    local i = 1
    while true do
        local l, r, s = i + i, i + i + 1, i
        if l <= n and h[l][1] < h[s][1] then s = l end
        if r <= n and h[r][1] < h[s][1] then s = r end
        if s == i then break end
        h[i], h[s] = h[s], h[i]
        i = s
    end
    return top[2]
end

local _vxHeurW = 2
local function _vxAStar(sz, startCell, goalCell, startPos, goalPos)
    local sx, sy, sz2 = _vxSnapStart(startPos, startCell.x, startCell.y, startCell.z)
    local gx, gy, gz = _vxSnapGoal(goalPos, goalCell.x, goalCell.y, goalCell.z)
    local goalKey = _vxKey(gx, gy, gz)
    local startKey = _vxKey(sx, sy, sz2)

    local nodes = { [startKey] = { x = sx, y = sy, z = sz2, g = 0, parent = nil } }
    local closed = {}
    local heap = {}
    _vxPush(heap, 0, startKey)

    local function Heur(x, y, z)
        local ax, ay, az = x - gx, y - gy, z - gz
        return _vxSqrt(ax * ax + ay * ay + az * az)
    end

    local pops = 0
    while #heap > 0 do
        local curKey = _vxPop(heap)
        if closed[curKey] then continue end
        closed[curKey] = true
        pops += 1
        if pops > 300000 then break end

        local cur = nodes[curKey]
        if curKey == goalKey then
            local path = {}
            local n = cur
            while n do
                path[#path + 1] = _vxWorld(sz, n.x, n.y, n.z)
                n = n.parent and nodes[n.parent]
            end
            local rev = {}
            for i = #path, 1, -1 do rev[#rev + 1] = path[i] end
            return rev
        end

        local cx, cy, cz = cur.x, cur.y, cur.z
        local cg = cur.g
        for _, off in _vxNeigh do
            local nk = curKey + off[6]
            if closed[nk] then continue end
            local nx, ny, nz = cx + off[1], cy + off[2], cz + off[3]
            if _vxIsSolid(nx, ny, nz) then continue end
            if not _vxNoCorner(cx, cy, cz, off) then continue end
            local tg = cg + off[4]
            local ex = nodes[nk]
            if not ex or tg < ex.g then
                if ex then
                    ex.g, ex.parent, ex.x, ex.y, ex.z = tg, curKey, nx, ny, nz
                else
                    nodes[nk] = { x = nx, y = ny, z = nz, g = tg, parent = curKey }
                end
                _vxPush(heap, tg + _vxHeurW * Heur(nx, ny, nz), nk)
            end
        end
    end
    return nil
end

local function _vxSimplify(path, radius, height)
    if not path or #path < 3 then return path end
    local out = { path[1] }
    local anchor = 1
    local i = 2
    while i <= #path do
        if not _vxSegClear(path[anchor], path[i + 1] or path[i], radius, height, false) then
            out[#out + 1] = path[i]
            anchor = i
        end
        i += 1
    end
    out[#out + 1] = path[#path]
    return out
end

voxelRoute = function(fromPos, toPos)
    local char = LP.Character
    local _flt = char and { char } or {}
    for _, cl in ipairs(_OTHER_CLONES) do _flt[#_flt + 1] = cl end
    _vxOverlap.FilterDescendantsInstances = _flt
    _vxCast.FilterDescendantsInstances = _flt

    local sz      = tonumber(_G.MeerkoPathCell)   or 4
    local inflate = tonumber(_G.MeerkoPathRadius) or 2.5
    local height  = tonumber(_G.MeerkoPathHeight) or 5
    local pad     = tonumber(_G.MeerkoPathPad)    or 40

    _vxSz, _vxInflate, _vxHeight = sz, inflate, height
    table.clear(_vxSolid)

    local mn = Vector3.new(_vxMin(fromPos.X, toPos.X), _vxMin(fromPos.Y, toPos.Y), _vxMin(fromPos.Z, toPos.Z)) - Vector3.new(pad, pad, pad)
    local mx = Vector3.new(_vxMax(fromPos.X, toPos.X), _vxMax(fromPos.Y, toPos.Y), _vxMax(fromPos.Z, toPos.Z)) + Vector3.new(pad, pad, pad)
    _vxOrigin = mn
    local size = mx - mn
    _vxDimX = _vxFloor(size.X / sz) + 1
    _vxDimY = _vxFloor(size.Y / sz) + 1
    _vxDimZ = _vxFloor(size.Z / sz) + 1
    if _vxDimX * _vxDimY * _vxDimZ > 200000 then return nil end

    local startCell = {
        x = _vxFloor((fromPos.X - _vxOrigin.X) / sz),
        y = _vxFloor((fromPos.Y - _vxOrigin.Y) / sz),
        z = _vxFloor((fromPos.Z - _vxOrigin.Z) / sz),
    }
    local goalCell = {
        x = _vxFloor((toPos.X - _vxOrigin.X) / sz),
        y = _vxFloor((toPos.Y - _vxOrigin.Y) / sz),
        z = _vxFloor((toPos.Z - _vxOrigin.Z) / sz),
    }

    local path = _vxAStar(sz, startCell, goalCell, fromPos, toPos)
    if not path then return nil end
    path = _vxSimplify(path, inflate, height)
    if not path or #path == 0 then return nil end

    local route = {}
    for idx = 2, #path do route[#route + 1] = path[idx] end
    if #route == 0 or (route[#route] - toPos).Magnitude > 0.5 then
        route[#route + 1] = toPos
    end
    return route
end

end

_G.MeerkoVoxelRoute = voxelRoute

local _MAP_CENTER = { minX = -458, maxX = -362, minZ = -40, maxZ = 185 }
local _BYPASS_Z_NORTH, _BYPASS_Z_SOUTH = 205, -95
local _BYPASS_X_WEST,  _BYPASS_X_EAST  = -525, -295

local function _inCenterZone(x, z)
    return x >= _MAP_CENTER.minX and x <= _MAP_CENTER.maxX
       and z >= _MAP_CENTER.minZ and z <= _MAP_CENTER.maxZ
end

local function _segmentCrossesCenter(a, b)
    if _inCenterZone(a.X, a.Z) or _inCenterZone(b.X, b.Z) then return true end
    for i = 1, 10 do
        local t = i / 11
        if _inCenterZone(a.X + (b.X - a.X) * t, a.Z + (b.Z - a.Z) * t) then return true end
    end
    return false
end

local function _findBestCenterDetour(fromPos, toPos, y)
    local candidates = {
        { Vector3.new(fromPos.X, y, _BYPASS_Z_NORTH), Vector3.new(toPos.X, y, _BYPASS_Z_NORTH) },
        { Vector3.new(fromPos.X, y, _BYPASS_Z_SOUTH), Vector3.new(toPos.X, y, _BYPASS_Z_SOUTH) },
        { Vector3.new(_BYPASS_X_WEST, y, fromPos.Z), Vector3.new(_BYPASS_X_WEST, y, toPos.Z) },
        { Vector3.new(_BYPASS_X_EAST, y, fromPos.Z), Vector3.new(_BYPASS_X_EAST, y, toPos.Z) },
    }
    local best, bestLen = nil, math.huge
    for _, pair in ipairs(candidates) do
        local w1, w2 = pair[1], pair[2]
        if _clearWide(fromPos, w1) and _clearWide(w1, w2) and _clearWide(w2, toPos) then
            local len = (fromPos - w1).Magnitude + (w1 - w2).Magnitude + (w2 - toPos).Magnitude
            if len < bestLen then bestLen = len; best = { w1, w2 } end
        end
    end
    return best
end
_G.MeerkoSegmentCrossesCenter = _segmentCrossesCenter
_G.MeerkoFindCenterDetour     = _findBestCenterDetour

local function _rowBoxX() return tonumber(_G.MeerkoRowBoxX) or 26 end
local function _rowBoxZ() return tonumber(_G.MeerkoRowBoxZ) or 30 end
local function _rowLane() return tonumber(_G.MeerkoRowLane) or 30 end

local function _nearestBase(p)
    local bi, bd = nil, math.huge
    for i = 1, 8 do
        local b = BASES_LOW[i]
        local d = (p.X - b.X) ^ 2 + (p.Z - b.Z) ^ 2
        if d < bd then bd = d; bi = i end
    end
    if bd > 70 * 70 then return nil end
    return bi
end

local function _segmentHitsOtherBase(a, b, ignA, ignB)
    local hx, hz = _rowBoxX(), _rowBoxZ()
    for i = 0, 24 do
        local t = i / 24
        local px = a.X + (b.X - a.X) * t
        local pz = a.Z + (b.Z - a.Z) * t
        for k = 1, 8 do
            if k ~= ignA and k ~= ignB then
                local bs = BASES_LOW[k]
                if math.abs(px - bs.X) <= hx and math.abs(pz - bs.Z) <= hz then
                    return true
                end
            end
        end
    end
    return false
end

local function _findRowDetour(fromPos, toPos, y)
    local iFrom, iTo = _nearestBase(fromPos), _nearestBase(toPos)
    if not _segmentHitsOtherBase(fromPos, toPos, iFrom, iTo) then return nil end

    local colX = BASES_LOW[iTo or 1].X
    local off  = _rowLane()
    local lanes = {}
    local outer = (colX < COLUMN_SPLIT_X) and (colX - off) or (colX + off)
    lanes[#lanes + 1] = outer
    local inner = (colX < COLUMN_SPLIT_X) and (colX + off) or (colX - off)
    if not _inCenterZone(inner, (fromPos.Z + toPos.Z) * 0.5) then
        lanes[#lanes + 1] = inner
    end

    local best, bestLen = nil, math.huge
    for _, laneX in ipairs(lanes) do
        local w1 = Vector3.new(laneX, y, fromPos.Z)
        local w2 = Vector3.new(laneX, y, toPos.Z)
        if _clearWide(fromPos, w1) and _clearWide(w1, w2) and _clearWide(w2, toPos)
           and not _segmentHitsOtherBase(w1, w2, iFrom, iTo) then
            local len = (fromPos - w1).Magnitude + (w1 - w2).Magnitude + (w2 - toPos).Magnitude
            if len < bestLen then bestLen = len; best = { w1, w2 } end
        end
    end
    return best
end
_G.MeerkoFindRowDetour = _findRowDetour

local _hopRP = RaycastParams.new()
_hopRP.FilterType = Enum.RaycastFilterType.Exclude

local function _partTopY(inst)
    local ok, t = pcall(function()
        local cf, sz = inst.CFrame, inst.Size
        local half = (math.abs(cf.RightVector.Y) * sz.X
            + math.abs(cf.UpVector.Y) * sz.Y
            + math.abs(cf.LookVector.Y) * sz.Z) / 2
        return cf.Position.Y + half
    end)
    if ok and t then return t end
    return inst.Position.Y + (inst.Size.Y / 2)
end

local function _hopBlockerTop(a, b)
    local ignore = { LP.Character }
    for _, cl in ipairs(_OTHER_CLONES) do ignore[#ignore + 1] = cl end
    local top = nil
    for _ = 1, 10 do
        _hopRP.FilterDescendantsInstances = ignore
        local r = workspace:Raycast(a, b - a, _hopRP)
        if not r then break end
        if _blocks(r.Instance) then
            local t = _partTopY(r.Instance)
            if not top or t > top then top = t end
        end
        ignore[#ignore + 1] = r.Instance
    end
    return top
end

local function _hopRoute(fromPos, toPos)
    local flat = Vector3.new(toPos.X - fromPos.X, 0, toPos.Z - fromPos.Z)
    local dist = flat.Magnitude
    if dist < 8 then return nil end
    local dir = flat.Unit
    local step = tonumber(_G.MeerkoHopStep) or 8
    local clear = tonumber(_G.MeerkoHopClear) or 4
    local maxUp = tonumber(_G.MeerkoHopMaxUp) or 22
    local groundY = fromPos.Y
    local route = {}
    local inHop, hopY, hopStart = false, nil, nil
    local i = step
    while i <= dist do
        local a = fromPos + dir * (i - step)
        local b = fromPos + dir * math.min(i, dist)
        local ga = Vector3.new(a.X, groundY, a.Z)
        local gb = Vector3.new(b.X, groundY, b.Z)
        if not _clear(ga, gb) then
            local top = _hopBlockerTop(ga, gb) or (groundY + 6)
            local want = top + clear
            if want - groundY > maxUp then return nil end
            if not inHop then
                inHop, hopY, hopStart = true, want, ga
                route[#route + 1] = Vector3.new(a.X, want, a.Z)
            elseif want > hopY then
                hopY = want
                route[#route + 1] = Vector3.new(a.X, want, a.Z)
            end
        elseif inHop then
            inHop = false
            route[#route + 1] = Vector3.new(b.X, hopY, b.Z)
            route[#route + 1] = gb
        end
        i = i + step
    end
    if inHop then
        route[#route + 1] = Vector3.new(toPos.X, hopY, toPos.Z)
    end
    route[#route + 1] = toPos
    return route
end
_G.MeerkoHopRoute = _hopRoute

function computeRoute(fromPos, toPos, facingDir, maxLift, preferCrest)
    local _ = maxLift

    if _G.MeerkoHopFirst == true and not _clearWide(fromPos, toPos) then
        local hop = _hopRoute(fromPos, toPos)
        if hop and #hop > 0 then return hop end
    end

    if _G.MeerkoCrestFirst == true and not _clearWide(fromPos, toPos) then
        local baseY = math.max(fromPos.Y, toPos.Y, 26)
        local lifts = { tonumber(_G.MeerkoCrestLift) or 12, 20, 30, 44, 60 }
        for _, lift in ipairs(lifts) do
            local cruiseY = baseY + lift
            local up   = Vector3.new(fromPos.X, cruiseY, fromPos.Z)
            local over = Vector3.new(toPos.X,   cruiseY, toPos.Z)
            local crest = { fromPos, up, over, toPos }
            local ok = true
            for i = 1, #crest - 1 do
                local a, b = crest[i], crest[i + 1]
                if (a - b).Magnitude > 0.5 then
                    if not _crestClear(a, b) then ok = false; break end
                end
            end
            if ok then return crest end
        end
    end

    local centerPatch = nil
    if _segmentCrossesCenter(fromPos, toPos) and not _clearWide(fromPos, toPos) then
        centerPatch = _findBestCenterDetour(fromPos, toPos, fromPos.Y)
        if centerPatch and #centerPatch > 0 then
            fromPos = centerPatch[#centerPatch]
        end
    end
    local rowPatch = _findRowDetour(fromPos, toPos, fromPos.Y)
    if rowPatch and #rowPatch > 0 then
        fromPos = rowPatch[#rowPatch]
    end

    local function _withPatch(route)
        if (not centerPatch or #centerPatch == 0)
           and (not rowPatch or #rowPatch == 0) then return route end
        local merged = {}
        if centerPatch then for _, p in ipairs(centerPatch) do merged[#merged + 1] = p end end
        if rowPatch    then for _, p in ipairs(rowPatch)    do merged[#merged + 1] = p end end
        for _, p in ipairs(route) do merged[#merged + 1] = p end
        return merged
    end

    if _clearWide(fromPos, toPos) then return _withPatch({ toPos }) end

    if preferCrest then
        local cruiseY = math.max(fromPos.Y, toPos.Y, 26) + 12
        local up   = Vector3.new(fromPos.X, cruiseY, fromPos.Z)
        local over = Vector3.new(toPos.X,   cruiseY, toPos.Z)
        local crest = { fromPos, up, over, toPos }
        local ok = true
        for i = 1, #crest - 1 do
            local a, b = crest[i], crest[i + 1]
            if (a - b).Magnitude > 0.5 then
                local sA = (i == 1) and _ENDPOINT_SLACK or 0
                local sB = (i == #crest - 1) and _ENDPOINT_SLACK or 0
                if not _clearWide(a, b, sA, sB) then ok = false; break end
            end
        end
        if ok then return _withPatch(crest) end
    end

    do
        local vr = voxelRoute(fromPos, toPos)
        if vr and #vr > 0 then return _withPatch(vr) end
    end

    local entry = facingDir and (toPos - facingDir * 14) or toPos

    local best, bestLen = nil, math.huge
    local function consider(pts)
        if not pts or #pts < 2 then return end
        local n = #pts
        for i = 1, n - 1 do
            local a, b = pts[i], pts[i + 1]
            if (a - b).Magnitude > 0.5 then
                local sA = (i == 1) and _ENDPOINT_SLACK or 0
                local sB = (i == n - 1) and _ENDPOINT_SLACK or 0
                if not _clearWide(a, b, sA, sB) then return end
            end
        end
        local pulled = _pullWide(pts)
        local L = _len(pulled)
        if L < bestLen then best, bestLen = pulled, L end
    end

    do
        local dirF = Vector3.new(entry.X - fromPos.X, 0, entry.Z - fromPos.Z)
        if dirF.Magnitude > 0.1 then
            dirF = dirF.Unit
            local perp = Vector3.new(-dirF.Z, 0, dirF.X)
            local midBase = (fromPos + entry) * 0.5
            for _, off in ipairs({ 14, -14, 24, -24, 38, -38, 56, -56, 76, -76 }) do
                consider({ fromPos, midBase + perp * off, entry })
                consider({ fromPos, fromPos + perp * off, entry + perp * off, entry })
            end
        end
    end

    local navRaw
    if not best then
        local groundTo = Vector3.new(entry.X, fromPos.Y, entry.Z)
        local path = PathfindingService:CreatePath({
            AgentRadius = 16, AgentHeight = 5, AgentCanJump = true, AgentJumpHeight = 10, AgentMaxSlope = 89,
        })
        local FLOAT = 5
        local nav = { fromPos }
        local ok = pcall(function()
            path:ComputeAsync(Vector3.new(fromPos.X, fromPos.Y, fromPos.Z), groundTo)
        end)
        if ok and path.Status == Enum.PathStatus.Success then
            local last = fromPos
            for _, wp in ipairs(path:GetWaypoints()) do
                if (wp.Position - last).Magnitude >= 8 then
                    nav[#nav + 1] = wp.Position + Vector3.new(0, FLOAT, 0)
                    last = wp.Position
                end
            end
        end
        nav[#nav + 1] = entry + Vector3.new(0, FLOAT, 0)
        nav = _pushOffWalls(nav)
        navRaw = nav
        consider(nav)
    end

    local route = best
    if not route and _clear(fromPos, toPos) then route = { toPos } end
    if not route and navRaw then route = _pullWide(navRaw) end
    if not route then route = { toPos } end
    if (route[#route] - toPos).Magnitude > 0.5 then
        route[#route + 1] = toPos
    end
    return _withPatch(route)
end
end

function equipTool(name)
    local char = LP.Character
    if not char or char:FindFirstChild(name) then return char ~= nil end
    local bp = LP:FindFirstChild("Backpack")
    if not bp then return false end
    local tool = bp:FindFirstChild(name)
    if tool and tool:IsA("Tool") then tool.Parent = char; return true end
    return false
end

function unequipAll()
    local char, bp = LP.Character, LP.Backpack
    if not char or not bp then return end
    for _, t in pairs(char:GetChildren()) do
        if t:IsA("Tool") then t.Parent = bp end
    end
end

function doClone()
    local char = LP.Character or LP.CharacterAdded:Wait()
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not char or not hum then return false end

    local cloner = (LP:FindFirstChild("Backpack") and LP.Backpack:FindFirstChild("Quantum Cloner"))
                or char:FindFirstChild("Quantum Cloner")
    if not cloner then return false end

    if cloner.Parent ~= char then
        pcall(function() hum:EquipTool(cloner) end)
        task.wait()
    end

    pcall(function() hum:UnequipTools() end)
    task.wait()
    if cloner.Parent ~= char then
        pcall(function() hum:EquipTool(cloner) end)
        task.wait()
    end

    local pg = LP:FindFirstChild("PlayerGui")
    local tf = pg and pg:FindFirstChild("ToolsFrames")
    local qc = tf and tf:FindFirstChild("QuantumCloner")
    local tb = qc and qc:FindFirstChild("TeleportToClone")

    _G.isCloning = true
    pcall(function() cloner:Activate() end)
    task.wait(0.05)

    local fired = false
    if tb and type(firesignal) == "function" then
        pcall(function() tb.Visible = true end)
        pcall(function() firesignal(tb.MouseButton1Click) end)
        pcall(function() firesignal(tb.MouseButton1Up) end)
        pcall(function() firesignal(tb.Activated) end)
        fired = true
    else
        local useItem = getRemote("RemoteEvent", "UseItem")
        local onTel   = getRemote("RemoteEvent", "QuantumCloner/OnTeleport")
        if useItem and onTel then
            pcall(function() useItem:FireServer() end)
            task.wait(0.05)
            pcall(function() onTel:FireServer() end)
            fired = true
        end
    end

    task.delay(0.55, function() _G.isCloning = false end)
    return fired
end

_TweenTS = game:GetService("TweenService")
function meerkoTween(rootPart, hum, targetPos, lookDir)
    if not rootPart or not rootPart.Parent then return end
    local STEP = 20
    local speed = (_G.TPTravelSpeed or 100)
    local hasLook = lookDir ~= nil and lookDir.Magnitude > 0.001
    local prevAnchored = rootPart.Anchored
    _vzL(rootPart)
    _vzA(rootPart)
    pcall(function() rootPart.Anchored = true end)
    local deadline = os.clock() + 12
    while rootPart and rootPart.Parent and os.clock() < deadline do
        local pos = rootPart.Position
        local toTarget = targetPos - pos
        local d = toTarget.Magnitude
        if d < 0.5 then break end
        local stepDist = math.min(STEP, d)
        local stepGoal = pos + toTarget.Unit * stepDist
        local stepCF
        if hasLook then
            stepCF = CFrame.lookAt(stepGoal, stepGoal + lookDir)
        else
            stepCF = (rootPart.CFrame - rootPart.CFrame.Position) + stepGoal
        end
        local dur = math.clamp(stepDist / speed, 0.02, 1)
        local tw = _TweenTS:Create(rootPart, TweenInfo.new(dur, Enum.EasingStyle.Linear), { CFrame = stepCF })
        tw:Play()
        tw.Completed:Wait()
    end
    pcall(function() rootPart.Anchored = prevAnchored end)
    if rootPart and rootPart.Parent then _vzL(rootPart) end
end

function _makeOneWay(plat)
    if not plat then return end
    local rsConn
    local lastY = nil
    rsConn = RunService.Stepped:Connect(function()
        if not plat or not plat.Parent then
            if rsConn then rsConn:Disconnect() end
            return
        end
        local char = LP.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local currentY = hrp.Position.Y
            if not lastY then lastY = currentY end
            local deltaY = currentY - lastY
            local isMovingUp = (hrp.AssemblyLinearVelocity.Y > 1) or (deltaY > 0.01 and deltaY < 5)
            if isMovingUp then
                plat.CanCollide = false
            else
                plat.CanCollide = (currentY > plat.Position.Y + 0.1)
            end
            lastY = currentY
        end
    end)
end

function goToBrainrot(petPos, slot)
    if not petPos then return end
    local char, hrp, hum
    local _t0 = os.clock()
    repeat
        char = LP.Character
        hrp = char and char:FindFirstChild("HumanoidRootPart")
        hum = char and char:FindFirstChildOfClass("Humanoid")
        if hrp and hum then break end
        RunService.Heartbeat:Wait()
    until os.clock() - _t0 > 3
    if not hrp or not hum then return end
    pcall(function() hrp.Anchored = false end)
    local _equipped = false
    do
        local _e0 = os.clock()
        repeat
            char = LP.Character
            for _, _cn in ipairs(CARPET_NAMES) do
                if char and char:FindFirstChild(_cn) then _equipped = true; break end
            end
            if _equipped then break end
            equipCarpet()
            RunService.Heartbeat:Wait()
        until _equipped or os.clock() - _e0 > (tonumber(_G.MeerkoGoCarpetWait) or 1.5)
        if _equipped then task.wait(tonumber(_G.MeerkoGoCarpetSettle) or 0.03) end
    end
    char = LP.Character
    hrp = char and char:FindFirstChild("HumanoidRootPart")
    hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp then return end
    pcall(function() hrp.Anchored = false end)
    local _plotRad = (petPos.Y <= 8.9) and 26 or 25
    do
        local _t0b = os.clock()
        repeat
            local p = hrp.Position
            local inRad = false
            local plotsFolder = workspace:FindFirstChild("Plots")
            if plotsFolder then
                for _, plot in ipairs(plotsFolder:GetChildren()) do
                    pcall(function()
                        local pp = plot:GetPivot().Position
                        if math.abs(p.X - pp.X) < _plotRad and math.abs(p.Z - pp.Z) < _plotRad then inRad = true end
                    end)
                    if inRad then break end
                end
            end
            if inRad then break end
            RunService.Heartbeat:Wait()
        until os.clock() - _t0b > (tonumber(_G.MeerkoGoPlotWait) or 0.4)
    end
    local h = petPos.Y
    pcall(function()
        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    end)
    local _wentUnder = false
    local _slot = tonumber(slot)
    local _under = tonumber(_G.MeerkoUnderOffset) or 6
    local targetY = hrp.Position.Y
    if (_slot and _slot >= 19) or (not _slot and h > 23.15) then
        targetY = h - (tonumber(_G.MeerkoUnderOffset3) or 4)
        _wentUnder = true
    elseif (_slot and _slot >= 11) or (not _slot and h >= 11 and h <= 23.15) then
        targetY = h - _under
        _wentUnder = true
    elseif (_slot and _slot >= 1) or (not _slot and h >= -6.9 and h <= 8.9) then
        targetY = tonumber(_G.MeerkoFloor1Y) or -4
        if _G.MeerkoFloor1Platform ~= false then _wentUnder = true end
    else
        targetY = h - _under
        _wentUnder = true
    end
    local _to = Vector3.new(petPos.X, targetY, petPos.Z)
    if hrp and hrp.Parent then
        -- Keep whatever direction we were already facing after cloning in;
        -- only move the position. (CFrame.new(_to) alone would reset the
        -- rotation and snap us to face the plot/brainrot.)
        do
            local _s1 = tonumber(_G.MeerkoGoGlideSpeed1) or 150
            local _t1 = tonumber(_G.MeerkoGoGlideTime1) or 0.03
            local _s2 = tonumber(_G.MeerkoGoGlideSpeed2) or 400
            local _cap = tonumber(_G.MeerkoGoGlideMax) or 2.5
            local _g0 = os.clock()
            while os.clock() - _g0 < _cap do
                if not (hrp and hrp.Parent) then break end
                if LP:GetAttribute("Stealing") or _G.MeerkoTPStop then break end
                local d = _to - hrp.Position
                if d.Magnitude <= 3 then break end
                equipCarpet()
                if _G.MeerkoGoJump == true then
                    local _gh = hrp.Parent and hrp.Parent:FindFirstChildOfClass("Humanoid")
                    if _gh then
                        pcall(function() _gh:ChangeState(Enum.HumanoidStateType.Jumping) end)
                        pcall(function() _gh.Jump = true end)
                    end
                end
                if _G.MeerkoGoZeroEachFrame ~= false then
                    pcall(function()
                        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                    end)
                end
                local _v = d.Unit * (((os.clock() - _g0) < _t1) and _s1 or _s2)
                if _G.MeerkoGoNoRise ~= false and hrp.Position.Y >= _to.Y - 0.5 and _v.Y > 0 then
                    _v = Vector3.new(_v.X, 0, _v.Z)
                end
                _setFlightVel(hrp, _v)
                RunService.Heartbeat:Wait()
            end
        end
        if _G.MeerkoGoJump == true then
            local _gh = hrp.Parent and hrp.Parent:FindFirstChildOfClass("Humanoid")
            if _gh then
                pcall(function() _gh:ChangeState(Enum.HumanoidStateType.Jumping) end)
                pcall(function() _gh.Jump = true end)
            end
        end
        local _snapCF = CFrame.new(_to) * (hrp.CFrame - hrp.CFrame.Position)
        pcall(function()
            hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            hrp.CFrame = _snapCF
        end)
        -- Hold it for a few frames: a single write can be undone by the
        -- humanoid's own physics step or a server correction landing in the
        -- same tick, which would drop us back where we came from.
        for _ = 1, (tonumber(_G.MeerkoSnapHoldFrames) or 8) do
            RunService.Heartbeat:Wait()
            if not (hrp and hrp.Parent) then break end
            if (hrp.Position - _to).Magnitude > 4 then
                pcall(function()
                    hrp.CFrame = _snapCF
                end)
                if _G.MeerkoGoJump == true then
                    local _gh = hrp.Parent and hrp.Parent:FindFirstChildOfClass("Humanoid")
                    if _gh then
                        pcall(function() _gh:ChangeState(Enum.HumanoidStateType.Jumping) end)
                        pcall(function() _gh.Jump = true end)
                    end
                end
            end
        end
    end
    if _wentUnder and _G.MeerkoPlatform ~= false then
        local _platPos = (hrp and hrp.Parent and hrp.Position) or _to
        local _feetY = _platPos.Y - 3
        local _sz = tonumber(_G.MeerkoPlatSize) or 10
        -- was named "ANGVELSTempPlatform" and found again by that name; both the
        -- name and the name-lookup are visible to the game. Track it by reference.
        local _old = _G.__MeerkoPlat
        if _old and _old.Parent then pcall(function() _old:Destroy() end) end
        local _plat = Instance.new("Part")
        _G.__MeerkoPlat = _plat
        _plat.Size = Vector3.new(_sz, 1, _sz)
        _plat.Position = Vector3.new(petPos.X, _feetY - (tonumber(_G.MeerkoPlatDrop) or 1.5), petPos.Z)
        _plat.Anchored = true; _plat.CanCollide = false; pcall(_makeOneWay, _plat); _plat.Transparency = 1
        _plat.Material = Enum.Material.SmoothPlastic; _plat.Parent = workspace
        task.spawn(function()
            local _s = tick()
            while tick() - _s < (tonumber(_G.MeerkoPlatLife) or 20) do
                if LP:GetAttribute("Stealing") then break end
                task.wait(0.1)
            end
            if _plat and _plat.Parent then _plat:Destroy() end
        end)
    end
end

_Stats = game:GetService("Stats")
function _pingMs()
    local ok, p = pcall(function() return LP:GetNetworkPing() * 1000 end)
    if ok and type(p) == "number" and p > 0 then return p end
    local ok2, p2 = pcall(function()
        return _Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    if ok2 and type(p2) == "number" and p2 > 0 then return p2 end
    return 0
end
_G.MeerkoPingMs = _pingMs
function _pingAdjustSpeed(spd)
    local thresh = tonumber(_G.MeerkoPingThresh) or 170
    local capped = tonumber(_G.MeerkoHighPingSpeed) or 400
    if _pingMs() >= thresh and spd > capped then return capped end
    return spd
end

function _inVoid(hrp)
    if not hrp or not hrp.Parent then return true end
    local voidY = tonumber(_G.MeerkoVoidY) or -50
    return hrp.Position.Y < voidY
end
function _waitOutOfVoid(timeout)
    local t0 = os.clock()
    local good = 0
    while os.clock() - t0 < (timeout or 12) do
        if _G.MeerkoTPStop then return false end
        local char = LP.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp and hrp.Parent and not _inVoid(hrp) and math.abs(hrp.AssemblyLinearVelocity.Y) < 12 then
            good += 1
            if good >= 4 then return true end
        else
            good = 0
        end
        RunService.Heartbeat:Wait()
    end
    return false
end

do
    local lastSafe = nil
    local recovering = false
    RunService.Heartbeat:Connect(LPH_NO_VIRTUALIZE(function()
        if _G.MeerkoVoidRecover == false then return end
        local char = LP.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp or not hrp.Parent then return end
        local voidY = tonumber(_G.MeerkoVoidY) or -50
        if hrp.Position.Y >= voidY then
            if math.abs(hrp.AssemblyLinearVelocity.Y) < 40 then
                lastSafe = hrp.Position
            end
            return
        end
        if recovering or not lastSafe then return end
        recovering = true

        pcall(function()
            _vzL(hrp)
            _vzA(hrp)
            hrp.CFrame = CFrame.new(lastSafe + Vector3.new(0, 5, 0))
        end)
        task.spawn(function()
            local delay = tonumber(_G.MeerkoVoidRecoverDelay) or 0
            if delay > 0 then task.wait(delay) end
            local vy = tonumber(_G.MeerkoVoidY) or -50
            local tries = 0
            while tries < 80 do
                local c = LP.Character
                local h = c and c:FindFirstChild("HumanoidRootPart")
                if not h or not h.Parent then break end
                if h.Position.Y >= vy and math.abs(h.AssemblyLinearVelocity.Y) < 18 then
                    break
                end
                if lastSafe then
                    pcall(function()
                        _vzL(h)
                        _vzA(h)
                        h.CFrame = CFrame.new(lastSafe + Vector3.new(0, 5, 0))
                    end)
                end
                tries = tries + 1
                RunService.Heartbeat:Wait()
            end
            recovering = false
        end)
    end))
end

isTeleporting = false

task.spawn(function()
    local _since = nil
    while true do
        task.wait(1)
        if isTeleporting then
            _since = _since or os.clock()
            if os.clock() - _since > (tonumber(_G.MeerkoTPWatchdog) or 25) then
                isTeleporting = false
                _G.MeerkoStealHold = false
                _since = nil
                if _G.MeerkoTPDebug ~= false then
                    warn("[MeerkoTP] watchdog: isTeleporting was stuck -> cleared")
                end
            end
        else
            _since = nil
        end
    end
end)

_G.MeerkoDoClone = doClone
_G.MeerkoIsTeleporting = function() return isTeleporting end

function cframeStepThrough(hrp, waypoints, stepSize)
    if not hrp or not hrp.Parent or #waypoints == 0 then return end
    stepSize = stepSize or 24
    local lockY = hrp.Position.Y
    vizPath(hrp.Position, waypoints)
    local wpIdx = 1
    local deadline = os.clock() + 10
    local _lastFire = 0
    while hrp and hrp.Parent and os.clock() < deadline do
        if _G.MeerkoTPStop then break end
        do
            local char = hrp.Parent
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum and char and not char:FindFirstChild("Grapple Hook") then
                local g = findGrapple()
                if g then pcall(function() hum:EquipTool(g) end) end
            end
            if os.clock() - _lastFire > 0.3 then
                _lastFire = os.clock()
                if char and char:FindFirstChild("Grapple Hook") then
                    -- Elite-method fire can yield (cooldown gate / equip wait);
                    -- spawn it so the 24-stud step cadence stays on Heartbeat
                    task.spawn(_fireGrapple)
                end
            end
        end
        local target = waypoints[wpIdx]
        local flat = Vector3.new(target.X - hrp.Position.X, 0, target.Z - hrp.Position.Z)
        local mag = flat.Magnitude
        if mag < 2 then
            wpIdx = wpIdx + 1
            if wpIdx > #waypoints then break end
            RunService.Heartbeat:Wait()
        else
            local hop = math.min(stepSize, mag)
            local nextPos = hrp.Position + flat.Unit * hop
            local _, y = hrp.CFrame:ToEulerAnglesYXZ()
            hrp.CFrame = CFrame.new(Vector3.new(nextPos.X, lockY, nextPos.Z)) * CFrame.Angles(0, y, 0)
            _vzL(hrp)
            _vzA(hrp)
            task.wait(hop / math.clamp(tonumber(_G.MeerkoCFrameSpeed) or 450, 60, 900))
        end
    end
    do
        local hum = hrp and hrp.Parent and hrp.Parent:FindFirstChildOfClass("Humanoid")
        if hum then pcall(function() hum:UnequipTools() end) end
        task.wait(0.05)
        equipCarpet()
    end
    if hrp and hrp.Parent then
        _vzL(hrp)
        _vzA(hrp)
    end
end

function _isStraightRoute(fromPos, route)
    if not route or #route <= 1 then return true end
    local turns, lastDir, prev = 0, nil, fromPos
    for _, wp in ipairs(route) do
        local seg = wp - prev
        if seg.Magnitude > 1 then
            local dir = seg.Unit
            if lastDir and dir:Dot(lastDir) < 0.94 then turns = turns + 1 end
            lastDir = dir
        end
        prev = wp
    end
    return turns <= (tonumber(_G.MeerkoStraightMaxTurns) or 1)
end

function doVelocityTP(forceGrapple)
    if isTeleporting then return end
    if LP:GetAttribute("Stealing") == true then return end
    isTeleporting = true
    if _G.MeerkoDisarmSteal then _G.MeerkoDisarmSteal() end
    _G.MeerkoTPStop = false
    clearViz()
    if not NetModule then pcall(loadNet) end

    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then isTeleporting = false; return end

    pcall(function()
        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    end)

    if _inVoid(hrp) or hrp.AssemblyLinearVelocity.Y < -40 then
        _waitOutOfVoid(12)
        if _G.MeerkoTPStop then isTeleporting = false; return end
        char = LP.Character
        hrp = char and char:FindFirstChild("HumanoidRootPart")
        hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then isTeleporting = false; return end
    end

    local allPets = scanForTP()
    if #allPets == 0 then
        local _t0 = os.clock()
        while #allPets == 0 and os.clock() - _t0 < (tonumber(_G.MeerkoTPScanWait) or 10) do
            task.wait(0.05)
            allPets = scanForTP()
        end
    end
    if #allPets == 0 then isTeleporting = false; return end

    if not (type(_G.MeerkoStealTargetUID) == "string" and _G.MeerkoStealTargetUID ~= "") then
        local pool, seen = {}, {}
        local function _absorb(list)
            if type(list) ~= "table" then return end
            for _, p in ipairs(list) do
                if not p.conveyor and p.plot and p.slot ~= nil then
                    local uid = tostring(p.plot) .. "_" .. tostring(p.slot)
                    local ex = seen[uid]
                    if not ex then
                        seen[uid] = p
                        pool[#pool + 1] = p
                    elseif (p.mps or 0) > (ex.mps or 0) then
                        for i = 1, #pool do
                            if pool[i] == ex then pool[i] = p break end
                        end
                        seen[uid] = p
                    end
                end
            end
        end
        _absorb(allPets)
        for _ = 1, (tonumber(_G.MeerkoTPScans) or 2) do
            task.wait(tonumber(_G.MeerkoTPScanGap) or 0.05)
            local _ok, _more = pcall(scanForTP)
            if _ok then _absorb(_more) end
        end
        if #pool > 0 then allPets = pool end
    end

    local pet
    if type(_G.MeerkoStealTargetUID) == "string" and _G.MeerkoStealTargetUID ~= "" then
        pet = _findStealTarget(allPets)
        if not pet then isTeleporting = false; return end
    else
        local prio, best
        for _, p in ipairs(allPets) do
            if not p.conveyor then
                if p._pri and (not prio or p._pri < prio._pri) then prio = p end
                if not best or (p.mps or 0) > (best.mps or 0) then best = p end
            end
        end
        pet = prio or best or allPets[1]
    end
    local petPos = pet.position
    local petName = pet.name
    if _G.MeerkoArmSteal then pcall(_G.MeerkoArmSteal, pet) end
    _G.MeerkoStealSay(string.format("TP start -> %s [%s/%s] mps=%s pri=%s of %d", tostring(pet and pet.name), tostring(pet and pet.plot), tostring(pet and pet.slot), tostring(pet and pet.mps), tostring(pet and pet._pri), #allPets))

    _G.MeerkoStealHold = true

    pcall(fireGrapple)

    local adjY = petPos.Y
    if TALL_PETS[petName] then adjY = petPos.Y - TALL_OFFSET end
    local coordTable = adjY > 23.15 and MK_UPPER or MK_LOWER

    if petPos.Y <= 8.9 and isPlotUnlocked(pet.plot) then
        carpetEngage(forceGrapple)
        vZero(hrp)
        local _to = Vector3.new(petPos.X, -4, petPos.Z)
        local route = computeRoute(hrp.Position, _to, nil)
        if not route or #route == 0 then route = { _to } end
        local _straight = _isStraightRoute(hrp.Position, route)
        local _obSpeed = math.clamp(tonumber(_G.TPVelocity) or 400, 200, 750)
        if _straight then
            _obSpeed = math.clamp(tonumber(_G.MeerkoStraightSpeed) or 300, 100, 500)
        end
        do
            local _len, _prev = 0, hrp.Position
            for _, wp in ipairs(route) do _len = _len + (wp - _prev).Magnitude; _prev = wp end
            if _len < 100 then
                _obSpeed = math.clamp(tonumber(_G.MeerkoCloseSpeed) or 80, 20, 400)
            end
        end
        _obSpeed = _pingAdjustSpeed(_obSpeed)
        velMoveThrough(hrp, route, _obSpeed, true, true)
        if hrp and hrp.Parent then
            _vzL(hrp)
            _vzA(hrp)
        end
        _G.MeerkoStealHold = false
        isTeleporting = false
        if _G.MeerkoTPStop then return end
        return
    end

    local closestData, skyKey = findClosest(petPos, coordTable)
    if not closestData or not skyKey then _G.MeerkoStealHold = false; isTeleporting = false; return end

    local destPos = closestData.coord

    local _carpet = carpetEngage(forceGrapple)
    vZero(hrp)

    local facingDir = closestData.facing == "NORTH" and Vector3.new(0, 0, -1) or Vector3.new(0, 0, 1)

    local _frontApproach = false
    do
        local isUpper = (coordTable == MK_UPPER)
        local idx = getClosestBaseIdx(petPos)
        local frontCoord, frontFace = buildFrontCandidate(idx, isUpper, hrp.Position.Z)
        local bestCoord, bestFace = frontCoord, frontFace
        local bestDist = (hrp.Position - frontCoord).Magnitude
        local pickedFront = true

        -- 1st floor (MK_LOWER) approaches from the side only.
        -- The front candidate is still built and left in bestCoord as a
        -- fallback: plotSides() can legitimately return nothing for a plot,
        -- and without it there would be no destination at all.
        local _sideOnly = (not isUpper) and (_G.MeerkoFirstFloorSideOnly ~= false)

        local _tb = BASES_LOW[idx]
        local _isWest = idx <= 4
        local _rowBlocked = false
        local _dx, _dz = hrp.Position.X - _tb.X, hrp.Position.Z - _tb.Z
        local _distToBase = math.sqrt(_dx * _dx + _dz * _dz)
        local _sideRange = tonumber(_G.MeerkoSideTPRange) or 100
        -- _rowBlocked forces the front approach, so it must not run in side-only mode
        if not _sideOnly and _G.MeerkoPreferFrontOnRow ~= false and _distToBase > _sideRange then
            for i = 1, 8 do
                if i ~= idx and (i <= 4) == _isWest then
                    local bz = BASES_LOW[i].Z
                    if (bz - hrp.Position.Z) * (bz - _tb.Z) < 0 then _rowBlocked = true; break end
                end
            end
        end

        -- drop the front's distance so the nearest side always wins the compare
        if _sideOnly then bestDist = math.huge end

        if not _rowBlocked then
            for _, d in ipairs(plotSides(coordTable, idx)) do
                local dd = (hrp.Position - d.coord).Magnitude
                if dd < bestDist then
                    bestDist = dd
                    bestCoord = d.coord
                    bestFace = d.facing == "NORTH" and Vector3.new(0, 0, -1) or Vector3.new(0, 0, 1)
                    pickedFront = false
                end
            end
        end
        destPos = bestCoord
        facingDir = bestFace
        _frontApproach = pickedFront
        if _G.MeerkoTPDebug ~= false then
            local _mode = pickedFront and "FRONT" or "SIDE"
            if _sideOnly then
                -- pickedFront still true here means no side coord existed
                _mode = pickedFront and "FRONT(sideonly-fallback)" or "SIDE(sideonly)"
            end
            warn(string.format(
                "[MeerkoTP] PICK baseIdx=%d %s floor=%s | pet=(%.0f,%.0f,%.0f) plot=%s | dest=(%.0f,%.0f,%.0f) | me=(%.0f,%.0f,%.0f) | sides=%d",
                idx, _mode, isUpper and "2nd" or "1st",
                petPos.X, petPos.Y, petPos.Z, tostring(pet.plot),
                destPos.X, destPos.Y, destPos.Z,
                hrp.Position.X, hrp.Position.Y, hrp.Position.Z,
                #plotSides(coordTable, idx)))
        end
    end

    if facingDir and facingDir.Magnitude > 0.1 then
        local axis = facingDir.Unit
        local toPlayer = hrp.Position - destPos
        local sign = (axis:Dot(toPlayer) >= 0) and 1 or -1
        destPos = destPos + axis * sign * (tonumber(_G.MeerkoCloneBackoff) or 0.5)
    end

    local _route = computeRoute(hrp.Position, destPos, facingDir, nil, true)

    local ASCEND_STEP = 10
    local _stepped = {}
    do
        local prev = hrp.Position
        for _, wp in ipairs(_route) do
            local dy = wp.Y - prev.Y
            if dy > ASCEND_STEP * 1.5 then
                local n = math.ceil(dy / ASCEND_STEP)
                for s = 1, n - 1 do
                    local t = s / n
                    _stepped[#_stepped + 1] = Vector3.new(
                        prev.X + (wp.X - prev.X) * t,
                        prev.Y + dy * t,
                        prev.Z + (wp.Z - prev.Z) * t
                    )
                end
            end
            _stepped[#_stepped + 1] = wp
            prev = wp
        end
    end
    local _mainSpeed = math.clamp(tonumber(_G.TPVelocity) or 400, 200, 750)
    do
        local _len, _prev = 0, hrp.Position
        for _, wp in ipairs(_route) do _len = _len + (wp - _prev).Magnitude; _prev = wp end
        if _len < 100 then
            _mainSpeed = math.clamp(tonumber(_G.MeerkoCloseSpeed) or 80, 20, 400)
        end
    end
    _mainSpeed = _pingAdjustSpeed(_mainSpeed)
    velMoveThrough(hrp, _stepped, _mainSpeed, true, true)
    if _G.MeerkoTPStop then
        if hrp and hrp.Parent then vZero(hrp) end
        _G.MeerkoStealHold = false
        isTeleporting = false
        return
    end

    do
        local above = destPos + Vector3.new(0, 16, 0)
        local _t0 = os.clock()
        while os.clock() - _t0 < 1.5 do
            if not hrp or not hrp.Parent then break end
            if LP:GetAttribute("Stealing") or _G.MeerkoTPStop then break end
            equipCarpet()
            local d = above - hrp.Position
            local flat = Vector3.new(d.X, 0, d.Z).Magnitude
            if flat <= 3 and hrp.Position.Y >= destPos.Y then break end
            if d.Y > 3 then
                local _hum = hrp.Parent and hrp.Parent:FindFirstChildOfClass("Humanoid")
                if _hum then
                    local st = _hum:GetState()
                    if st ~= Enum.HumanoidStateType.Jumping and st ~= Enum.HumanoidStateType.Freefall then
                        pcall(function() _hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
                        pcall(function() _hum.Jump = true end)
                    end
                end
            end
            _setFlightVel(hrp, d.Unit * math.min(math.max(d.Magnitude * 8, 55), 320))
            _vzA(hrp)
            RunService.Heartbeat:Wait()
        end
    end

    do
        local _runCap = _frontApproach and (tonumber(_G.MeerkoFrontRunIn) or 120) or 320
        if _G.MeerkoTPSafeMode ~= false then
            _runCap = math.min(_runCap, tonumber(_G.MeerkoTPSafeSpeed) or 300)
        end
        local _t0 = os.clock()
        local _bestMag, _bestT = math.huge, os.clock()
        while os.clock() - _t0 < 4 do
            if not hrp or not hrp.Parent then break end
            if LP:GetAttribute("Stealing") or _G.MeerkoTPStop then break end
            equipCarpet()
            local diff = destPos - hrp.Position
            local mag = diff.Magnitude
            if mag <= 3 then break end
            if mag < _bestMag - 0.5 then _bestMag = mag; _bestT = os.clock()
            elseif os.clock() - _bestT > 0.6 then break end
            if diff.Y > 3 then
                local _hum = hrp.Parent and hrp.Parent:FindFirstChildOfClass("Humanoid")
                if _hum then
                    local st = _hum:GetState()
                    if st ~= Enum.HumanoidStateType.Jumping and st ~= Enum.HumanoidStateType.Freefall then
                        pcall(function() _hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
                        pcall(function() _hum.Jump = true end)
                    end
                end
            end
            _setFlightVel(hrp, diff.Unit * math.min(math.max(mag * 8, 55), _runCap))
            _vzA(hrp)
            RunService.Heartbeat:Wait()
        end
    end

    if hrp and hrp.Parent and not _G.MeerkoTPStop then
        local _tol = tonumber(_G.MeerkoTPReachTolerance) or 4.5
        local _retryMax = math.clamp(tonumber(_G.MeerkoTPRetryCount) or 2, 0, 4)
        for _retry = 1, _retryMax do
            if not (hrp and hrp.Parent) or _G.MeerkoTPStop then break end
            local _flatOff = Vector3.new(destPos.X - hrp.Position.X, 0, destPos.Z - hrp.Position.Z).Magnitude
            local _yOff = math.abs(destPos.Y - hrp.Position.Y)
            if _flatOff <= _tol and _yOff <= 6 then break end
            if _G.MeerkoTPDebug ~= false then
                warn(string.format("[MeerkoTP] REACH retry %d/%d: flat=%.1f y=%.1f -> fresh route", _retry, _retryMax, _flatOff, _yOff))
            end
            task.wait(tonumber(_G.MeerkoTPRetryDelay) or 0.08)
            local _fresh = computeRoute(hrp.Position, destPos, facingDir, nil, true)
            if not _fresh or #_fresh == 0 then _fresh = { destPos } end
            local _freshStepped = {}
            local _prev = hrp.Position
            for _, _wp in ipairs(_fresh) do
                local _dy = _wp.Y - _prev.Y
                if _dy > 15 then
                    local _n = math.ceil(_dy / 10)
                    for _s = 1, _n - 1 do
                        local _t = _s / _n
                        _freshStepped[#_freshStepped + 1] = Vector3.new(
                            _prev.X + (_wp.X - _prev.X) * _t,
                            _prev.Y + _dy * _t,
                            _prev.Z + (_wp.Z - _prev.Z) * _t)
                    end
                end
                _freshStepped[#_freshStepped + 1] = _wp
                _prev = _wp
            end
            local _retrySpeed = _mainSpeed
            if _G.MeerkoTPSafeMode ~= false then
                _retrySpeed = math.min(_retrySpeed, tonumber(_G.MeerkoTPSafeSpeed) or 300)
            end
            velMoveThrough(hrp, _freshStepped, _retrySpeed, true, true)
            if hrp and hrp.Parent then
                _vzL(hrp); _vzA(hrp)
            end
        end
    end

    if hrp and hrp.Parent then
        hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + facingDir)
    end
    vZero(hrp)

    local syncFrames = (_G.MeerkoTPSafeMode ~= false) and 8 or 5
    local syncConn
    syncConn = RunService.Heartbeat:Connect(LPH_NO_VIRTUALIZE(function()
        if not hrp or not hrp.Parent then syncConn:Disconnect(); return end
        syncFrames = syncFrames - 1
        hrp.CFrame = CFrame.new(destPos, destPos + facingDir)
        _vzL(hrp)
        _vzA(hrp)
        if syncFrames <= 0 then syncConn:Disconnect() end
    end))

    for _ = 1, 20 do
        task.wait(0.05)
        if hum.FloorMaterial ~= Enum.Material.Air then break end
    end

    do
        local stable, _st0 = 0, os.clock()
        while os.clock() - _st0 < 3 do
            if _G.MeerkoTPStop then break end
            local _hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not _hrp or not _hrp.Parent then break end
            local flat = (Vector3.new(_hrp.Position.X, 0, _hrp.Position.Z) - Vector3.new(destPos.X, 0, destPos.Z)).Magnitude
            if flat <= 3.5 and math.abs(_hrp.Position.Y - destPos.Y) <= 4 then
                stable = stable + 1
                if stable >= 4 then break end
            else
                stable = 0
                pcall(function() _hrp.CFrame = CFrame.new(destPos, destPos + facingDir) end)
                _vzL(_hrp)
                _vzA(_hrp)
            end
            RunService.Heartbeat:Wait()
        end
    end
    local _ahrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    local _clonePos = (_ahrp and _ahrp.Parent and _ahrp.Position) or destPos

    local _clonePlat = Instance.new("Part")
    -- was "MeerkoHubClonePlatform"; an unnamed Part is indistinguishable from
    -- the thousands the game already has in Workspace.
    _clonePlat.Size = Vector3.new(12, 1, 12)
    _clonePlat.Position = Vector3.new(_clonePos.X, _clonePos.Y - 3, _clonePos.Z)
    _clonePlat.Anchored = true
    _clonePlat.CanCollide = true
    _clonePlat.Transparency = 1
    _clonePlat.Material = Enum.Material.SmoothPlastic
    _clonePlat.Parent = workspace

    if _ahrp and _ahrp.Parent then
        _vzL(_ahrp)
        _vzA(_ahrp)
    end

    local _preClonePos, _preCloneChar
    do
        _preCloneChar = LP.Character
        local _h = _preCloneChar and _preCloneChar:FindFirstChild("HumanoidRootPart")
        _preClonePos = _h and _h.Position or destPos
    end
    local _charAdded = false
    local _caConn = LP.CharacterAdded:Connect(function() _charAdded = true end)

    _G.MeerkoStealHold = false

    task.wait(tonumber(_G.LandingDelay) or tonumber(_G.TPCloneDelay) or 0.35)

    if facingDir and facingDir.Magnitude > 0.1 then
        local _pinHum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        if _pinHum then pcall(function() _pinHum.AutoRotate = false end) end
        for _ = 1, 4 do
            local _h = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            if not _h or not _h.Parent then break end
            pcall(function()
                _h.CFrame = CFrame.new(_h.Position, _h.Position + facingDir)
                _vzL(_h)
                _vzA(_h)
            end)
            RunService.Heartbeat:Wait()
        end
    end

    local _cloneOk = doClone()
    if _clonePlat then
        local _plat = _clonePlat
        _clonePlat = nil
        task.delay(1.5, function() pcall(function() _plat:Destroy() end) end)
    end
    do
        local _t0 = os.clock()
        repeat
            if _charAdded then break end
            if LP.Character ~= _preCloneChar then break end
            local _h = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            if _h then
                local _dx = _h.Position.X - _preClonePos.X
                local _dz = _h.Position.Z - _preClonePos.Z
                if (_dx * _dx + _dz * _dz) > 1 then break end
            end
            RunService.Heartbeat:Wait()
        until os.clock() - _t0 > (tonumber(_G.MeerkoCloneSettle) or 0.5)
    end
    if _caConn then _caConn:Disconnect() end

    pcall(function()
        local _rh = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        if _rh then _rh.AutoRotate = true end
    end)

    goToBrainrot(petPos, pet and pet.slot)
    isTeleporting = false
    if _G.MeerkoTPStop then return end
    if _G.MeerkoArmSteal then pcall(_G.MeerkoArmSteal, pet) end
    _G.MeerkoStealSay("TP arrive -> " .. tostring(pet and pet.name) .. " [" .. tostring(pet and pet.plot) .. "/" .. tostring(pet and pet.slot) .. "]")
end

_manualTPBusy = false
function manualFullTP()
    if _manualTPBusy or isTeleporting then return end
    if LP:GetAttribute("Stealing") == true then return end
    _manualTPBusy = true
    if _G.MeerkoScanProfile and _G.MeerkoScanMode == "fast" then _G.MeerkoScanProfile("normal") end
    local okAll = pcall(function()
        local _t0 = os.clock()
        local _lastN, _lastTop = -1, nil
        repeat
            local ok, pets = pcall(scanForTP)
            if ok and pets and #pets > 0 then
                local top = tostring(pets[1].plot) .. "_" .. tostring(pets[1].slot)
                if #pets == _lastN and top == _lastTop then break end
                _lastN, _lastTop = #pets, top
                task.wait(tonumber(_G.MeerkoScanSettle) or 0.06)
            else
                task.wait(0.05)
            end
        until os.clock() - _t0 > (tonumber(_G.MeerkoTPMaxWait) or 4)
        doVelocityTP(true)
    end)
    _manualTPBusy = false
    return okAll
end
_G.MeerkoStartSideTP = manualFullTP

if type(_G.SHARED_PRIORITY_ITEMS) ~= "table" or #_G.SHARED_PRIORITY_ITEMS == 0 then
_G.SHARED_PRIORITY_ITEMS = {
    "Headless Horseman","Strawberry Elephant","Signore Carapace","John Pork","Meowl",
    "Elefanto Frigo","Arcadragon","Skibidi Toilet","Griffin","Antonio",
    "Dragon Aquanini","Dragon Gingerini","Love Love Bear","Kalika Bros","Moby Bros",
    "Grabatron","Jelly Moby","La Supreme Combinasion","Ginger Gerat","Digi Narwhal",
    "Hydra Dragon Cannelloni","Hydra Bunny","Bunny and Eggy","Kraken","Fishino Clownino",
    "Tirilikalika Tirilikalako","Pancake and Syrup","Dragon Cannelloni","Sammyni Cakini","Ketupat Bros",
    "Bumbatron","Venuspino","Dug dug dug","La Casa Boo","Rico Dinero",
    "Foxini Lanternini","Duggy Bros","Rosey and Teddy","Globa Steppa","Los Hackers",
    "Cerberus","Fragrama and Chocrama","Cooki and Milki","La Secret Combinasion","Burguro and Fryuro",
    "Capitano Moby","Spooky and Pumpky","Garama and Madundung","Popcuru and Fizzuru","Pizza and Ranch",
    "Reinito Sleighito","Tenini Ballini","Fragola La La La","Ketchuru and Musturu","Tralaledon",
    "Tictac Sahur","Ketupat Kepat","Tang Tang Keletang","Orcaledon","La Ginger Sekolah",
    "Los Spaghettis","Lavadorito Spinito","Swaggy Bros","La Taco Combinasion","Los Primos",
    "Los Chillis","Chillin Chili","Tuff Toucan","W or L","Chipso and Queso",
    "Guest 666","Money Money Reindeer","Quackini Snackini","Los Sekolahs","Los Tacoritas",
    "Los Amigos","Fortunu and Cashuru","Jolly Jolly Sahur","Boppin Bunny","Gym Bros",
    "Los Cupids","Festive 67","Celularcini Viciosini","Cloverat Clapat","La Food Combinasion",
    "Hopilikalika Hopilikalako","Celestial Pegasus","Sammyni Fattini","Money Money Bros","La Spooky Grande",
    "Cash or Card","Swag Soda","Los Planitos","Lovin Rose","Tacorita Bicicleta",
    "Los Jolly Combinasionas","La Romantic Grande","La Easter Grande","Los Hotspotsitos","Rosetti Tualetti",
    "Los Bros","Gobblino Uniciclino","Chicleteira Cupideira","La Extinct Grande","Las Sis",
    "Nacho Spyder","Gold Gold Gold","Los Mariachis","Snailo Clovero","La Jolly Grande",
    "Los Candies","Churrito Bunnito","Bananito","Eviledon","Los 67",
    "Los Sweethearts","Noo my Heart","La Lucky Grande","Ventoliero Pavonero","Baskito",
    "Chimnino","Los Puggies","Camera Ramena","Los 25","Spinny Hammy",
    "Money Money Puggy","Cigno Fulgoro","Los Spooky Combinasionas","Chicleteira Noelteira","Mariachi Corazoni",
    "Tacorillo Crocodillo","Noo my Gold","Los Mobilis","Mieteteira Bicicleteira","DJ Panda",
    "Los Combinasionas","Nuclearo Dinossauro","Bacuru and Egguru","Spaghetti Tualetti","La Grande Combinasion",
    "Esok Sekolah",
}
end

UIS.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if input.KeyCode == Enum.KeyCode.V then
        task.spawn(function() pcall(doClone) end)
    end
    local want = _G._stp_tpKeyName
    if type(want) ~= "string" or want == "" then want = "T" end
    if input.KeyCode.Name == want then
        task.spawn(function() pcall(manualFullTP) end)
    end
end)

task.spawn(function() pcall(loadModules) pcall(loadNet) end)

_G.MeerkoChannelsReady = false

task.spawn(function()
    local char = LP.Character or LP.CharacterAdded:Wait()

    local hrpReady, humReady = false, false
    task.spawn(function() char:WaitForChild("HumanoidRootPart", 20); hrpReady = true end)
    task.spawn(function() char:WaitForChild("Humanoid", 20); humReady = true end)
    local _tw0 = os.clock()
    while (not hrpReady or not humReady) and os.clock() - _tw0 < 20 do
        RunService.Heartbeat:Wait()
    end
    pcall(loadModules); pcall(loadNet)
    if _G.MeerkoAutoTP == false then return end

    if _G.MeerkoWaitForTools ~= false and type(_G.MeerkoToolsReady) == "function" then
        local _tt0 = os.clock()
        local _tcap = tonumber(_G.MeerkoToolWait) or 30
        while os.clock() - _tt0 < _tcap do
            local ok, ready = pcall(_G.MeerkoToolsReady)
            if ok and ready then break end
            if _G.MeerkoAutoTP == false then return end
            task.wait(0.2)
        end
    end
    pcall(carpetEngage)
    do
        local _d = tonumber(_G._stp_tpDelay) or tonumber(_G.TPDelay) or 0
        if _d > 0 then task.wait(_d) end
    end

    local _w0 = os.clock()
    local _wMax = tonumber(_G.MeerkoAutoTPWait) or 20
    while os.clock() - _w0 < _wMax do
        if _G.MeerkoAutoTP == false then return end
        if LP:GetAttribute("Stealing") == true then return end
        local ok, pets = pcall(scanForTP)
        if ok and pets and #pets > 0 then break end
        task.wait(tonumber(_G.MeerkoAutoTPPoll) or 0.05)
    end
    pcall(doVelocityTP)
    if _G.MeerkoScanProfile then _G.MeerkoScanProfile("normal") end
end)

do
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local LP = Players.LocalPlayer
    local PG = LP:WaitForChild("PlayerGui")

    local function diag()
        pcall(loadModules)
        local Plots = workspace:FindFirstChild("Plots")
        local nPlots = Plots and #Plots:GetChildren() or 0
        local nCh, nOwn, nAl = 0,0,0
        if Plots then
            for _, plot in ipairs(Plots:GetChildren()) do
                local ch = getPlotChannel(plot.Name)
                if ch then
                    nCh = nCh + 1
                    if ownerInGame(ch) then nOwn = nOwn + 1 end
                    if channelGet(ch, "AnimalList") then nAl = nAl + 1 end
                end
            end
        end
        local ok, pets = pcall(scanAllPets)
        local nPets = (ok and pets and #pets) or 0
        local msg = string.format("plots=%d ch=%d owner=%d animals=%d PETS=%d", nPlots, nCh, nOwn, nAl, nPets)
        print("[TP TEST] " .. msg)
        if nPets > 0 and pets[1] then
            print("[TP TEST] top=", pets[1].name, pets[1].plot, pets[1].slot)
        end
        return nPets
    end

    local function findStealPrompt(pet)
        if not pet then return nil end
        if pet.plot and pet.slot then
            local plots = workspace:FindFirstChild("Plots")
            local plot = plots and plots:FindFirstChild(pet.plot)
            local podiums = plot and plot:FindFirstChild("AnimalPodiums")
            local podium = podiums and podiums:FindFirstChild(tostring(pet.slot))
            if podium then
                local base = podium:FindFirstChild("Base")
                local spawn = base and base:FindFirstChild("Spawn")
                local attach = spawn and spawn:FindFirstChild("PromptAttachment")
                if attach then
                    for _, p in ipairs(attach:GetChildren()) do
                        if p:IsA("ProximityPrompt") then return p end
                    end
                end
                for _, d in ipairs(podium:GetDescendants()) do
                    if d:IsA("ProximityPrompt") then return d end
                end
            end
        end
        return nil
    end

    local InternalStealCache = {}
    local STEAL_HOLD_DURATION = 1.3
    local STEAL_PROXIMITY = tonumber(_G.MeerkoStealProximity) or 28
    local _stealHoldStart, _stealHoldActive = 0, false
    local _stealTarget, _stealArmedAt = nil, 0
    local _lastTargetPick, _lastPickUid, _currentTargetName = 0, nil, nil
    local _stealLastScan, _autoLastScan = 0, 0
    local _inRangeLast = 0
    local _armCheckAt = 0
    local _petsCache, _petsCacheAt = nil, 0

    -- one scan shared by the picker, the in-range check and the watchdog
    local function _scanCached(now, maxAge)
        if _petsCache and (now - _petsCacheAt) <= (maxAge or 0.15) then return _petsCache end
        local ok, pets = pcall(scanAllPets)
        if ok and type(pets) == "table" then
            _petsCache, _petsCacheAt = pets, now
            return pets
        end
        return nil
    end

    -- is the brainrot still on that podium, per the game's own data
    local function _petListed(plot, slot)
        local ch = getPlotChannel(plot)
        local al = ch and channelGet(ch, "AnimalList")
        if type(al) ~= "table" then return true, false end
        local e = al[slot]
        if e == nil then e = al[tonumber(slot) or -1] end
        if e == nil then e = al[tostring(slot)] end
        return e ~= nil, true
    end

    local function _prox()
        return tonumber(_G.MeerkoStealProximity) or STEAL_PROXIMITY
    end
    local function _holdDur()
        return tonumber(_G.MeerkoStealHoldDuration) or STEAL_HOLD_DURATION
    end

    -- after each attempt: did the brainrot actually leave that podium?
    -- one in-range miss flips the method, so the next grab already uses the other one
    local _cooldownUntil = 0
    local function _verifyFire(pet, path, judge)
        task.delay(tonumber(_G.MeerkoVerifyDelay) or 0.5, function()
            if not (pet and pet.plot and pet.slot ~= nil) then return end
            local listed, known = true, false
            pcall(function() listed, known = _petListed(pet.plot, pet.slot) end)
            if not known then return end
            if not listed then
                _G.MeerkoStealFails = 0
                _cooldownUntil = 0
                _G.MeerkoStealSay("steal landed (" .. tostring(path) .. ")")
                return
            end
            if not judge then _cooldownUntil = 0 return end
            if _G.MeerkoAutoSwapMethod ~= true then return end
            _G.MeerkoStealFails = (_G.MeerkoStealFails or 0) + 1
            if _G.MeerkoStealFails >= (tonumber(_G.MeerkoFailsBeforeSwap) or 1) then
                _G.MeerkoStealFails = 0
                if path == "remote" then
                    _G.MeerkoRemoteStealOn = false
                    _G.MeerkoStealSay("remote missed -> prompt mode")
                else
                    _G.MeerkoRemoteStealOn = true
                    _G.MeerkoStealSay("prompt missed -> remote mode")
                end
            end
        end)
    end
    local function _holdBusy()
        if _stealHoldActive
            and (tick() - _stealHoldStart) < (_holdDur() + (tonumber(_G.MeerkoStealRetryGap) or 0.15)) then
            return true
        end
        return tick() < _cooldownUntil
    end

    local _armedPet, _armLostSince = nil, 0
    local function _armLivePos(p)
        if not (p and p.plot and p.slot ~= nil) then return nil end
        local plots = workspace:FindFirstChild("Plots")
        local plot = plots and plots:FindFirstChild(p.plot)
        if not plot then return nil end
        local ok, pos = pcall(getPetPosition, plot, p.slot)
        if ok then return pos end
        return nil
    end
    _G.MeerkoArmSteal = function(pet)
        if type(pet) ~= "table" or type(pet.plot) ~= "string" or pet.slot == nil then return end
        _armedPet = {
            name = pet.name, index = pet.index, mps = pet.mps, _pri = pet._pri,
            plot = pet.plot, slot = tostring(pet.slot), position = pet.position,
        }
        _armLostSince = 0
        _stealTarget = _armedPet
        _stealArmedAt = os.clock()
        if type(pet.name) == "string" and pet.name ~= "" then _currentTargetName = pet.name end
    end
    _G.MeerkoDisarmSteal = function()
        _armedPet, _armLostSince = nil, 0
    end
    _G.MeerkoArmedName = function() return _armedPet and _armedPet.name or nil end

    local UIC = {
        bg   = Color3.fromRGB(12, 12, 18),
        bg2  = Color3.fromRGB(18, 18, 26),
        card = Color3.fromRGB(24, 24, 36),
        track = Color3.fromRGB(32, 32, 48),
        line = Color3.fromRGB(60, 60, 80),
        acc  = Color3.fromRGB(45, 220, 120),
        acc2 = Color3.fromRGB(120, 255, 175),
        txt  = Color3.fromRGB(255, 255, 255),
        dim  = Color3.fromRGB(140, 140, 160),
    }
    local UIF, UIFB = Enum.Font.Gotham, Enum.Font.GothamBold

    local function mk(class, parent, props)
        local o = Instance.new(class)
        for k, v in pairs(props or {}) do o[k] = v end
        o.Parent = parent
        return o
    end
    local function corner(o, r) mk("UICorner", o, { CornerRadius = UDim.new(0, r or 8) }) return o end
    local function stroke(o, col) mk("UIStroke", o, { Color = col or UIC.line, Thickness = 1 }) return o end

    pcall(function()
        local _oldDbg = LP:FindFirstChild("PlayerGui")
        _oldDbg = _oldDbg and _oldDbg:FindFirstChild("MeerkoStealDbg")
        if _oldDbg then _oldDbg:Destroy() end
    end)

    -- This bar was the one piece of UI parented straight into PlayerGui under a
    -- self-identifying name, so the game could both see it and name it. Prefer
    -- the executor's hidden container; fall back to PlayerGui under a native-
    -- looking name, and track it by reference rather than re-finding by name.
    local stealBarSg, stealBarFill, stealBarTitle, stealBarPct
    local function ensureStealBar()
        if stealBarSg and stealBarSg.Parent then return end
        local host = (gethui and gethui()) or PG
        stealBarSg = mk("ScreenGui", host, {
            Name = "hudProgressLayer", ResetOnSpawn = false,
            IgnoreGuiInset = true, DisplayOrder = 120,
        })
        local wrap = mk("Frame", stealBarSg, {
            Name = "Wrap", AnchorPoint = Vector2.new(0.5, 1),
            Position = UDim2.new(0.5, 0, 1, -120), Size = UDim2.fromOffset(260, 34),
            BackgroundTransparency = 1,
        })
        stealBarTitle = mk("TextLabel", wrap, {
            Size = UDim2.new(1, -46, 0, 12), Position = UDim2.fromOffset(0, 0),
            BackgroundTransparency = 1, Font = UIFB, TextSize = 11,
            TextColor3 = UIC.txt, TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd, Text = "STEAL",
        })
        mk("UIStroke", stealBarTitle, {
            Color = Color3.new(0, 0, 0), Thickness = 2, Transparency = 0.55,
        })
        stealBarPct = mk("TextLabel", wrap, {
            Size = UDim2.fromOffset(42, 12), Position = UDim2.new(1, -42, 0, 0),
            BackgroundTransparency = 1, Font = UIFB, TextSize = 11,
            TextColor3 = UIC.acc, TextXAlignment = Enum.TextXAlignment.Right, Text = "0%",
        })
        mk("UIStroke", stealBarPct, {
            Color = Color3.new(0, 0, 0), Thickness = 2, Transparency = 0.55,
        })
        local track = corner(mk("Frame", wrap, {
            Position = UDim2.new(0, 0, 1, -6), Size = UDim2.new(1, 0, 0, 6),
            BackgroundColor3 = UIC.track, BackgroundTransparency = 0.25, BorderSizePixel = 0,
        }), 3)
        stroke(track, Color3.fromRGB(10, 8, 4))
        stealBarFill = corner(mk("Frame", track, {
            Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = UIC.acc, BorderSizePixel = 0,
        }), 3)
        mk("UIGradient", stealBarFill, {
            Color = ColorSequence.new(UIC.acc, UIC.acc2),
        })
        stealBarSg.Enabled = true
    end
    local function showStealBar(name, pct)
        pcall(function()
            ensureStealBar()
            pct = math.clamp(tonumber(pct) or 0, 0, 1)
            stealBarSg.Enabled = true
            stealBarTitle.Text = name and ("STEAL  " .. tostring(name)) or "STEAL"
            stealBarPct.Text = math.floor(pct * 100 + 0.5) .. "%"
            stealBarFill.Size = UDim2.new(pct, 0, 1, 0)
        end)
    end
    local function setStealBarPct(pct)
        if not stealBarSg or not stealBarSg.Enabled then return end
        pcall(function()
            pct = math.clamp(tonumber(pct) or 0, 0, 1)
            stealBarPct.Text = tostring(math.floor(pct * 100 + 0.5)) .. "%"
            stealBarFill.Size = UDim2.new(pct, 0, 1, 0)
        end)
    end
    local function hideStealBar()
        pcall(function()
            ensureStealBar()
            stealBarSg.Enabled = true
            stealBarTitle.Text = "STEAL"
            stealBarPct.Text = "0%"
            stealBarFill.Size = UDim2.new(0, 0, 1, 0)
        end)
    end
    task.defer(hideStealBar)

    local function buildStealCallbacks(prompt)
        if InternalStealCache[prompt] then return end
        if not prompt or not prompt.Parent then return end
        local data = { holdCallbacks = {}, triggerCallbacks = {}, holdEndCallbacks = {}, ready = true }
        local function grab(sig, into)
            local ok, conns = pcall(getconnections, sig)
            if ok and type(conns) == "table" then
                for _, c in ipairs(conns) do
                    if type(c.Function) == "function" then table.insert(into, c.Function) end
                end
            end
        end
        grab(prompt.PromptButtonHoldBegan, data.holdCallbacks)
        grab(prompt.Triggered, data.triggerCallbacks)
        grab(prompt.PromptButtonHoldEnded, data.holdEndCallbacks)
        if #data.holdCallbacks > 0 or #data.triggerCallbacks > 0 or #data.holdEndCallbacks > 0 then
            InternalStealCache[prompt] = data
        end
    end

    local _rawFireServer = Instance.new("RemoteEvent").FireServer
    local _reBegin, _reCommit = nil, nil
    local _reState, _reRetryAt = {}, {}
    local function _re(cache, hash)
        if cache and cache.Parent then return cache end
        local st = _reState[hash]
        if typeof(st) == "Instance" then
            if st.Parent then return st end
            _reState[hash] = nil
            st = nil
        end
        if st == "pending" then return nil end
        if st == "failed" and os.clock() < (_reRetryAt[hash] or 0) then return nil end
        _reState[hash] = "pending"
        task.spawn(function()
            local got
            pcall(function()
                if _G.MeerkoGetRemote then got = _G.MeerkoGetRemote("RemoteEvent", hash) end
            end)
            if typeof(got) == "Instance" then
                _reState[hash] = got
                _G.MeerkoStealSay("remote resolved " .. tostring(hash):sub(1, 8))
            else
                _reState[hash] = "failed"
                _reRetryAt[hash] = os.clock() + (tonumber(_G.MeerkoRemoteRetry) or 5)
                _G.MeerkoStealSay("remote resolve FAILED " .. tostring(hash):sub(1, 8))
            end
        end)
        task.delay(tonumber(_G.MeerkoRemoteResolveWait) or 3, function()
            if _reState[hash] == "pending" then
                _reState[hash] = "failed"
                _reRetryAt[hash] = os.clock() + (tonumber(_G.MeerkoRemoteRetry) or 5)
                _G.MeerkoStealSay("remote resolve TIMEOUT " .. tostring(hash):sub(1, 8))
            end
        end)
        return nil
    end

    local function _stealBegin()
        _reBegin = _re(_reBegin, "f40f7d9e-2f0d-4167-b250-899273f46874")
        if not _reBegin then return false end
        local t = workspace:GetServerTimeNow() + 124
        pcall(_rawFireServer, _reBegin, t, "68c86eb7-eb7e-4b4d-96ae-cf7cd847c5b0")
        pcall(function() _rawFireServer(_reBegin, t, "07b9cc25-2a1f-4a26-a0ec-f2fab578d8bd") end)
        return true
    end

    local function _stealCommit(plot, slot)
        _reCommit = _re(_reCommit, "3ba148c9-7ed6-4675-93f8-9f7c356a2c54")
        if not _reCommit then return false end
        if type(plot) ~= "string" or slot == nil then return false end
        local sl = tonumber(slot) or slot
        local t = workspace:GetServerTimeNow() + 31
        pcall(_rawFireServer, _reCommit, t, "cda5c764-d4e3-45c4-94e4-53a538347590", plot, sl)
        pcall(function()
            _rawFireServer(_reCommit, t, "8c852fbf-d542-4ef4-aa28-612e24db8d4a", plot, sl)
        end)
        return true
    end
    _G.MeerkoStealBegin, _G.MeerkoStealCommit = _stealBegin, _stealCommit

    -- fire the same two remotes (4) does; have them resolved before the first grab
    local _RE_BEGIN  = "f40f7d9e-2f0d-4167-b250-899273f46874"
    local _RE_COMMIT = "3ba148c9-7ed6-4675-93f8-9f7c356a2c54"
    local _reWarmT0 = os.clock()
    local function _remotesReady()
        return typeof(_reState[_RE_BEGIN]) == "Instance"
            and typeof(_reState[_RE_COMMIT]) == "Instance"
    end
    task.spawn(function()
        for _ = 1, 60 do
            if _remotesReady() then _G.MeerkoStealSay("steal remotes ready") return end
            _re(nil, _RE_BEGIN)
            _re(nil, _RE_COMMIT)
            task.wait(0.25)
        end
    end)

    local function remoteStealAsync(pet, judge)
        if not (pet and type(pet.plot) == "string" and pet.slot ~= nil) then return false end
        if _holdBusy() then
            return false
        end
        if not _stealBegin() then return false end
        _stealHoldStart = tick()
        _stealHoldActive = true
        showStealBar(pet.name, 0)
        task.spawn(function()
            local hold = tonumber(_G.MeerkoStealHoldDuration) or STEAL_HOLD_DURATION
            while true do
                local el = tick() - _stealHoldStart
                if el >= hold then break end
                setStealBarPct(el / hold)
                RunService.Heartbeat:Wait()
            end
            setStealBarPct(1)
            _stealCommit(pet.plot, pet.slot)
            _verifyFire(pet, "remote", judge)
            _stealHoldActive = false
            task.wait(0.2)
            hideStealBar()
        end)
        task.delay(STEAL_HOLD_DURATION + 0.6, hideStealBar)
        return true
    end

    local function executeStealAsync(prompt, petName, restoreMax)
        if _holdBusy() then
            return false
        end
        local data = InternalStealCache[prompt]
        if not data or not data.ready then return false end
        data.ready = false
        _stealHoldStart = tick()
        _stealHoldActive = true
        pcall(function() prompt.MaxActivationDistance = math.huge end)
        showStealBar(petName, 0)
        task.spawn(function()
            for _, fn in ipairs(data.holdCallbacks) do task.spawn(fn) end
            local hold = tonumber(_G.MeerkoStealHoldDuration) or STEAL_HOLD_DURATION
            pcall(function()
                local hd = prompt.HoldDuration
                if type(hd) == "number" and hd > 0 then
                    hold = math.max(hold, hd + 0.05)
                end
            end)
            while true do
                local el = tick() - _stealHoldStart
                if el >= hold then break end
                setStealBarPct(el / hold)
                RunService.Heartbeat:Wait()
            end
            setStealBarPct(1)
            if prompt and prompt.Parent then
                for _, fn in ipairs(data.triggerCallbacks) do task.spawn(fn) end
            end
            for _, fn in ipairs(data.holdEndCallbacks) do task.spawn(fn) end
            _stealHoldActive = false
            if restoreMax ~= nil then
                pcall(function()
                    if prompt and prompt.Parent then prompt.MaxActivationDistance = restoreMax end
                end)
            end
            task.wait(0.05)
            data.ready = true
            task.wait(0.2)
            hideStealBar()
        end)
        task.delay(STEAL_HOLD_DURATION + 0.6, hideStealBar)
        return true
    end

    local function timeUntilCanSteal()
        if LP:GetAttribute("Stealing") or LP:GetAttribute("IsTrading")
            or LP:GetAttribute("IsDuelSelecting") or LP:GetAttribute("Web") then
            return -1
        end
        local ragdoll = LP:GetAttribute("RagdollEndTime")
        if ragdoll then
            local r = ragdoll - workspace:GetServerTimeNow()
            if r > 0 then return r end
        end
        return 0
    end

    local stealOn = (_G.MeerkoStealMode ~= nil)
    local _emptyScans = 0
    local function _fireSteal(pet)
        if not pet then return false end
        if _holdBusy() then _G.MeerkoStealSay("hold already running") return false end
        local _fhrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        local _fd = (_fhrp and pet.position) and (pet.position - _fhrp.Position).Magnitude or nil
        local _judge = (_fd ~= nil) and (_fd <= _prox() + 2) or false
        local _cd = _holdDur() + (tonumber(_G.MeerkoVerifyDelay) or 0.5) + 0.15
        _G.MeerkoStealSay("gates ok -> firing on " .. tostring(pet.name))
        if _G.MeerkoRemoteStealOn ~= false then
            if remoteStealAsync(pet, _judge) then
                _G.MeerkoLastFire = os.clock()
                _cooldownUntil = tick() + _cd
                _G.MeerkoStealSay("FIRE remote -> " .. tostring(pet.name))
                return true
            end
            _G.MeerkoStealSay("remote not ready -> prompt path")
        end
        local prompt = findStealPrompt(pet)
        if not prompt or not prompt.Parent then
            _G.MeerkoStealSay("no prompt at " .. tostring(pet.plot) .. "/" .. tostring(pet.slot))
            return false
        end
        local oldMax
        pcall(function() oldMax = prompt.MaxActivationDistance end)
        pcall(function() prompt.MaxActivationDistance = math.huge end)
        buildStealCallbacks(prompt)
        if InternalStealCache[prompt] then
            if executeStealAsync(prompt, pet.name, oldMax) then
                _G.MeerkoLastFire = os.clock()
                _cooldownUntil = tick() + _cd
                _verifyFire(pet, "prompt", _judge)
                _G.MeerkoStealSay("FIRE prompt-callback -> " .. tostring(pet.name))
                return true
            end
            _G.MeerkoStealSay("prompt-callback not ready")
            if oldMax ~= nil then pcall(function() prompt.MaxActivationDistance = oldMax end) end
            return false
        elseif fireproximityprompt then
            pcall(function() prompt.MaxActivationDistance = math.huge end)
            showStealBar(pet.name, 1)
            pcall(function() fireproximityprompt(prompt) end)
            _G.MeerkoLastFire = os.clock()
            _cooldownUntil = tick() + (tonumber(_G.MeerkoVerifyDelay) or 0.5) + 0.5
            _verifyFire(pet, "prompt", _judge)
            _G.MeerkoStealSay("FIRE proximityprompt -> " .. tostring(pet.name))
            task.delay(0.4, hideStealBar)
            pcall(function() if oldMax ~= nil then prompt.MaxActivationDistance = oldMax end end)
            return true
        end
        _G.MeerkoStealSay("no steal method available")
        return false
    end
    _G.MeerkoFireSteal = _fireSteal
    local function _stealTick()
        _G.MeerkoTickN = (_G.MeerkoTickN or 0) + 1
        stealOn = (_G.MeerkoStealMode ~= nil)
        if not stealOn then _G.MeerkoStealSay("steal mode OFF") return end
        local now = os.clock()
        local _lockUid = _G.MeerkoStealTargetUID
        local _lockChanged = (type(_lockUid) == "string" and _lockUid ~= "" and _lockUid ~= _lastPickUid)
        local _needPick = (not _stealTarget) or _lockChanged or (now - _lastTargetPick) >= (tonumber(_G.MeerkoRepickGap) or 0.35)
        if _armedPet then
            local _lp = _armLivePos(_armedPet)
            if _lp then
                _armedPet.position = _lp
                _armLostSince = 0
            elseif _armLostSince == 0 then
                _armLostSince = now
            elseif now - _armLostSince > (tonumber(_G.MeerkoArmLostGrace) or 1.5) then
                _armedPet, _armLostSince = nil, 0
            end
            if _armedPet and (now - _armCheckAt) >= (tonumber(_G.MeerkoArmCheckGap) or 0.5) then
                _armCheckAt = now
                local okL, listed = pcall(_petListed, _armedPet.plot, _armedPet.slot)
                if okL and not listed then
                    _G.MeerkoStealSay("armed pet gone -> repicking")
                    _armedPet, _armLostSince = nil, 0
                end
            end
            if _armedPet then
                _stealTarget = _armedPet
                if type(_armedPet.name) == "string" then _currentTargetName = _armedPet.name end
                _needPick = false
            end
        end
        local _scanGap = (_emptyScans >= 3) and (tonumber(_G.MeerkoStealIdleGap) or 0.3) or 0.01
        if not LP:GetAttribute("Stealing") and _needPick and (now - _autoLastScan) >= _scanGap then
            _autoLastScan = now
            _lastTargetPick = now
            local char = LP.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local pets = _scanCached(now, 0.05)
                local ok = pets ~= nil
                if ok and pets and #pets > 0 then _emptyScans = 0 else _emptyScans = _emptyScans + 1 end
                if ok and pets and #pets > 0 then
                    local best
                    if type(_lockUid) == "string" and _lockUid ~= "" then
                        for _, p in ipairs(pets) do
                            if not p.conveyor and _petUid(p) == _lockUid then best = p break end
                        end
                    end
                    if not best and _G.MeerkoStealMode == "nearest" then
                        local myPos = hrp.Position
                        local bestD = math.huge
                        for _, p in ipairs(pets) do
                            if not p.conveyor and p.position then
                                local d = (p.position - myPos).Magnitude
                                if d < bestD then bestD = d; best = p end
                            end
                        end
                    elseif not best then
                        for _, p in ipairs(pets) do if not p.conveyor then best = p; break end end
                    end
                    best = best or pets[1]
                    if best then
                        _stealTarget = best
                        _stealArmedAt = now
                        _lastPickUid = _lockUid
                        if type(best.name) == "string" and best.name ~= "" then
                            _currentTargetName = best.name
                        end
                    end
                end
            end
        end
        if _G.MeerkoStealInRangeFirst ~= false
            and not (_armedPet and _G.MeerkoTPTargetWins ~= false)
            and not (type(_lockUid) == "string" and _lockUid ~= "") then
            local _c2 = LP.Character
            local _h2 = _c2 and _c2:FindFirstChild("HumanoidRootPart")
            if _h2 then
                local _cur = _stealTarget
                local _curD = (_cur and _cur.position) and (_cur.position - _h2.Position).Magnitude or math.huge
                if _curD > _prox() and (now - _inRangeLast) >= (tonumber(_G.MeerkoInRangeGap) or 0.25) then
                    _inRangeLast = now
                    local _pets2 = _scanCached(now, 0.15)
                    local _ok2 = _pets2 ~= nil
                    if _ok2 and type(_pets2) == "table" then
                        local _near, _nd = nil, math.huge
                        local _mp = _h2.Position
                        for _, p in ipairs(_pets2) do
                            if not p.conveyor and p.position then
                                local d = (p.position - _mp).Magnitude
                                if d < _nd then _nd, _near = d, p end
                            end
                        end
                        if _near and _nd <= _prox() then
                            _stealTarget = _near
                            _armedPet, _armLostSince = nil, 0
                            _lastTargetPick = now
                            if type(_near.name) == "string" then _currentTargetName = _near.name end
                            _G.MeerkoStealSay(string.format("switch to in-range %s d=%.0f", tostring(_near.name), _nd))
                        end
                    end
                end
            end
        end
        local pet = _stealTarget
        if not pet then _G.MeerkoStealSay("no target") return end

        if now - _stealLastScan < 0.033 then _G.MeerkoThrN = (_G.MeerkoThrN or 0) + 1 return end
        _stealLastScan = now
        local t = timeUntilCanSteal()
        if t == -1 then
            if LP:GetAttribute("Stealing") then _stealTarget = nil; _armedPet, _armLostSince = nil, 0 end
            _G.MeerkoStealSay("busy: stealing/trading/web")
            return
        end
        if t > 0 and t > _holdDur() then _G.MeerkoStealSay(string.format("cooldown %.1fs", t)) return end
        local char = LP.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then _G.MeerkoStealSay("no character") return end

        if pet.position then
            local toPet = pet.position - hrp.Position
            local dist = toPet.Magnitude
            _G.MeerkoStealTgt = string.format("%s [%s/%s] d=%.0f", tostring(pet.name), tostring(pet.plot), tostring(pet.slot), dist)
            local hold = tonumber(_G.MeerkoStealHoldDuration) or STEAL_HOLD_DURATION

            local lead = tonumber(_G.MeerkoStealLead) or 0.27

            local closing = dist > 0.001 and (hrp.AssemblyLinearVelocity:Dot(toPet) / dist) or 0

            local _nearBase = false
            do
                local _bi = getClosestBaseIdx(pet.position)
                local _b = _bi and BASES_LOW[_bi]
                if _b then
                    local _bx, _bz = hrp.Position.X - _b.X, hrp.Position.Z - _b.Z
                    if math.sqrt(_bx * _bx + _bz * _bz) <= (tonumber(_G.MeerkoCloseBaseRange) or 100) then
                        _nearBase = true
                    end
                end
            end

            if _nearBase then
                if dist > (tonumber(_G.MeerkoNearBaseStealStart) or 55) then _G.MeerkoStealSay(string.format("nearbase far d=%.0f", dist)) return end
            elseif closing > (tonumber(_G.MeerkoFastApproach) or 150) then

                if dist > (tonumber(_G.MeerkoStealLeadMax) or 223) then _G.MeerkoStealSay(string.format("lead far d=%.0f", dist)) return end
                if (dist / closing) > hold * lead then _G.MeerkoStealSay(string.format("lead wait d=%.0f c=%.0f", dist, closing)) return end
            elseif closing > 5 then

                if dist > (tonumber(_G.MeerkoCloseProximity) or 24) then _G.MeerkoStealSay(string.format("moving far d=%.0f c=%.0f", dist, closing)) return end
            else
                
                if dist > _prox() then _G.MeerkoStealSay(string.format("far d=%.0f", dist)) return end
            end
        end
        _fireSteal(pet)
    end
    RunService.Heartbeat:Connect(function()
        local _ok, _err = pcall(_stealTick)
        if not _ok then _G.MeerkoStealSay("ERROR " .. tostring(_err)) end
    end)

    task.spawn(function()
        while true do
            task.wait(tonumber(_G.MeerkoWatchdogTick) or 0.2)
            if _G.MeerkoStealMode ~= nil and _G.MeerkoStealWatchdog ~= false
                and not LP:GetAttribute("Stealing")
                and not _holdBusy()
                and (os.clock() - (_G.MeerkoLastFire or 0)) > (tonumber(_G.MeerkoWatchdogGap) or 1.5) then
                local c = LP.Character
                local h = c and c:FindFirstChild("HumanoidRootPart")
                if h then
                    local pets = _scanCached(os.clock(), 0.15)
                    local ok = pets ~= nil
                    if ok and type(pets) == "table" then
                        local near, nd = nil, math.huge
                        local mp = h.Position
                        for _, p in ipairs(pets) do
                            if not p.conveyor and p.position then
                                local d = (p.position - mp).Magnitude
                                if d < nd then nd, near = d, p end
                            end
                        end
                        if near and nd <= _prox() then
                            _G.MeerkoStealSay(string.format("WATCHDOG in range %s d=%.0f", tostring(near.name), nd))
                            pcall(_fireSteal, near)
                        end
                    end
                end
            end
        end
    end)

    do
        local function applyUnwalkAlways(char)
            if not char then return end
            local hum = char:FindFirstChildOfClass("Humanoid")
            local animator = hum and hum:FindFirstChildOfClass("Animator")
            local animate = char:FindFirstChild("Animate")
            if animate then animate.Disabled = true end
            if animator then
                local ok, tracks = pcall(function() return animator:GetPlayingAnimationTracks() end)
                if ok and tracks then for _, t in ipairs(tracks) do pcall(function() t:Stop(0) end) end end
            end
        end
        local function hook(char)
            task.spawn(function()
                char:WaitForChild("Humanoid", 10); task.wait(0.05)
                for i = 1, 8 do
                    if LP.Character ~= char then break end
                    applyUnwalkAlways(char); task.wait(0.25)
                end
            end)
        end
        if LP.Character then hook(LP.Character) end
        LP.CharacterAdded:Connect(hook)
        local _unwalkLast = 0
        RunService.Heartbeat:Connect(function()
            local now = os.clock()
            if now - _unwalkLast < 1.5 then return end
            _unwalkLast = now
            if LP.Character then applyUnwalkAlways(LP.Character) end
        end)
    end

    local HS = game:GetService("HttpService")
    local UIS = game:GetService("UserInputService")
    local CFG_FILE = "SideTP.json"

    local function loadCfgTable()
        local t = {}
        if readfile then
            pcall(function()
                local raw = readfile(CFG_FILE)
                if type(raw) == "string" and #raw > 0 then
                    local ok, d = pcall(HS.JSONDecode, HS, raw)
                    if ok and type(d) == "table" then t = d end
                end
            end)
        end
        return t
    end

    local function saveTpSettings()
        if not writefile then return end
        local t = loadCfgTable()
        t.tpVelocity = tonumber(_G.TPVelocity) or 400
        t.climbSpeed = tonumber(_G.MeerkoClimb) or 160
        t.goSpeed = tonumber(_G.MeerkoGoSpeed) or 200
        t.cframeSpeed = tonumber(_G.MeerkoCFrameSpeed) or 450
        t.walkSpeed = tonumber(_G.MeerkoWalkSpeed) or 27
        t.landingDelay = tonumber(_G.LandingDelay) or 0.35
        t.closeSpeed = tonumber(_G.MeerkoCloseSpeed) or 80
        t.tpSafeMode = _G.MeerkoTPSafeMode ~= false
        t.tpSafeSpeed = tonumber(_G.MeerkoTPSafeSpeed) or 300
        t.tpSafeVerticalSpeed = tonumber(_G.MeerkoTPSafeVerticalSpeed) or 110
        t.tpRetryCount = tonumber(_G.MeerkoTPRetryCount) or 2
        t.autoTp = _G.MeerkoAutoTP ~= false
        t.autoKickOnSteal = _G.MeerkoAutoKickOnSteal == true
        t.kickToPS = _G.MeerkoKickToPS == true
        t.psLink = tostring(_G.MeerkoPrivateServerLink or "")
        t.priAlert = _G.MeerkoPriAlert == true
        t.alertSound = tostring(_G.MeerkoAlertSound or "111786441593851")
        t.alertMinGen = tonumber(_G.MeerkoAlertMinGen) or 80e6
        t.walkSpeedOn = _G.MeerkoWalkSpeedOn ~= false
        t.xray = _G.MeerkoXray ~= false
        t.invisAuto = _G.MeerkoInvisAuto == true
        t.invisDepth = tonumber(_G.MeerkoInvisDepth) or 4.2
        t.invisAngle = tonumber(_G.MeerkoInvisAngle) or 180
        t.autoSteal = stealOn
        t.stealMode = _G.MeerkoStealMode
        t.priorityList = _G.SHARED_PRIORITY_ITEMS
        t.panelX = tonumber(_G._stp_panelX)
        t.panelY = tonumber(_G._stp_panelY)
        t.panelPos = _G._stp_pos
        
        if type(_G.MeerkoCloneKeyName)  == "string" then t.cloneKey  = _G.MeerkoCloneKeyName  else t.cloneKey  = nil end
        if type(_G.MeerkoKickKeyName)   == "string" then t.kickKey   = _G.MeerkoKickKeyName   else t.kickKey   = nil end
        if type(_G.MeerkoStopTPKeyName) == "string" then t.stopTpKey = _G.MeerkoStopTPKeyName else t.stopTpKey = nil end
        if type(_G.MeerkoNearestKey)    == "string" then t.nearestKey= _G.MeerkoNearestKey    else t.nearestKey= nil end
        if type(_G.MeerkoDropKeyName)   == "string" then t.dropKey   = _G.MeerkoDropKeyName   else t.dropKey   = nil end
        if type(_G.MeerkoResetKeyName)  == "string" then t.resetKey  = _G.MeerkoResetKeyName  else t.resetKey  = nil end
        t.antiFlash = _G.MeerkoAntiFlash ~= false
        t.faceAway = _G.MeerkoFaceAway == true
        t.faceAwayNearest = _G.MeerkoFaceAwayNearest == true
        t.faceAwayDelay = tonumber(_G.MeerkoFaceAwayDelay) or 2
        t.antiBee   = _G.MeerkoAntiBee ~= false
        t.infJump   = _G.MeerkoInfJump ~= false
        t.antiDie   = _G.AntiDieDisabled ~= true
        t.carpetSpeedValue = tonumber(_G.MeerkoCarpetSpeedValue) or 140
        t.autoBuy = _G.MeerkoAutoBuy == true
        t.autoBuyRange = tonumber(_G.MeerkoAutoBuyRange) or 17
        t.autoBuyHover = tonumber(_G.MeerkoAutoBuyHover) or 9
        t.exX = tonumber(_G._meerko_exX); t.exY = tonumber(_G._meerko_exY)
        t.fX  = tonumber(_G._meerko_fX);  t.fY  = tonumber(_G._meerko_fY)
        t.kX  = tonumber(_G._meerko_kX);  t.kY  = tonumber(_G._meerko_kY)
        pcall(function() writefile(CFG_FILE, HS:JSONEncode(t)) end)
    end
    _G.MeerkoSaveSettings = saveTpSettings  

    if _G.TPVelocity == nil then _G.TPVelocity = 400 end
    if _G.MeerkoClimb == nil then _G.MeerkoClimb = 160 end
    if _G.MeerkoGoSpeed == nil then _G.MeerkoGoSpeed = 200 end
    if _G.MeerkoCFrameSpeed == nil then _G.MeerkoCFrameSpeed = 450 end
    if _G.MeerkoWalkSpeed == nil then _G.MeerkoWalkSpeed = 27 end
    if _G.LandingDelay == nil then _G.LandingDelay = 0.35 end
    if _G.MeerkoCloseSpeed == nil then _G.MeerkoCloseSpeed = 80 end
    if _G.MeerkoInvisDepth == nil then _G.MeerkoInvisDepth = 4.2 end
    if _G.MeerkoInvisAngle == nil then _G.MeerkoInvisAngle = 180 end

    local TS = game:GetService("TweenService")
    local EASE = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local function tween(o, props) TS:Create(o, EASE, props):Play() end

    local guiParent = (gethui and gethui()) or game:GetService("CoreGui") or PG
    for _, par in ipairs({ guiParent, PG }) do
        pcall(function()
            local old = par:FindFirstChild("uiMainLayer")
            if old then old:Destroy() end
        end)
    end

    local sg = mk("ScreenGui", nil, {
        Name = "uiMainLayer", ResetOnSpawn = false, IgnoreGuiInset = true,
        DisplayOrder = 999999, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    pcall(function() sg.Parent = guiParent end)
    if not sg.Parent then sg.Parent = PG end

    sg.Enabled = false

    UIS.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.RightControl then
            sg.Enabled = not sg.Enabled
        end
    end)

    do
        local hdr = corner(mk("Frame", sg, {
            Name = "Bar", AnchorPoint = Vector2.new(0.5, 0),
            Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(340, 26),
            BackgroundColor3 = UIC.bg, BorderSizePixel = 0, ZIndex = 50,
        }), 8)
        mk("UIGradient", hdr, { Rotation = 90, Color = ColorSequence.new(UIC.card, UIC.bg) })
        local hrim = mk("UIStroke", hdr, { Thickness = 1, Transparency = 0.15 })
        mk("UIGradient", hrim, { Rotation = 90, Color = ColorSequence.new(UIC.acc, UIC.line) })

        local function seg(x, w, txt, col, font)
            return mk("TextLabel", hdr, {
                Size = UDim2.fromOffset(w, 26), Position = UDim2.fromOffset(x, 0),
                BackgroundTransparency = 1, Text = txt, Font = font, TextSize = 11,
                TextColor3 = col, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 51,
            })
        end
        local function div(x)
            mk("Frame", hdr, {
                Size = UDim2.fromOffset(1, 12), Position = UDim2.fromOffset(x, 7),
                BackgroundColor3 = UIC.line, BorderSizePixel = 0, ZIndex = 51,
            })
        end
        seg(16, 96, "MEERKO TP", UIC.acc, UIFB)
        div(120)
        local fpsLbl = seg(132, 84, "FPS: --", UIC.txt, UIF)
        div(224)
        local pingLbl = seg(236, 88, "PING: --", UIC.txt, UIF)

        local frames, since, pingItem = 0, 0, nil
        RunService.RenderStepped:Connect(function(dt)
            frames, since = frames + 1, since + dt
            if since < 0.5 then return end
            fpsLbl.Text = "FPS: " .. math.floor(frames / since + 0.5)
            frames, since = 0, 0
            if not pingItem then
                pcall(function()
                    pingItem = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]
                end)
            end
            local ok, v = pcall(function() return pingItem:GetValue() end)
            pingLbl.Text = "PING: " .. ((ok and math.floor(v + 0.5)) or "--") .. " ms"
        end)
    end

    local W, H, RAIL, PAD = 460, 320, 130, 16

    local root = mk("Frame", sg, {
        Name = "Root", Active = true, BackgroundTransparency = 1,
        Size = UDim2.fromOffset(W, H),
        Position = UDim2.fromOffset(tonumber(_G._stp_panelX) or 40, tonumber(_G._stp_panelY) or 160),
    })

    local shadow = mk("Frame", root, {
        Size = UDim2.new(1, 12, 1, 12), Position = UDim2.fromOffset(-6, -6),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0), BackgroundTransparency = 0.75,
        ZIndex = -1, BorderSizePixel = 0,
    })
    corner(shadow, 16)

    local card = corner(mk("Frame", root, {
        BackgroundColor3 = UIC.bg, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 1,
    }), 16)
    mk("UIGradient", card, {
        Rotation = 135,
        Color = ColorSequence.new({ColorSequenceKeypoint.new(0, UIC.bg2), ColorSequenceKeypoint.new(1, UIC.bg)}),
    })
    local rim = mk("UIStroke", card, { Thickness = 1.5, Transparency = 0.25, Color = UIC.acc })
    mk("UIGradient", rim, {
        Rotation = 135,
        Color = ColorSequence.new({ColorSequenceKeypoint.new(0, UIC.acc), ColorSequenceKeypoint.new(1, UIC.acc2)}),
    })

    local rail = mk("Frame", card, {
        Size = UDim2.new(0, RAIL, 1, 0), BackgroundTransparency = 1, ZIndex = 2,
    })
    mk("TextLabel", rail, {
        Size = UDim2.new(1, -PAD * 2, 0, 18), Position = UDim2.fromOffset(PAD, 20),
        BackgroundTransparency = 1, Text = "MEERKO", Font = UIFB, TextSize = 14,
        TextColor3 = UIC.txt, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2,
    })
    mk("TextLabel", rail, {
        Size = UDim2.new(1, -PAD * 2, 0, 12), Position = UDim2.fromOffset(PAD, 40),
        BackgroundTransparency = 1, Text = "TELEPORT", Font = UIF, TextSize = 9,
        TextColor3 = UIC.acc, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2,
    })
    mk("Frame", rail, {
        Position = UDim2.fromOffset(PAD, 58), Size = UDim2.new(1, -PAD * 2, 0, 2),
        BackgroundColor3 = UIC.line, BorderSizePixel = 0,
    })

    local body = mk("Frame", card, {
        Position = UDim2.fromOffset(RAIL, 0), Size = UDim2.new(1, -RAIL, 1, 0),
        BackgroundTransparency = 1, ZIndex = 2,
    })

    local pages, tabs = {}, {}
    local tabOpenHook = {}
    local function selectTab(name)
        local _h = tabOpenHook[name]
        if _h then tabOpenHook[name] = nil; pcall(_h) end
        for n, p in pairs(pages) do p.Visible = (n == name) end
        for n, t in pairs(tabs) do
            local on = (n == name)
            tween(t.bg, { BackgroundTransparency = on and 0 or 1 })
            tween(t.lbl, { TextColor3 = on and UIC.txt or UIC.dim })
            tween(t.btn, { BackgroundTransparency = on and 0.2 or 0.5 })
        end
    end

    local function tab(name, order)
        local b = corner(mk("TextButton", rail, {
            Size = UDim2.new(1, -PAD * 2, 0, 32), Position = UDim2.fromOffset(PAD, 72 + (order - 1) * 38),
            BackgroundColor3 = UIC.card, BackgroundTransparency = 0.5, Text = "",
            AutoButtonColor = false, Active = true, ZIndex = 2,
        }), 8)
        local bg = mk("Frame", b, {
            Size = UDim2.fromScale(1, 1), BackgroundColor3 = UIC.acc,
            BackgroundTransparency = 1, BorderSizePixel = 0,
        })
        corner(bg, 8)
        local lbl = mk("TextLabel", b, {
            Size = UDim2.new(1, 0, 1, 0), Position = UDim2.fromOffset(0, 0),
            BackgroundTransparency = 1, Text = name, Font = UIFB, TextSize = 11,
            TextColor3 = UIC.dim, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3,
        })
        mk("UIPadding", lbl, { PaddingLeft = UDim.new(0, 12) })
        local page = mk("ScrollingFrame", body, {
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
            Visible = false, ScrollBarThickness = 0, ScrollBarImageColor3 = UIC.line,
            CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 2,
        })
        mk("UIPadding", page, {
            PaddingLeft = UDim.new(0, PAD), PaddingRight = UDim.new(0, PAD + 4),
            PaddingTop = UDim.new(0, PAD + 4), PaddingBottom = UDim.new(0, PAD),
        })
        mk("UIListLayout", page, { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
        tabs[name], pages[name] = { btn = b, bg = bg, lbl = lbl }, page
        b.MouseButton1Click:Connect(function() selectTab(name) end)
        b.MouseEnter:Connect(function()
            if not pages[name].Visible then
                tween(b, { BackgroundTransparency = 0.3 })
            end
        end)
        b.MouseLeave:Connect(function()
            if not pages[name].Visible then
                tween(b, { BackgroundTransparency = 0.5 })
            end
        end)
        return page
    end

    local function label(parent, txt, first)
        local l = mk("TextLabel", parent, {
            Size = UDim2.new(1, 0, 0, first and 14 or 26), BackgroundTransparency = 1,
            Text = string.upper(txt), Font = UIFB, TextSize = 10, TextColor3 = UIC.dim,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Bottom, ZIndex = 2,
        })
        return l
    end

    local function shell(parent, h)
        local card = corner(mk("Frame", parent, {
            Size = UDim2.new(1, 0, 0, h), BackgroundColor3 = UIC.card,
            BorderSizePixel = 0, Active = true, ZIndex = 2,
        }), 10)
        local bg = mk("Frame", card, {
            Size = UDim2.fromScale(1, 1), BackgroundColor3 = UIC.acc,
            BackgroundTransparency = 1, BorderSizePixel = 0,
        })
        corner(bg, 10)
        return card
    end

    local function action(parent, txt, fn)
        local card2 = shell(parent, 36)
        local b = mk("TextButton", card2, {
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = txt,
            Font = UIFB, TextSize = 12, TextColor3 = UIC.txt,
            Active = true, AutoButtonColor = false, ZIndex = 3,
        })
        b.MouseEnter:Connect(function() 
            tween(card2:FindFirstChildOfClass("Frame"), { BackgroundTransparency = 0.3 })
        end)
        b.MouseLeave:Connect(function() 
            tween(card2:FindFirstChildOfClass("Frame"), { BackgroundTransparency = 1 })
        end)
        b.MouseButton1Click:Connect(fn)
    end

    local function toggle(parent, txt, get, fn)
        local card2 = shell(parent, 36)
        local hit = mk("TextButton", card2, {
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "",
            Active = true, AutoButtonColor = false, ZIndex = 4,
        })
        mk("TextLabel", card2, {
            Size = UDim2.new(1, -70, 1, 0), Position = UDim2.fromOffset(14, 0),
            BackgroundTransparency = 1, Text = txt, Font = UIFB, TextSize = 12,
            TextColor3 = UIC.txt, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3,
        })
        local pill = corner(mk("Frame", card2, {
            Size = UDim2.fromOffset(40, 20), Position = UDim2.new(1, -52, 0.5, -10),
            BackgroundColor3 = UIC.track, BorderSizePixel = 0, ZIndex = 3,
        }), 10)
        local knob = corner(mk("Frame", pill, {
            Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(2, 2),
            BackgroundColor3 = UIC.dim, BorderSizePixel = 0, ZIndex = 4,
        }), 8)
        local function paint(instant)
            local v = get()
            local pc = v and UIC.acc or UIC.track
            local kc = v and UIC.txt or UIC.dim
            local kp = UDim2.fromOffset(v and 22 or 2, 2)
            if instant then
                pill.BackgroundColor3, knob.BackgroundColor3, knob.Position = pc, kc, kp
            else
                tween(pill, { BackgroundColor3 = pc })
                tween(knob, { BackgroundColor3 = kc, Position = kp })
            end
        end
        hit.MouseButton1Click:Connect(function() fn(); paint() end)
        paint(true)
        return paint
    end

    local function input(parent, txt, hint, get, set)
        local card2 = shell(parent, 52)
        mk("TextLabel", card2, {
            Size = UDim2.new(1, -24, 0, 12), Position = UDim2.fromOffset(14, 8),
            BackgroundTransparency = 1, Text = txt, Font = UIF, TextSize = 11,
            TextColor3 = UIC.dim, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3,
        })
        local box = mk("TextBox", card2, {
            Size = UDim2.new(1, -24, 0, 20), Position = UDim2.fromOffset(14, 24),
            BackgroundTransparency = 1, Font = UIFB, TextSize = 12,
            TextColor3 = UIC.txt, TextXAlignment = Enum.TextXAlignment.Left,
            PlaceholderText = hint, PlaceholderColor3 = UIC.line,
            ClearTextOnFocus = false, Text = tostring(get() or ""),
            TextTruncate = Enum.TextTruncate.AtEnd, Active = true, ZIndex = 4,
        })
        box.FocusLost:Connect(function() set(box.Text) end)
        return box
    end

    local function slider(parent, txt, min, max, get, set, step)
        step = step or 1
        local card2 = shell(parent, 50)
        mk("TextLabel", card2, {
            Size = UDim2.new(1, -76, 0, 14), Position = UDim2.fromOffset(14, 8),
            BackgroundTransparency = 1, Text = txt, Font = UIF, TextSize = 11,
            TextColor3 = UIC.dim, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3,
        })
        local val = mk("TextLabel", card2, {
            Size = UDim2.fromOffset(52, 14), Position = UDim2.new(1, -64, 0, 8),
            BackgroundTransparency = 1, Font = UIFB, TextSize = 12, TextColor3 = UIC.txt,
            TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 3,
        })
        local track = corner(mk("TextButton", card2, {
            Size = UDim2.new(1, -24, 0, 6), Position = UDim2.fromOffset(14, 32),
            BackgroundColor3 = UIC.track, Text = "", AutoButtonColor = false,
            Active = true, BorderSizePixel = 0, ZIndex = 3,
        }), 3)
        local fill = corner(mk("Frame", track, {
            Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = UIC.acc,
            BorderSizePixel = 0, ZIndex = 4,
        }), 3)
        local knob = corner(mk("Frame", track, {
            Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0, 0, 0.5, 0), BackgroundColor3 = UIC.txt,
            BorderSizePixel = 0, ZIndex = 5,
        }), 7)

        local function refresh()
            local v = math.clamp(tonumber(get()) or min, min, max)
            local rel = (v - min) / math.max(max - min, 1e-6)
            fill.Size = UDim2.new(rel, 0, 1, 0)
            knob.Position = UDim2.new(rel, 0, 0.5, 0)
            val.Text = step < 1 and string.format("%.2f", v) or tostring(math.floor(v + 0.5))
        end
        local function applyAt(x)
            local rel = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
            set(math.clamp(math.floor((min + (max - min) * rel) / step + 0.5) * step, min, max))
            refresh()
        end

        local sliding = false
        track.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1
                or i.UserInputType == Enum.UserInputType.Touch then
                sliding = true; tween(knob, { Size = UDim2.fromOffset(14, 14) }); applyAt(i.Position.X)
            end
        end)
        UIS.InputChanged:Connect(function(i)
            if sliding and (i.UserInputType == Enum.UserInputType.MouseMovement
                or i.UserInputType == Enum.UserInputType.Touch) then applyAt(i.Position.X) end
        end)
        UIS.InputEnded:Connect(function(i)
            if sliding and (i.UserInputType == Enum.UserInputType.MouseButton1
                or i.UserInputType == Enum.UserInputType.Touch) then
                sliding = false; tween(knob, { Size = UDim2.fromOffset(10, 10) }); saveTpSettings()
            end
        end)
        refresh()
    end

    do
        local dragging, dragStart, startPos, dragInput
        card.Active = true
        rail.Active, body.Active = true, true

        local function begin(i)
            if i.UserInputType ~= Enum.UserInputType.MouseButton1
                and i.UserInputType ~= Enum.UserInputType.Touch then return end
            dragging, dragStart, startPos = true, i.Position, root.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End and dragging then
                    dragging = false
                    _G._stp_panelX = root.Position.X.Offset
                    _G._stp_panelY = root.Position.Y.Offset
                    saveTpSettings()
                end
            end)
        end
        local function track(i)
            if i.UserInputType == Enum.UserInputType.MouseMovement
                or i.UserInputType == Enum.UserInputType.Touch then dragInput = i end
        end
        for _, o in ipairs({ card, rail, body }) do
            o.InputBegan:Connect(begin)
            o.InputChanged:Connect(track)
        end
        UIS.InputChanged:Connect(function(i)
            if not dragging or i ~= dragInput then return end
            local d = i.Position - dragStart
            root.Position = UDim2.fromOffset(startPos.X.Offset + d.X, startPos.Y.Offset + d.Y)
        end)
    end

    local home = tab("Home", 1)
    local tune = tab("Tuning", 2)

    label(home, "actions", true)
    action(home, "MANUAL TP", function()
        task.spawn(function()
            if diag() == 0 then return end
            if _G.MeerkoStartSideTP then pcall(_G.MeerkoStartSideTP)
            else pcall(doVelocityTP, true) end
        end)
    end)

    label(home, "general")
    _G.MeerkoRepaintAutoTP = toggle(home, "AUTO TP",
        function() return _G.MeerkoAutoTP ~= false end,
        function() _G.MeerkoAutoTP = not (_G.MeerkoAutoTP ~= false); saveTpSettings() end)

    label(tune, "movement", true)
    _G.MeerkoRepaintTPSafe = toggle(tune, "TP SAFE MODE",
        function() return _G.MeerkoTPSafeMode ~= false end,
        function() _G.MeerkoTPSafeMode = not (_G.MeerkoTPSafeMode ~= false); saveTpSettings() end)
    for _, s in ipairs({
        { "TP Velocity",          200,  750, "TPVelocity",        5    },
        { "Rise Speed",           100,  250, "MeerkoClimb",       5    },
        { "Go To Brainrot Speed",  80,  600, "MeerkoGoSpeed",     5    },
        { "Walk Speed",            16,   29, "MeerkoWalkSpeed",   1    },
        { "Landing Delay",       0.05, 0.75, "LandingDelay",      0.05 },
        { "100 Studs Base Speed",  20,  400, "MeerkoCloseSpeed",  5    },
    }) do
        slider(tune, s[1], s[2], s[3],
            function() return _G[s[4]] end, function(v) _G[s[4]] = v end, s[5])
    end

    local pri = tab("Priority", 3)
    local refreshPri

    label(pri, "add animal", true)
    do
        local card2 = shell(pri, 36)
        stroke(card2)
        local box = mk("TextBox", card2, {
            Size = UDim2.new(1, -74, 0, 24), Position = UDim2.fromOffset(10, 6),
            BackgroundColor3 = UIC.track, BorderSizePixel = 0,
            Font = UIF, TextSize = 12, TextColor3 = UIC.txt,
            TextXAlignment = Enum.TextXAlignment.Left,
            PlaceholderText = "type a name, then Enter", PlaceholderColor3 = UIC.dim,
            ClearTextOnFocus = false, Text = "", Active = true, ZIndex = 4,
        })
        corner(box, 6)
        mk("UIPadding", box, { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) })
        local addBtn = corner(mk("TextButton", card2, {
            Size = UDim2.fromOffset(52, 24), Position = UDim2.new(1, -60, 0, 6),
            BackgroundColor3 = UIC.acc, Text = "ADD", Font = UIFB, TextSize = 11,
            TextColor3 = UIC.bg, AutoButtonColor = false, Active = true, ZIndex = 4,
        }), 6)
        local function doAdd()
            local name = (box.Text or ""):match("^%s*(.-)%s*$")
            if name and name ~= "" then
                table.insert(_G.SHARED_PRIORITY_ITEMS, name)
                _G.MeerkoPriVersion = (_G.MeerkoPriVersion or 0) + 1
                pcall(saveTpSettings)
                box.Text = ""
                if refreshPri then refreshPri() end
            end
        end
        addBtn.MouseButton1Click:Connect(doAdd)
        addBtn.MouseEnter:Connect(function() tween(addBtn, { BackgroundColor3 = UIC.txt }) end)
        addBtn.MouseLeave:Connect(function() tween(addBtn, { BackgroundColor3 = UIC.acc }) end)
        box.FocusLost:Connect(function(enter) if enter then doAdd() end end)
    end

    label(pri, "priority  -  top = highest")
    local rowsHost = mk("Frame", pri, {
        Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 2,
    })
    mk("UIListLayout", rowsHost, { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder })

    refreshPri = function()
        for _, c in ipairs(rowsHost:GetChildren()) do
            if c:IsA("GuiObject") then c:Destroy() end
        end
        local L = _G.SHARED_PRIORITY_ITEMS
        for i = 1, #L do
            local nm = tostring(L[i])
            local row = corner(mk("Frame", rowsHost, {
                Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = UIC.card,
                BorderSizePixel = 0, LayoutOrder = i, ZIndex = 2,
            }), 7)
            stroke(row)
            mk("TextLabel", row, {
                Size = UDim2.new(1, -104, 1, 0), Position = UDim2.fromOffset(12, 0),
                BackgroundTransparency = 1, Text = i .. ".  " .. nm,
                Font = UIF, TextSize = 12, TextColor3 = UIC.txt,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 3,
            })
            local function commit()
                _G.MeerkoPriVersion = (_G.MeerkoPriVersion or 0) + 1
                pcall(saveTpSettings)
                refreshPri()
            end
            local function mini(xoff, sym, act)
                local b = corner(mk("TextButton", row, {
                    Size = UDim2.fromOffset(26, 22), Position = UDim2.new(1, xoff, 0.5, -11),
                    BackgroundColor3 = UIC.track, Text = sym, Font = UIFB, TextSize = 12,
                    TextColor3 = UIC.txt, AutoButtonColor = false, Active = true, ZIndex = 3,
                }), 6)
                b.MouseEnter:Connect(function() tween(b, { BackgroundColor3 = UIC.line }) end)
                b.MouseLeave:Connect(function() tween(b, { BackgroundColor3 = UIC.track }) end)
                b.MouseButton1Click:Connect(act)
                return b
            end
            mini(-98, "\u{25B2}", function() if i > 1 then L[i], L[i - 1] = L[i - 1], L[i]; commit() end end)
            mini(-68, "\u{25BC}", function() if i < #L then L[i], L[i + 1] = L[i + 1], L[i]; commit() end end)
            mini(-36, "\u{2715}", function() table.remove(L, i); commit() end)
        end
    end
    tabOpenHook["Priority"] = refreshPri

    selectTab("Home")
    task.delay(1.5, diag)
end

do
    local RunService = game:GetService("RunService")
    local Lighting   = game:GetService("Lighting")
    local RS         = game:GetService("ReplicatedStorage")
    local LP         = game:GetService("Players").LocalPlayer

    local RAG_STATES = {
        [Enum.HumanoidStateType.Physics]     = true,
        [Enum.HumanoidStateType.Ragdoll]     = true,
        [Enum.HumanoidStateType.FallingDown] = true,
        [Enum.HumanoidStateType.GettingUp]   = true,
    }
    local KILL = {
        BallSocketConstraint = true, NoCollisionConstraint = true, HingeConstraint = true,
        BodyVelocity = true, BodyPosition = true, BodyGyro = true,
    }

    local conns, char, hum, hrp, anim, lastVel = {}, nil, nil, nil, nil, Vector3.zero

    local function ragdolled()
        return hum ~= nil and RAG_STATES[hum:GetState()] == true
    end

    local function cleanup()
        if not char then return end
        pcall(function()
            for _, o in ipairs(char:GetDescendants()) do
                if KILL[o.ClassName] then o:Destroy()
                elseif o:IsA("Motor6D") then o.Enabled = true
                elseif o:IsA("Attachment") and (o.Name == "A" or o.Name == "B") then o:Destroy() end
            end
        end)
        if anim then
            for _, t in pairs(anim:GetPlayingAnimationTracks()) do
                local n = t.Animation and t.Animation.Name:lower() or ""
                if n:find("rag") or n:find("fall") or n:find("hurt") or n:find("down") then t:Stop(0) end
            end
        end
    end

    local function recover()
        hum:ChangeState(Enum.HumanoidStateType.Running)
        cleanup()
        pcall(function() workspace.CurrentCamera.CameraSubject = hum end)
        pcall(function()
            require(LP:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 10)):GetControls():Enable()
        end)
    end

    local function bind(c)
        for _, v in pairs(conns) do pcall(function() v:Disconnect() end) end
        conns = {}
        char = c
        hum  = c:WaitForChild("Humanoid", 10)
        hrp  = c:WaitForChild("HumanoidRootPart", 10)
        anim = hum and hum:WaitForChild("Animator", 10)
        lastVel = Vector3.zero
        if not hum then return end

        conns[#conns + 1] = hum.StateChanged:Connect(function()
            if ragdolled() then recover() end
        end)
        conns[#conns + 1] = c.DescendantAdded:Connect(function()
            if ragdolled() then cleanup() end
        end)
        local f = 0
        conns[#conns + 1] = RunService.Heartbeat:Connect(function()
            f = f + 1
            if f < 6 then return end
            f = 0
            if not (ragdolled() and hrp) then return end
            cleanup()
            local v = hrp.AssemblyLinearVelocity
            if (v - lastVel).Magnitude > 40 and v.Magnitude > 25 then
                hrp.AssemblyLinearVelocity = v.Unit * math.min(v.Magnitude, 15)
            end
            lastVel = v
        end)
    end

    LP.CharacterAdded:Connect(function(c) pcall(bind, c) end)
    if LP.Character then pcall(bind, LP.Character) end

    local BAD = { Blue = true, DiscoEffect = true, BeeBlur = true, ColorCorrection = true }
    local function nuke(o) if o and o.Parent and BAD[o.Name] then pcall(function() o:Destroy() end) end end

    local buzz
    local function muteBuzz()
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
        muteBuzz()
        local acc = 0
        RunService.Heartbeat:Connect(function(dt)
            local cam = workspace.CurrentCamera
            if cam and math.abs(cam.FieldOfView - 20) < 0.01 then
                cam.FieldOfView = tonumber(_G.MeerkoFOV) or 70
            end
            acc = acc + dt
            if acc >= 0.5 then acc = 0; muteBuzz() end
        end)
    end)
end

;(function()
    local C = {
        bg   = Color3.fromRGB(7, 8, 10),
        bg2  = Color3.fromRGB(12, 13, 16),
        row  = Color3.fromRGB(16, 17, 20),
        rowH = Color3.fromRGB(24, 26, 29),
        line = Color3.fromRGB(38, 40, 44),
        acc  = Color3.fromRGB(45, 220, 120),
        acc2 = Color3.fromRGB(125, 255, 175),
        txt  = Color3.fromRGB(245, 247, 250),
        dim  = Color3.fromRGB(145, 148, 155),
    }
    local FB, FR = Enum.Font.GothamBold, Enum.Font.Gotham
    local TS = game:GetService("TweenService")
    local EASE = TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    local function tw(o, p) TS:Create(o, EASE, p):Play() end

    local function mk(cls, parent, props)
        local o = Instance.new(cls)
        for k, v in pairs(props or {}) do o[k] = v end
        o.Parent = parent
        return o
    end
    local function round(o, r) mk("UICorner", o, { CornerRadius = UDim.new(0, r or 8) }) return o end

    local host = (gethui and gethui()) or game:GetService("CoreGui")
        or LP:WaitForChild("PlayerGui")
    pcall(function()
        local old = host:FindFirstChild("uiListLayer")
        if old then old:Destroy() end
    end)

    local sg = mk("ScreenGui", nil, {
        Name = "uiListLayer", ResetOnSpawn = false,
        IgnoreGuiInset = true, DisplayOrder = 999998,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    pcall(function() sg.Parent = host end)
    if not sg.Parent then sg.Parent = LP:WaitForChild("PlayerGui") end

    -- Compact target panel: flat black, no outer rim or shadow.
    local root = mk("Frame", sg, {
        Name = "Root", Active = true, BackgroundColor3 = C.bg, BorderSizePixel = 0,
        -- Wide / tall target panel to match the reference layout.
        Size = UDim2.fromOffset(
            tonumber(_G._meerko_tgtW) or 245,
            tonumber(_G._meerko_tgtH) or 300
        ),
        Position = UDim2.fromOffset(tonumber(_G._meerko_tgtX) or 0,
            tonumber(_G._meerko_tgtY) or 184),
    })

    mk("UICorner", root, { CornerRadius = UDim.new(0, 5) })

    local head = mk("TextLabel", root, {
        Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -46, 0, 24),
        BackgroundTransparency = 1, Text = "TARGETS", Font = FB, TextSize = 14,
        TextColor3 = C.txt, TextXAlignment = Enum.TextXAlignment.Left,
    })
    local count = mk("TextLabel", root, {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 7),
        Size = UDim2.fromOffset(24, 18), BackgroundTransparency = 1,
        Text = "0", Font = FB, TextSize = 11, TextColor3 = C.acc,
        TextXAlignment = Enum.TextXAlignment.Right,
    })
    local modeContainer = mk("Frame", root, {
        Position = UDim2.fromOffset(10, 43), Size = UDim2.new(1, -20, 0, 25),
        BackgroundTransparency = 1,
    })
    mk("UIListLayout", modeContainer, {
        Padding = UDim.new(0, 14), FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
    })
    
    local modeButtons = {}
    local lastModeState = nil
    local function updateAllModes()
        local currentState = _G.MeerkoStealMode
        if currentState == lastModeState then return end
        lastModeState = currentState
        for _, btnData in ipairs(modeButtons) do
            local on = currentState == btnData.mode
            tw(btnData.bg, { BackgroundTransparency = on and 0 or 1 })
            tw(btnData.btn, { TextColor3 = on and C.txt or C.dim })
        end
    end
    
    local function modeBtn(txt, mode)
        local btnBg = mk("Frame", modeContainer, {
            Size = UDim2.fromOffset(82, 24), BackgroundColor3 = C.row,
            BorderSizePixel = 0, ZIndex = 1,
        })
        mk("UICorner", btnBg, { CornerRadius = UDim.new(0, 5) })
        local bg = mk("Frame", btnBg, {
            Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.acc,
            BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 2,
        })
        local btn = mk("TextButton", btnBg, {
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
            Text = txt, Font = FB, TextSize = 10, TextColor3 = C.dim,
            AutoButtonColor = false, Active = true, ZIndex = 3,
        })
        btn.MouseButton1Click:Connect(function()
            if _G.MeerkoStealMode == mode then
                _G.MeerkoStealMode = nil
            else
                _G.MeerkoStealMode = mode
            end
            stealOn = _G.MeerkoStealMode ~= nil
            saveTpSettings()
            updateAllModes()
        end)
        btn.MouseEnter:Connect(function()
            if _G.MeerkoStealMode ~= mode then
                tw(btnBg, { BackgroundColor3 = C.rowH })
            end
        end)
        btn.MouseLeave:Connect(function()
            if _G.MeerkoStealMode ~= mode then
                tw(btnBg, { BackgroundColor3 = C.row })
            end
        end)
        table.insert(modeButtons, { btn = btn, bg = bg, mode = mode })
        return btn
    end
    modeBtn("PRIORITY", "priority")
    modeBtn("NEAREST", "nearest")

    task.spawn(function()
        while sg.Parent do
            updateAllModes()
            task.wait(0.2)
        end
    end)

    local list = mk("ScrollingFrame", root, {
        Position = UDim2.fromOffset(7, 76), Size = UDim2.new(1, -14, 1, -82),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    })
    mk("UIListLayout", list, { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder })

    do
        local on, from, base, tracked
        head.InputBegan:Connect(function(i)
            if i.UserInputType ~= Enum.UserInputType.MouseButton1
                and i.UserInputType ~= Enum.UserInputType.Touch then return end
            on, from, base = true, i.Position, root.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then
                    on = false
                    _G._meerko_tgtX = root.Position.X.Offset
                    _G._meerko_tgtY = root.Position.Y.Offset
                end
            end)
        end)
        head.InputChanged:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseMovement
                or i.UserInputType == Enum.UserInputType.Touch then tracked = i end
        end)
        UIS.InputChanged:Connect(function(i)
            if not on or i ~= tracked then return end
            local d = i.Position - from
            root.Position = UDim2.fromOffset(base.X.Offset + d.X, base.Y.Offset + d.Y)
        end)
    end

    -- Bottom-right resize handle: drag to change the TARGETS panel size.
    -- Size is kept inside safe bounds and saved in globals for this session.
    local resize = mk("TextButton", root, {
        Name = "ResizeHandle", AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -3, 1, -3), Size = UDim2.fromOffset(18, 18),
        BackgroundTransparency = 1, BorderSizePixel = 0, Text = "",
        AutoButtonColor = false, Active = true, ZIndex = 20,
    })
    local resizeMark = mk("Frame", resize, {
        AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, 0),
        Size = UDim2.fromOffset(10, 2), Rotation = -45,
        BackgroundColor3 = C.dim, BorderSizePixel = 0, ZIndex = 21,
    })

    do
        local resizing, from, baseSize
        resize.InputBegan:Connect(function(i)
            if i.UserInputType ~= Enum.UserInputType.MouseButton1
                and i.UserInputType ~= Enum.UserInputType.Touch then return end
            resizing = true
            from = i.Position
            baseSize = root.AbsoluteSize
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then
                    resizing = false
                    _G._meerko_tgtW = root.AbsoluteSize.X
                    _G._meerko_tgtH = root.AbsoluteSize.Y
                end
            end)
        end)
        resize.InputChanged:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseMovement
                or i.UserInputType == Enum.UserInputType.Touch then
                tracked = i
            end
        end)
        UIS.InputChanged:Connect(function(i)
            if not resizing or i ~= tracked then return end
            local d = i.Position - from
            local w = math.clamp(baseSize.X + d.X, 205, 520)
            local h = math.clamp(baseSize.Y + d.Y, 205, 700)
            root.Size = UDim2.fromOffset(math.floor(w), math.floor(h))
        end)
    end

    local function short(n)
        n = tonumber(n) or 0
        if n >= 1e9 then return string.format("%.1fB", n / 1e9) end
        if n >= 1e6 then return string.format("%.1fM", n / 1e6) end
        if n >= 1e3 then return string.format("%.1fK", n / 1e3) end
        return string.format("%d", n)
    end

    local _CTP_TOL_X, _CTP_TOL_Z = 62, 58
    local function _ctpFloorFromY(y)
        if y >= -6.9 and y <= 8.9 then return 1 end
        if y >= 11 and y <= 23.15 then return 2 end
        if y > 23.15 then return 3 end
        return nil
    end
    local function _ctpFloorFromSlot(slot, py)
        local s = tonumber(slot)
        if s then
            if s >= 19 then return 3 end
            if s >= 11 then return 2 end
            if s >= 1 then return 1 end
        end
        if py then return _ctpFloorFromY(py) end
        return nil
    end
    local function _ctpSameBase(petPos, myPos)
        local pIdx = getClosestBaseIdx(petPos)
        local mIdx = getClosestBaseIdx(myPos)
        if pIdx ~= mIdx then return false end
        local b = BASES_LOW[mIdx]
        if not b then return false end
        return math.abs(myPos.X - b.X) <= _CTP_TOL_X
           and math.abs(myPos.Z - b.Z) <= _CTP_TOL_Z
    end
    local function _ctpAllowed(pet)
        if not pet or not pet.position then return false end
        local char = LP.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return false end
        local myPos = hrp.Position
        if not _ctpSameBase(pet.position, myPos) then return false end
        local myFloor = _ctpFloorFromY(myPos.Y)
        if not myFloor then return false end
        local tgtFloor = _ctpFloorFromSlot(pet.slot, pet.position.Y)
        if not tgtFloor then return false end
        local diff = tgtFloor - myFloor
        local up = tonumber(_G.MeerkoClickTPMaxUp) or 3
        local down = tonumber(_G.MeerkoClickTPMaxDown) or 3
        return diff <= up and diff >= -down
    end

    local rows = {}

    -- Resolve icon IDs from the game's Mutation/Trait data.
    local _iconDataCache = {}
    local function _iconId(v)
        if v == nil then return nil end
        if type(v) == "number" then
            return "rbxassetid://" .. tostring(math.floor(v))
        end
        if type(v) == "string" and v ~= "" then
            if v:match("^rbxassetid://") or v:match("^rbxasset://") or v:match("^https?://") then
                return v
            end
            local n = tonumber(v)
            if n then return "rbxassetid://" .. tostring(math.floor(n)) end
        end
        return nil
    end

    local function _dataModule(name)
        if _iconDataCache[name] ~= nil then
            return _iconDataCache[name] or nil
        end
        local ok, result = pcall(function()
            local d = RS:FindFirstChild("Datas")
            local m = d and d:FindFirstChild(name)
            return m and require(m)
        end)
        if ok and type(result) == "table" then
            _iconDataCache[name] = result
            return result
        end
        _iconDataCache[name] = false
        return nil
    end

    local function _findIcon(data)
        if type(data) ~= "table" then return nil end
        for _, key in ipairs({
            "Icon", "IconId", "IconID", "Image", "ImageId", "ImageID",
            "Texture", "TextureId", "TextureID", "Thumbnail", "ThumbnailId",
        }) do
            local id = _iconId(data[key])
            if id then return id end
        end
        return nil
    end

    local function _mutationIcon(name)
        if not name or name == "" or name == "None" then return nil end
        local md = _dataModule("Mutations")
        return md and _findIcon(md[name]) or nil
    end

    local function _traitIcon(name)
        if not name or name == "" then return nil end
        local td = _dataModule("Traits")
        return td and _findIcon(td[name]) or nil
    end

    local function _clearIcons(holder)
        for _, child in ipairs(holder:GetChildren()) do
            if child:IsA("ImageLabel") then child:Destroy() end
        end
    end

    local function _addIcon(holder, image, order)
        if not image then return end
        mk("ImageLabel", holder, {
            Size = UDim2.fromOffset(13, 13),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Image = image,
            ScaleType = Enum.ScaleType.Fit,
            LayoutOrder = order or 1,
        })
    end

    local function rowFor(uid)
        local r = rows[uid]
        if r and r.card.Parent then return r end

        local card = mk("Frame", list, {
            Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = C.row,
            BorderSizePixel = 0, Active = true,
        })
        mk("UICorner", card, { CornerRadius = UDim.new(0, 4) })

        local idx = mk("TextLabel", card, {
            Position = UDim2.fromOffset(7, 0), Size = UDim2.fromOffset(14, 38),
            BackgroundTransparency = 1, Text = "1", Font = FR, TextSize = 9,
            TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 2,
        })

        local bg = mk("Frame", card, {
            Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.acc,
            BackgroundTransparency = 1, BorderSizePixel = 0,
        })
        

        local bar = nil

        local nm = mk("TextLabel", card, {
            Position = UDim2.fromOffset(28, 4), Size = UDim2.new(1, -100, 0, 15),
            BackgroundTransparency = 1, Font = FB, TextSize = 11, TextColor3 = C.txt,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd, Text = "", ZIndex = 2,
        })

        local iconHolder = mk("Frame", card, {
            Position = UDim2.fromOffset(28, 20), Size = UDim2.new(1, -100, 0, 14),
            BackgroundTransparency = 1, ZIndex = 2,
        })
        mk("UIListLayout", iconHolder, {
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Left,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Padding = UDim.new(0, 2),
            SortOrder = Enum.SortOrder.LayoutOrder,
        })

        local sub = mk("TextLabel", card, {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -9, 0, 19),
            Size = UDim2.fromOffset(72, 16),
            BackgroundTransparency = 1, Font = FB, TextSize = 10, TextColor3 = C.acc,
            TextXAlignment = Enum.TextXAlignment.Right, Text = "", ZIndex = 2,
        })

        local hit = mk("TextButton", card, {
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "",
            AutoButtonColor = false, Active = true, ZIndex = 3,
        })

        r = {
            card = card, bg = bg, bar = bar, idx = idx, name = nm, sub = sub,
            icons = iconHolder, hit = hit, lastLocked = false,
        }
        rows[uid] = r
        return r
    end

    task.spawn(function()
        local _pd = tonumber(_G.MeerkoPanelStartDelay) or 0
        if _pd > 0 then task.wait(_pd) end
        local _filled = false
        local _panelT0 = os.clock()
        while sg.Parent do
            local _pw = os.clock()
            while _filled
                and (_G.MeerkoStealHold or (_G.MeerkoIsTeleporting and _G.MeerkoIsTeleporting()))
                and os.clock() - _pw < (tonumber(_G.MeerkoPanelPauseMax) or 3) do
                task.wait(0.2)
            end
            local ok, pets = pcall(scanAllPets)
            if ok and type(pets) == "table" then
                local seen = {}
                for i, p in ipairs(pets) do
                    if not p.conveyor then
                        local uid = _petUid(p)
                        seen[uid] = true
                        local r = rowFor(uid)
                        r.pet = p
                        r.card.LayoutOrder = i
                        if r.idx then r.idx.Text = tostring(i) end
                        r.name.Text = tostring(p.name or "?")
                        r.sub.Text = "$" .. short(p.mps or 0) .. "/s"

                        -- Mutation + Traits: icons only, shown below the brainrot name.
                        _clearIcons(r.icons)
                        local _io = 0
                        local _mi = _mutationIcon(p.mutation)
                        if _mi then
                            _io = _io + 1
                            _addIcon(r.icons, _mi, _io)
                        end
                        if type(p.traits) == "table" then
                            for _, tr in ipairs(p.traits) do
                                local _ti = _traitIcon(tr)
                                if _ti then
                                    _io = _io + 1
                                    _addIcon(r.icons, _ti, _io)
                                end
                            end
                        end
                        local locked = (_G.MeerkoStealTargetUID == uid)
                        if locked ~= r.lastLocked then
                            r.lastLocked = locked
                            tw(r.bg, { BackgroundTransparency = 1 })
                            -- No left accent bar.
                            tw(r.card, { BackgroundColor3 = C.row })
                        end
                        if not r.wired then
                            r.wired = true
                            local myUid = uid
                            local _crow = r
                            r.hit.MouseButton1Click:Connect(function()
                                if _G.MeerkoStealTargetUID == myUid then
                                    _G.MeerkoStealTargetUID = nil
                                    _G.MeerkoStealTarget = nil
                                else
                                    _G.MeerkoStealTargetUID = myUid
                                    local pet = _crow.pet
                                    do
                                        local okS, fresh = pcall(scanAllPets)
                                        if okS and type(fresh) == "table" then
                                            for _, fp in ipairs(fresh) do
                                                if _petUid(fp) == myUid then pet = fp break end
                                            end
                                        end
                                    end
                                    if pet and pet.position and not isTeleporting
                                        and not _G.MeerkoClickTPBusy
                                        and _ctpAllowed(pet) then
                                        _G.MeerkoClickTPBusy = true
                                        isTeleporting = true
                                        if _G.MeerkoArmSteal then pcall(_G.MeerkoArmSteal, pet) end
                                        task.spawn(function()
                                            pcall(function()
                                                goToBrainrot(pet.position, pet.slot)
                                            end)
                                            isTeleporting = false
                                            _G.MeerkoClickTPBusy = false
                                        end)
                                    end
                                end
                            end)
                            r.hit.MouseEnter:Connect(function()
                                if _G.MeerkoStealTargetUID ~= myUid then
                                    tw(r.card, { BackgroundColor3 = C.rowH })
                                end
                            end)
                            r.hit.MouseLeave:Connect(function()
                                if _G.MeerkoStealTargetUID ~= myUid then
                                    tw(r.card, { BackgroundColor3 = C.row })
                                end
                            end)
                        end
                    end
                end
                local n = 0
                for uid, r in pairs(rows) do
                    if seen[uid] then n = n + 1
                    else r.card:Destroy() rows[uid] = nil end
                end
                count.Text = tostring(n)
                if n > 0 then _filled = true end
            end
            if not _filled and (os.clock() - _panelT0) < (tonumber(_G.MeerkoPanelRush) or 10) then
                task.wait(tonumber(_G.MeerkoPanelRushGap) or 0.05)
            else
                task.wait(tonumber(_G.MeerkoPanelScanGap) or 0.4)
            end
        end
    end)

    _G.MeerkoToggleTargets = function() sg.Enabled = not sg.Enabled end
end)()
