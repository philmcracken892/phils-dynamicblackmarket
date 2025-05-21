local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

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
    Citizen.InvokeNative(0x9CB1A1623062F402, currentBlip, locale('cl_lang_1'))
    
    local targetOptions = {
        {
            label = locale('cl_lang_2'),
            icon = 'fas fa-dollars',
            action = function()
                TriggerServerEvent('rsg-shops:server:openstore', 'blackmarket', 'blackmarket', locale('cl_lang_1'))
            end
        },
        {
            label = locale('cl_lang_3'),
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
        title = locale('cl_lang_1'),
        description = locale('cl_lang_4'),
        type = 'info',
        timeout = 5000
    })
    CreateBlackMarket(coords)
end)

RegisterNetEvent('phils-blackmarket:client:priceUpdate')
AddEventHandler('phils-blackmarket:client:priceUpdate', function(prices)
    currentPrices = prices
    lib.notify({
        title = locale('cl_lang_1'),
        description = locale('cl_lang_5'),
        type = 'info',
        timeout = 5000
    })
end)

function OpenSellMenu()
    RSGCore.Functions.TriggerCallback('phils-blackmarket:server:getInventory', function(inventory)
        if not inventory or next(inventory) == nil then
            return lib.notify({
                title = locale('cl_lang_6'),
                description = locale('cl_lang_7'),
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
                description = string.format(locale('cl_lang_8'), itemLabel, sellPrice, itemAmount),
                onSelect = function()
                    local input = lib.inputDialog(locale('cl_lang_9'), {
                        {
                            type = 'number',
                            label = locale('cl_lang_10'),
                            description = locale('cl_lang_11'),
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
                                title = locale('cl_lang_12'),
                                description = locale('cl_lang_13'),
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
            title = locale('cl_lang_14'),
            options = options
        })
        
        lib.showContext('sell_items')
    end)
end