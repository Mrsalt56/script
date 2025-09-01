-- 99 Nights in the Forest — Xeno-Compatible Rewrite (No Rayfield)
-- Single-file GUI using Roblox instances only.
-- Tested for basic compatibility with limited executors.
-- NOTE: Some features (Kill Aura / Auto Chop) depend on game-specific RemoteEvents/Functions.
--       This script tries to auto-detect common remotes safely (pcall) and will fail gracefully if not found.

--// Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local LP = Players.LocalPlayer
local Char = LP.Character or LP.CharacterAdded:Wait()
local Hum = Char:WaitForChild("Humanoid")
local HRP = Char:WaitForChild("HumanoidRootPart")

--// Helpers
local function notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {Title = title, Text = text, Duration = duration or 4})
    end)
end

local function safeFindModelPrimaryCFrame(obj)
    if not obj then return end
    if obj:IsA("Model") then
        local primary = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
        if primary then return primary.CFrame end
    elseif obj:IsA("BasePart") then
        return obj.CFrame
    end
end

local function safePivotTo(obj, cframe)
    if not obj or not cframe then return false end
    local ok = false
    if obj:IsA("Model") and obj.PivotTo then
        ok = pcall(function() obj:PivotTo(cframe) end)
    elseif obj:IsA("BasePart") then
        ok = pcall(function() obj.CFrame = cframe end)
    end
    return ok
end

local function distance(a, b)
    return (a.Position - b.Position).Magnitude
end

local function getAllDescendantsSafe(container)
    local list = {}
    for _, d in ipairs(container:GetDescendants()) do
        table.insert(list, d)
    end
    return list
end

local function setClipboard(text)
    -- Only available in some executors
    if setclipboard then
        pcall(setclipboard, text)
        notify("Copied", "Copied to clipboard.", 3)
    else
        notify("Clipboard not supported", text, 6)
    end
end

--// GUI Factory
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "NightsLiteGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = game.CoreGui

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 560, 0, 380)
Main.Position = UDim2.new(0.06, 0, 0.2, 0)
Main.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
Main.BorderSizePixel = 0
Main.Parent = ScreenGui

local UICorner = Instance.new("UICorner", Main)
UICorner.CornerRadius = UDim.new(0, 10)

-- Dragging
do
    local dragging, dragStart, startPos
    Main.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = Main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- TitleBar
local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -120, 0, 36)
Title.Position = UDim2.new(0, 12, 0, 8)
Title.BackgroundTransparency = 1
Title.Text = "99 Nights — Lite"
Title.Font = Enum.Font.GothamBold
Title.TextSize = 20
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.TextColor3 = Color3.new(1,1,1)
Title.Parent = Main

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 100, 0, 28)
CloseBtn.Position = UDim2.new(1, -108, 0, 10)
CloseBtn.Text = "Unload"
CloseBtn.TextColor3 = Color3.new(1,1,1)
CloseBtn.Font = Enum.Font.GothamSemibold
CloseBtn.TextSize = 14
CloseBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
CloseBtn.AutoButtonColor = true
CloseBtn.Parent = Main
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0,6)
CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)

-- Tab buttons
local Tabs = Instance.new("Frame", Main)
Tabs.Size = UDim2.new(0, 120, 1, -52)
Tabs.Position = UDim2.new(0, 12, 0, 44)
Tabs.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
Tabs.BorderSizePixel = 0
Instance.new("UICorner", Tabs).CornerRadius = UDim.new(0, 8)

local Pages = Instance.new("Frame", Main)
Pages.Size = UDim2.new(1, -156, 1, -52)
Pages.Position = UDim2.new(0, 144, 0, 44)
Pages.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
Pages.BorderSizePixel = 0
Instance.new("UICorner", Pages).CornerRadius = UDim.new(0, 8)

local function createPage(name)
    local sf = Instance.new("ScrollingFrame")
    sf.Name = name
    sf.BackgroundTransparency = 1
    sf.Size = UDim2.new(1, -16, 1, -16)
    sf.Position = UDim2.new(0, 8, 0, 8)
    sf.CanvasSize = UDim2.new(0, 0, 0, 0)
    sf.ScrollBarThickness = 6
    sf.Visible = false
    sf.Parent = Pages
    local layout = Instance.new("UIListLayout", sf)
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    return sf, layout
end

local function createTab(name, page)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -16, 0, 30)
    btn.Position = UDim2.new(0, 8, 0, 0)
    btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Text = name
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 14
    btn.AutoButtonColor = true
    btn.Parent = Tabs
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)
    btn.MouseButton1Click:Connect(function()
        for _, p in ipairs(Pages:GetChildren()) do
            if p:IsA("ScrollingFrame") then p.Visible = false end
        end
        page.Visible = true
    end)
