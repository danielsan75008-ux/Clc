-- CoiledTom Hub | Target Attach System
-- Wind UI v2 | By CoiledTom

-- ═══════════════════════════════════
--  LOAD WindUI v2
-- ═══════════════════════════════════
local WindUI = loadstring(game:HttpGet(
    "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"
))()

-- ═══════════════════════════════════
--  SERVICES
-- ═══════════════════════════════════
local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

-- ═══════════════════════════════════
--  VARIÁVEIS GLOBAIS
-- ═══════════════════════════════════
TargetPlayer      = nil
AttachEnabled     = false
AutoAttackEnabled = false
DistanceValue     = 5
TweenSpeedValue   = 100
OrbitSpeedValue   = 1.5
SelectedPosition  = "Behind"
MovementMode      = "Teleport"

local orbitAngle = 0
local attachLoop = nil

-- ═══════════════════════════════════
--  HELPERS
-- ═══════════════════════════════════
local function getTarget()
    if TargetPlayer and TargetPlayer.Character then
        return TargetPlayer.Character:FindFirstChild("HumanoidRootPart")
    end
    return nil
end

-- ═══════════════════════════════════
--  MODOS DE MOVIMENTO
-- ═══════════════════════════════════
local function getBehindCF(targetHRP)
    local goalCF  = targetHRP.CFrame * CFrame.new(0, 0, DistanceValue)
    local lookDir = (targetHRP.Position - goalCF.Position).Unit
    return CFrame.lookAt(goalCF.Position, goalCF.Position + lookDir)
end

local function getOrbitTopCF(targetHRP, dt)
    orbitAngle = orbitAngle + OrbitSpeedValue * dt
    local x   = math.cos(orbitAngle) * DistanceValue
    local z   = math.sin(orbitAngle) * DistanceValue
    local pos = targetHRP.Position + Vector3.new(x, DistanceValue * 1.2, z)
    return CFrame.lookAt(pos, targetHRP.Position)
end

local function movePlayer(myHRP, goalCF)
    if MovementMode == "Teleport" then
        myHRP.CFrame = goalCF
    else
        local t = TweenService:Create(
            myHRP,
            TweenInfo.new(1 / TweenSpeedValue, Enum.EasingStyle.Linear),
            { CFrame = goalCF }
        )
        t:Play()
    end
end

-- ═══════════════════════════════════
--  AUTO ATTACK
-- ═══════════════════════════════════
local cachedPunchButton = nil

local function findPunchButton()
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not playerGui then return nil end
    for _, v in pairs(playerGui:GetDescendants()) do
        if v:IsA("GuiButton") and v.Name == "PunchButton" then
            return v
        end
    end
    return nil
end

local function fireButton(btn)
    pcall(function()
        -- 1) VirtualInputManager: simula MouseButton1Down + Up
        local vgui = game:GetService("VirtualInputManager")
        if vgui then
            local abs = btn.AbsolutePosition
            local sz  = btn.AbsoluteSize
            local cx  = abs.X + sz.X / 2
            local cy  = abs.Y + sz.Y / 2
            vgui:SendMouseButtonEvent(cx, cy, 0, true,  game, 1)
            vgui:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
        end
    end)
    pcall(function()
        -- 2) getconnections: dispara listeners diretamente
        if type(getconnections) == "function" then
            for _, c in pairs(getconnections(btn.MouseButton1Down))  do c:Fire() end
            for _, c in pairs(getconnections(btn.MouseButton1Up))    do c:Fire() end
            for _, c in pairs(getconnections(btn.MouseButton1Click)) do c:Fire() end
            for _, c in pairs(getconnections(btn.Activated))         do c:Fire() end
        end
    end)
    pcall(function()
        -- 3) Activate como fallback final
        btn:Activate()
    end)
end

