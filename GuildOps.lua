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

-- Guild bank ledger capture (passive scraping of Blizzard's bank log).
-- The log API only exposes relative ages (years/months/days/hours ago) and has
-- no unique IDs, so entries are matched on identity fields plus an estimated
-- timestamp within the tolerance implied by the age granularity.
local HOUR = 3600
local DAY = 24 * HOUR
local MONEY_LOG_TAB = (MAX_GUILDBANK_TABS or 8) + 1

local function EstimateTimestamp(now, year, month, day, hour)
    year, month, day, hour = year or 0, month or 0, day or 0, hour or 0
    local age = ((year * 365 + month * 30 + day) * 24 + hour) * HOUR
    local tolerance = 2 * HOUR
    if year > 0 then
        tolerance = 2 * 366 * DAY
    elseif month > 0 then
        tolerance = 62 * DAY
    elseif day > 0 then
        tolerance = 2 * DAY
    end
    return now - age, tolerance
end

local function SameEntry(stored, candidate)
    return stored.tab == candidate.tab
        and stored.kind == candidate.kind
        and stored.type == candidate.type
        and stored.name == candidate.name
        and stored.item == candidate.item
        and stored.count == candidate.count
        and stored.amount == candidate.amount
        and stored.moveTab == candidate.moveTab
end

-- Appends candidates not already in the ledger; returns the number added.
-- Each stored entry can satisfy at most one candidate per call, so genuinely
-- repeated identical transactions are still recorded.
local function AppendNewEntries(ledger, candidates)
    local matched = {}
    local added = 0
    for _, candidate in ipairs(candidates) do
        local found = false
        for index, stored in ipairs(ledger) do
            if not matched[index] and SameEntry(stored, candidate)
                and math.abs(stored.time - candidate.time) <= candidate.tolerance then
                matched[index] = true
                found = true
                break
            end
        end
        if not found then
            local entry = {}
            for key, value in pairs(candidate) do
                entry[key] = value
            end
            entry.tolerance = nil
            ledger[#ledger + 1] = entry
            matched[#ledger] = true
            added = added + 1
        end
    end
    return added
end

local function ReadItemTab(tab, now)
    local candidates = {}
    for i = 1, GetNumGuildBankTransactions(tab) or 0 do
        local type, name, item, count, moveTab, year, month, day, hour = GetGuildBankTransaction(tab, i)
        if type then
            local time, tolerance = EstimateTimestamp(now, year, month, day, hour)
            candidates[#candidates + 1] = {
                kind = "item", tab = tab, type = type, name = name, item = item,
                count = count, moveTab = moveTab, time = time, tolerance = tolerance,
            }
        end
    end
    return candidates
end

local function ReadMoneyLog(now)
    local candidates = {}
    for i = 1, GetNumGuildBankMoneyTransactions() or 0 do
        local type, name, amount, year, month, day, hour = GetGuildBankMoneyTransaction(i)
        if type then
            local time, tolerance = EstimateTimestamp(now, year, month, day, hour)
            candidates[#candidates + 1] = {
                kind = "money", tab = MONEY_LOG_TAB, type = type, name = name,
                amount = amount, time = time, tolerance = tolerance,
            }
        end
    end
    return candidates
end

-- Reads whatever log data Blizzard currently has cached for every tab.
-- Re-reading cached data is safe because of the de-duplication above.
local function CaptureBankLog()
    if not (GetNumGuildBankTransactions and GetGuildBankTransaction) then
        return 0
    end
    local now = time()
    local added = 0
    for tab = 1, GetNumGuildBankTabs and GetNumGuildBankTabs() or 0 do
        added = added + AppendNewEntries(GuildOpsDB.ledger, ReadItemTab(tab, now))
    end
    if GetNumGuildBankMoneyTransactions and GetGuildBankMoneyTransaction then
        added = added + AppendNewEntries(GuildOpsDB.ledger, ReadMoneyLog(now))
    end
    return added
end


local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("GUILDBANKFRAME_OPENED")
eventFrame:RegisterEvent("GUILDBANKLOG_UPDATE")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "GUILDBANKFRAME_OPENED" and QueryGuildBankLog and GetNumGuildBankTabs then
        for tab = 1, GetNumGuildBankTabs() do
            QueryGuildBankLog(tab)
        end
        QueryGuildBankLog(MONEY_LOG_TAB)
    else
        CaptureBankLog()
    end
end)

SLASH_GUILDOPS1 = "/guildops"
SLASH_GUILDOPS2 = "/gops"
SlashCmdList.GUILDOPS = function(message)
    if message == "ledger" then
        print("GuildOps ledger entries: " .. #GuildOpsDB.ledger)
        return
    end
    print("GuildOps is loaded.")
end
