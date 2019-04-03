local Config = {}

Config.forceUnsupervisedTargeting = false   -- forces the "Unsupervised targeting"- setting for attacking fighters. Default: false

Config.basePriorities = {   -- higher priority targets will be destroyed first
    fighter = 25,
    ship = 20,
    guardian = 15,
    station = 5,
}
Config.additionalPriorities = { --Only for modded additions. Modders: When creating a new Boss then use Entity():setValue("customBoss", anyDataNotNil), to mark it. The Attack script will then activley search for those marked enemies and assign the priority set in the config

    --customBoss = 25
}

return Config
