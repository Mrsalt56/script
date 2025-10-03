-- Auto Pet Seller & Buyer - One Click Farm Script
-- Automatically enables all features for farming

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Configuration
local CONFIG = {
    MIN_WEIGHT_TO_KEEP = 300, -- Минимальный вес for сохранения пета
    MAX_WEIGHT_TO_KEEP = 50000, -- Максимальный вес for сохранения пета
    SELL_DELAY = 0.01, -- Задержка между продажами
    BUY_DELAY = 0.01, -- Задержка между покупками
    BUY_INTERVAL = 2, -- Интервал между циклами покупки (секунды)
    COLLECT_INTERVAL = 60, -- Интервал сбора монет (секунды)
    REPLACE_INTERVAL = 30, -- Интервал замены брейнротов (секунды)
    PLANT_INTERVAL = 10, -- Интервал посадки plants (секунды)
    WATER_INTERVAL = 5, -- Интервал полива plants (секунды)
    PLATFORM_BUY_INTERVAL = 120, -- Интервал покупки platforms (секунды)
    LOG_COPY_KEY = Enum.KeyCode.F4, -- Клавиша for копирования логов
    AUTO_BUY_SEEDS = true, -- Auto-buy seeds
    AUTO_BUY_GEAR = true, -- Auto-buy gear
    AUTO_COLLECT_COINS = true, -- Авто-сбор монет
    AUTO_REPLACE_BRAINROTS = true, -- Авто-замена брейнротов
    AUTO_PLANT_SEEDS = true, -- Авто-посадка seeds
    AUTO_WATER_PLANTS = true, -- Авто-полив plants
    AUTO_BUY_PLATFORMS = true, -- Авто-покупка platforms
    DEBUG_COLLECT_COINS = true, -- Отладочные сообщения for сбора монет
    DEBUG_PLANTING = true, -- Отладочные сообщения for посадки
    SMART_SELLING = true, -- Умная система продажи (адаптивная)
}

-- Pet rarities in ascending order
local RARITY_ORDER = {
    ["Rare"] = 1,
    ["Epic"] = 2,
    ["Legendary"] = 3,
    ["Mythic"] = 4,
    ["Godly"] = 5,
    ["Secret"] = 6,
    ["Limited"] = 7
}

-- Variables
local logs = {}
local itemSellRemote = nil
local dataRemoteEvent = nil
local useItemRemote = nil
local openEggRemote = nil
local playerData = nil
local protectedPet = nil -- Защищенный от продажи пет (in руке for замены)
local petAnalysis = nil -- Analyze current pet state
local currentPlot = nil -- Текущий плот игрока
local plantedSeeds = {} -- Отслеживание посаженных seeds
local diagnosticsRun = false -- Флаг for запуска диагностики

-- Codes to enter
local CODES = {
    "based",
    "stacks",
    "frozen"
}

-- Seeds to buy
local SEEDS = {
    "Cactus Seed",
    "Strawberry Seed", 
    "Sunflower Seed",
    "Pumpkin Seed",
    "Dragon Fruit Seed",
    "Eggplant Seed",
    "Watermelon Seed",
    "Grape Seed",
    "Cocotank Seed",
    "Carnivorous Plant Seed",
    "Mr Carrot Seed",
    "Tomatrio Seed",
    "Shroombino Seed"
}

-- Items from Gear Shop
local GEAR_ITEMS = {
    "Water Bucket",
    "Frost Blower",
    "Frost Grenade",
    "Carrot Launcher",
    "Banana Gun"
}

-- Protected items (do not sell)
local PROTECTED_ITEMS = {
    "Meme Lucky Egg",
    "Godly Lucky Egg",
    "Secret Lucky Egg"
}


-- Initialization
local function initialize()
    print("Initializing Auto Pet Seller & Buyer...")
    
    -- Waiting for required services
    itemSellRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ItemSell")
    dataRemoteEvent = ReplicatedStorage:WaitForChild("BridgeNet2"):WaitForChild("dataRemoteEvent")
    useItemRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("UseItem")
    openEggRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("OpenEgg")
    
    -- Инициализируем PlayerData
    local success, result = pcall(function()
        playerData = require(ReplicatedStorage:WaitForChild("PlayerData"))
    end)
    
    if success then
        print("✅ ✅ PlayerData initialized successfully")
    else
        print("❌ ❌ Error initializing PlayerData: " .. tostring(result))
        playerData = nil
    end
    
    -- Getting current plot
    local plotNumber = LocalPlayer:GetAttribute("Plot")
    if plotNumber then
        currentPlot = workspace.Plots:FindFirstChild(tostring(plotNumber))
        if currentPlot then
            print("Found plot: " .. plotNumber)
        else
            print("Plot " .. plotNumber .. " not found in workspace.Plots")
        end
    else
        print("Plot attribute not found on player")
    end
    
    print("Initialization completed!")
end

-- Get pet weight from name
local function getPetWeight(petName)
    local weight = petName:match("%[(%d+%.?%d*)%s*kg%]")
    return weight and tonumber(weight) or 0
end

-- Get pet rarity
local function getPetRarity(pet)
    local petData = pet:FindFirstChild(pet.Name)
    if not petData then
        -- Пробуем найти по имени без веса and мутаций
        local cleanName = pet.Name:gsub("%[.*%]%s*", "")
        petData = pet:FindFirstChild(cleanName)
    end
    
    if not petData then
        -- Ищем любой дочерний объект with атрибутом Rarity
        for _, child in pairs(pet:GetChildren()) do
            if child:GetAttribute("Rarity") then
                petData = child
                break
            end
        end
    end
    
    if petData then
        return petData:GetAttribute("Rarity") or "Rare"
    end
    
    return "Rare"
end

-- Check protected mutations
local function hasProtectedMutations(petName)
    return petName:find("%[Neon%]") or petName:find("%[Galactic%]")
end

-- Check protected items
local function isProtectedItem(itemName)
    for _, protected in pairs(PROTECTED_ITEMS) do
        if itemName:find(protected) then
            return true
        end
    end
    return false
end

-- Get pet info
local function getPetInfo(pet)
    local petData = pet:FindFirstChild(pet.Name)
    if not petData then
        local cleanName = pet.Name:gsub("%[.*%]%s*", "")
        petData = pet:FindFirstChild(cleanName)
    end
    
    if not petData then
        for _, child in pairs(pet:GetChildren()) do
            if child:GetAttribute("Rarity") then
                petData = child
                break
            end
        end
    end
    
    -- Получаем MoneyPerSecond из UI
    local moneyPerSecond = 0
    if petData then
        local rootPart = petData:FindFirstChild("RootPart")
        if rootPart then
            local brainrotToolUI = rootPart:FindFirstChild("BrainrotToolUI")
            if brainrotToolUI then
                local moneyLabel = brainrotToolUI:FindFirstChild("Money")
                if moneyLabel then
                    -- Парсим MoneyPerSecond from текста типа "$1,234/s"
                    local moneyText = moneyLabel.Text
                    local moneyValue = moneyText:match("%$(%d+,?%d*)/s")
                    if moneyValue then
                        -- Убираем запятые and конвертируем in число
                        local cleanValue = moneyValue:gsub(",", "")
                        moneyPerSecond = tonumber(cleanValue) or 0
                    end
                end
            end
        end
    end
    
    if petData then
        return {
            name = pet.Name,
            weight = getPetWeight(pet.Name),
            rarity = petData:GetAttribute("Rarity") or "Rare",
            worth = petData:GetAttribute("Worth") or 0,
            size = petData:GetAttribute("Size") or 1,
            offset = petData:GetAttribute("Offset") or 0,
            moneyPerSecond = moneyPerSecond
        }
    end
    
    return {
        name = pet.Name,
        weight = getPetWeight(pet.Name),
        rarity = "Rare",
        worth = 0,
        size = 1,
        offset = 0,
        moneyPerSecond = moneyPerSecond
    }
end

-- Get best brainrot from inventory (for replacement)
local function getBestBrainrotForReplacement()
    local backpack = LocalPlayer:WaitForChild("Backpack")
    local bestBrainrot = nil
    local bestMoneyPerSecond = 0
    
    for _, pet in pairs(backpack:GetChildren()) do
        if pet:IsA("Tool") and pet.Name:match("%[%d+%.?%d*%s*kg%]") then
            local petInfo = getPetInfo(pet)
            local moneyPerSecond = petInfo.moneyPerSecond
            
            if moneyPerSecond > bestMoneyPerSecond then
                bestMoneyPerSecond = moneyPerSecond
                bestBrainrot = pet
            end
        end
    end
    
    return bestBrainrot, bestMoneyPerSecond
end

-- Analyze current pet state
local function analyzePets()
    local backpack = LocalPlayer:WaitForChild("Backpack")
    local analysis = {
        totalPets = 0,
        petsByRarity = {},
        petsByMoneyPerSecond = {},
        bestMoneyPerSecond = 0,
        worstMoneyPerSecond = math.huge,
        averageMoneyPerSecond = 0,
        totalMoneyPerSecond = 0,
        shouldSellRare = false,
        shouldSellEpic = false,
        shouldSellLegendary = false,
        minMoneyPerSecondToKeep = 0
    }
    
    -- Собираем данные о всех петах
    for _, pet in pairs(backpack:GetChildren()) do
        if pet:IsA("Tool") and pet.Name:match("%[%d+%.?%d*%s*kg%]") then
            local petInfo = getPetInfo(pet)
            local rarity = petInfo.rarity
            local moneyPerSecond = petInfo.moneyPerSecond
            
            analysis.totalPets = analysis.totalPets + 1
            analysis.totalMoneyPerSecond = analysis.totalMoneyPerSecond + moneyPerSecond
            
            -- Группируем по редкости
            if not analysis.petsByRarity[rarity] then
                analysis.petsByRarity[rarity] = 0
            end
            analysis.petsByRarity[rarity] = analysis.petsByRarity[rarity] + 1
            
            -- Отслеживаем лучший and худший MoneyPerSecond
            if moneyPerSecond > analysis.bestMoneyPerSecond then
                analysis.bestMoneyPerSecond = moneyPerSecond
            end
            if moneyPerSecond < analysis.worstMoneyPerSecond then
                analysis.worstMoneyPerSecond = moneyPerSecond
            end
            
            -- Группируем по MoneyPerSecond
            table.insert(analysis.petsByMoneyPerSecond, {
                pet = pet,
                moneyPerSecond = moneyPerSecond,
                rarity = rarity
            })
        end
    end
    
    -- Сортируем по MoneyPerSecond
    table.sort(analysis.petsByMoneyPerSecond, function(a, b)
        return a.moneyPerSecond > b.moneyPerSecond
    end)
    
    -- Вычисляем средний MoneyPerSecond
    if analysis.totalPets > 0 then
        analysis.averageMoneyPerSecond = analysis.totalMoneyPerSecond / analysis.totalPets
    end
    
    -- Smart logic to determine what to sell
    if analysis.totalPets > 0 then
        -- Если у нас мало pets (меньше 10), продаем только самых плохих
        if analysis.totalPets < 10 then
            analysis.minMoneyPerSecondToKeep = analysis.averageMoneyPerSecond * 0.5 -- Оставляем только лучшие 50%
            analysis.shouldSellRare = false
            analysis.shouldSellEpic = false
            analysis.shouldSellLegendary = false
        -- Если у нас среднее количество pets (10-20), начинаем продавать Rare
        elseif analysis.totalPets < 20 then
            analysis.minMoneyPerSecondToKeep = analysis.averageMoneyPerSecond * 0.7
            analysis.shouldSellRare = true
            analysis.shouldSellEpic = false
            analysis.shouldSellLegendary = false
        -- Если у нас много pets (20+), продаем Rare и Epic
        else
            analysis.minMoneyPerSecondToKeep = analysis.averageMoneyPerSecond * 0.8
            analysis.shouldSellRare = true
            analysis.shouldSellEpic = true
            analysis.shouldSellLegendary = false
        end
        
        -- Дополнительная проверка: if у нас is очень хорошие петы, можем продавать and Legendary
        if analysis.bestMoneyPerSecond > analysis.averageMoneyPerSecond * 2 then
            analysis.shouldSellLegendary = true
        end
        
        -- Специальная логика for мутаций: if у нас много pets with мутациями, можем продавать плохих
        local mutationPets = 0
        for _, petData in pairs(analysis.petsByMoneyPerSecond) do
            if hasProtectedMutations(petData.pet.Name) then
                mutationPets = mutationPets + 1
            end
        end
        
        -- Если у нас много pets with мутациями (больше 5), можем продавать плохих with мутациями
        if mutationPets > 5 then
            analysis.shouldSellEpic = true -- Разрешаем продавать Epic with мутациями
            if analysis.totalPets > 25 then
                analysis.shouldSellLegendary = true -- И Legendary тоже
            end
        end
    end
    
    return analysis