-- ═══════════════════════════════════
--  LOOPS PRINCIPAIS
-- ═══════════════════════════════════
local function startAttachLoop()
    if attachLoop then attachLoop:Disconnect() end
    attachLoop = RunService.Heartbeat:Connect(function(dt)
        if not AttachEnabled then return end
        local targetHRP = getTarget()
        if not targetHRP then return end
        local char = LocalPlayer.Character
        if not char then return end
        local myHRP = char:FindFirstChild("HumanoidRootPart")
        if not myHRP then return end
        local goalCF
        if SelectedPosition == "Behind" then
            goalCF = getBehindCF(targetHRP)
        elseif SelectedPosition == "OrbitTop" then
            goalCF = getOrbitTopCF(targetHRP, dt)
        end
        if goalCF then movePlayer(myHRP, goalCF) end
    end)
end

local function startAutoAttack()
    task.spawn(function()
        while true do
            task.wait() -- roda a cada frame
            if AutoAttackEnabled then
                if not cachedPunchButton or not cachedPunchButton.Parent then
                    cachedPunchButton = findPunchButton()
                end
                if cachedPunchButton then
                    fireButton(cachedPunchButton)
                end
            end
        end
    end)
end

startAttachLoop()
startAutoAttack()

-- ═══════════════════════════════════
--  WINDOW
-- ═══════════════════════════════════
local Window = WindUI:CreateWindow({
    Title       = "CoiledTom Hub",
    Icon        = "solar:planet-bold",
    Author      = "by CoiledTom",
    Folder      = "CoiledTomHub",
    Size        = UDim2.fromOffset(580, 480),
    Theme       = "Dark",
    Transparent = true,
})

local TabAttach = Window:Tab({ Title = "Target Attach", Icon = "solar:crosshairs-bold" })
local TabWin    = Window:Tab({ Title = "eu consegui 😌",  Icon = "solar:star-bold"     })