end

local function sectionLabel(text, parent)
    local lb = Instance.new("TextLabel")
    lb.Size = UDim2.new(1, -16, 0, 26)
    lb.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
    lb.TextColor3 = Color3.fromRGB(200,200,200)
    lb.TextXAlignment = Enum.TextXAlignment.Left
    lb.Font = Enum.Font.GothamSemibold
    lb.TextSize = 14
    lb.Text = "  "..text
    lb.Parent = parent
    Instance.new("UICorner", lb).CornerRadius = UDim.new(0, 6)
end

local function makeButton(text, parent, callback)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -16, 0, 32)
    b.BackgroundColor3 = Color3.fromRGB(60,60,60)
    b.TextColor3 = Color3.new(1,1,1)
    b.Text = text
    b.Font = Enum.Font.Gotham
    b.TextSize = 14
    b.Parent = parent
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,6)
    b.MouseButton1Click:Connect(function()
        pcall(callback)
    end)
    return b
end

local function makeToggle(text, parent, default, onChanged)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, -16, 0, 32)
    holder.BackgroundColor3 = Color3.fromRGB(36,36,36)
    holder.Parent = parent
    Instance.new("UICorner", holder).CornerRadius = UDim.new(0,6)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -60, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextColor3 = Color3.new(1,1,1)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 14
    lbl.Text = text
    lbl.Parent = holder

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 50, 0, 24)
    btn.Position = UDim2.new(1, -58, 0.5, -12)
    btn.BackgroundColor3 = default and Color3.fromRGB(0,170,90) or Color3.fromRGB(90,90,90)
    btn.Text = default and "ON" or "OFF"
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.Parent = holder
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)

    local value = default or false
    btn.MouseButton1Click:Connect(function()
        value = not value
        btn.Text = value and "ON" or "OFF"
        btn.BackgroundColor3 = value and Color3.fromRGB(0,170,90) or Color3.fromRGB(90,90,90)
        pcall(onChanged, value)
    end)

    return function() return value end, function(v)
        value = v and true or false
        btn.Text = value and "ON" or "OFF"
        btn.BackgroundColor3 = value and Color3.fromRGB(0,170,90) or Color3.fromRGB(90,90,90)
        pcall(onChanged, value)
    end
end

local function makeTextBox(label, parent, placeholder, onSubmit)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, -16, 0, 32)
    holder.BackgroundColor3 = Color3.fromRGB(36,36,36)
    holder.Parent = parent
    Instance.new("UICorner", holder).CornerRadius = UDim.new(0,6)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.35, -10, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextColor3 = Color3.new(1,1,1)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 14
    lbl.Text = label
    lbl.Parent = holder

    local tb = Instance.new("TextBox")
    tb.Size = UDim2.new(0.65, -10, 0, 24)
    tb.Position = UDim2.new(0.35, 0, 0.5, -12)
    tb.BackgroundColor3 = Color3.fromRGB(60,60,60)
    tb.TextColor3 = Color3.new(1,1,1)
    tb.Font = Enum.Font.Gotham
    tb.TextSize = 14
    tb.ClearTextOnFocus = false
    tb.PlaceholderText = placeholder or ""
    tb.Parent = holder
    Instance.new("UICorner", tb).CornerRadius = UDim.new(0,6)

    tb.FocusLost:Connect(function(enter)
        if enter then pcall(onSubmit, tb.Text) end
    end)
    return tb
end

local function makeNumberBox(label, parent, default, onChanged)
    local tb = makeTextBox(label, parent, tostring(default or 0), function(text)
        local n = tonumber(text)
        if n then pcall(onChanged, n) else notify("Invalid number", "Enter a valid number", 3) end
    end)
    tb.Text = tostring(default or 0)
    return tb
end

-- Create pages
local pagePlayer = createPage("Player")
local pageESP = createPage("ESP")
local pageGame = createPage("Game")
local pageBring = createPage("Bring")
local pageTP = createPage("Teleport")
local pageDiscord = createPage("Discord")
local pageSettings = createPage("Settings")

-- Create tabs
createTab("Player", pagePlayer)
createTab("ESP", pageESP)
createTab("Game", pageGame)
createTab("Bring", pageBring)
createTab("TP", pageTP)
createTab("Discord", pageDiscord)
createTab("Settings", pageSettings)

pagePlayer.Visible = true