end

-- Determine if a pet should be sold (smart system)
local function shouldSellPet(pet)
    local petName = pet.Name
    local weight = getPetWeight(petName)
    local rarity = getPetRarity(pet)
    local rarityValue = RARITY_ORDER[rarity] or 0
    local petInfo = getPetInfo(pet)
    
    -- Не продаем защищенного пета (который in руке for замены)
    if protectedPet and pet == protectedPet then
        return false
    end
    
    -- Не продаем защищенные предметы
    if isProtectedItem(petName) then
        return false
    end
    
    -- Не продаем тяжелых pets
    if weight >= CONFIG.MIN_WEIGHT_TO_KEEP then
        return false
    end
    
    -- Не продаем высоких редкостей (Mythic and выше)
    if rarityValue > RARITY_ORDER["Legendary"] then
        return false
    end
    
    -- Если умная система отключена, используем старую логику
    if not CONFIG.SMART_SELLING then
        -- Старая логика: not продаем Legendary with мутациями and брейнротов with высоким MoneyPerSecond
        if rarity == "Legendary" and hasProtectedMutations(petName) then
            return false
        end
        if petInfo.moneyPerSecond > 100 then
            return false
        end
        return true
    end
    
    -- Умная система: используем анализ pets
    if not petAnalysis then
        petAnalysis = analyzePets()
    end
    
    -- Проверяем по MoneyPerSecond
    if petInfo.moneyPerSecond >= petAnalysis.minMoneyPerSecondToKeep then
        return false
    end
    
    -- Проверяем по редкости (только if анализ говорит, что можно продавать эту редкость)
    if rarity == "Rare" and not petAnalysis.shouldSellRare then
        return false
    elseif rarity == "Epic" and not petAnalysis.shouldSellEpic then
        return false
    elseif rarity == "Legendary" and not petAnalysis.shouldSellLegendary then
        return false
    end
    
    -- В умной системе НЕ защищаем мутации автоматически - пусть анализ решает
    -- Только if это очень редкие мутации (Neon/Galactic), тогда защищаем
    if hasProtectedMutations(petName) and (rarity == "Mythic" or rarity == "Godly" or rarity == "Secret") then
        return false
    end
    
    return true
end

-- Selling pet
local function sellPet(pet)
    local character = LocalPlayer.Character
    if not character then return false end
    
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then return false end
    
    -- Берем пета in руку перед продажей
    humanoid:EquipTool(pet)
    wait(0.1) -- Ждем пока пет возьмется in руку
    
    -- Продаем пета
    itemSellRemote:FireServer(pet)
    
    return true
end

-- Получение лучшего брейнрота from inventory
local function getBestBrainrotFromInventory()
    local backpack = LocalPlayer:WaitForChild("Backpack")
    local bestBrainrot = nil
    local bestMoneyPerSecond = 0
    
    for _, pet in pairs(backpack:GetChildren()) do
        if pet:IsA("Tool") and pet.Name:match("%[%d+%.?%d*%s*kg%]") then
            local petInfo = getPetInfo(pet)
            local moneyPerSecond = petInfo.moneyPerSecond
            
            -- Сравниваем по MoneyPerSecond
            if moneyPerSecond > bestMoneyPerSecond then
                bestMoneyPerSecond = moneyPerSecond
                bestBrainrot = {
                    tool = pet,
                    name = pet.Name,
                    rarity = petInfo.rarity,
                    size = petInfo.size,
                    worth = petInfo.worth,
                    moneyPerSecond = moneyPerSecond
                }
            end
        end
    end
    
    return bestBrainrot
end

-- Auto-sell pets
local function autoSellPets()
    local success, error = pcall(function()
        local backpack = LocalPlayer:WaitForChild("Backpack")
        local soldCount = 0
        local keptCount = 0
        
        -- Обновляем анализ pets перед продажей
        petAnalysis = analyzePets()
        
        -- Показываем информацию об анализе
        if CONFIG.SMART_SELLING and petAnalysis.totalPets > 0 then
            -- Считаем pets with мутациями
            local mutationPets = 0
            for _, petData in pairs(petAnalysis.petsByMoneyPerSecond) do
                if hasProtectedMutations(petData.pet.Name) then
                    mutationPets = mutationPets + 1
                end
            end
            
            print("=== PET ANALYSIS ===")
            print("Total pets: " .. petAnalysis.totalPets)
            print("Pets with mutations: " .. mutationPets)
            print("Average MoneyPerSecond: " .. math.floor(petAnalysis.averageMoneyPerSecond))
            print("Best MoneyPerSecond: " .. petAnalysis.bestMoneyPerSecond)
            print("Minimum to keep: " .. math.floor(petAnalysis.minMoneyPerSecondToKeep))
            print("Selling Rare: " .. (petAnalysis.shouldSellRare and "YES" or "NO"))
            print("Selling Epic: " .. (petAnalysis.shouldSellEpic and "YES" or "NO"))
            print("Selling Legendary: " .. (petAnalysis.shouldSellLegendary and "YES" or "NO"))
            print("==================")
        end
        
        -- Сначала находим лучшего брейнрота for замены and защищаем его
        local bestBrainrot = getBestBrainrotFromInventory()
        if bestBrainrot then
            protectedPet = bestBrainrot.tool
            print("Protected from sale: " .. bestBrainrot.name .. " (" .. bestBrainrot.moneyPerSecond .. "/s)")
        end
        
        for _, pet in pairs(backpack:GetChildren()) do
            if pet:IsA("Tool") and pet.Name:match("%[%d+%.?%d*%s*kg%]") then
                if shouldSellPet(pet) then
                    local petInfo = getPetInfo(pet)
                    local sellSuccess = sellPet(pet)
                    
                    if sellSuccess then
                        soldCount = soldCount + 1
                        
                        local reason = "Sold: " .. petInfo.rarity .. " (вес: " .. petInfo.weight .. "kg)"
                        if CONFIG.SMART_SELLING then
                            reason = reason .. " [MoneyPerSecond: " .. petInfo.moneyPerSecond .. "/s]"
                        end
                        
                        table.insert(logs, {
                            action = "SELL",
                            item = petInfo.name,
                            reason = reason,
                            timestamp = os.time()
                        })
                        
                        print("Sold: " .. petInfo.name .. " (" .. petInfo.rarity .. ", " .. petInfo.weight .. "kg, " .. petInfo.moneyPerSecond .. "/s)")
                    else
                        print("Failed to sell: " .. petInfo.name)
                    end
                    
                    wait(CONFIG.SELL_DELAY)
                else
                    local petInfo = getPetInfo(pet)
                    local reason = "Kept: "
                    
                    -- Проверяем, является ли это полезным брейнротом
                    if petInfo.moneyPerSecond >= petAnalysis.minMoneyPerSecondToKeep then
                        reason = reason .. "высокий MoneyPerSecond (" .. petInfo.moneyPerSecond .. "/s)"
                    elseif petInfo.weight >= CONFIG.MIN_WEIGHT_TO_KEEP then
                        reason = reason .. "тяжелый (" .. petInfo.weight .. "kg)"
                    elseif RARITY_ORDER[petInfo.rarity] > RARITY_ORDER["Legendary"] then
                        reason = reason .. "высокая редкость (" .. petInfo.rarity .. ")"
                    elseif petInfo.rarity == "Legendary" and hasProtectedMutations(pet.Name) then
                        reason = reason .. "защищенные мутации"
                    else
                        reason = reason .. "защищенный предмет"
                    end
                    
                    table.insert(logs, {
                        action = "KEEP",
                        item = petInfo.name,
                        reason = reason,
                        timestamp = os.time()
                    })
                    
                    keptCount = keptCount + 1
                end
            end
        end
        
        -- Снимаем защиту после продажи
        protectedPet = nil
        
        if soldCount > 0 or keptCount > 0 then
            print("Pets sold: " .. soldCount .. ", kept: " .. keptCount)
        end
    end)
    
    if not success then
        print("Error in autoSellPets: " .. tostring(error))
    end
end

-- Redeem codes
local function redeemCodes()
    print("Redeem codes...")
    for _, code in pairs(CODES) do
        local args = {{"code", "\031"}}
        dataRemoteEvent:FireServer(unpack(args))
        wait(0.1)
    end
    print("Codes redeemed!")
end

-- Auto-open eggs
local function autoOpenEggs()
    local success, error = pcall(function()
        local backpack = LocalPlayer:WaitForChild("Backpack")
        local openedCount = 0
        
        for _, item in pairs(backpack:GetChildren()) do
            if item:IsA("Tool") then
                for _, eggName in pairs(PROTECTED_ITEMS) do
                    if item.Name:find(eggName) then
                        local args = {eggName}
                        openEggRemote:FireServer(unpack(args))
                        
                        table.insert(logs, {
                            action = "OPEN_EGG",
                            item = eggName,
                            reason = "Автоматически открыто яйцо",
                            timestamp = os.time()
                        })
                        
                        print("Opened egg: " .. eggName)
                        openedCount = openedCount + 1
                        wait(0.1)
                        break
                    end
                end
            end
        end
        
        if openedCount > 0 then
            print("Eggs opened: " .. openedCount)
        end
    end)
    
    if not success then
        print("Error in autoOpenEggs: " .. tostring(error))
    end
end

