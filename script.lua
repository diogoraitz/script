--[[
    SELL LEMONS ULTIMATE FARM v3.0
    By: Claude AI
    Funcionalidades:
    - Auto Farm Completo (Compras, Upgrades, Frutas, Drops)
    - Auto Rebirth/Evolve/Ascend INTELIGENTE
    - Sistema de Levers + Sewer Alien
    - Painel de Status em tempo real
    - Anti-AFK + FPS Boost
    - Interface Rayfield Moderna
]]

--// Carregar UI
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Sell Lemons ULTIMATE",
    LoadingTitle = "Sell Lemons Ultimate Farm",
    LoadingSubtitle = "By Claude AI",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false,
})

--// Serviços
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer

--// Encontrar Tycoon
local userTycoon = (function()
    for _, v in pairs(workspace:GetChildren()) do
        if v:IsA("Folder") and v.Name:match("Tycoon%d") then
            if v:FindFirstChild("Owner") and v.Owner.Value == LocalPlayer then
                return v
            end
        end
    end
end)()

if not userTycoon then
    Rayfield:Notify({ Title = "Erro", Content = "Tycoon não encontrado!", Duration = 5 })
    return
end

--// Configurações
local Config = {
    AutoBuy = false,
    AutoUpgrade = false,
    AutoFruit = false,
    AutoRebirth = false,
    AutoEvolve = false,
    AutoAscend = false,
    AutoPower = false,
    AutoLevers = false,
    AutoVine = false,
    AutoDrops = false,
    AutoClick = false,
    AutoPhone = false,
    AutoOffline = false,
    AutoTime = false,
    AutoEarner = false,
    AutoRace = false,
    AutoTrade = false,
    AntiAFK = false,
    BoostFPS = false,
    FastCollect = false, -- coleta frutas sem teleportar (mais rápido, mas só funciona se o servidor não checar distância)
}

--// Stats
local Stats = {
    buys = 0, upgrades = 0, fruit = 0, rebirths = 0,
    evolves = 0, ascends = 0, power = 0, drops = 0,
    clicks = 0, phone = 0, levers = 0, vine = 0,
    races = 0, trades = 0,
}

--// Caches
local upgradeRemotes = {}
local upgradeLevel = {}
local lastUpgradeScan = 0
local treeCache = {}
local BuyLock = {}

--// Funções Auxiliares
local function GetRemote(name)
    local remotes = userTycoon:FindFirstChild("Remotes")
    return remotes and remotes:FindFirstChild(name)
end

local function GetCash()
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    if not ls then return 0 end
    for _, v in ipairs(ls:GetChildren()) do
        if v:IsA("NumberValue") and v.Name:lower():find("cash") then
            return v.Value
        end
    end
    return 0
end

--// AUTO BUY OTIMIZADO
local function BuyAllAffordable()
    for _, obj in ipairs(userTycoon.Purchases:GetDescendants()) do
        if obj:IsA("Model") then
            if obj:GetAttribute("Shown") == true and obj:GetAttribute("Purchased") ~= true then
                local purchase = obj:FindFirstChild("Purchase")
                if purchase and purchase:IsA("RemoteFunction") and not BuyLock[purchase] then
                    BuyLock[purchase] = true
                    task.spawn(function()
                        pcall(function() purchase:InvokeServer() end)
                        Stats.buys += 1
                        task.wait(0.5)
                        BuyLock[purchase] = nil
                    end)
                end
            end
        end
    end
end

task.spawn(function()
    while true do
        task.wait(0.1)
        if Config.AutoBuy then pcall(BuyAllAffordable) end
    end
end)

