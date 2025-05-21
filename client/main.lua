local RSGCore = exports['rsg-core']:GetCoreObject()
local blackmarketPed = nil
local currentBlip = nil
local currentPrices = {} -- Track dynamic prices


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


local function CreateBlackMarket(coords)
    if not coords then return end
    CleanupBlackMarket()
    
    local model = Config.BlackmarketPed
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(10)
    end
    
    blackmarketPed = CreatePed(model, coords.x, coords.y, coords.z - 1.0, coords.w, true, false, 0, 0)
    Citizen.InvokeNative(0x283978A15512B2FE, blackmarketPed, true)
    FreezeEntityPosition(blackmarketPed, true)
    SetEntityInvincible(blackmarketPed, true)
    SetBlockingOfNonTemporaryEvents(blackmarketPed, true)
    
    currentBlip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, coords.x, coords.y, coords.z)
    SetBlipSprite(currentBlip, joaat('blip_cash_arthur'), true)
    SetBlipScale(currentBlip, 0.2)
    Citizen.InvokeNative(0x662D364ABF16DE2F, currentBlip, joaat('BLIP_MODIFIER_MP_COLOR_6'))
    Citizen.InvokeNative(0x9CB1A1623062F402, currentBlip, 'Black Market')
    
    local targetOptions = {
        {
            label = 'Open Market',
            icon = 'fas fa-dollars',
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
    RSGCore.Functions.TriggerCallback('phils-blackmarket:server:getCoords', function(coords)
        CreateBlackMarket(coords)
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
    CreateBlackMarket(coords)
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
            return lib.notify({ 
                title = 'No Items', 
                description = 'You have no items to sell!', 
                type = 'error', 
                timeout = 3000 
            })
        end

        local options = {}
        for _, item in pairs(inventory) do
            local itemName = item.name
            local itemLabel = item.label
            local itemAmount = item.amount
            local sellPrice = currentPrices[itemName] or Config.SpecialItemPrices[itemName] and Config.SpecialItemPrices[itemName].base or Config.DefaultSellPrice
            
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