-- Check seed stock
local function checkSeedStock(seedName)
    local seedsGui = PlayerGui:FindFirstChild("Main")
    if not seedsGui then return false, 0 end
    
    local seedsFrame = seedsGui:FindFirstChild("Seeds")
    if not seedsFrame then return false, 0 end
    
    local scrollingFrame = seedsFrame:FindFirstChild("Frame"):FindFirstChild("ScrollingFrame")
    if not scrollingFrame then return false, 0 end
    
    local seedFrame = scrollingFrame:FindFirstChild(seedName)
    if not seedFrame then return false, 0 end
    
    local stockLabel = seedFrame:FindFirstChild("Stock")
    if not stockLabel then return false, 0 end
    
    local stockText = stockLabel.Text
    local stockCount = tonumber(stockText:match("x(%d+)")) or 0
    
    return stockCount > 0, stockCount
end

-- Auto-buy seeds
local function autoBuySeeds()
    local success, error = pcall(function()
        for _, seedName in pairs(SEEDS) do
            local hasStock, stockCount = checkSeedStock(seedName)
            if hasStock then
                local args = {{seedName, "\b"}}
                dataRemoteEvent:FireServer(unpack(args))
                
                table.insert(logs, {
                    action = "BUY_SEED",
                    item = seedName,
                    reason = "Bought (in стоке: " .. stockCount .. ")",
                    timestamp = os.time()
                })
                
                print("Bought seed: " .. seedName .. " (in стоке: " .. stockCount .. ")")
                wait(0.1)
            end
        end
    end)
    
    if not success then
        print("Error in autoBuySeeds: " .. tostring(error))
    end
end

-- Check gear stock
local function checkGearStock(gearName)
    local gearsGui = PlayerGui:FindFirstChild("Main")
    if not gearsGui then return false, 0 end
    
    local gearsFrame = gearsGui:FindFirstChild("Gears")
    if not gearsFrame then return false, 0 end
    
    local scrollingFrame = gearsFrame:FindFirstChild("Frame"):FindFirstChild("ScrollingFrame")
    if not scrollingFrame then return false, 0 end
    
    local gearFrame = scrollingFrame:FindFirstChild(gearName)
    if not gearFrame then return false, 0 end
    
    local stockLabel = gearFrame:FindFirstChild("Stock")
    if not stockLabel then return false, 0 end
    
    local stockText = stockLabel.Text
    local stockCount = tonumber(stockText:match("x(%d+)")) or 0
    
    return stockCount > 0, stockCount
end

-- Auto-buy gear
local function autoBuyGear()
    local success, error = pcall(function()
        for _, gearName in pairs(GEAR_ITEMS) do
            local hasStock, stockCount = checkGearStock(gearName)
            if hasStock then
                local args = {{gearName, "\026"}}
                dataRemoteEvent:FireServer(unpack(args))
                
                table.insert(logs, {
                    action = "BUY_GEAR",
                    item = gearName,
                    reason = "Bought (in стоке: " .. stockCount .. ")",
                    timestamp = os.time()
                })
                
                print("Bought gear: " .. gearName .. " (in стоке: " .. stockCount .. ")")
                wait(0.1)
            end
        end
    end)
    
    if not success then
        print("Error in autoBuyGear: " .. tostring(error))
    end
end

-- Get player's current plot
local function getCurrentPlot()
    local plotNumber = LocalPlayer:GetAttribute("Plot")
    if plotNumber then
        local plot = workspace.Plots:FindFirstChild(tostring(plotNumber))
        if plot then
            print("Found plot: " .. plotNumber)
            return plot
        else
            print("Plot " .. plotNumber .. " not found in workspace.Plots")
        end
    else
        print("Plot attribute not found on player")
    end
    return nil
end

-- Get player balance
local function getPlayerBalance()
    if not playerData then
        table.insert(logs, {
            action = "PLATFORM_DEBUG",
            message = "❌ playerData not инициализирован, пробуем альтернативный способ",
            timestamp = os.time()
        })
        
        -- Альтернативный способ получения balanceа
        local character = LocalPlayer.Character
        if character then
            local humanoid = character:FindFirstChild("Humanoid")
            if humanoid then
                local moneyValue = humanoid:FindFirstChild("Money")
                if moneyValue then
                    local balance = moneyValue.Value
                    table.insert(logs, {
                        action = "PLATFORM_DEBUG",
                        message = "💰 Баланс получен альтернативным способом: $" .. balance,
                        timestamp = os.time()
                    })
                    return balance
                end
            end
        end
        return 0
    end
    
    local success, balance = pcall(function()
        return playerData.get("Money") or 0
    end)
    
    if success then
        table.insert(logs, {
            action = "PLATFORM_DEBUG",
            message = "💰 Баланс получен: $" .. balance,
            timestamp = os.time()
        })
        return balance
    else
        table.insert(logs, {
            action = "PLATFORM_DEBUG",
            message = "❌ Error получения balanceа, пробуем альтернативный способ",
            timestamp = os.time()
        })
        
        -- Альтернативный способ получения balanceа
        local character = LocalPlayer.Character
        if character then
            local humanoid = character:FindFirstChild("Humanoid")
            if humanoid then
                local moneyValue = humanoid:FindFirstChild("Money")
                if moneyValue then
                    local balance = moneyValue.Value
                    table.insert(logs, {
                        action = "PLATFORM_DEBUG",
                        message = "💰 Баланс получен альтернативным способом: $" .. balance,
                        timestamp = os.time()
                    })
                    return balance
                end
            end
        end
        return 0
    end
end

-- Buy platform
local function buyPlatform(platformNumber)
    table.insert(logs, {
        action = "PLATFORM_DEBUG",
        message = "=== ATTEMPT TO BUY PLATFORM " .. platformNumber .. " ===",
        timestamp = os.time()
    })
    
    local args = {
        {
            tostring(platformNumber),
            ","
        }
    }
    
    table.insert(logs, {
        action = "PLATFORM_DEBUG",
        message = "Sending request to buy platform " .. platformNumber,
        timestamp = os.time()
    })
    
    table.insert(logs, {
        action = "PLATFORM_DEBUG",
        message = "Request arguments: " .. tostring(args[1][1]) .. ", " .. tostring(args[1][2]),
        timestamp = os.time()
    })
    
    local success, error = pcall(function()
        dataRemoteEvent:FireServer(unpack(args))
    end)
    
    if success then
        table.insert(logs, {
            action = "PLATFORM_DEBUG",
            message = "✅ Platform purchase request " .. platformNumber .. " отправлен успешно",
            timestamp = os.time()
        })
        
        table.insert(logs, {
            action = "BUY_PLATFORM",
            item = "Platform " .. platformNumber,
            reason = "Куплена platform",
            timestamp = os.time()
        })
    else
        table.insert(logs, {
            action = "PLATFORM_DEBUG",
            message = "❌ ОШИБКА при покупке platformsы " .. platformNumber .. ": " .. tostring(error),
            timestamp = os.time()
        })
    end
    
    table.insert(logs, {
        action = "PLATFORM_DEBUG",
        message = "=== ЗАВЕРШЕНИЕ ПОПЫТКИ ПОКУПКИ ПЛАТФОРМЫ " .. platformNumber .. " ===",
        timestamp = os.time()
    })
end

-- Testовая функция for диагностики покупки platforms
local function testPlatformBuying()
    -- Простая проверка доступности platforms
    local plotNumber = LocalPlayer:GetAttribute("Plot")
    if plotNumber then
        local plot = workspace.Plots[tostring(plotNumber)]
        if plot and plot:FindFirstChild("Brainrots") then
            table.insert(logs, {
                action = "PLATFORM_DEBUG",
                message = "✅ Platforms available for purchase",
                timestamp = os.time()
            })
        end
    end
end

-- Авто-покупка platforms
local function autoBuyPlatforms()
    table.insert(logs, {
        action = "PLATFORM_DEBUG",
        message = "=== ФУНКЦИЯ autoBuyPlatforms() ВЫЗВАНА ===",
        timestamp = os.time()
    })
    
    
    local success, error = pcall(function()
        if not CONFIG.AUTO_BUY_PLATFORMS then
            table.insert(logs, {
                action = "PLATFORM_DEBUG",
                message = "Авто-покупка platforms отключена in конфигурации",
                timestamp = os.time()
            })
            return
        end
        
        table.insert(logs, {
            action = "PLATFORM_DEBUG",
            message = "Авто-покупка platforms включена, начинаем проверку...",
            timestamp = os.time()
        })
        
        local currentPlot = getCurrentPlot()
        if not currentPlot then
            table.insert(logs, {
                action = "PLATFORM_DEBUG",
                message = "Current plot not found for platform purchase",
                timestamp = os.time()
            })
            return
        end
        
        table.insert(logs, {
            action = "PLATFORM_DEBUG",
            message = "Found plot: " .. tostring(currentPlot),
            timestamp = os.time()
        })
        
        local brainrots = currentPlot:FindFirstChild("Brainrots")
        if not brainrots then
            table.insert(logs, {
                action = "PLATFORM_DEBUG",
                message = "Не found Brainrots on плоте for покупки platforms",
                timestamp = os.time()
            })
            return
        end
        
        table.insert(logs, {
            action = "PLATFORM_DEBUG",
            message = "Найден Brainrots, проверяем platformsы...",
            timestamp = os.time()
        })
        
        
        local playerBalance = getPlayerBalance()
        local boughtCount = 0
        local platformsChecked = 0
        
        table.insert(logs, {
            action = "PLATFORM_DEBUG",
            message = "Checking platforms for purchase. Balance: $" .. playerBalance,
            timestamp = os.time()
        })
        
        -- Проверяем dataRemoteEvent
        if dataRemoteEvent then
            table.insert(logs, {
                action = "PLATFORM_DEBUG",
                message = "dataRemoteEvent found: " .. tostring(dataRemoteEvent),
                timestamp = os.time()
            })
        else
            table.insert(logs, {
                action = "PLATFORM_DEBUG",
                message = "ERROR: dataRemoteEvent not found!",
                timestamp = os.time()
            })
        end
        
        for _, platform in pairs(brainrots:GetChildren()) do
            if platform:IsA("Model") and platform.Name:match("^%d+$") then
                platformsChecked = platformsChecked + 1
                
                -- Проверяем PlatformPrice.Money вместо просто PlatformPrice
                local platformPrice = platform:GetAttribute("PlatformPrice")
                if platformPrice then
                    -- Проверяем, is ли у PlatformPrice атрибут Money
                    local platformPriceMoney = platformPrice.Money
                    if platformPriceMoney then
                        -- Парсим цену from PlatformPrice.Money
                        local priceText = tostring(platformPriceMoney)
                        local priceValue = priceText:match("%$(%d+,?%d*%d*)")
                        if priceValue then
                            -- Убираем запятые and конвертируем in число
                            local cleanPrice = priceValue:gsub(",", "")
                            local price = tonumber(cleanPrice) or 0
                        
                            -- Всегда пытаемся купить platformsу, независимо от balanceа
                            table.insert(logs, {
                                action = "PLATFORM_DEBUG",
                                message = "Покупаем platformsу " .. platform.Name .. " за $" .. price .. " (balance: $" .. playerBalance .. ")",
                                timestamp = os.time()
                            })
                            buyPlatform(platform.Name)
                            boughtCount = boughtCount + 1
                            wait(0.5) -- Небольшая пауза между покупками
                        end
                    end
                end
            end
        end
        
        table.insert(logs, {
            action = "PLATFORM_DEBUG",
            message = "Platforms checked: " .. platformsChecked .. ", bought: " .. boughtCount,
            timestamp = os.time()
        })
        
        if boughtCount > 0 then
            table.insert(logs, {
                action = "PLATFORM_DEBUG",
                message = "Bought platforms: " .. boughtCount,
                timestamp = os.time()
            })
        else
            table.insert(logs, {
                action = "PLATFORM_DEBUG",
                message = "No platforms for покупки",
                timestamp = os.time()
            })
        end
    end)
    
    if not success then
        table.insert(logs, {
            action = "PLATFORM_DEBUG",
            message = "Error in autoBuyPlatforms: " .. tostring(error),
            timestamp = os.time()
        })
    end
    
    table.insert(logs, {
        action = "PLATFORM_DEBUG",
        message = "=== ФУНКЦИЯ autoBuyPlatforms() ЗАВЕРШЕНА ===",
        timestamp = os.time()
    })