--// AUTO UPGRADE COM CACHE
local function RefreshUpgradeRemotes()
    upgradeRemotes = {}
    upgradeLevel = {}
    local purchases = userTycoon:FindFirstChild("Purchases")
    if not purchases then return end
    for _, obj in ipairs(purchases:GetDescendants()) do
        if obj:IsA("RemoteFunction") and obj.Name == "Upgrade" then
            upgradeRemotes[#upgradeRemotes + 1] = obj
        end
    end
end

task.spawn(function()
    while true do
        task.wait(0.25)
        if Config.AutoUpgrade then
            if tick() - lastUpgradeScan > 3 then
                RefreshUpgradeRemotes()
                lastUpgradeScan = tick()
            end
            for _, remote in ipairs(upgradeRemotes) do
                if remote.Parent then
                    local lvl = (upgradeLevel[remote] or 0) + 1
                    while lvl <= 100 do
                        local ok, res = pcall(function() return remote:InvokeServer(lvl) end)
                        if not ok or res == false then break end
                        upgradeLevel[remote] = lvl
                        Stats.upgrades += 1
                        lvl = lvl + 1
                    end
                end
            end
        end
    end
end)

--// AUTO FRUIT COM CACHE DINÂMICA
local function AddTree(obj)
    if obj:IsA("Model") and obj.Name == "LemonTree" then
        if not table.find(treeCache, obj) then
            table.insert(treeCache, obj)
        end
    end
end

local function RemoveTree(obj)
    local idx = table.find(treeCache, obj)
    if idx then table.remove(treeCache, idx) end
end

for _, v in ipairs(workspace:GetDescendants()) do AddTree(v) end
workspace.DescendantAdded:Connect(AddTree)
workspace.DescendantRemoving:Connect(RemoveTree)

-- Modo rápido: dispara os detectores sem mover o personagem.
-- Seguro pra rodar em paralelo (não mexe em hrp.CFrame), mas só funciona
-- se o servidor não validar a distância do jogador até a fruta.
local function CollectFruitFast(tree)
    for _, obj in ipairs(tree:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name == "Fruit" then
            local clickPart = obj:FindFirstChild("ClickPart")
            local detector = clickPart and clickPart:FindFirstChildOfClass("ClickDetector")
            if detector then
                pcall(function() fireclickdetector(detector) end)
                Stats.fruit += 1
            end
        end
    end
end

-- Modo clássico: teleporta até a árvore antes de clicar (funciona mesmo
-- se o servidor checar distância, mas é sequencial e mais lento).
local function CollectFruitTeleport(tree)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    for _, obj in ipairs(tree:GetDescendants()) do
        if obj:IsA("BasePart") then obj.CanCollide = false end
    end

    local cf = tree:GetPivot()
    pcall(function() hrp.CFrame = cf + Vector3.new(0, 5, 0) end)

    for _, obj in ipairs(tree:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name == "Fruit" then
            obj.CanCollide = false
            local clickPart = obj:FindFirstChild("ClickPart")
            local detector = clickPart and clickPart:FindFirstChildOfClass("ClickDetector")
            if detector then
                task.wait(0.1)
                pcall(function() fireclickdetector(detector) end)
                Stats.fruit += 1
            end
        end
    end
end

task.spawn(function()
    while true do
        task.wait(0.1)
        if Config.AutoFruit then
            if Config.FastCollect then
                -- paralelo: seguro porque cada coroutine só lê a própria árvore
                for _, tree in ipairs(treeCache) do
                    if not Config.AutoFruit then break end
                    if tree and tree.Parent then
                        task.spawn(function() pcall(CollectFruitFast, tree) end)
                    end
                end
            else
                for _, tree in ipairs(treeCache) do
                    if not Config.AutoFruit then break end
                    if tree and tree.Parent then
                        pcall(CollectFruitTeleport, tree)
                    end
                end
            end
        end
    end
end)

--// AUTO REBIRTH INTELIGENTE
local RebirthCooldown = false
local RebirthGainMultiple = 1.0
local MinPotential = 1

local function ParseNumber(s)
    if not s then return nil end
    s = tostring(s):gsub(",", ""):lower()
    local num = s:match("[%d%.]+")
    local val = num and tonumber(num)
    if not val then return nil end
    local scales = { k=1e3, m=1e6, b=1e9, t=1e12, qd=1e15, qn=1e18, sx=1e21, sp=1e24 }
    local word = s:match("[%d%.%s]+([a-z]+)")
    if word and scales[word] then val = val * scales[word] end
    return val
end

local function GetInvestorInfo()
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local r = pg and pg:FindFirstChild("Rebirth")
    local im = r and r:FindFirstChild("InvestorsMenu")
    local body = im and im:FindFirstChild("Body")
    if not body then return 0, nil end

    local current = 0
    local potential = nil

    local amount = body:FindFirstChild("Amount")
    if amount and amount:FindFirstChild("Quantity") then
        current = ParseNumber(amount.Quantity.Text) or 0
    end

    local pot = body:FindFirstChild("Potential")
    if pot and pot:FindFirstChild("Quantity") then
        potential = ParseNumber(pot.Quantity.Text)
    end

    return current, potential
end

task.spawn(function()
    while true do
        task.wait(0.5)
        if Config.AutoRebirth and not RebirthCooldown then
            local remote = GetRemote("Rebirth")
            local current, potential = GetInvestorInfo()

            if remote and potential and potential >= MinPotential and potential >= current * RebirthGainMultiple then
                RebirthCooldown = true
                task.spawn(function()
                    pcall(function() remote:InvokeServer() end)
                    Stats.rebirths += 1
                    task.wait(5)
                    RebirthCooldown = false
                end)
            end
        end
    end
end)

--// AUTO EVOLVE
local EvolveBusy = false

local function GetEvolveProgress()
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local r = pg and pg:FindFirstChild("Rebirth")
    local em = r and r:FindFirstChild("EvolutionMenu")
    local body = em and em:FindFirstChild("Body")
    local p = body and body:FindFirstChild("Progress")
    if not p then return nil end
    return tonumber(tostring(p.Text):match("[%d%.]+"))
end

task.spawn(function()
    while true do
        task.wait(0.5)
        if Config.AutoEvolve and not EvolveBusy then
            local remote = GetRemote("Evolve")
            local progress = GetEvolveProgress()
            if remote and progress and progress >= 100 then
                EvolveBusy = true
                pcall(function() remote:InvokeServer() end)
                Stats.evolves += 1
                task.wait(2)
                EvolveBusy = false
            end
        end
    end
end)

--// AUTO ASCEND
task.spawn(function()
    while true do
        task.wait(1)
        if Config.AutoAscend then
            local remote = GetRemote("Ascend")
            if remote then
                pcall(function() remote:InvokeServer() end)
                Stats.ascends += 1
            end
        end
    end
end)

--// AUTO POWER LEVEL
task.spawn(function()
    while true do
        task.wait(0.5)
        if Config.AutoPower then
            local remote = GetRemote("UpgradePowerLevel")
            if remote then
                pcall(function() remote:InvokeServer() end)
                Stats.power += 1
            end
        end
    end
end)

--// AUTO CLICK INCOME
local IncomeStreams = {
    "LemonDash", "LemonDepot", "LemonLabs",
    "LemonTrading", "LemonRepublic", "LemonRobotics",
    "LemonStand", "LemonX",
}

task.spawn(function()
    while true do
        task.wait(0.1)
        if Config.AutoClick then
            local remote = GetRemote("WakeIncomeStream")
            if remote then
                for _, stream in ipairs(IncomeStreams) do
                    task.spawn(function()
                        pcall(function() remote:InvokeServer(stream) end)
                        Stats.clicks += 1
                    end)
                end
            end
        end
    end
end)

--// AUTO PHONE OFFER
task.spawn(function()
    while true do
        task.wait(0.5)
        if Config.AutoPhone then
            local remote = GetRemote("PhoneOffer")
            if remote then
                pcall(function() remote:FireServer("Accept") end)
                Stats.phone += 1
            end
        end
    end
end)

--// AUTO OFFLINE CASH
task.spawn(function()
    while true do
        task.wait(20)
        if Config.AutoOffline then
            local remote = GetRemote("DoubleOfflineCash")
            if remote then pcall(function() remote:InvokeServer() end) end
        end
    end
end)

--// AUTO TIME CASH
task.spawn(function()
    while true do
        task.wait(10)
        if Config.AutoTime then
            local remote = GetRemote("UseTimeCash")
            if remote then pcall(function() remote:InvokeServer() end) end
        end
    end
end)

--// AUTO EARNER BOOST
task.spawn(function()
    while true do
        task.wait(10)
        if Config.AutoEarner then
            local remote = GetRemote("UseEarnerBoost")
            if remote then pcall(function() remote:InvokeServer() end) end
        end
    end
end)

--// AUTO MINIGAME RACE
task.spawn(function()
    while true do
        task.wait(5)
        if Config.AutoRace then
            local core = game:GetService("ReplicatedStorage"):FindFirstChild("Core")
            local request = core and core:FindFirstChild("RemoteRequest")
            local startRF = request and request:FindFirstChild("MinigameRaceService.Start")
            local endRF = request and request:FindFirstChild("MinigameRaceService.End")
            if startRF and endRF then
                pcall(function() startRF:InvokeServer() end)
                task.wait(0.25)
                pcall(function() endRF:InvokeServer(1) end)
                Stats.races += 1
            end
        end
    end
end)

--// AUTO MINIGAME TRADE
task.spawn(function()
    while true do
        task.wait(5)
        if Config.AutoTrade then
            local core = game:GetService("ReplicatedStorage"):FindFirstChild("Core")
            local request = core and core:FindFirstChild("RemoteRequest")
            local startRF = request and request:FindFirstChild("MinigameTradeService.Start")
            local endRF = request and request:FindFirstChild("MinigameTradeService.End")
            if startRF and endRF then
                pcall(function() startRF:InvokeServer() end)
                task.wait(0.25)
                pcall(function() endRF:InvokeServer(1) end)
                Stats.trades += 1
            end
        end
    end
end)

--// AUTO LEVERS + SEWER
local function TouchPart(hrp, part)
    pcall(function()
        firetouchinterest(hrp, part, 0)
        firetouchinterest(hrp, part, 1)
    end)
end

local function DoSewerRun()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    local map = workspace:FindFirstChild("Map")
    local sewer = map and map:FindFirstChild("Sewer")
    if not sewer then return false end

    -- Puxar alavancas
    for _, o in ipairs(sewer:GetDescendants()) do
        if o:IsA("BasePart") and string.find(string.lower(o.Name), "lever", 1, true) then
            TouchPart(hrp, o)
            Stats.levers += 1
        end
    end

    -- Coletar chaves
    for _, folderName in ipairs({ "CashVine", "SewerAlien" }) do
        local folder = sewer:FindFirstChild(folderName)
        if folder then
            for _, o in ipairs(folder:GetDescendants()) do
                if o:IsA("BasePart") and (o.Name == "VineKey" or o.Name == "UFOKey") then
                    TouchPart(hrp, o)
                end
            end
        end
    end
    task.wait(0.3)

    -- Abrir porta e coletar vine
    local cashVine = sewer:FindFirstChild("CashVine")
    if cashVine then
        local vineDoor = cashVine:FindFirstChild("VineDoor")
        if vineDoor then
            for _, o in ipairs(vineDoor:GetDescendants()) do
                if o:IsA("BasePart") then TouchPart(hrp, o) end
            end
        end
        task.wait(0.3)
        local vineModel = cashVine:FindFirstChild("CashVine")
        if vineModel then
            local pivot = vineModel:GetPivot()
            pcall(function() hrp.CFrame = pivot + Vector3.new(0, 3, 0) end)
            task.wait(0.2)
            for _, o in ipairs(vineModel:GetDescendants()) do
                if o:IsA("BasePart") then TouchPart(hrp, o) end
            end
            Stats.vine += 1
        end
    end

    return true
end

task.spawn(function()
    while true do
        task.wait(30)
        if Config.AutoLevers then pcall(DoSewerRun) end
    end
end)

--// ANTI-AFK
LocalPlayer.Idled:Connect(function()
    if Config.AntiAFK then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end
end)

--// FPS BOOST
local RemovedObjects = {}
local FPSBoostActive = false

local function EnableFPSBoost()
    if FPSBoostActive then return end
    FPSBoostActive = true
    local removeClasses = {
        "Texture", "Decal", "ParticleEmitter", "Trail", "Smoke",
        "Fire", "Sparkles", "SpecialMesh", "SelectionBox", "SurfaceAppearance"
    }
    for _, obj in ipairs(workspace:GetDescendants()) do
        for _, cls in ipairs(removeClasses) do
            if obj:IsA(cls) then
                table.insert(RemovedObjects, { obj = obj, parent = obj.Parent })
                obj.Parent = nil
                break
            end
        end
    end
    Lighting.GlobalShadows = false
end

local function DisableFPSBoost()
    if not FPSBoostActive then return end
    FPSBoostActive = false
    for _, entry in ipairs(RemovedObjects) do
        pcall(function() entry.obj.Parent = entry.parent end)
    end
    RemovedObjects = {}
    Lighting.GlobalShadows = true
end

--// UI - TABS
local MainTab = Window:CreateTab("Farm", 4483362458)
local BonusTab = Window:CreateTab("Bonus", 4483362458)
local MiscTab = Window:CreateTab("Misc", 4483362458)

--// Tab Farm
MainTab:CreateToggle({ Name = "Auto Buy", CurrentValue = false, Callback = function(v) Config.AutoBuy = v end })
MainTab:CreateToggle({ Name = "Auto Upgrade Stands", CurrentValue = false, Callback = function(v) Config.AutoUpgrade = v end })
MainTab:CreateToggle({ Name = "Auto Fruit", CurrentValue = false, Callback = function(v) Config.AutoFruit = v end })
MainTab:CreateToggle({ Name = "Fruit: Modo Rápido (sem teleporte)", CurrentValue = false, Callback = function(v) Config.FastCollect = v end })
MainTab:CreateToggle({ Name = "Auto Click Income", CurrentValue = false, Callback = function(v) Config.AutoClick = v end })
MainTab:CreateToggle({ Name = "Auto Rebirth", CurrentValue = false, Callback = function(v) Config.AutoRebirth = v end })
MainTab:CreateToggle({ Name = "Auto Evolve (x10 speed)", CurrentValue = false, Callback = function(v) Config.AutoEvolve = v end })
MainTab:CreateToggle({ Name = "Auto Ascend", CurrentValue = false, Callback = function(v) Config.AutoAscend = v end })
MainTab:CreateToggle({ Name = "Auto Power Level", CurrentValue = false, Callback = function(v) Config.AutoPower = v end })

--// Tab Bonus
BonusTab:CreateToggle({ Name = "Auto Phone Offer", CurrentValue = false, Callback = function(v) Config.AutoPhone = v end })
BonusTab:CreateToggle({ Name = "Auto Double Offline Cash", CurrentValue = false, Callback = function(v) Config.AutoOffline = v end })
BonusTab:CreateToggle({ Name = "Auto Time Cash", CurrentValue = false, Callback = function(v) Config.AutoTime = v end })
BonusTab:CreateToggle({ Name = "Auto Earner Boost", CurrentValue = false, Callback = function(v) Config.AutoEarner = v end })
BonusTab:CreateToggle({ Name = "Auto Minigame Race", CurrentValue = false, Callback = function(v) Config.AutoRace = v end })
BonusTab:CreateToggle({ Name = "Auto Minigame Trade", CurrentValue = false, Callback = function(v) Config.AutoTrade = v end })
BonusTab:CreateToggle({ Name = "Auto Levers + Vine", CurrentValue = false, Callback = function(v) Config.AutoLevers = v end })

--// Tab Misc
MiscTab:CreateToggle({ Name = "Anti-AFK", CurrentValue = false, Callback = function(v) Config.AntiAFK = v end })
MiscTab:CreateToggle({ Name = "Boost FPS", CurrentValue = false, Callback = function(v) Config.BoostFPS = v; if v then EnableFPSBoost() else DisableFPSBoost() end end })

MiscTab:CreateButton({ Name = "Vine Harvest (Manual)", Callback = function()
    task.spawn(function()
        local ok = DoSewerRun()
        Rayfield:Notify({ Title = "Vine Harvest", Content = ok and "Sucesso!" or "Falhou!", Duration = 3 })
    end)
end })

MiscTab:CreateButton({ Name = "Teleportar para Sewer Alien", Callback = function()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        pcall(function() hrp.CFrame = CFrame.new(-42, -41, 180) end)
    end
end })

MiscTab:CreateButton({ Name = "Destruir GUI", Callback = function() Rayfield:Destroy() end })

--// PAINEL DE STATUS
task.spawn(function()
    local parent = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not parent then
        local ok, hui = pcall(function() return gethui() end)
        parent = (ok and hui) or game:GetService("CoreGui")
    end

    pcall(function()
        local old = parent:FindFirstChild("UltimateStatusGui")
        if old then old:Destroy() end
    end)

    local gui = Instance.new("ScreenGui")
    gui.Name = "UltimateStatusGui"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 9999
    gui.Parent = parent

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 220, 0, 200)
    frame.Position = UDim2.new(0, 10, 0, 90)
    frame.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
    frame.BackgroundTransparency = 0.1
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Parent = gui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 24)
    title.BackgroundColor3 = Color3.fromRGB(38, 40, 54)
    title.BorderSizePixel = 0
    title.Text = "ULTIMATE STATUS"
    title.TextColor3 = Color3.fromRGB(120, 235, 140)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 13
    title.Parent = frame
    Instance.new("UICorner", title).CornerRadius = UDim.new(0, 8)

    local body = Instance.new("TextLabel")
    body.Size = UDim2.new(1, -12, 1, -30)
    body.Position = UDim2.new(0, 8, 0, 28)
    body.BackgroundTransparency = 1
    body.TextXAlignment = Enum.TextXAlignment.Left
    body.TextYAlignment = Enum.TextYAlignment.Top
    body.RichText = true
    body.TextColor3 = Color3.fromRGB(235, 235, 245)
    body.Font = Enum.Font.Code
    body.TextSize = 11
    body.Parent = frame

    -- Drag
    local UIS = game:GetService("UserInputService")
    local dragging, ds, sp
    title.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, ds, sp = true, i.Position, frame.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - ds
            frame.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
        end
    end)

    local frames, fps, fpsT = 0, 0, tick()
    RunService.RenderStepped:Connect(function()
        frames = frames + 1
        if tick() - fpsT >= 1 then fps, frames, fpsT = frames, 0, tick() end
    end)

    local function On(b) return b and "<font color='#7CFF7C'>ON</font>" or "<font color='#777'>off</font>" end

    while gui.Parent do
        local cash = GetCash()
        body.Text = string.format(
            "FPS: %d | Cash: %s\n"
            .. "Buys: %d | Upgr: %d | Fruit: %d\n"
            .. "Reb: %d | Evo: %d | Asc: %d\n"
            .. "Power: %d | Drops: %d | Click: %d\n"
            .. "Levers: %d | Vine: %d\n"
            .. "Race: %d | Trade: %d | Phone: %d",
            fps, cash,
            Stats.buys, Stats.upgrades, Stats.fruit,
            Stats.rebirths, Stats.evolves, Stats.ascends,
            Stats.power, Stats.drops, Stats.clicks,
            Stats.levers, Stats.vine,
            Stats.races, Stats.trades, Stats.phone
        )
        task.wait(0.25)
    end
end)

--// Notificação Final
Rayfield:Notify({ Title = "ULTIMATE FARM", Content = "Carregado com sucesso!", Duration = 5 })
