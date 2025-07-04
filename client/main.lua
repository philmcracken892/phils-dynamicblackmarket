local RSGCore = exports['rsg-core']:GetCoreObject()
local blackmarketPed = nil
local currentBlip = nil
local currentPrices = {}
function OpenSellMenu()
    RSGCore.Functions.TriggerCallback('phils-blackmarket:server:getInventory', function(inventory)
        if not inventory or next(inventory) == nil then
            lib.notify({ 
                title = 'No Valuable Items', 
                description = 'You have no valuable items to sell! Use "What Can I Sell?" to see accepted items.', 
                type = 'error', 
                timeout = 5000 
            })
            return
        end

        local options = {}
        for _, item in pairs(inventory) do
            local itemName = item.name
            local itemLabel = item.label
            local itemAmount = item.amount
            local sellPrice = currentPrices[itemName] or Config.SpecialItemPrices[itemName].base
            local priceData = Config.SpecialItemPrices[itemName]
            
            table.insert(options, {
                title = itemLabel,
                description = string.format("Sell for $%d each | Range: $%d-$%d | You have: %d", 
                    sellPrice, priceData.min, priceData.max, itemAmount),
                onSelect = function()
                    local input = lib.inputDialog('Sell Items', {
                        {
                            type = 'number',
                            label = 'Amount',
                            description = 'Items to sell',
                            required = true,
                            min = 1,
                            max = itemAmount,
                            default = 1,
                        }
                    })
                    
                    if input and input[1] then
                        local amount = tonumber(input[1])
                        if amount > 0 and amount <= itemAmount then
                            TriggerServerEvent('phils-blackmarket:server:sellItems', itemName, amount)
                        else
                            lib.notify({
                                title = 'Error',
                                description = 'Invalid amount!',
                                type = 'error',
                                timeout = 3000
                            })
                        end
                    end
                end
            })
        end
        
        lib.registerContext({
            id = 'sell_items',
            title = 'Black Market - Sell Items',
            options = options
        })
        lib.showContext('sell_items')
    end)
end
function ShowSellableItems()
    local options = {}
    
    -- Sort items by price (highest first) for better display
    local sortedItems = {}
    for item, priceData in pairs(Config.SpecialItemPrices) do
        table.insert(sortedItems, {item = item, priceData = priceData})
    end
    table.sort(sortedItems, function(a, b) return a.priceData.base > b.priceData.base end)
    
    for _, itemData in ipairs(sortedItems) do
        local item = itemData.item
        local priceData = itemData.priceData
        local itemLabel = RSGCore.Shared.Items[item] and RSGCore.Shared.Items[item].label or item
        local currentPrice = currentPrices[item] or priceData.base
        
        table.insert(options, {
            title = itemLabel,
            description = string.format("Current Price: $%d | Range: $%d - $%d", currentPrice, priceData.min, priceData.max),
            icon = 'fas fa-gem'
        })
    end
    
    lib.registerContext({
        id = 'sellable_items',
        title = 'Black Market - Accepted Items',
        options = options
    })
    lib.showContext('sellable_items')
end
local function CleanupBlackMarket()
    if blackmarketPed then
        DeletePed(blackmarketPed)
        blackmarketPed = nil
    end
    if currentBlip then
        RemoveBlip(currentBlip)
        currentBlip = nil
    end
end
function ShowCurrentPrices()
    RSGCore.Functions.TriggerCallback('phils-blackmarket:server:getInventory', function(inventory)
        local options = {}
        
        -- Create a lookup table for player's items
        local playerItems = {}
        for _, item in pairs(inventory) do
            playerItems[item.name] = item.amount
        end
        
        -- Sort items by price (highest first)
        local sortedItems = {}
        for item, priceData in pairs(Config.SpecialItemPrices) do
            table.insert(sortedItems, {item = item, priceData = priceData})
        end
        table.sort(sortedItems, function(a, b) return a.priceData.base > b.priceData.base end)
        
        for _, itemData in ipairs(sortedItems) do
            local item = itemData.item
            local priceData = itemData.priceData
            local itemLabel = RSGCore.Shared.Items[item] and RSGCore.Shared.Items[item].label or item
            local currentPrice = currentPrices[item] or priceData.base
            local playerAmount = playerItems[item] or 0
            
            local description = string.format("Price: $%d | Range: $%d - $%d", currentPrice, priceData.min, priceData.max)
            if playerAmount > 0 then
                description = description .. string.format(" | You have: %d", playerAmount)
            end
            
            table.insert(options, {
                title = itemLabel,
                description = description,
                icon = playerAmount > 0 and 'fas fa-check-circle' or 'fas fa-circle'
            })
        end
        
        lib.registerContext({
            id = 'current_prices',
            title = 'Black Market - Current Prices',
            options = options
        })
        lib.showContext('current_prices')
    end)
end