--// PLAYER PAGE
sectionLabel("Movement", pagePlayer)

-- Noclip
local noclipConn
local _, setNoclip = makeToggle("Noclip", pagePlayer, false, function(state)
    if state then
        noclipConn = RunService.Stepped:Connect(function()
            local c = LP.Character
            if c then
                for _, v in ipairs(c:GetDescendants()) do
                    if v:IsA("BasePart") then v.CanCollide = false end
                end
            end
        end)
    else
        if noclipConn then noclipConn:Disconnect() end
    end
end)

-- Infinite Jump
local ijConn
local _, setIJ = makeToggle("Infinite Jump", pagePlayer, false, function(state)
    if state then
        ijConn = UIS.JumpRequest:Connect(function()
            local c = LP.Character
            if c then
                local h = c:FindFirstChildOfClass("Humanoid")
                if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
            end
        end)
    else
        if ijConn then ijConn:Disconnect() end
    end
end)

-- WalkSpeed
local currentSpeed = 16
sectionLabel("Speed", pagePlayer)
makeNumberBox("WalkSpeed", pagePlayer, 16, function(n)
    currentSpeed = math.clamp(n, 8, 200)
    if Hum then Hum.WalkSpeed = currentSpeed end
end)
makeButton("Apply WalkSpeed", pagePlayer, function()
    if LP.Character and LP.Character:FindFirstChildOfClass("Humanoid") then
        LP.Character:FindFirstChildOfClass("Humanoid").WalkSpeed = currentSpeed
        notify("WalkSpeed", "Set to "..tostring(currentSpeed), 3)
    end
end)

-- Fly
sectionLabel("Fly", pagePlayer)
local flyEnabled = false
local flyBV, flyConn
makeButton("Toggle Fly (WASD + Space/CTRL)", pagePlayer, function()
    flyEnabled = not flyEnabled
    if flyEnabled then
        local c = LP.Character or LP.CharacterAdded:Wait()
        local hrp = c:WaitForChild("HumanoidRootPart")
        flyBV = Instance.new("BodyVelocity")
        flyBV.MaxForce = Vector3.new(1e9,1e9,1e9)
        flyBV.Velocity = Vector3.new()
        flyBV.Parent = hrp
        local speed = 80
        flyConn = RunService.RenderStepped:Connect(function()
            if hrp and flyBV then
                local cam = workspace.CurrentCamera
                local dir = Vector3.new()
                if UIS:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
                if UIS:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
                if UIS:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
                if UIS:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
                if UIS:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0,1,0) end
                if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir + Vector3.new(0,-1,0) end
                if dir.Magnitude > 0 then dir = dir.Unit end
                flyBV.Velocity = dir * speed
            end
        end)
        notify("Fly", "Enabled", 3)
    else
        if flyConn then flyConn:Disconnect() end
        if flyBV then flyBV:Destroy() end
        notify("Fly", "Disabled", 3)
    end
end)

-- Teleport shortcuts
sectionLabel("Teleport", pageTP)
makeButton("Teleport to (Guess) Campfire", pageTP, function()
    local target = workspace:FindFirstChild("Map")
        and workspace.Map:FindFirstChild("Campground")
        and workspace.Map.Campground:FindFirstChild("MainFire")
    if target and target.PrimaryPart then
        LP.Character:WaitForChild("HumanoidRootPart").CFrame = target.PrimaryPart.CFrame + Vector3.new(0, 5, 0)
    else
        notify("Not found", "Could not find Campfire path", 4)
    end
end)

makeTextBox("Teleport to Part/Model by Name", pageTP, "Enter exact name", function(name)
    if not name or name == "" then return end
    local found = workspace:FindFirstChild(name, true)
    if found then
        local cf = safeFindModelPrimaryCFrame(found)
        if cf then
            LP.Character:WaitForChild("HumanoidRootPart").CFrame = cf + Vector3.new(0, 5, 0)
            notify("Teleported", name, 3)
        else
            notify("No CFrame", "Target has no BasePart", 4)
        end
    else
        notify("Not found", "No instance named "..name, 3)
    end
end)

--// ESP PAGE (Billboard-based for compatibility)
sectionLabel("ESP Options", pageESP)
local espEnabledItems = false
local espEnabledEnemies = false
local espEnabledChildren = false
local espShowDistance = true
local espNameFilter = ""