-- ══════════════════════════════════════════════════════
--  ABA: TARGET ATTACH
-- ══════════════════════════════════════════════════════
do
    -- ── Player Selection ──────────────────────────────
    TabAttach:Section({ Title = "Player Selection" })

    local function getPlayerNames()
        local names = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                table.insert(names, p.Name)
            end
        end
        if #names == 0 then table.insert(names, "(Nenhum player)") end
        return names
    end

    local playerDropdown
    local function refreshDropdown()
        pcall(function() playerDropdown:Refresh(getPlayerNames()) end)
    end

    playerDropdown = TabAttach:Dropdown({
        Title    = "Select Target",
        Desc     = "Escolha o player alvo",
        Values   = getPlayerNames(),
        Callback = function(selected)
            if selected ~= "(Nenhum player)" then
                TargetPlayer = Players:FindFirstChild(selected) or nil
                WindUI:Notify({ Title = "Target", Content = "Alvo: " .. tostring(selected), Duration = 2 })
            else
                TargetPlayer = nil
            end
        end,
    })

    task.defer(function() task.wait(1); pcall(refreshDropdown) end)
    Players.PlayerAdded:Connect(function() task.wait(0.5); pcall(refreshDropdown) end)
    Players.PlayerRemoving:Connect(function(p)
        if p == TargetPlayer then TargetPlayer = nil; AttachEnabled = false end
        task.wait(0.5); pcall(refreshDropdown)
    end)

    TabAttach:Button({
        Title    = "Atualizar Lista",
        Icon     = "solar:refresh-bold",
        Desc     = "Recarrega os players disponiveis",
        Callback = function()
            pcall(refreshDropdown)
            WindUI:Notify({ Title = "Players", Content = "Lista atualizada!", Duration = 2 })
        end,
    })

    TabAttach:Button({
        Title    = "Anti Bug",
        Icon     = "solar:bug-bold",
        Desc     = "Clique em mim se estiver bugado",
        Callback = function()
            pcall(refreshDropdown)
            WindUI:Notify({ Title = "Anti Bug", Content = "Lista corrigida!", Duration = 2 })
        end,
    })

    -- ── Position Mode ─────────────────────────────────
    TabAttach:Section({ Title = "Position Mode" })

    TabAttach:Dropdown({
        Title    = "Position Type",
        Desc     = "Behind = atras | OrbitTop = orbita em cima",
        Values   = { "Behind", "OrbitTop" },
        Callback = function(selected)
            SelectedPosition = tostring(selected)
            orbitAngle = 0
        end,
    })

    -- ── Movement Mode ─────────────────────────────────
    TabAttach:Section({ Title = "Movement Mode" })

    TabAttach:Dropdown({
        Title    = "Move Type",
        Desc     = "Teleport = instantaneo | Tween = suave",
        Values   = { "Teleport", "Tween" },
        Callback = function(selected)
            MovementMode = tostring(selected)
            WindUI:Notify({ Title = "Movement Mode", Content = "Modo: " .. tostring(selected), Duration = 2 })
        end,
    })

    -- ── Movement Settings ─────────────────────────────
    TabAttach:Section({ Title = "Movement Settings" })

    TabAttach:Slider({
        Title = "Distance",
        Desc  = "Distancia ate o alvo (studs)",
        Step  = 1,
        Value = { Min = 1, Max = 30, Default = 5 },
        Callback = function(v) DistanceValue = v end,
    })

    TabAttach:Slider({
        Title = "Tween Speed",
        Desc  = "Velocidade do Tween (so ativo no modo Tween)",
        Step  = 1,
        Value = { Min = 1, Max = 1000, Default = 100 },
        Callback = function(v) TweenSpeedValue = v end,
    })

    TabAttach:Slider({
        Title = "Orbit Speed",
        Desc  = "Velocidade de rotacao no modo OrbitTop",
        Step  = 1,
        Value = { Min = 1, Max = 10, Default = 3 },
        Callback = function(v) OrbitSpeedValue = v * 0.5 end,
    })

    -- ── Controls ──────────────────────────────────────
    TabAttach:Section({ Title = "Controls" })

    TabAttach:Toggle({
        Title = "Toggle Attach",
        Desc  = "Ativa movimentacao relativa ao alvo",
        Value = false,
        Callback = function(v)
            AttachEnabled = v
            WindUI:Notify({
                Title   = "Attach",
                Content = v and "Attach ATIVADO!" or "Attach desativado.",
                Duration = 2,
            })
        end,
    })

    TabAttach:Toggle({
        Title = "Auto Attack",
        Desc  = "Clica PunchButton em loop automaticamente",
        Value = false,
        Callback = function(v)
            AutoAttackEnabled = v
            if v then cachedPunchButton = nil end
            WindUI:Notify({
                Title   = "Auto Attack",
                Content = v and "Auto Attack ATIVADO!" or "Auto Attack desativado.",
                Duration = 2,
            })
        end,
    })
end

-- ══════════════════════════════════════════════════════
--  ABA: EU CONSEGUI 😌
-- ══════════════════════════════════════════════════════
do
    TabWin:Section({ Title = "Missao Cumprida!" })
    TabWin:Section({ Title = "O Target Attach esta funcionando. Bom jogo! 😌" })
    TabWin:Section({ Title = "Creditos" })
    TabWin:Section({ Title = "Script: CoiledTom | UI: Wind UI v2 by Footagesus" })

    TabWin:Button({
        Title    = "Fechar aviso",
        Icon     = "solar:check-circle-bold",
        Desc     = "Fechar esta mensagem",
        Callback = function()
            WindUI:Notify({ Title = "CoiledTom Hub", Content = "Pronto! Bom jogo 😌", Duration = 3 })
        end,
    })
end

-- ══════════════════════════════════════════════════════
--  NOTIFICACAO INICIAL
-- ══════════════════════════════════════════════════════
WindUI:Notify({
    Title    = "CoiledTom Hub",
    Content  = "Target Attach carregado com sucesso!",
    Duration = 4,
})