local function SetupBlackMarket(coords, shouldCreatePed)
    CleanupBlackMarket()
    
    if shouldCreatePed then
        local model = Config.BlackmarketPed
        RequestModel(model)
        while not HasModelLoaded(model) do
            Wait(10)
        end
        
        blackmarketPed = CreatePed(model, coords.x, coords.y, coords.z - 1.0, coords.w, true, true)
        Citizen.InvokeNative(0x283978A15512B2FE, blackmarketPed, true)
        FreezeEntityPosition(blackmarketPed, true)
        SetEntityInvincible(blackmarketPed, true)
        SetBlockingOfNonTemporaryEvents(blackmarketPed, true)
        
    else
        local timeout = 20000
        local startTime = GetGameTimer()
        while not blackmarketPed and GetGameTimer() - startTime < timeout do
            for _, ped in ipairs(GetGamePool('CPed')) do
                if GetEntityModel(ped) == Config.BlackmarketPed then
                    local pedCoords = GetEntityCoords(ped)
                    if #(vector3(coords.x, coords.y, coords.z) - pedCoords) < 2.0 then
                        blackmarketPed = ped
                        break
                    end
                end
            end
            Wait(100)
        end
        if not blackmarketPed then
            return
        end
    end
    
    -- Create blip
    currentBlip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, coords.x, coords.y, coords.z)
    SetBlipSprite(currentBlip, joaat('blip_cash_arthur'), true)
    SetBlipScale(currentBlip, 0.2)
    Citizen.InvokeNative(0x662D364ABF16DE2F, currentBlip, joaat('BLIP_MODIFIER_MP_COLOR_6'))
    Citizen.InvokeNative(0x9CB1A1623062F402, currentBlip, 'Black Market')
    
    -- Enhanced target options
    local targetOptions = {
        {
            label = 'Open Market',
            icon = 'fas fa-shopping-cart',
            action = function()
                TriggerServerEvent('rsg-shops:server:openstore', 'blackmarket', 'blackmarket', 'Black Market')
            end
        },
        {
            label = 'Sell Items',
            icon = 'fas fa-dollar-sign',
            action = function()
                OpenSellMenu()
            end
        },
        {
            label = 'What Can I Sell?',
            icon = 'fas fa-question-circle',
            action = function()
                ShowSellableItems()
            end
        },
        {
            label = 'Check Current Prices',
            icon = 'fas fa-chart-line',
            action = function()
                ShowCurrentPrices()
            end
        }
    }
    
    exports['rsg-target']:AddTargetEntity(blackmarketPed, { options = targetOptions })
end


Citizen.CreateThread(function()
    local isLoggedIn = false
    while not isLoggedIn do
        Wait(1000)
        if LocalPlayer.state.isLoggedIn then
            isLoggedIn = true
        end
    end
    Wait(1000)
    RSGCore.Functions.TriggerCallback('phils-blackmarket:server:getCoords', function(coords, shouldCreatePed)
        SetupBlackMarket(coords, shouldCreatePed)
    end)
end)


RegisterNetEvent('phils-blackmarket:client:newPos')
AddEventHandler('phils-blackmarket:client:newPos', function(coords)
    lib.notify({
        title = 'Black Market',
        description = 'Black market has moved to a new location!',
        type = 'info',
        timeout = 5000
    })
    RSGCore.Functions.TriggerCallback('phils-blackmarket:server:getCoords', function(newCoords, shouldCreatePed)
        SetupBlackMarket(newCoords, shouldCreatePed)
    end)
end)


RegisterNetEvent('phils-blackmarket:client:priceUpdate')
AddEventHandler('phils-blackmarket:client:priceUpdate', function(prices)
    currentPrices = prices
    lib.notify({
        title = 'Black Market',
        description = 'Black market prices have been updated!',
        type = 'info',
        timeout = 5000
    })
end)


function OpenSellMenu()
    RSGCore.Functions.TriggerCallback('phils-blackmarket:server:getInventory', function(inventory)
       
        if not inventory or next(inventory) == nil then
            lib.notify({ 
                title = 'No Items', 
                description = 'You have no valuable items to sell!', 
                type = 'error', 
                timeout = 3000 
            })
            return
        end

        local options = {}
        for _, item in pairs(inventory) do
            local itemName = item.name
            local itemLabel = item.label
            local itemAmount = item.amount
            local sellPrice = currentPrices[itemName] or Config.SpecialItemPrices[itemName].base
            
            table.insert(options, {
                title = itemLabel,
                description = string.format("Sell %s for $%d each (You have: %d)", itemLabel, sellPrice, itemAmount),
                onSelect = function()
                    local input = lib.inputDialog('Sell Items', {
                        {
                            type = 'number',
                            label = 'Amount',
                            description = 'Items to sell',
                            required = true,
                            min = 1,
                            max = itemAmount,
                            default = 1,
                        }
                    })
                    
                    if input and input[1] then
                        local amount = tonumber(input[1])
                        if amount > 0 and amount <= itemAmount then
                            TriggerServerEvent('phils-blackmarket:server:sellItems', itemName, amount)
                        else
                            lib.notify({
                                title = 'Error',
                                description = 'Invalid amount!',
                                type = 'error',
                                timeout = 3000
                            })
                        end
                    end
                end
            })
        end
        
        lib.registerContext({
            id = 'sell_items',
            title = 'Black Market - Sell Items',
            options = options
        })
        lib.showContext('sell_items')
    end)
end
