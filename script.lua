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
    AutoPlots = false,
    AutoEatFruit = false,
    AutoSellFruits = false,
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
local BuyLock = {}

--// Limitador de chamadas simultâneas ao servidor.
-- Disparar dezenas de InvokeServer em paralelo estoura o rate-limit do
-- servidor, que aí passa a ignorar/atrasar TODAS as chamadas (é isso que
-- causava "compra para de funcionar" depois de um tempo). Isso trava um
-- teto de chamadas simultâneas em voo.
local activeRemoteCalls = 0
local MAX_CONCURRENT_CALLS = 6

local function limitedSpawn(fn)
    if activeRemoteCalls >= MAX_CONCURRENT_CALLS then return end
    activeRemoteCalls += 1
    task.spawn(function()
        pcall(fn)
        activeRemoteCalls -= 1
    end)
end

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
                    limitedSpawn(function()
                        pcall(function() purchase:InvokeServer() end)
                        Stats.buys += 1
                    end)
                    task.delay(0.5, function() BuyLock[purchase] = nil end)
                end
            end
        end
    end
end

task.spawn(function()
    while true do
        task.wait(0.5)
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
        task.wait() -- ~1 frame (poucos milésimos): upgrade de stand é barato, não precisa de rate-limit
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

--// AUTO FRUIT — detecção por objeto-fruta, não por container
-- Não confia no nome da árvore/orchard (muda entre versões do jogo).
-- Busca direto qualquer BasePart com "fruit" no nome que tenha um
-- ClickDetector (direto ou dentro de um filho "ClickPart"), procurando
-- só dentro do SEU tycoon (não o workspace inteiro — evita clicar em
-- fruta de outro jogador e gerar tráfego desnecessário no servidor).
local fruitCache = {}
local lastFruitScan = 0
local fruitIdx = 1

local function findDetector(part)
    local d = part:FindFirstChildOfClass("ClickDetector")
    if d then return d end
    local clickPart = part:FindFirstChild("ClickPart")
    return clickPart and clickPart:FindFirstChildOfClass("ClickDetector")
end

local function scanFruits()
    table.clear(fruitCache)
    for _, obj in ipairs(userTycoon:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name:lower():find("fruit") then
            local detector = findDetector(obj)
            if detector then
                table.insert(fruitCache, { part = obj, detector = detector })
            end
        end
    end
    fruitIdx = 1
end
scanFruits()

-- Coleta UMA fruta por vez, num ritmo fixo (não em rajada). Isso é
-- proposital: disparar dezenas de cliques no mesmo instante é o que
-- estourava o rate-limit do servidor e derrubava Buy/Upgrade junto.
task.spawn(function()
    while true do
        if Config.AutoFruit then
            if tick() - lastFruitScan > 3 then
                pcall(scanFruits)
                lastFruitScan = tick()
            end

            if #fruitCache == 0 then
                task.wait(1)
            else
                if fruitIdx > #fruitCache then fruitIdx = 1 end
                local entry = fruitCache[fruitIdx]
                fruitIdx += 1
                if entry and entry.part and entry.part.Parent and entry.detector and entry.detector.Parent then
                    pcall(function() fireclickdetector(entry.detector) end)
                    Stats.fruit += 1
                end
                task.wait(0.08) -- ~12 frutas/segundo, ritmo seguro
            end
        else
            task.wait(0.3)
        end
    end
end)

--// AUTO ORCHARD (plantar/colher/desbloquear parcelas + comer/vender fruta)
-- Descoberto analisando a estrutura real do jogo: cada parcela em
-- Orchard/Plots/PlotN tem um ProximityPrompt "OrchardPlotPrompt" que serve
-- pras 3 ações (desbloquear, plantar, colher) dependendo do estado atual —
-- é o mesmo prompt que o próprio jogo usa quando você aperta E. Disparando
-- ele via fireproximityprompt fazemos exatamente o que o jogo já faria.
local plotPrompts = {}
local lastPlotScan = 0
local plotIdx = 1

local function scanPlots()
    table.clear(plotPrompts)
    local orchard = userTycoon:FindFirstChild("Orchard")
    local plots = orchard and orchard:FindFirstChild("Plots")
    if not plots then return end
    for _, plot in ipairs(plots:GetChildren()) do
        for _, obj in ipairs(plot:GetDescendants()) do
            if obj:IsA("ProximityPrompt") then
                table.insert(plotPrompts, obj)
            end
        end
    end
    plotIdx = 1
end
scanPlots()

task.spawn(function()
    while true do
        if Config.AutoPlots then
            if tick() - lastPlotScan > 5 then
                pcall(scanPlots)
                lastPlotScan = tick()
            end
            if #plotPrompts == 0 then
                task.wait(1)
            else
                if plotIdx > #plotPrompts then plotIdx = 1 end
                local prompt = plotPrompts[plotIdx]
                plotIdx += 1
                if prompt and prompt.Parent then
                    pcall(function() fireproximityprompt(prompt) end)
                end
                task.wait(0.15) -- ritmo controlado, mesmo motivo do fruit/click
            end
        else
            task.wait(0.3)
        end
    end
end)

--// AUTO EAT FRUIT / SELL FRUITS
-- Remotes confirmados na estrutura do jogo (Tycoon/Remotes/EatFruit e
-- .../SellFruits). Chamamos sem argumento; se o jogo exigir algum, a
-- chamada simplesmente falha (protegida por pcall) sem quebrar o resto.
task.spawn(function()
    while true do
        task.wait(3)
        if Config.AutoEatFruit then
            local remote = GetRemote("EatFruit")
            if remote then pcall(function() remote:InvokeServer() end) end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(5)
        if Config.AutoSellFruits then
            local remote = GetRemote("SellFruits")
            if remote then pcall(function() remote:InvokeServer() end) end
        end
    end
end)

--// AUTO REBIRTH INTELIGENTE
local RebirthCooldown = false
local RebirthGainMultiple = 1.0
local MinPotential = 1
local RebirthMinInterval = 1800 -- 30 minutos entre rebirths, mesmo que já "valha a pena" antes disso
local lastRebirthTime = 0

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

            local worthIt = remote and potential
                and potential >= MinPotential
                and potential >= current * RebirthGainMultiple
            local intervalOk = (tick() - lastRebirthTime) >= RebirthMinInterval

            if worthIt and intervalOk then
                RebirthCooldown = true
                task.spawn(function()
                    pcall(function() remote:InvokeServer() end)
                    Stats.rebirths += 1
                    lastRebirthTime = tick()
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

-- Antes disparava as 8 streams em paralelo a cada 100ms (até 80 chamadas/s).
-- Agora cicla uma stream por vez, ritmo fixo — mesmo princípio da correção
-- das frutas, pra não estourar o rate-limit do servidor.
task.spawn(function()
    local idx = 1
    while true do
        if Config.AutoClick then
            local remote = GetRemote("WakeIncomeStream")
            if remote then
                if idx > #IncomeStreams then idx = 1 end
                local stream = IncomeStreams[idx]
                idx += 1
                pcall(function() remote:InvokeServer(stream) end)
                Stats.clicks += 1
            end
            task.wait(0.15)
        else
            task.wait(0.3)
        end
    end
end)

--// AUTO PHONE OFFER
task.spawn(function()
    while true do
        task.wait(2)
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

--// Botão único: liga tudo de uma vez (farm completo, sem precisar tocar em mais nada)
local AutoBuyToggle, AutoUpgradeToggle, AutoFruitToggle
local AutoRebirthToggle, AutoEvolveToggle, AutoAscendToggle
local AutoPowerToggle, AutoClickToggle
local AutoPhoneToggle, AutoOfflineToggle, AutoTimeToggle
local AutoEarnerToggle, AutoLeversToggle, AntiAFKToggle
local AutoPlotsToggle, AutoEatFruitToggle, AutoSellFruitsToggle

local function SetAllFarm(v)
    Config.AutoBuy = v
    Config.AutoUpgrade = v
    Config.AutoFruit = v
    Config.AutoRebirth = v
    Config.AutoEvolve = v
    Config.AutoAscend = v
    Config.AutoPower = v
    Config.AutoClick = v
    Config.AutoPhone = v
    Config.AutoOffline = v
    Config.AutoTime = v
    Config.AutoEarner = v
    Config.AutoLevers = v
    Config.AntiAFK = v
    Config.AutoPlots = v
    Config.AutoEatFruit = v
    Config.AutoSellFruits = v

    -- tenta sincronizar visualmente as toggles individuais (best-effort:
    -- se essa versão do Rayfield não suportar :Set, as flags acima já
    -- garantem que o farm funciona mesmo assim)
    for _, t in ipairs({
        AutoBuyToggle, AutoUpgradeToggle, AutoFruitToggle,
        AutoRebirthToggle, AutoEvolveToggle, AutoAscendToggle,
        AutoPowerToggle, AutoClickToggle, AutoPhoneToggle,
        AutoOfflineToggle, AutoTimeToggle, AutoEarnerToggle,
        AutoLeversToggle, AntiAFKToggle, AutoPlotsToggle,
        AutoEatFruitToggle, AutoSellFruitsToggle,
    }) do
        if t then pcall(function() t:Set(v) end) end
    end

    Rayfield:Notify({
        Title = "Auto Farm",
        Content = v and "Tudo ativado: comprando, upando stands, colhendo/plantando frutas, vendendo, rebirth/evolve/ascend, bônus e anti-AFK."
            or "Tudo desativado.",
        Duration = 6,
    })
end

MainTab:CreateToggle({ Name = "AUTO FARM COMPLETO (ativa tudo)", CurrentValue = false, Callback = SetAllFarm })

--// Tab Farm (controle individual, opcional)
AutoBuyToggle = MainTab:CreateToggle({ Name = "Auto Buy", CurrentValue = false, Callback = function(v) Config.AutoBuy = v end })
AutoUpgradeToggle = MainTab:CreateToggle({ Name = "Auto Upgrade Stands", CurrentValue = false, Callback = function(v) Config.AutoUpgrade = v end })
AutoFruitToggle = MainTab:CreateToggle({ Name = "Auto Fruit", CurrentValue = false, Callback = function(v) Config.AutoFruit = v end })
AutoClickToggle = MainTab:CreateToggle({ Name = "Auto Click Income", CurrentValue = false, Callback = function(v) Config.AutoClick = v end })
AutoRebirthToggle = MainTab:CreateToggle({ Name = "Auto Rebirth", CurrentValue = false, Callback = function(v) Config.AutoRebirth = v end })
AutoEvolveToggle = MainTab:CreateToggle({ Name = "Auto Evolve (x10 speed)", CurrentValue = false, Callback = function(v) Config.AutoEvolve = v end })
AutoAscendToggle = MainTab:CreateToggle({ Name = "Auto Ascend", CurrentValue = false, Callback = function(v) Config.AutoAscend = v end })
AutoPowerToggle = MainTab:CreateToggle({ Name = "Auto Power Level", CurrentValue = false, Callback = function(v) Config.AutoPower = v end })
AutoPlotsToggle = MainTab:CreateToggle({ Name = "Auto Plots (plantar/colher/desbloquear)", CurrentValue = false, Callback = function(v) Config.AutoPlots = v end })
AutoEatFruitToggle = MainTab:CreateToggle({ Name = "Auto Eat Fruit", CurrentValue = false, Callback = function(v) Config.AutoEatFruit = v end })
AutoSellFruitsToggle = MainTab:CreateToggle({ Name = "Auto Sell Fruits", CurrentValue = false, Callback = function(v) Config.AutoSellFruits = v end })

--// Tab Bonus
AutoPhoneToggle = BonusTab:CreateToggle({ Name = "Auto Phone Offer", CurrentValue = false, Callback = function(v) Config.AutoPhone = v end })
AutoOfflineToggle = BonusTab:CreateToggle({ Name = "Auto Double Offline Cash", CurrentValue = false, Callback = function(v) Config.AutoOffline = v end })
AutoTimeToggle = BonusTab:CreateToggle({ Name = "Auto Time Cash", CurrentValue = false, Callback = function(v) Config.AutoTime = v end })
AutoEarnerToggle = BonusTab:CreateToggle({ Name = "Auto Earner Boost", CurrentValue = false, Callback = function(v) Config.AutoEarner = v end })
BonusTab:CreateToggle({ Name = "Auto Minigame Race", CurrentValue = false, Callback = function(v) Config.AutoRace = v end })
BonusTab:CreateToggle({ Name = "Auto Minigame Trade", CurrentValue = false, Callback = function(v) Config.AutoTrade = v end })
AutoLeversToggle = BonusTab:CreateToggle({ Name = "Auto Levers + Vine", CurrentValue = false, Callback = function(v) Config.AutoLevers = v end })

--// Tab Misc
AntiAFKToggle = MiscTab:CreateToggle({ Name = "Anti-AFK", CurrentValue = false, Callback = function(v) Config.AntiAFK = v end })
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

MiscTab:CreateButton({ Name = "Debug: Escanear Parcelas (Orchard)", Callback = function()
    pcall(scanPlots)
    Rayfield:Notify({
        Title = "Debug Parcelas",
        Content = string.format("ProximityPrompts encontrados em Orchard/Plots: %d", #plotPrompts),
        Duration = 6,
    })
end })

-- Testa uma vez só (não repete sozinho) pra descobrir se o remote aceita
-- chamada sem argumento, sem arriscar gastar moeda repetidamente no caso
-- de estar comprando algo errado por engano.
MiscTab:CreateButton({ Name = "Debug: Testar BuyOrchardItems (1x, sem argumento)", Callback = function()
    local remote = GetRemote("BuyOrchardItems")
    if not remote then
        Rayfield:Notify({ Title = "Debug", Content = "Remote BuyOrchardItems não encontrado.", Duration = 5 })
        return
    end
    local ok, result = pcall(function() return remote:InvokeServer() end)
    Rayfield:Notify({
        Title = "Debug BuyOrchardItems",
        Content = ok and ("Sucesso! Retornou: " .. tostring(result)) or ("Erro: " .. tostring(result)),
        Duration = 10,
    })
end })

MiscTab:CreateButton({ Name = "Debug: Testar UnlockOrchard (1x, sem argumento)", Callback = function()
    local remote = GetRemote("UnlockOrchard")
    if not remote then
        Rayfield:Notify({ Title = "Debug", Content = "Remote UnlockOrchard não encontrado.", Duration = 5 })
        return
    end
    local ok, result = pcall(function() return remote:InvokeServer() end)
    Rayfield:Notify({
        Title = "Debug UnlockOrchard",
        Content = ok and ("Sucesso! Retornou: " .. tostring(result)) or ("Erro: " .. tostring(result)),
        Duration = 10,
    })
end })

MiscTab:CreateButton({ Name = "Debug: Escanear Frutas", Callback = function()
    pcall(scanFruits)
    local withDetector = #fruitCache
    local rawFruitParts = 0
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name:lower():find("fruit") then
            rawFruitParts += 1
        end
    end
    Rayfield:Notify({
        Title = "Debug Frutas",
        Content = string.format(
            "Partes com 'fruit' no nome: %d\nCom ClickDetector utilizável: %d",
            rawFruitParts, withDetector
        ),
        Duration = 8,
    })
end })

--// Tab Stats (dentro da própria janela, não sobrepõe nada)
local StatsTab = Window:CreateTab("Stats", 4483362458)
local StatsPanel = StatsTab:CreateParagraph({
    Title = "Contadores",
    Content = "Carregando...",
})

task.spawn(function()
    while true do
        task.wait(1)
        pcall(function()
            StatsPanel:Set({
                Title = "Contadores",
                Content = string.format(
                    "Cash: %d\nCompras: %d | Upgrades: %d | Frutas: %d\nRebirths: %d\nFrutas detectadas: %d | Parcelas detectadas: %d",
                    math.floor(GetCash()), Stats.buys, Stats.upgrades, Stats.fruit,
                    Stats.rebirths, #fruitCache, #plotPrompts
                ),
            })
        end)
    end
end)

--// Notificação Final
Rayfield:Notify({ Title = "ULTIMATE FARM", Content = "Carregado com sucesso!", Duration = 5 })