end

-- Check platform availability (is it visible in game)
local function isPlatformAvailable(platform)
    -- Проверяем, is ли у platformsы PlatformPrice.Money - if is, then подиум недоступен
    local platformPrice = platform:GetAttribute("PlatformPrice")
    if platformPrice then
        -- Проверяем, is ли у PlatformPrice атрибут Money
        local platformPriceMoney = platformPrice.Money
        if platformPriceMoney then
            return false -- Подиум недоступен, так как is цена for покупки
        end
    end
    
    -- Проверяем, is ли у platformsы видимые части
    local hasVisibleParts = false
    
    -- Проверяем все дочерние объекты platformsы
    for _, child in pairs(platform:GetChildren()) do
        if child:IsA("BasePart") then
            -- Проверяем, видна ли часть (not прозрачная)
            -- Не проверяем Visible, так как not все BasePart имеют это свойство
            if child.Transparency < 1 then
                hasVisibleParts = true
                break
            end
        elseif child:IsA("Model") then
            -- Проверяем дочерние модели
            for _, subChild in pairs(child:GetChildren()) do
                if subChild:IsA("BasePart") and subChild.Transparency < 1 then
                    hasVisibleParts = true
                    break
                end
            end
            if hasVisibleParts then break end
        end
    end
    
    return hasVisibleParts
end

-- Ensure PrimaryPart for platform if missing
local function ensurePlatformPrimaryPart(platform)
    if platform.PrimaryPart then
        return true
    end
    
    -- Ищем подходящую часть for PrimaryPart
    local candidates = {}
    
    -- Ищем Hitbox как основной кандидат
    local hitbox = platform:FindFirstChild("Hitbox")
    if hitbox and hitbox:IsA("BasePart") then
        table.insert(candidates, hitbox)
    end
    
    -- Ищем любые BasePart in platformsе
    for _, child in pairs(platform:GetChildren()) do
        if child:IsA("BasePart") and child.Name ~= "Hitbox" then
            table.insert(candidates, child)
        end
    end
    
    -- Устанавливаем первый foundный BasePart как PrimaryPart
    if #candidates > 0 then
        platform.PrimaryPart = candidates[1]
        print("PrimaryPart set for platform " .. platform.Name .. " (" .. candidates[1].Name .. ")")
        return true
    end
    
    return false
end

