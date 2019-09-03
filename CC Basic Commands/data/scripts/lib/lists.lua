
-- actionTostringMap
list.actionTostringMap[FighterOrders.Attack] = "Attacking ship %s."%_t
list.actionTostringMap[FighterOrders.Defend] = "Defending ship %s."%_t
list.actionTostringMap[FighterOrders.Return] = "Waiting for %i Fighter(s) in %i Squad(s) to dock at %s."%_t
list.actionTostringMap[FighterOrders.FlyToLocation] = "Flying to location."%_t
list.actionTostringMap["Mining"] = "Mining asteroids."%_t
list.actionTostringMap["Salvaging"] = "Salvaging wrecks."%_t
list.actionTostringMap["disabled"] = "Getting Disengaged."%_t
list.actionTostringMap["noAsteroid"] = "No asteroids found."%_t
list.actionTostringMap["asteroidWithHigherMaterialPresent"] = "Left over asteroids' mining level is too high: %s."%_t

-- actionToColorMap
list.actionToColorMap[FighterOrders.Attack] = ColorRGB(0.1, 0.8, 0.1) -- default green (everything alright)
list.actionToColorMap[FighterOrders.Defend] = ColorRGB(0.3, 0.3, 0.9) -- default blue (idle and active)
list.actionToColorMap[FighterOrders.Return] = ColorRGB(0.5, 0.5, 0.0) -- default orange (docking)
list.actionToColorMap[FighterOrders.FlyToLocation] = ColorRGB(0.0, 0.5, 0.5)  -- never used
list.actionToColorMap["Mining"] = ColorRGB(0.1, 0.8, 0.1)
list.actionToColorMap["Salvaging"] = ColorRGB(0.1, 0.8, 0.1)
list.actionToColorMap["disabled"] = ColorRGB(0.0, 0.5, 0.5)
list.actionToColorMap["noAsteroid"] = ColorRGB(0.9, 0.1, 0.1)
list.actionToColorMap["asteroidWithHigherMaterialPresent"] = ColorRGB(0.9, 0.1, 0.1)
