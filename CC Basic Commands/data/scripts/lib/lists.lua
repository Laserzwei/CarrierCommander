
-- actionTostringMap
list.actionTostringMap[FighterOrders.Attack] = "Attacking ship %s."%_t
list.actionTostringMap[FighterOrders.Defend] = "Defending ship %s."%_t
list.actionTostringMap[FighterOrders.Return] = "Waiting for %i Fighter(s) in %i Squad(s) to dock at %s."%_t
list.actionTostringMap[FighterOrders.FlyToLocation] = "Flying to location."%_t
list.actionTostringMap["TargetButNoFighter"] = "Found a target, but no suitable fighters."%_t
list.actionTostringMap["Mining"] = "Mining asteroids."%_t
list.actionTostringMap["Salvaging"] = "Salvaging wrecks."%_t
list.actionTostringMap["Disengaged"] = "Getting Disengaged."%_t
list.actionTostringMap["NoAsteroid"] = "No asteroids found."%_t
list.actionTostringMap["NoWreckage"] = "No wreckages found."%_t
list.actionTostringMap["AsteroidWithHigherMaterialPresent"] = "Left over asteroids' matrial level is too high: %s."%_t
list.actionTostringMap["WreckageWithHigherMaterialPresent"] = "Left over wreckages' matrial level is too high: %s."%_t
list.actionTostringMap["NoCargospace"] = "Cargobay is full."%_t
list.actionTostringMap["CollectOreLoot"] = "Collecting Ore Loot"%_t

-- actionToColorMap
list.actionToColorMap[FighterOrders.Attack] = ColorRGB(0.1, 0.8, 0.1) -- default green (everything alright)
list.actionToColorMap[FighterOrders.Defend] = ColorRGB(0.3, 0.3, 0.9) -- default blue (idle and active)
list.actionToColorMap[FighterOrders.Return] = ColorRGB(0.5, 0.5, 0.0) -- default orange (docking)
list.actionToColorMap[FighterOrders.FlyToLocation] = ColorRGB(0.0, 0.5, 0.5)  -- never used
list.actionToColorMap["TargetButNoFighter"] = ColorRGB(0.9, 0.1, 0.1)
list.actionToColorMap["Mining"] = ColorRGB(0.1, 0.8, 0.1)
list.actionToColorMap["Salvaging"] = ColorRGB(0.1, 0.8, 0.1)
list.actionToColorMap["Disengaged"] = ColorRGB(0.0, 0.5, 0.5)
list.actionToColorMap["NoAsteroid"] = ColorRGB(0.9, 0.1, 0.1)
list.actionToColorMap["NoWreckage"] = ColorRGB(0.9, 0.1, 0.1)
list.actionToColorMap["AsteroidWithHigherMaterialPresent"] = ColorRGB(0.9, 0.1, 0.1)
list.actionToColorMap["WreckageWithHigherMaterialPresent"] = ColorRGB(0.9, 0.1, 0.1)
list.actionToColorMap["NoCargospace"] = ColorRGB(0.9, 0.1, 0.1)
list.actionToColorMap["CollectOreLoot"] = ColorRGB(0.0, 0.5, 0.5)
