local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local coords = nil
local sales = {}
local currentPrices = {}

local function LoadMarketData()
    local result = exports.oxmysql:fetchSync('SELECT item, sales, price FROM blackmarket_data')
    sales = {}
    currentPrices = {}
    
    if result then
        for _, row in ipairs(result) do
            sales[row.item] = row.sales or 0
            currentPrices[row.item] = row.price or (Config.SpecialItemPrices[row.item] and Config.SpecialItemPrices[row.item].base or Config.DefaultSellPrice)
        end
    end
    
    for item, priceData in pairs(Config.SpecialItemPrices) do
        if not currentPrices[item] then
            currentPrices[item] = priceData.base
            exports.oxmysql:insertSync('INSERT INTO blackmarket_data (item, sales, price) VALUES (?, ?, ?)', {item, 0, priceData.base})
        end
    end
end

local function SaveMarketData()
    for item, salesCount in pairs(sales) do
        local price = currentPrices[item] or (Config.SpecialItemPrices[item] and Config.SpecialItemPrices[item].base or Config.DefaultSellPrice)
        exports.oxmysql:executeSync('INSERT INTO blackmarket_data (item, sales, price) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE sales = ?, price = ?', {item, salesCount, price, salesCount, price})
    end
end

Citizen.CreateThread(function()
    LoadMarketData() -- Load initial data
    coords = Config.BlackmarketPositions[math.random(1, #Config.BlackmarketPositions)]
    
    if Config.BlackmarketCycling then
        while true do
            Wait(Config.CycleInterval * 60000)
            coords = Config.BlackmarketPositions[math.random(1, #Config.BlackmarketPositions)]
            TriggerClientEvent('phils-blackmarket:client:newPos', -1, coords)
        end
    end
end)

Citizen.CreateThread(function()
    if not Config.DynamicPricing then return end
    
    while true do
        Wait(Config.PriceUpdateInterval * 60000)
        
        for item, priceData in pairs(Config.SpecialItemPrices) do
            local salesCount = sales[item] or 0
            local basePrice = priceData.base
            local currentPrice = currentPrices[item] or basePrice
            local adjustment = salesCount * Config.PriceAdjustmentRate * basePrice
            local newPrice = math.max(priceData.min, math.min(priceData.max, currentPrice - adjustment))
            currentPrices[item] = math.floor(newPrice)
        end
        
        for item, _ in pairs(sales) do
            if not Config.SpecialItemPrices[item] then
                local basePrice = Config.DefaultSellPrice
                local currentPrice = currentPrices[item] or basePrice
                local adjustment = sales[item] * Config.PriceAdjustmentRate * basePrice
                local newPrice = math.max(Config.DefaultMinPrice, math.min(Config.DefaultMaxPrice, currentPrice - adjustment))
                currentPrices[item] = math.floor(newPrice)
            end
        end
        
        SaveMarketData()
        TriggerClientEvent('phils-blackmarket:client:priceUpdate', -1, currentPrices)
    end
end)

-- Reset sales tracking periodically
Citizen.CreateThread(function()
    if not Config.DynamicPricing then return end
    
    while true do
        Wait(Config.SalesResetInterval * 60000)
        sales = {}
        exports.oxmysql:executeSync('UPDATE blackmarket_data SET sales = 0')
        SaveMarketData()
    end
end)

RSGCore.Functions.CreateCallback('phils-blackmarket:server:getCoords', function(source, cb)
    cb(coords)
end)

RSGCore.Functions.CreateCallback('phils-blackmarket:server:getInventory', function(source, cb)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then
        return cb({})
    end
    
    local inventory = {}
    
    for slot, item in pairs(Player.PlayerData.items or {}) do
        if item and item.amount > 0 then
            table.insert(inventory, {
                name = item.name,
                label = RSGCore.Shared.Items[item.name] and RSGCore.Shared.Items[item.name].label or locale('sv_lang_1'),
                amount = item.amount
            })
        end
    end
    
    cb(inventory)
end)

RegisterNetEvent('phils-blackmarket:server:sellItems', function(item, amount)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local itemData = Player.Functions.GetItemByName(item)
    if not itemData or itemData.amount < amount then
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('cl_lang_12'),
            description = locale('sv_lang_2'),
            type = 'error',
            timeout = 3000
        })
        return
    end
    
    local pricePerItem = currentPrices[item] or (Config.SpecialItemPrices[item] and Config.SpecialItemPrices[item].base or Config.DefaultSellPrice)
    local totalPrice = pricePerItem * amount
    
    Player.Functions.RemoveItem(item, amount)
    TriggerClientEvent('inventory:client:ItemBox', src, RSGCore.Shared.Items[item], 'remove')
    Player.Functions.AddMoney('cash', totalPrice)
    
    sales[item] = (sales[item] or 0) + amount
    SaveMarketData()
    
    TriggerClientEvent('ox_lib:notify', src, {
        title = locale('cl_lang_1'),
        description = string.format(locale('sv_lang_3'), amount, RSGCore.Shared.Items[item].label, totalPrice),
        type = 'success',
        timeout = 3000
    })
end)