local function createBillboard(target, text)
    local part
    if target:IsA("Model") then
        part = target:FindFirstChild("Head") or target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart")
    elseif target:IsA("BasePart") then
        part = target
    end
    if not part then return end
    if part:FindFirstChild("NightsESP") then return end

    local bb = Instance.new("BillboardGui")
    bb.Name = "NightsESP"
    bb.Size = UDim2.new(0, 200, 0, 40)
    bb.AlwaysOnTop = true
    bb.Adornee = part
    bb.Parent = part

    local tl = Instance.new("TextLabel", bb)
    tl.BackgroundTransparency = 1
    tl.Size = UDim2.new(1, 0, 1, 0)
    tl.TextColor3 = Color3.new(1,1,1)
    tl.TextStrokeTransparency = 0.5
    tl.Font = Enum.Font.GothamBold
    tl.TextScaled = true
    tl.Text = text or target.Name

    return bb, tl, part
end

local function clearESP(container)
    for _, d in ipairs(container:GetDescendants()) do
        if d:IsA("BillboardGui") and d.Name == "NightsESP" then
            d:Destroy()
        end
    end
end

local function matchesFilter(obj, filter)
    if filter == "" then return true end
    return string.find(string.lower(obj.Name), string.lower(filter), 1, true) ~= nil
end

local function isEnemyLike(obj)
    local n = string.lower(obj.Name)
    return n:find("enemy") or n:find("monster") or n:find("bandit") or n:find("wolf") or n:find("bear")
end

local function isChildNPC(obj)
    local n = string.lower(obj.Name)
    return n:find("child") or n:find("kid") or n:find("lost")
end

local function isItemLike(obj)
    local n = string.lower(obj.Name)
    return n:find("coin") or n:find("log") or n:find("ammo") or n:find("gun") or n:find("med") or n:find("bandage") or n:find("carrot") or n:find("scrap") or n:find("fuel")
end

local function updateESP()
    if not (espEnabledItems or espEnabledEnemies or espEnabledChildren) then
        clearESP(workspace)
        return
    end
    local myHRP = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") or obj:IsA("BasePart") then
            if matchesFilter(obj, espNameFilter) then
                local want = false
                if espEnabledItems and isItemLike(obj) then want = true end
                if espEnabledEnemies and isEnemyLike(obj) then want = true end
                if espEnabledChildren and isChildNPC(obj) then want = true end
                if want then
                    local bb, tl, part = createBillboard(obj, obj.Name)
                    if bb and tl and myHRP and espShowDistance then
                        local d = 0
                        pcall(function() d = math.floor(distance(part, myHRP)) end)
                        tl.Text = obj.Name .. " ["..tostring(d).."m]"
                    end
                end
            end
        end
    end
end

local _, setESPItems = makeToggle("Items ESP", pageESP, false, function(v)
    espEnabledItems = v; if not v then clearESP(workspace) end
end)
local _, setESPEnemies = makeToggle("Enemies ESP", pageESP, false, function(v)
    espEnabledEnemies = v; if not v then clearESP(workspace) end
end)
local _, setESPChildren = makeToggle("Children NPC ESP", pageESP, false, function(v)
    espEnabledChildren = v; if not v then clearESP(workspace) end
end)
local _, setESPDist = makeToggle("Show Distance", pageESP, true, function(v) espShowDistance = v end)
makeTextBox("Name Filter (optional)", pageESP, "e.g. coin / log / wolf", function(txt)
    espNameFilter = txt or ""
    clearESP(workspace)
end)

RunService.RenderStepped:Connect(function()
    pcall(updateESP)
end)

--// GAME PAGE (Kill Aura, Auto Chop Tree)
sectionLabel("Combat / Farming", pageGame)

-- Remote finder
local candidateRemoteNames = {"ToolDamageObject", "Damage", "Hit", "Swing", "Attack", "DealDamage"}
local function findCombatRemote()
    for _, name in ipairs(candidateRemoteNames) do
        local r = ReplicatedStorage:FindFirstChild(name, true)
        if r and (r:IsA("RemoteFunction") or r:IsA("RemoteEvent")) then
            return r
        end
    end
end

local function tryDamage(remote, target)
    if not remote or not target then return end
    local ok = pcall(function()
        if remote:IsA("RemoteFunction") then
            remote:InvokeServer(target)
        else
            remote:FireServer(target)
        end
    end)
    return ok
end

