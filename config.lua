Config = {}

-- Black Market Settings
Config.BlackmarketCycling = false       -- Whether the blackmarket should move around
Config.BlackmarketMoveAtStart = false   -- Moves Blackmarket only on restart if true
Config.CycleInterval = 240              -- How often (in minutes) the blackmarket should move
Config.BlackmarketPed = 'g_m_m_unibanditos_01' -- The NPC model for Black Market
Config.DefaultSellPrice = 1            -- Default price for items not specifically listed
Config.BlackmarketPositions = {         -- Locations where the Black Market can spawn
    vector4(2843.02, -1233.78, 47.70, 169.20)
}

-- Dynamic Pricing Settings
Config.DynamicPricing = true           -- Enable dynamic pricing
Config.PriceUpdateInterval = 2        -- How often (in minutes) to update prices
Config.PriceAdjustmentRate = 0.1       -- Price change per unit sold (e.g., 0.1 = 10% per unit)
Config.MinPriceMultiplier = 0.5        -- Minimum price as a fraction of base price
Config.MaxPriceMultiplier = 2.0        -- Maximum price as a fraction of base price
Config.SalesResetInterval = 1440       -- Reset sales tracking every X minutes (e.g., 24 hours)
Config.DefaultMinPrice = 5             -- Minimum price for non-special items
Config.DefaultMaxPrice = 50            -- Maximum price for non-special items

-- Special prices for valuable items with dynamic price ranges
Config.SpecialItemPrices = {
    ["diamond_uncut"] = { base = 1000, min = 500, max = 2000 },
    ["ruby_uncut"] = { base = 900, min = 450, max = 1800 },
    ["emerald_uncut"] = { base = 900, min = 450, max = 1800 },
    ["sapphire_uncut"] = { base = 900, min = 450, max = 1800 },
    ["goldbar"] = { base = 400, min = 200, max = 800 },
	["gold_bar"] = { base = 400, min = 200, max = 800 },
    ["diamond"] = { base = 1500, min = 750, max = 3000 },
    ["moneywash"] = { base = 50, min = 25, max = 100 },
    ["ruby"] = { base = 1200, min = 600, max = 2400 },
    ["emerald"] = { base = 1200, min = 600, max = 2400 },
    ["opal"] = { base = 900, min = 450, max = 1800 },
    ["goldwatch"] = { base = 400, min = 200, max = 800 },
    ["silver_bar"] = { base = 100, min = 50, max = 200 },
    ["copper_bar"] = { base = 10, min = 5, max = 20 },
    ["iron_bar"] = { base = 10, min = 5, max = 20 },
    ["lead_bar"] = { base = 10, min = 5, max = 20 },
    ["steel_bar"] = { base = 10, min = 5, max = 20 },
    ["zinc_bar"] = { base = 10, min = 5, max = 20 }
}