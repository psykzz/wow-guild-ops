local DATABASE_VERSION = 1

local migrations = {
    [0] = function(database)
        database.notes = type(database.notes) == "table" and database.notes or {}
        database.ledger = type(database.ledger) == "table" and database.ledger or {}
    end,
}

local function InitializeDatabase()
    if type(GuildOpsDB) ~= "table" then
        GuildOpsDB = {}
    end

    local version = tonumber(GuildOpsDB.version) or 0
    if version < 0 or version % 1 ~= 0 then
        version = 0
    end

    while version < DATABASE_VERSION do
        local migration = migrations[version]
        if not migration then
            break
        end

        migration(GuildOpsDB)
        version = version + 1
        GuildOpsDB.version = version
    end

    if version == DATABASE_VERSION then
        GuildOpsDB.notes = type(GuildOpsDB.notes) == "table" and GuildOpsDB.notes or {}
        GuildOpsDB.ledger = type(GuildOpsDB.ledger) == "table" and GuildOpsDB.ledger or {}
    end
end

InitializeDatabase()

SLASH_GUILDOPS1 = "/guildops"
SLASH_GUILDOPS2 = "/gops"
SlashCmdList.GUILDOPS = function()
    print("GuildOps is loaded.")
end