-- Auto-collect coins from platforms
local function autoCollectCoins()
    local success, error = pcall(function()
        local currentPlot = getCurrentPlot()
        if not currentPlot then
            print("Не found текущий плот for сбора монет")
            return
        end
        
        local brainrots = currentPlot:FindFirstChild("Brainrots")
        if not brainrots then
            print("Не found Brainrots on плоте")
            return
        end
        
        local collectedCount = 0
        local character = LocalPlayer.Character
        if not character then
            print("Character not found for сбора монет")
            return
        end
        
        -- Сохраняем текущую позицию персонажа
        local originalPosition = character:GetPrimaryPartCFrame()
        
        print("Found platforms: " .. #brainrots:GetChildren())
        if CONFIG.DEBUG_COLLECT_COINS then
            print("List of all platforms:")
            for _, platform in pairs(brainrots:GetChildren()) do
                print("  - " .. platform.Name .. " (тип: " .. platform.ClassName .. ")")
            end
        end
        
        for _, platform in pairs(brainrots:GetChildren()) do
            if platform:IsA("Model") and platform.Name:match("^%d+$") then -- Только platformsы with числовыми именами
                -- Проверяем доступность platformsы (видна ли она)
                if isPlatformAvailable(platform) then
                    if CONFIG.DEBUG_COLLECT_COINS then
                        print("Обрабатываем доступную platformsу: " .. platform.Name)
                    end
                    
                    -- Устанавливаем PrimaryPart if его нет
                    if not ensurePlatformPrimaryPart(platform) then
                        if CONFIG.DEBUG_COLLECT_COINS then
                            print("У platformsы " .. platform.Name .. " нет подходящих частей for PrimaryPart")
                        end
                    else
                    
                    -- Просто телепортируемся к platformsе for сбора монет
                    local platformPosition = platform.PrimaryPart.Position
                    character:SetPrimaryPartCFrame(CFrame.new(platformPosition + Vector3.new(0, 3, 0)))
                    wait(0.2)
                    
                    collectedCount = collectedCount + 1
                    if CONFIG.DEBUG_COLLECT_COINS then
                        print("Teleported to platformsе " .. platform.Name .. " for сбора монет")
                    end
                    
                    wait(0.1)
                    end
                elseif CONFIG.DEBUG_COLLECT_COINS then
                    local platformPrice = platform:GetAttribute("PlatformPrice")
                    if platformPrice then
                        print("Пропускаем недоступную platformsу: " .. platform.Name .. " (is PlatformPrice: " .. platformPrice .. ")")
                    else
                        print("Пропускаем недоступную platformsу: " .. platform.Name .. " (not видна in игре)")
                    end
                end
            elseif CONFIG.DEBUG_COLLECT_COINS then
                print("Пропускаем объект: " .. platform.Name .. " (тип: " .. platform.ClassName .. ")")
            end
        end
        
        -- Возвращаемся on исходную позицию
        character:SetPrimaryPartCFrame(originalPosition)
        
        if collectedCount > 0 then
            table.insert(logs, {
                action = "COLLECT_COINS",
                item = "Платформы",
                reason = "Teleported to " .. collectedCount .. " platforms to collect coins",
                timestamp = os.time()
            })
            print("Teleported to " .. collectedCount .. " platforms to collect coins")
        else
            print("No available platforms to collect coins")
        end
    end)
    
    if not success then
        print("Error in autoCollectCoins: " .. tostring(error))
    end
end

-- Get brainrot info on platform
local function getPlatformBrainrotInfo(platform)
    local brainrot = platform:FindFirstChild("Brainrot")
    if not brainrot then return nil end
    
    local name = brainrot:GetAttribute("Name") or brainrot.Name
    local rarity = brainrot:GetAttribute("Rarity") or "Rare"
    local size = brainrot:GetAttribute("Size") or 1
    local moneyPerSecond = platform:GetAttribute("MoneyPerSecond") or 0
    
    return {
        name = name,
        rarity = rarity,
        size = size,
        moneyPerSecond = moneyPerSecond,
        model = brainrot
    }
end

-- Replace brainrot on platform
local function replaceBrainrotOnPlatform(platform, newBrainrot)
    local character = LocalPlayer.Character
    if not character then 
        print("Character not found")
        protectedPet = nil -- Снимаем защиту при ошибке
        return false 
    end
    
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then 
        print("Humanoid not found")
        protectedPet = nil -- Снимаем защиту при ошибке
        return false 
    end
    
    -- Пытаемся установить PrimaryPart if его нет
    if not ensurePlatformPrimaryPart(platform) then
        print("У platformsы " .. platform.Name .. " нет подходящих частей for PrimaryPart")
        protectedPet = nil -- Снимаем защиту при ошибке
        return false
    end
    
    -- Собираем деньги with platformsы
    local hitbox = platform:FindFirstChild("Hitbox")
    if hitbox then
        local proximityPrompt = hitbox:FindFirstChild("ProximityPrompt")
        if proximityPrompt and proximityPrompt.Enabled then
            proximityPrompt:InputHoldBegin()
            wait(0.1)
            proximityPrompt:InputHoldEnd()
            wait(0.5)
        end
    end
    
    -- Protecting pet from sale
    protectedPet = newBrainrot.tool
    
    -- Equip the new brainrot
    humanoid:EquipTool(newBrainrot.tool)
    wait(0.2)
    
    -- Teleporting to platform
    local platformPosition = platform.PrimaryPart.Position
    character:SetPrimaryPartCFrame(CFrame.new(platformPosition + Vector3.new(0, 5, 0)))
    wait(0.5)
    
    -- Hold E for 1 second
    local hitbox = platform:FindFirstChild("Hitbox")
    if hitbox then
        local proximityPrompt = hitbox:FindFirstChild("ProximityPrompt")
        if proximityPrompt then
            proximityPrompt:InputHoldBegin()
            wait(1)
            proximityPrompt:InputHoldEnd()
            wait(0.5)
        end
    end
    
    -- Unprotect pet
    protectedPet = nil
    
    return true
end

-- Авто-замена брейнротов on platformsах
local function autoReplaceBrainrots()
    local success, error = pcall(function()
        local currentPlot = getCurrentPlot()
        if not currentPlot then
            print("Current plot not found for replacing brainrots")
            return
        end
        
        local brainrots = currentPlot:FindFirstChild("Brainrots")
        if not brainrots then
            print("Не found Brainrots on плоте")
            return
        end
        
        -- Используем уже защищенного пета или ищем лучшего
        local bestBrainrot = nil
        if protectedPet then
            local petInfo = getPetInfo(protectedPet)
            bestBrainrot = {
                tool = protectedPet,
                name = petInfo.name,
                rarity = petInfo.rarity,
                size = petInfo.size,
                worth = petInfo.worth,
                moneyPerSecond = petInfo.moneyPerSecond
            }
            print("Используем защищенного брейнрота: " .. bestBrainrot.name .. " (" .. bestBrainrot.moneyPerSecond .. "/s)")
        else
            bestBrainrot = getBestBrainrotFromInventory()
            if not bestBrainrot then
                print("No best brainrot found in inventory")
                return
            end
            print("Лучший брейнрот in inventory: " .. bestBrainrot.name .. " (" .. bestBrainrot.moneyPerSecond .. "/s)")
        end
        
        print("Найдено platforms for замены: " .. #brainrots:GetChildren())
        if CONFIG.DEBUG_COLLECT_COINS then
            print("Список всех platforms for замены:")
            for _, platform in pairs(brainrots:GetChildren()) do
                print("  - " .. platform.Name .. " (тип: " .. platform.ClassName .. ")")
            end
        end
        
        local replacedCount = 0
        
        for _, platform in pairs(brainrots:GetChildren()) do
            if platform:IsA("Model") and platform.Name:match("^%d+$") then -- Только platformsы with числовыми именами
                -- Проверяем доступность platformsы (видна ли она)
                if isPlatformAvailable(platform) then
                    -- Пытаемся установить PrimaryPart if его нет
                    if ensurePlatformPrimaryPart(platform) then
                    local currentBrainrot = getPlatformBrainrotInfo(platform)
                    local shouldReplace = false
                    local replaceReason = ""
                    
                    if currentBrainrot then
                        print("Платформа " .. platform.Name .. ": " .. currentBrainrot.name .. " (" .. currentBrainrot.moneyPerSecond .. "/s)")
                        
                        -- Сравниваем MoneyPerSecond: if у пета in inventory больше, чем on platformsе
                        if bestBrainrot.moneyPerSecond > currentBrainrot.moneyPerSecond then
                            shouldReplace = true
                            replaceReason = "замена on лучшего (" .. currentBrainrot.moneyPerSecond .. "/s -> " .. bestBrainrot.moneyPerSecond .. "/s)"
                        end
                    else
                        print("Платформа " .. platform.Name .. ": пустая")
                        shouldReplace = true
                        replaceReason = "установка on пустую platformsу"
                    end
                    
                    if shouldReplace then
                        local success = replaceBrainrotOnPlatform(platform, bestBrainrot)
                        if success then
                            replacedCount = replacedCount + 1
                            if currentBrainrot then
                                print("Replaced brainrot on platform " .. platform.Name .. 
                                      " с " .. currentBrainrot.name .. " (" .. currentBrainrot.moneyPerSecond .. "/s) " ..
                                      "на " .. bestBrainrot.name .. " (" .. bestBrainrot.moneyPerSecond .. "/s)")
                            else
                                print("Installed brainrot on empty platform " .. platform.Name .. 
                                      ": " .. bestBrainrot.name .. " (" .. bestBrainrot.moneyPerSecond .. "/s)")
                            end
                        end
                        
                        wait(2)
                    end
                else
                    print("У platformsы " .. platform.Name .. " нет подходящих частей for PrimaryPart")
                end
                elseif CONFIG.DEBUG_COLLECT_COINS then
                    local platformPrice = platform:GetAttribute("PlatformPrice")
                    if platformPrice then
                        print("Пропускаем недоступную platformsу for замены: " .. platform.Name .. " (is PlatformPrice: " .. platformPrice .. ")")
                    else
                        print("Пропускаем недоступную platformsу for замены: " .. platform.Name .. " (not видна in игре)")
                    end
                end
            elseif CONFIG.DEBUG_COLLECT_COINS then
                print("Пропускаем объект for замены: " .. platform.Name .. " (тип: " .. platform.ClassName .. ")")
            end
        end
        
        if replacedCount > 0 then
            table.insert(logs, {
                action = "REPLACE_BRAINROT",
                item = "Платформы",
                reason = "Replaced/installed brainrots: " .. replacedCount,
                timestamp = os.time()
            })
            print("Replaced/installed brainrots: " .. replacedCount)
        else
            print("No platforms to replace/install brainrots")
        end
    end)
    
    if not success then
        print("Error in autoReplaceBrainrots: " .. tostring(error))
    end
end

-- Get best seed from inventory for planting
local function getBestSeedFromInventory()
    table.insert(logs, {
        action = "PLANT_DEBUG",
        message = "🔍 Поиск seeds in inventory...",
        timestamp = os.time()
    })
    local backpack = LocalPlayer:WaitForChild("Backpack")
    local bestSeed = nil
    local bestRarity = 0
    local seedCount = 0
    
    table.insert(logs, {
        action = "PLANT_DEBUG",
        message = "Backpack found: " .. tostring(backpack ~= nil),
        timestamp = os.time()
    })
    
    -- Приоритет редкости seeds
    local seedRarity = {
        ["Cactus Seed"] = 1,
        ["Strawberry Seed"] = 1,
        ["Sunflower Seed"] = 2,
        ["Pumpkin Seed"] = 2,
        ["Dragon Fruit Seed"] = 3,
        ["Eggplant Seed"] = 3,
        ["Watermelon Seed"] = 4,
        ["Grape Seed"] = 4,
        ["Cocotank Seed"] = 5,
        ["Carnivorous Plant Seed"] = 5,
        ["Mr Carrot Seed"] = 6,
        ["Tomatrio Seed"] = 6,
        ["Shroombino Seed"] = 7
    }
    
    local totalItems = 0
    for _, item in pairs(backpack:GetChildren()) do
        totalItems = totalItems + 1
        table.insert(logs, {
            action = "PLANT_DEBUG",
            message = "Предмет in inventory: " .. item.Name .. " (тип: " .. item.ClassName .. ")",
            timestamp = os.time()
        })
        if item:IsA("Tool") and item.Name:match("Seed$") then
            seedCount = seedCount + 1
            -- Убираем количество from названия for поиска редкости
            local cleanName = item.Name:gsub("%[x%d+%]%s*", "")
            local rarity = seedRarity[cleanName] or 0
            table.insert(logs, {
                action = "PLANT_DEBUG",
                message = "🌱 Найдено семя: " .. item.Name .. " (чистое: " .. cleanName .. ", редкость: " .. rarity .. ")",
                timestamp = os.time()
            })
            -- Если это первое семя или семя with лучшей редкостью
            if not bestSeed or rarity > bestRarity then
                bestRarity = rarity
                bestSeed = item
                table.insert(logs, {
                    action = "PLANT_DEBUG",
                    message = "🎯 Новое лучшее семя: " .. item.Name .. " (редкость: " .. rarity .. ")",
                    timestamp = os.time()
                })
            end
        end
    end
    
    table.insert(logs, {
        action = "PLANT_DEBUG",
        message = "Total items in inventory: " .. totalItems,
        timestamp = os.time()
    })
    table.insert(logs, {
        action = "PLANT_DEBUG",
        message = "Total seeds in inventory: " .. seedCount,
        timestamp = os.time()
    })
    if bestSeed then
        table.insert(logs, {
            action = "PLANT_DEBUG",
            message = "✅ Best seed: " .. bestSeed.Name .. " (редкость: " .. bestRarity .. ")",
            timestamp = os.time()
        })
    else
        table.insert(logs, {
            action = "PLANT_DEBUG",
            message = "❌ Семена not foundы",
            timestamp = os.time()
        })
    end
    
    return bestSeed
end

-- Получение пустого места on грядке
local function getEmptyPlotSpot()
    -- Получаем номер текущего плота
    local plotNumber = LocalPlayer:GetAttribute("Plot")
    if not plotNumber then
        table.insert(logs, {
            action = "PLANT_DEBUG",
            message = "❌ Не found номер плота у игрока",
            timestamp = os.time()
        })
        return nil
    end
    
    local plot = workspace.Plots[tostring(plotNumber)]
    if not plot then
        table.insert(logs, {
            action = "PLANT_DEBUG",
            message = "❌ Plot " .. plotNumber .. " not found in workspace.Plots",
            timestamp = os.time()
        })
        return nil
    end
    
    table.insert(logs, {
        action = "PLANT_DEBUG",
        message = "🔍 Searching for empty spots in plot " .. plotNumber,
        timestamp = os.time()
    })
    
    -- Проверяем все ряды (Rows) on наличие пустых мест
    local totalSpots = 0
    local emptySpots = 0
    local emptySpotsList = {}
    
    -- Получаем список всех plants on плоту
    local plants = plot:FindFirstChild("Plants")
    local existingPlants = {}
    if plants then
        for _, plant in pairs(plants:GetChildren()) do
            local plantRow = plant:GetAttribute("Row")
            local plantSpot = plant:GetAttribute("Spot")
            if plantRow and plantSpot then
                existingPlants[plantRow .. "_" .. plantSpot] = true
            end
        end
    end
    
    for _, row in pairs(plot.Rows:GetChildren()) do
        if row.Name:match("^%d+$") then -- Проверяем что это числовой ряд
            local grass = row:FindFirstChild("Grass")
            if grass then
                -- Проверяем все места in этом ряду
                for _, spot in pairs(grass:GetChildren()) do
                    totalSpots = totalSpots + 1
                    local canPlace = spot:GetAttribute("CanPlace")
                    if canPlace == true then
                        -- Проверяем, is ли уже plant in этом конкретном месте
                        local spotKey = row.Name .. "_" .. spot.Name
                        local hasPlant = existingPlants[spotKey] or false
                        
                        if not hasPlant then
                            emptySpots = emptySpots + 1
                            table.insert(emptySpotsList, {
                                row = row.Name,
                                spot = spot,
                                grass = grass,
                                plot = plot,
                                spotKey = spotKey
                            })
                        end
                    end
                end
            end
        end
    end
    
    table.insert(logs, {
        action = "PLANT_DEBUG",
        message = "Total spots: " .. totalSpots .. ", empty: " .. emptySpots,
        timestamp = os.time()
    })
    
    if emptySpots == 0 then
        table.insert(logs, {
            action = "PLANT_DEBUG",
            message = "❌ No empty spots found",
            timestamp = os.time()
        })
        return nil
    end
    
    -- Возвращаем первое foundное пустое место
    return emptySpotsList[1]
end

-- Get worst plant for replacement
local function getWorstPlantForReplacement()
    if not currentPlot then
        currentPlot = getCurrentPlot()
        if not currentPlot then
            return nil
        end
    end
    
    local plants = currentPlot:FindFirstChild("Plants")
    if not plants then
        return nil
    end
    
    local worstPlant = nil
    local worstDamage = math.huge
    
    -- Приоритет редкости plants (чем выше редкость, тем лучше)
    local plantRarity = {
        ["Cactus"] = 1,
        ["Strawberry"] = 1,
        ["Sunflower"] = 2,
        ["Pumpkin"] = 2,
        ["Dragon Fruit"] = 3,
        ["Eggplant"] = 3,
        ["Watermelon"] = 4,
        ["Grape"] = 4,
        ["Cocotank"] = 5,
        ["Carnivorous Plant"] = 5,
        ["Mr Carrot"] = 6,
        ["Tomatrio"] = 6,
        ["Shroombino"] = 7
    }
    
    for _, plant in pairs(plants:GetChildren()) do
        local damage = plant:GetAttribute("Damage") or 0
        local rarity = plantRarity[plant.Name] or 0
        
        -- Считаем "ценность" растения (редкость * урон)
        local value = rarity * damage
        
        if value < worstDamage then
            worstDamage = value
            worstPlant = plant
        end
    end
    
    return worstPlant
end

-- Удаление растения with грядки
local function removePlantFromPlot(plantId)
    local args = {
        {
            plantId,
            "\006"
        }
    }
    dataRemoteEvent:FireServer(unpack(args))
    
    table.insert(logs, {
        action = "REMOVE_PLANT",
        item = "Plant ID: " .. plantId,
        reason = "Removed plant for освобождения места",
        timestamp = os.time()
    })
    
    if CONFIG.DEBUG_PLANTING then
        print("Removed plant with ID: " .. plantId)
    end
end

-- Plant seed
local function plantSeed(seed, spotData)
    local character = LocalPlayer.Character
    if not character then
        table.insert(logs, {
            action = "PLANT_DEBUG",
            message = "❌ Character not found for посадки",
            timestamp = os.time()
        })
        return false
    end
    
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then
        table.insert(logs, {
            action = "PLANT_DEBUG",
            message = "❌ Humanoid not found for посадки",
            timestamp = os.time()
        })
        return false
    end
    
    -- Берем семя in руку
    humanoid:EquipTool(seed)
    wait(0.2)
    
    -- Генерируем UUID for растения
    local plantId = game:GetService("HttpService"):GenerateGUID(false)
    
    -- Очищаем название семени от количества
    local cleanSeedName = seed.Name:gsub("%[x%d+%]%s*", ""):gsub(" Seed", "")
    
    table.insert(logs, {
        action = "PLANT_DEBUG",
        message = "🌱 Attempting to plant: " .. cleanSeedName .. " в Row " .. spotData.row .. " с ID: " .. plantId,
        timestamp = os.time()
    })
    
    -- Получаем номер плота
    local plotNumber = LocalPlayer:GetAttribute("Plot")
    
    -- ИСПРАВЛЕНИЕ: Floor должен быть числом (индексом), а not объектом
    -- Получаем номер места (Spot) как Floor индекс
    local floorIndex = tonumber(spotData.spot.Name) or 1
    
    -- Пробуем разные форматы запроса
    local requestFormats = {
        -- Формат 1: Самый простой - только Row и Spot
        {
            tonumber(spotData.row),
            floorIndex,
            cleanSeedName
        },
        -- Формат 2: С ID
        {
            plantId,
            tonumber(spotData.row),
            floorIndex,
            cleanSeedName
        },
        -- Формат 3: С CFrame
        {
            {
                Row = tonumber(spotData.row),
                Spot = floorIndex,
                Item = cleanSeedName,
                CFrame = spotData.spot.CFrame
            }
        },
        -- Формат 4: С ID и CFrame
        {
            {
                ID = plantId,
                Row = tonumber(spotData.row),
                Spot = floorIndex,
                Item = cleanSeedName,
                CFrame = spotData.spot.CFrame
            }
        }
    }
    
    local success = false
    local lastError = ""
    
    -- Пробуем каждый формат
    for i, args in ipairs(requestFormats) do
        table.insert(logs, {
            action = "PLANT_DEBUG",
            message = "📤 Trying format " .. i .. ":",
            timestamp = os.time()
        })
        
        -- Логируем детали запроса
        if type(args) == "table" and type(args[1]) == "table" then
            for key, value in pairs(args[1]) do
                table.insert(logs, {
                    action = "PLANT_DEBUG",
                    message = "  " .. key .. ": " .. tostring(value),
                    timestamp = os.time()
                })
            end
        else
            table.insert(logs, {
                action = "PLANT_DEBUG",
                message = "  Аргументы: " .. tostring(args),
                timestamp = os.time()
            })
        end
        
        local formatSuccess, error = pcall(function()
            if type(args) == "table" and #args > 0 then
                if type(args[1]) == "table" then
                    -- Если это таблица, отправляем как is
                    dataRemoteEvent:FireServer(args[1])
                else
                    -- Если это массив аргументов, распаковываем
                    dataRemoteEvent:FireServer(unpack(args))
                end
            else
                dataRemoteEvent:FireServer(args)
            end
        end)
        
        if formatSuccess then
            table.insert(logs, {
                action = "PLANT_DEBUG",
                message = "✅ Формат " .. i .. " отправлен успешно",
                timestamp = os.time()
            })
            
            -- Ждем and проверяем результат
            wait(1.5)
            
            local plot = workspace.Plots[tostring(plotNumber)]
            local plantCreated = false
            
            if plot and plot:FindFirstChild("Plants") then
                -- Проверяем, is ли plant with нашим ID
                local newPlant = plot.Plants:FindFirstChild(plantId)
                if newPlant then
                    plantCreated = true
                    table.insert(logs, {
                        action = "PLANT_DEBUG",
                        message = "🎉 SUCCESS! Plant created with ID: " .. plantId,
                        timestamp = os.time()
                    })
                else
                    -- Альтернативная проверка: ищем plant in том же ряду with похожим именем
                    for _, plant in pairs(plot.Plants:GetChildren()) do
                        if plant:GetAttribute("Row") == spotData.row and plant.Name == cleanSeedName then
                            plantCreated = true
                            table.insert(logs, {
                                action = "PLANT_DEBUG",
                                message = "✅ Plant found in Row " .. spotData.row .. " with именем: " .. plant.Name,
                                timestamp = os.time()
                            })
                            break
                        end
                    end
                end
            end
            
            if plantCreated then
                success = true
                break
            else
                table.insert(logs, {
                    action = "PLANT_DEBUG",
                    message = "⚠️ Формат " .. i .. " отправлен, но plant not создано",
                    timestamp = os.time()
                })
            end
        else
            lastError = tostring(error)
            table.insert(logs, {
                action = "PLANT_DEBUG",
                message = "❌ Формат " .. i .. " not удался: " .. lastError,
                timestamp = os.time()
            })
        end
        
        wait(0.5) -- Небольшая пауза между попытками
    end
    
    if not success then
        table.insert(logs, {
            action = "PLANT_DEBUG",
            message = "❌ All formats failed. Last error: " .. lastError,
            timestamp = os.time()
        })
        return false
    end
    
    -- Запоминаем посаженное семя
    plantedSeeds[plantId] = {
        seedName = seed.Name,
        plantName = cleanSeedName,
        timestamp = os.time(),
        needsWatering = true,
        row = spotData.row,
        spot = spotData.spot,
        verified = true
    }
    
    table.insert(logs, {
        action = "PLANT_SEED",
        item = seed.Name,
        reason = "Посажено plant on грядку (Row " .. spotData.row .. ")",
        timestamp = os.time()
    })
    
    if CONFIG.DEBUG_PLANTING then
        print("Seed planted: " .. seed.Name .. " с ID: " .. plantId .. " в Row " .. spotData.row)
    end
    
    return true
end

-- Water plant
local function waterPlant(plantPosition)
    local character = LocalPlayer.Character
    if not character then
        return false
    end
    
    -- Ищем Water Bucket in inventory
    local waterBucket = nil
    for _, tool in pairs(character:GetChildren()) do
        if tool:IsA("Tool") and tool.Name:match("Water Bucket") then
            waterBucket = tool
            break
        end
    end
    
    if not waterBucket then
        -- Ищем in рюкзаке
        local backpack = LocalPlayer:WaitForChild("Backpack")
        for _, tool in pairs(backpack:GetChildren()) do
            if tool:IsA("Tool") and tool.Name:match("Water Bucket") then
                waterBucket = tool
                break
            end
        end
    end
    
    if not waterBucket then
        return false
    end
    
    -- Берем ведро in руку
    local humanoid = character:FindFirstChild("Humanoid")
    if humanoid then
        humanoid:EquipTool(waterBucket)
        wait(0.1)
    end
    
    -- Поливаем plant
    local args = {
        {
            Toggle = true,
            Tool = waterBucket,
            Pos = plantPosition
        }
    }
    useItemRemote:FireServer(unpack(args))
    
    if CONFIG.DEBUG_PLANTING then
        print("Watered plant at position: " .. tostring(plantPosition))
    end
    
    return true
end

-- Testовая функция for проверки улучшенной системы посадки
local function testImprovedPlantingSystem()
    table.insert(logs, {
        action = "PLANT_DEBUG",
        message = "=== TEST IMPROVED PLANTING SYSTEM ===",
        timestamp = os.time()
    })
    
    -- Получаем пустое место
    local emptySpot = getEmptyPlotSpot()
    if not emptySpot then
        table.insert(logs, {
            action = "PLANT_DEBUG",
            message = "❌ No empty spots for test",
            timestamp = os.time()
        })
        return
    end
    
    -- Получаем семя
    local bestSeed = getBestSeedFromInventory()
    if not bestSeed then
        table.insert(logs, {
            action = "PLANT_DEBUG",
            message = "❌ No seeds for test",
            timestamp = os.time()
        })
        return
    end
    
    table.insert(logs, {
        action = "PLANT_DEBUG",
        message = "🧪 Testируем улучшенную систему посадки: " .. bestSeed.Name .. " в Row " .. emptySpot.row,
        timestamp = os.time()
    })
    
    -- Используем улучшенную функцию посадки
    local success = plantSeed(bestSeed, emptySpot)
    
    if success then
        table.insert(logs, {
            action = "PLANT_DEBUG",
            message = "🎉 TEST SUCCESS! Plant planted successfully",
            timestamp = os.time()
        })
    else
        table.insert(logs, {
            action = "PLANT_DEBUG",
            message = "❌ TEST FAILED! Plant not planted",
            timestamp = os.time()
        })
    end
end

-- Testовая функция for диагностики посадки
local function testPlantingDiagnostics()
    table.insert(logs, {
        action = "PLANT_DEBUG",
        message = "=== PLANTING DIAGNOSTICS ===",
        timestamp = os.time()
    })
    
    -- Проверяем dataRemoteEvent
    if dataRemoteEvent then
        table.insert(logs, {
            action = "PLANT_DEBUG",
            message = "✅ dataRemoteEvent found: " .. tostring(dataRemoteEvent),
            timestamp = os.time()
        })
    else
        table.insert(logs, {
            action = "PLANT_DEBUG",
            message = "❌ dataRemoteEvent not found!",
            timestamp = os.time()
        })
    end
    
    -- Проверяем персонажа
    local character = LocalPlayer.Character
    if character then
        table.insert(logs, {
            action = "PLANT_DEBUG",
            message = "✅ Character found: " .. character.Name,
            timestamp = os.time()
        })
        
        local humanoid = character:FindFirstChild("Humanoid")
        if humanoid then
            table.insert(logs, {
                action = "PLANT_DEBUG",
                message = "✅ Humanoid found",
                timestamp = os.time()
            })
        else
            table.insert(logs, {
                action = "PLANT_DEBUG",
                message = "❌ Humanoid not found",
                timestamp = os.time()
            })
        end
    else
        table.insert(logs, {
            action = "PLANT_DEBUG",
            message = "❌ Character not found",
            timestamp = os.time()
        })
    end
    
    -- Проверяем плот
    local plotNumber = LocalPlayer:GetAttribute("Plot")
    if plotNumber then
        table.insert(logs, {
            action = "PLANT_DEBUG",
            message = "✅ Номер плота: " .. plotNumber,
            timestamp = os.time()
        })
        
        local plot = workspace.Plots[tostring(plotNumber)]
        if plot then
            table.insert(logs, {
                action = "PLANT_DEBUG",
                message = "✅ Plot found in workspace",
                timestamp = os.time()
            })
            
            local plants = plot:FindFirstChild("Plants")
            if plants then
                local plantCount = #plants:GetChildren()
                table.insert(logs, {
                    action = "PLANT_DEBUG",
                    message = "✅ Plants контейнер found, plants: " .. plantCount,
                    timestamp = os.time()
                })
            else
                table.insert(logs, {
                    action = "PLANT_DEBUG",
                    message = "❌ Plants контейнер not found",
                    timestamp = os.time()
                })
            end
        else
            table.insert(logs, {
                action = "PLANT_DEBUG",
                message = "❌ Plot not found in workspace",
                timestamp = os.time()
            })
        end
    else
        table.insert(logs, {
            action = "PLANT_DEBUG",
            message = "❌ Plot attribute not found on player",
            timestamp = os.time()
        })
    end
end

-- Авто-посадка seeds
local function autoPlantSeeds()
    table.insert(logs, {
        action = "PLANT_DEBUG",
        message = "🌱 ФУНКЦИЯ autoPlantSeeds() ВЫЗВАНА",
        timestamp = os.time()
    })
    
    -- Запускаем диагностику при первом вызове
    if not diagnosticsRun then
        testPlantingDiagnostics()
        diagnosticsRun = true
    end
    
    local success, error = pcall(function()
        if not CONFIG.AUTO_PLANT_SEEDS then
            table.insert(logs, {
                action = "PLANT_DEBUG",
                message = "❌ Авто-посадка seeds отключена in конфигурации",
                timestamp = os.time()
            })
            return
        end
        
        table.insert(logs, {
            action = "PLANT_DEBUG",
            message = "✅ Авто-посадка seeds включена, начинаем...",
            timestamp = os.time()
        })
        table.insert(logs, {
            action = "PLANT_DEBUG",
            message = "=== НАЧАЛО АВТО-ПОСАДКИ СЕМЯН ===",
            timestamp = os.time()
        })
        
        -- Проверяем конфигурацию
        table.insert(logs, {
            action = "PLANT_DEBUG",
            message = "CONFIG.AUTO_PLANT_SEEDS = " .. tostring(CONFIG.AUTO_PLANT_SEEDS),
            timestamp = os.time()
        })
        table.insert(logs, {
            action = "PLANT_DEBUG",
            message = "CONFIG.DEBUG_PLANTING = " .. tostring(CONFIG.DEBUG_PLANTING),
            timestamp = os.time()
        })
        
        local bestSeed = getBestSeedFromInventory()
        if not bestSeed then
            table.insert(logs, {
                action = "PLANT_DEBUG",
                message = "❌ No seeds for посадки in inventory",
                timestamp = os.time()
            })
            return
        end
        
        table.insert(logs, {
            action = "PLANT_DEBUG",
            message = "✅ Найдено лучшее семя: " .. bestSeed.Name,
            timestamp = os.time()
        })
        
        -- Ищем пустое место
        local emptySpot = getEmptyPlotSpot()
        if emptySpot then
            table.insert(logs, {
                action = "PLANT_DEBUG",
                message = "🌱 Сажаем in пустое место: Row " .. emptySpot.row .. ", Spot " .. emptySpot.spot.Name,
                timestamp = os.time()
            })
            
            -- Дополнительная проверка места перед посадкой
            local canPlace = emptySpot.spot:GetAttribute("CanPlace")
            table.insert(logs, {
                action = "PLANT_DEBUG",
                message = "🔍 CanPlace атрибут: " .. tostring(canPlace),
                timestamp = os.time()
            })
            
            -- Сажаем in пустое место
            local planted = plantSeed(bestSeed, emptySpot)
            if planted then
                table.insert(logs, {
                    action = "PLANT_SEED",
                    item = bestSeed.Name,
                    location = "Row " .. emptySpot.row,
                    reason = "Посажено in пустое место",
                    timestamp = os.time()
                })
            else
                table.insert(logs, {
                    action = "PLANT_DEBUG",
                    message = "❌ Не удалось посадить семя in пустое место",
                    timestamp = os.time()
                })
            end
        else
            table.insert(logs, {
                action = "PLANT_DEBUG",
                message = "❌ No пустых мест, ищем худшее plant for замены",
                timestamp = os.time()
            })
            -- No пустых мест, ищем худшее plant for замены
            local worstPlant = getWorstPlantForReplacement()
            if worstPlant then
                table.insert(logs, {
                    action = "PLANT_DEBUG",
                    message = "✅ Найдено худшее plant for замены: " .. worstPlant.Name,
                    timestamp = os.time()
                })
                local plantId = worstPlant:GetAttribute("ID")
                if plantId then
                    -- Удаляем худшее plant
                    removePlantFromPlot(plantId)
                    wait(0.5) -- Ждем пока plant удалится
                    
                    -- Ищем hitbox for этого места
                    -- Находим место где было plant for посадки нового
                    local plotNumber = LocalPlayer:GetAttribute("Plot")
                    if plotNumber then
                        local plot = workspace.Plots[tostring(plotNumber)]
                        if plot then
                            local plantRow = worstPlant:GetAttribute("Row")
                            if plantRow then
                                local row = plot.Rows:FindFirstChild(plantRow)
                                if row then
                                    local grass = row:FindFirstChild("Grass")
                                    if grass then
                                        -- Ищем первое доступное место in этом ряду
                                        for _, spot in pairs(grass:GetChildren()) do
                                            local canPlace = spot:GetAttribute("CanPlace")
                                            if canPlace == true then
                                                local spotData = {
                                                    row = plantRow,
                                                    spot = spot,
                                                    grass = grass,
                                                    plot = plot
                                                }
                                                
                                                -- Сажаем новое семя
                                                local planted = plantSeed(bestSeed, spotData)
                                                if planted then
                                                    table.insert(logs, {
                                                        action = "PLANT_SEED",
                                                        item = bestSeed.Name,
                                                        location = "Row " .. plantRow,
                                                        reason = "Заменено plant " .. worstPlant.Name,
                                                        timestamp = os.time()
                                                    })
                                                else
                                                    table.insert(logs, {
                                                        action = "PLANT_DEBUG",
                                                        message = "❌ Не удалось посадить семя вместо " .. worstPlant.Name,
                                                        timestamp = os.time()
                                                    })
                                                end
                                                break
                                            end
                                        end
                                    else
                                        table.insert(logs, {
                                            action = "PLANT_DEBUG",
                                            message = "❌ Не found Grass in ряду " .. plantRow,
                                            timestamp = os.time()
                                        })
                                    end
                                else
                                    table.insert(logs, {
                                        action = "PLANT_DEBUG",
                                        message = "❌ Не found ряд " .. plantRow,
                                        timestamp = os.time()
                                    })
                                end
                            else
                                table.insert(logs, {
                                    action = "PLANT_DEBUG",
                                    message = "❌ У растения " .. worstPlant.Name .. " нет атрибута Row",
                                    timestamp = os.time()
                                })
                            end
                        else
                            table.insert(logs, {
                                action = "PLANT_DEBUG",
                                message = "❌ Plot " .. plotNumber .. " not found",
                                timestamp = os.time()
                            })
                        end
                    else
                        table.insert(logs, {
                            action = "PLANT_DEBUG",
                            message = "❌ Не found номер плота у игрока",
                            timestamp = os.time()
                        })
                    end
                else
                    table.insert(logs, {
                        action = "PLANT_DEBUG",
                        message = "❌ У растения " .. worstPlant.Name .. " нет ID",
                        timestamp = os.time()
                    })
                end
            else
                table.insert(logs, {
                    action = "PLANT_DEBUG",
                    message = "❌ No места for посадки and нет plants for замены",
                    timestamp = os.time()
                })
            end
        end
    end)
    
    if not success then
        print("Error in autoPlantSeeds: " .. tostring(error))
    end
end

-- Авто-полив plants
local function autoWaterPlants()
    local success, error = pcall(function()
        if not CONFIG.AUTO_WATER_PLANTS then
            return
        end
        
        if not currentPlot then
            currentPlot = getCurrentPlot()
            if not currentPlot then
                return
            end
        end
        
        local plants = currentPlot:FindFirstChild("Plants")
        if not plants then
            return
        end
        
        local wateredCount = 0
        
        -- Поливаем только недавно посаженные растения
        for plantId, seedData in pairs(plantedSeeds) do
            if seedData.needsWatering then
                -- Проверяем, существует ли plant
                local plant = nil
                for _, p in pairs(plants:GetChildren()) do
                    if p:GetAttribute("ID") == plantId then
                        plant = p
                        break
                    end
                end
                
                if plant then
                    -- Получаем позицию растения
                    local hitboxes = currentPlot:FindFirstChild("Hitboxes")
                    if hitboxes then
                        local hitbox = hitboxes:FindFirstChild(plantId)
                        if hitbox then
                            local watered = waterPlant(hitbox.Position)
                            if watered then
                                wateredCount = wateredCount + 1
                                if CONFIG.DEBUG_PLANTING then
                                    print("Полито plant: " .. seedData.plantName)
                                end
                            end
                        end
                    end
                    
                    -- Проверяем, выросло ли plant (через 30 секунд считаем выросшим)
                    if os.time() - seedData.timestamp > 30 then
                        seedData.needsWatering = false
                    end
                else
                    -- Plant not found, убираем from списка
                    plantedSeeds[plantId] = nil
                end
            end
        end
        
        if wateredCount > 0 and CONFIG.DEBUG_PLANTING then
            print("Полито plants: " .. wateredCount)
        end
    end)
    
    if not success then
        print("Error in autoWaterPlants: " .. tostring(error))
    end
end

-- Копирование логов in буфер обмена
local function copyLogsToClipboard()
    if #logs == 0 then
        print("Логи пусты!")
        return
    end
    
    local logText = "=== АВТО ПЕТ СЕЛЛЕР ЛОГИ ===\n\n"
    
    for i, log in pairs(logs) do
        local timeStr = os.date("%H:%M:%S", log.timestamp)
        if log.action == "PLANT_DEBUG" or log.action == "PLATFORM_DEBUG" then
            -- Для отладочных сообщений используем message
            logText = logText .. string.format("[%s] %s: %s\n", 
                timeStr, log.action, log.message or "No сообщения")
        else
            -- Для обычных логов используем item и reason
            logText = logText .. string.format("[%s] %s: %s - %s\n", 
                timeStr, log.action, log.item or "No предмета", log.reason or "No причины")
        end
    end
    
    logText = logText .. "\nВсего записей: " .. #logs
    
    -- Пробуем разные способы копирования
    local success = false
    
    -- Метод 1: setclipboard (основной метод for эксплойтеров)
    -- luacheck: ignore setclipboard
    if type(setclipboard) == "function" then
        pcall(function()
            setclipboard(logText)
            print("✅ Логи скопированы in буфер обмена!")
            success = true
        end)
    end
    
    -- Метод 2: _G.setclipboard (альтернативный)
    if not success and _G.setclipboard then
        pcall(function()
            _G.setclipboard(logText)
            print("✅ Логи скопированы in буфер обмена!")
            success = true
        end)
    end
    
    -- Метод 3: game:GetService("TextService") (if доступен)
    if not success then
        pcall(function()
            local TextService = game:GetService("TextService")
            if TextService then
                -- Создаем временный GUI for копирования
                local tempGui = Instance.new("ScreenGui")
                tempGui.Name = "TempClipboard"
                tempGui.Parent = PlayerGui
                
                local textBox = Instance.new("TextBox")
                textBox.Size = UDim2.new(0, 1, 0, 1)
                textBox.Position = UDim2.new(0, -1000, 0, -1000) -- Скрываем за экраном
                textBox.Text = logText
                textBox.Parent = tempGui
                
                -- Выделяем and копируем
                textBox:CaptureFocus()
                wait(0.1)
                textBox:SelectAll()
                wait(0.1)
                
                -- Симулируем Ctrl+C
                local userInputService = game:GetService("UserInputService")
                userInputService:InputBegan(Enum.KeyCode.LeftControl, false)
                wait(0.1)
                userInputService:InputBegan(Enum.KeyCode.C, false)
                wait(0.1)
                userInputService:InputEnded(Enum.KeyCode.C, false)
                wait(0.1)
                userInputService:InputEnded(Enum.KeyCode.LeftControl, false)
                
                wait(0.5)
                tempGui:Destroy()
                print("✅ Логи скопированы in буфер обмена!")
                success = true
            end
        end)
    end
    
    -- Метод 4: TextBox with выделением (видимый)
    if not success then
        pcall(function()
            local tempGui = Instance.new("ScreenGui")
            tempGui.Name = "TempClipboard"
            tempGui.Parent = PlayerGui
            
            local textBox = Instance.new("TextBox")
            textBox.Size = UDim2.new(0, 400, 0, 300)
            textBox.Position = UDim2.new(0.5, -200, 0.5, -150)
            textBox.Text = logText
            textBox.TextWrapped = true
            textBox.TextScaled = true
            textBox.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
            textBox.TextColor3 = Color3.fromRGB(255, 255, 255)
            textBox.BorderSizePixel = 2
            textBox.BorderColor3 = Color3.fromRGB(100, 100, 100)
            textBox.Parent = tempGui
            
            -- Выделяем весь текст
            textBox:CaptureFocus()
            wait(0.1)
            textBox:SelectAll()
            wait(0.1)
            
            -- Ждем 3 секунды, чтобы пользователь мог скопировать вручную
            print("📋 Логи отображены in окне! Выделите текст and нажмите Ctrl+C for копирования")
            wait(3)
            
            tempGui:Destroy()
            success = true
        end)
    end
    
    -- Метод 5: Просто выводим in консоль
    if not success then
        print("=== ЛОГИ (скопируйте вручную) ===")
        print(logText)
        print("=== КОНЕЦ ЛОГОВ ===")
    end
    
    print("Всего записей in логах: " .. #logs)
end

-- Функция for удаления дублирующихся записей in логах
local function removeDuplicateLogs()
    local uniqueLogs = {}
    local seen = {}
    
    for _, log in ipairs(logs) do
        local key = log.action .. "|" .. (log.item or "") .. "|" .. (log.message or "") .. "|" .. (log.reason or "")
        if not seen[key] then
            seen[key] = true
            table.insert(uniqueLogs, log)
        end
    end
    
    logs = uniqueLogs
    print("Очищено дублирующихся записей in логах. Осталось: " .. #logs)
end

-- Основная функция
local function main()
    print("=== AUTO PET SELLER & BUYER - ONE CLICK FARM ===")
    print("Запуск всех функций автоматически...")
    
    -- Initialization
    initialize()
    
    -- Redeem codes при запуске
    redeemCodes()
    
    -- Проверка покупки platforms при запуске
    table.insert(logs, {
        action = "PLATFORM_DEBUG",
        message = "=== ПРИНУДИТЕЛЬНАЯ ПРОВЕРКА ПЛАТФОРМ ПРИ ЗАПУСКЕ ===",
        timestamp = os.time()
    })
    
    -- Простой тест логирования
    table.insert(logs, {
        action = "PLATFORM_DEBUG",
        message = "🧪 ТЕСТ ЛОГИРОВАНИЯ - ЭТО СООБЩЕНИЕ ДОЛЖНО БЫТЬ ВИДНО",
        timestamp = os.time()
    })
    
    -- Сначала запускаем диагностику
    table.insert(logs, {
        action = "PLATFORM_DEBUG",
        message = "=== НАЧИНАЕМ ДИАГНОСТИКУ ПЛАТФОРМ ===",
        timestamp = os.time()
    })
    
    local success, error = pcall(function()
        testPlatformBuying()
    end)
    
    if not success then
        table.insert(logs, {
            action = "PLATFORM_DEBUG",
            message = "❌ Error in testPlatformBuying: " .. tostring(error),
            timestamp = os.time()
        })
    else
        table.insert(logs, {
            action = "PLATFORM_DEBUG",
            message = "✅ testPlatformBuying выполнен успешно",
            timestamp = os.time()
        })
    end
    
    if CONFIG.AUTO_BUY_PLATFORMS then
        table.insert(logs, {
            action = "PLATFORM_DEBUG",
            message = "CONFIG.AUTO_BUY_PLATFORMS = true, запускаем autoBuyPlatforms()",
            timestamp = os.time()
        })
        
        local success, error = pcall(function()
            autoBuyPlatforms()
        end)
        
        if not success then
            table.insert(logs, {
                action = "PLATFORM_DEBUG",
                message = "❌ Error in autoBuyPlatforms: " .. tostring(error),
                timestamp = os.time()
            })
        end
    else
        table.insert(logs, {
            action = "PLATFORM_DEBUG",
            message = "CONFIG.AUTO_BUY_PLATFORMS = false, авто-покупка platforms отключена in конфигурации",
            timestamp = os.time()
        })
    end
    
    -- Дополнительная проверка через 3 секунды
    spawn(function()
        wait(3)
        table.insert(logs, {
            action = "PLATFORM_DEBUG",
            message = "=== ДОПОЛНИТЕЛЬНАЯ ПРОВЕРКА ПЛАТФОРМ ЧЕРЕЗ 3 СЕКУНДЫ ===",
            timestamp = os.time()
        })
        autoBuyPlatforms()
    end)
    
    -- Test посадки plants при запуске
    table.insert(logs, {
        action = "PLANT_DEBUG",
        message = "=== ТЕСТ ПОСАДКИ РАСТЕНИЙ ПРИ ЗАПУСКЕ ===",
        timestamp = os.time()
    })
    autoPlantSeeds()
    
    -- Test улучшенной системы посадки
    wait(2)
    testImprovedPlantingSystem()
    
    -- Дополнительный тест через 5 секунд
    spawn(function()
        wait(5)
        table.insert(logs, {
            action = "PLANT_DEBUG",
            message = "=== ДОПОЛНИТЕЛЬНЫЙ ТЕСТ ПОСАДКИ ЧЕРЕЗ 5 СЕКУНД ===",
            timestamp = os.time()
        })
        autoPlantSeeds()
        
        -- Очищаем дублирующиеся логи после тестов
        wait(2)
        removeDuplicateLogs()
    end)
    
    -- Настройка горячей клавиши for логов
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == CONFIG.LOG_COPY_KEY then
            copyLogsToClipboard()
        end
    end)
    
    -- Основной цикл авто-продажи and замены брейнротов
    spawn(function()
        print("Запуск цикла авто-продажи and замены брейнротов...")
        while true do
            autoSellPets()
            wait(1) -- Небольшая пауза между продажей and заменой
            if CONFIG.AUTO_REPLACE_BRAINROTS then
                autoReplaceBrainrots()
            end
            wait(1) -- Небольшая пауза перед покупкой platforms
            if CONFIG.AUTO_BUY_PLATFORMS then
                table.insert(logs, {
                    action = "PLATFORM_DEBUG",
                    message = "Вызываем autoBuyPlatforms from основного цикла...",
                    timestamp = os.time()
                })
                autoBuyPlatforms()
            else
                table.insert(logs, {
                    action = "PLATFORM_DEBUG",
                    message = "Авто-покупка platforms отключена",
                    timestamp = os.time()
                })
            end
            wait(1) -- Небольшая пауза перед открытием яиц
            autoOpenEggs() -- Автоматически открываем яйца
            wait(2) -- Проверяем каждые 2 секунды
        end
    end)
    
    -- Основной цикл авто-покупки
    spawn(function()
        print("Запуск цикла авто-покупки...")
        while true do
            if CONFIG.AUTO_BUY_SEEDS then
                autoBuySeeds()
            end
            if CONFIG.AUTO_BUY_GEAR then
                autoBuyGear()
            end
            wait(CONFIG.BUY_INTERVAL)
        end
    end)
    
    -- Основной цикл авто-сбора монет
    spawn(function()
        print("Запуск цикла авто-сбора монет...")
        while true do
            if CONFIG.AUTO_COLLECT_COINS then
                autoCollectCoins()
            end
            wait(CONFIG.COLLECT_INTERVAL)
        end
    end)
    
    -- Основной цикл авто-посадки seeds
    spawn(function()
        print("Запуск цикла авто-посадки seeds...")
        -- Принудительный тест посадки при запуске
        table.insert(logs, {
            action = "PLANT_DEBUG",
            message = "=== ТЕСТ ПОСАДКИ ПРИ ЗАПУСКЕ ===",
            timestamp = os.time()
        })
        autoPlantSeeds()
        wait(2)
        
        while true do
            if CONFIG.AUTO_PLANT_SEEDS then
                autoPlantSeeds()
            end
            wait(CONFIG.PLANT_INTERVAL)
        end
    end)
    
    -- Основной цикл авто-полива plants
    spawn(function()
        print("Запуск цикла авто-полива plants...")
        while true do
            if CONFIG.AUTO_WATER_PLANTS then
                autoWaterPlants()
            end
            wait(CONFIG.WATER_INTERVAL)
        end
    end)
    
    -- Основной цикл авто-покупки platforms
    spawn(function()
        print("Запуск цикла авто-покупки platforms...")
        while true do
            if CONFIG.AUTO_BUY_PLATFORMS then
                autoBuyPlatforms()
            end
            wait(CONFIG.PLATFORM_BUY_INTERVAL)
        end
    end)
    
    
    print("=== ВСЕ ФУНКЦИИ АКТИВНЫ ===")
    print("✅ Auto-sell pets Rare-Legendary (умная адаптивная система)")
    print("✅ Auto-buy seeds and предметов from Gear Shop")
    print("✅ Auto-collect coins from platforms каждые " .. CONFIG.COLLECT_INTERVAL .. " секунд")
    print("✅ Авто-замена брейнротов on лучших (сразу после продажи)")
    print("✅ Авто-посадка seeds каждые " .. CONFIG.PLANT_INTERVAL .. " секунд")
    print("✅ Авто-полив plants каждые " .. CONFIG.WATER_INTERVAL .. " секунд")
    print("✅ Авто-покупка platforms каждые " .. CONFIG.PLATFORM_BUY_INTERVAL .. " секунд")
    print("✅ Авто-открытие Lucky Eggs (Meme/Godly/Secret)")
    print("✅ Redeem codes при запуске")
    print("✅ Копирование логов по F4")
    print("")
    print("🚀 ФАРМ НАЧАТ! Просто играй and получай прибыль!")
end

-- Запуск скрипта
main()