-- Kill Aura
local KAEnabled = false
local KADistance = 20
makeNumberBox("Kill Aura Distance", pageGame, 20, function(n) KADistance = math.clamp(n, 5, 100) end)
local KAConn
local _, setKA = makeToggle("Kill Aura", pageGame, false, function(state)
    KAEnabled = state
    if state then
        local remote = findCombatRemote()
        if not remote then
            notify("Kill Aura", "No combat remote found. Will still try.", 4)
        end
        KAConn = RunService.Heartbeat:Connect(function()
            if not KAEnabled then return end
            local my = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            if not my then return end
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("Model") then
                    if isEnemyLike(obj) then
                        local part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                        if part and distance(part, my) <= KADistance then
                            if remote then tryDamage(remote, obj) end
                        end
                    end
                end
            end
        end)
    else
        if KAConn then KAConn:Disconnect() end
    end
end)

-- Auto Chop Tree
local ACEnabled = false
local ACRadius = 30
makeNumberBox("Auto Chop Radius", pageGame, 30, function(n) ACRadius = math.clamp(n, 5, 120) end)
local ACConn
local _, setAC = makeToggle("Auto Chop Trees", pageGame, false, function(state)
    ACEnabled = state
    if state then
        local remote = findCombatRemote()
        if not remote then
            notify("Auto Chop", "No suitable remote found. Will still try.", 4)
        end
        ACConn = RunService.Heartbeat:Connect(function()
            if not ACEnabled then return end
            local my = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            if not my then return end
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("Model") and string.lower(obj.Name):find("tree") then
                    local part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                    if part and distance(part, my) <= ACRadius then
                        if remote then tryDamage(remote, obj) end
                    end
                end
            end
        end)
    else
        if ACConn then ACConn:Disconnect() end
    end
end)

--// BRING PAGE
sectionLabel("Bring Items / NPCs", pageBring)
local function bringByPredicate(pred, limit)
    local count = 0
    local mycf = HRP.CFrame
    for _, d in ipairs(workspace:GetDescendants()) do
        if (d:IsA("Model") or d:IsA("BasePart")) and pred(d) then
            if safePivotTo(d, mycf + Vector3.new(0, 3 + (count%5)*2, 3)) then
                count = count + 1
                if limit and count >= limit then break end
            end
        end
    end
    notify("Bring", "Brought "..tostring(count).." objects.", 4)
end

makeButton("Bring: All Coins", pageBring, function()
    bringByPredicate(function(o) return string.lower(o.Name):find("coin") end, 100)
end)
makeButton("Bring: Logs", pageBring, function()
    bringByPredicate(function(o) return string.lower(o.Name):find("log") end, 50)
end)
makeButton("Bring: Ammo", pageBring, function()
    bringByPredicate(function(o) return string.lower(o.Name):find("ammo") end, 50)
end)
makeButton("Bring: Guns", pageBring, function()
    bringByPredicate(function(o) return string.lower(o.Name):find("gun") end, 20)
end)
makeButton("Bring: Medkits/Bandages", pageBring, function()
    bringByPredicate(function(o) local n=string.lower(o.Name); return n:find("med") or n:find("bandage") end, 30)
end)
makeButton("Bring: Fuel/Coal", pageBring, function()
    bringByPredicate(function(o) local n=string.lower(o.Name); return n:find("fuel") or n:find("coal") end, 40)
end)
makeButton("Bring: Children NPCs", pageBring, function()
    bringByPredicate(function(o) return isChildNPC(o) end, 20)
end)
makeButton("Bring: Scraps", pageBring, function()
    bringByPredicate(function(o) local n=string.lower(o.Name); return n:find("scrap") or n:find("tyre") or n:find("sheet") or n:find("radio") end, 60)
end)

makeTextBox("Bring by Exact Name", pageBring, "Enter name", function(txt)
    if not txt or txt == "" then return end
    bringByPredicate(function(o) return o.Name == txt end, nil)
end)

--// DISCORD PAGE
sectionLabel("Share / Discord", pageDiscord)
makeButton("Copy Invite (example)", pageDiscord, function()
    setClipboard("https://discord.gg/yourinvite")
end)

--// SETTINGS
sectionLabel("UI", pageSettings)
makeButton("Unload GUI", pageSettings, function()
    ScreenGui:Destroy()
end)

-- Info section
sectionLabel("Info", pageSettings)
makeButton("Server Info to Console", pageSettings, function()
    local placeId = game.PlaceId
    local jobId = game.JobId
    local studio = tostring(game:GetService("RunService"):IsStudio())
    local count = #Players:GetPlayers()
    print(("[NightsLite] PlaceId=%s | JobId=%s | Studio=%s | Players=%d"):format(placeId, jobId, studio, count))
    notify("Server Info", "Printed to F9 console.", 4)
end)

notify("99 Nights — Lite", "GUI loaded. Use tabs on the left.", 5)
