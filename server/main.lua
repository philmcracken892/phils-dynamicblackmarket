local RSGCore = exports['rsg-core']:GetCoreObject()
local sales = {}
local currentPrices = {}
local coords = nil
local pedCreator = nil


local function LoadMarketData()
    local result = exports.oxmysql:fetchSync('SELECT item, sales, price FROM blackmarket_data')
    sales = {}
    currentPrices = {}
    if result then
        for _, row in ipairs(result) do
            -- Only load data for special items
            if Config.SpecialItemPrices[row.item] then
                sales[row.item] = row.sales or 0
                currentPrices[row.item] = row.price or Config.SpecialItemPrices[row.item].base
            end
        end
    end
    -- Initialize all special items
    for item, priceData in pairs(Config.SpecialItemPrices) do
        if not currentPrices[item] then
            currentPrices[item] = priceData.base
            exports.oxmysql:insertSync('INSERT INTO blackmarket_data (item, sales, price) VALUES (?, ?, ?)', {item, 0, priceData.base})
        end
    end
end

local function SaveMarketData()
    for item, salesCount in pairs(sales) do
        -- Only save data for special items
        if Config.SpecialItemPrices[item] then
            local price = currentPrices[item] or Config.SpecialItemPrices[item].base
            exports.oxmysql:executeSync('INSERT INTO blackmarket_data (item, sales, price) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE sales = ?, price = ?', {item, salesCount, price, salesCount, price})
        end
    end
end


Citizen.CreateThread(function()
    LoadMarketData()
    coords = Config.BlackmarketPositions[math.random(1, #Config.BlackmarketPositions)]
    
    if Config.BlackmarketCycling then
        while true do
            Wait(Config.CycleInterval * 60000)
            coords = Config.BlackmarketPositions[math.random(1, #Config.BlackmarketPositions)]
            pedCreator = nil
            TriggerClientEvent('phils-blackmarket:client:newPos', -1, coords)
        end
    end
end)

-- Dynamic pricing
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
        SaveMarketData()
        TriggerClientEvent('phils-blackmarket:client:priceUpdate', -1, currentPrices)
    end
end)


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
    if not pedCreator then
        pedCreator = source
        
    end
    cb(coords, pedCreator == source)
end)


RSGCore.Functions.CreateCallback('phils-blackmarket:server:getInventory', function(source, cb)
   
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then
       
        cb({})
        return
    end

    local inventory = {}
    local items = Player.PlayerData.items or {}
  

    for slot, item in pairs(items) do
        if item and item.name and item.amount and item.amount > 0 then
            -- Only include items that are in the special items list
            if Config.SpecialItemPrices[item.name] then
                local itemLabel = RSGCore.Shared.Items[item.name] and RSGCore.Shared.Items[item.name].label or "Unknown Item"
                table.insert(inventory, {
                    name = item.name,
                    label = itemLabel,
                    amount = item.amount
                })
            end
        end
    end

   
    cb(inventory)
end)


RegisterNetEvent('phils-blackmarket:server:sellItems', function(item, amount)
    local src = source
  
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not Player then
      
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            description = "Player data not found!",
            type = 'error',
            timeout = 3000
        })
        return
    end
    
    -- Check if item is in special items list
    if not Config.SpecialItemPrices[item] then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            description = "This item cannot be sold here!",
            type = 'error',
            timeout = 3000
        })
        return
    end
    
    local itemData = Player.Functions.GetItemByName(item)
    if not itemData or itemData.amount < amount then
       
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            description = "You don't have enough of this item!",
            type = 'error',
            timeout = 3000
        })
        return
    end
    
    local pricePerItem = currentPrices[item] or Config.SpecialItemPrices[item].base
    local totalPrice = pricePerItem * amount
    
    Player.Functions.RemoveItem(item, amount)
    TriggerClientEvent('inventory:client:ItemBox', src, RSGCore.Shared.Items[item], 'remove')
    Player.Functions.AddMoney('cash', totalPrice)
    
    sales[item] = (sales[item] or 0) + amount
    SaveMarketData()
    
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Black Market',
        description = string.format("You sold %dx %s for $%d", amount, RSGCore.Shared.Items[item].label, totalPrice),
        type = 'success',
        timeout = 3000
    })
end)
