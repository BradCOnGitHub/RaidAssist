
--stopped doing the duplicate savedTable

local DF = _G ["DetailsFramework"]
if (not DF or not DetailsFrameworkCanLoad) then
	return
end

--create namespace
DF.SavedVars = {}

function DF.SavedVars.CreateNewSavedTable(dbTable, savedTableName)
    local defaultVars = dbTable.defaultSavedVars
    local newSavedTable = DF.table.deploy({}, defaultVars)

    dbTable.profiles[savedTableName] = newSavedTable
    return newSavedTable
end

function DF.SavedVars.GetOrCreateAddonSavedTablesPlayerList(addonFrame)
    local addonGlobalSavedTable = _G[addonFrame.savedVarsName]
    local playerList = addonGlobalSavedTable.__savedVarsByGUID
    if (not playerList) then
        addonGlobalSavedTable.__savedVarsByGUID = {}
    end

    return addonGlobalSavedTable.__savedVarsByGUID
end

--addon statup
function DF.SavedVars.LoadSavedVarsForPlayer(addonFrame)
    local playerSerial = UnitGUID("player")

    --savedTableObject is equivalent of "addon.db"
    local dbTable = DF.SavedVars.CreateSavedVarsTable(addonFrame, addonFrame.__savedVarsDefaultTemplate)
    addonFrame.__savedVarsDefaultTemplate = nil
    addonFrame.db = dbTable

    --load players list
    local savedVarsName = DF.SavedVars.GetOrCreateAddonSavedTablesPlayerList(addonFrame)

    local playerSavedTableName = savedVarsName[playerSerial]
    if (not playerSavedTableName) then
        savedVarsName[playerSerial] = "Default"
        playerSavedTableName = savedVarsName[playerSerial]
    end

    local savedTable = addonFrame.db:GetSavedTable(playerSavedTableName)
    if (not savedTable) then
        --create a new saved table for this character
        savedTable = addonFrame.db:CreateNewSavedTable(playerSavedTableName)
    end

    addonFrame.db.profile = savedTable
    addonFrame.db.currentSavedTableName = playerSavedTableName

    return savedTable
end


--base functions
function DF.SavedVars.SetSavedTable(dbTable, savedTableName, createIfNonExistant)
    local savedTableToBeApplied = dbTable:GetSavedTable(savedTableName)

    if (savedTableToBeApplied) then
        --callback unload profile table
        local currentSavedTable = dbTable:GetSavedTable(dbTable:GetCurrentSavedTableName())
        dbTable:TriggerCallback("OnProfileUnload", currentSavedTable)

        dbTable.profile = savedTableToBeApplied
        dbTable:TriggerCallback("OnProfileLoad", savedTableToBeApplied)

    else
        if (createIfNonExistant) then
            local newSavedTable = dbTable:CreateNewSavedTable(savedTableName)

            --callback unload profile table
            local currentSavedTable = dbTable:GetSavedTable(dbTable:GetCurrentSavedTableName())
            dbTable:TriggerCallback("OnProfileUnload", currentSavedTable)

            dbTable.profile = newSavedTable
            dbTable:TriggerCallback("OnProfileLoad", newSavedTable)

        else
            DF:Msg("profile does not exists", savedTableName)
            return
        end
    end
end

function DF.SavedVars.GetSavedTables(dbTable)
    return dbTable.profiles
end

function DF.SavedVars.GetSavedTable(dbTable, savedTableName)
    local profiles = dbTable:GetSavedTables()
    return profiles[savedTableName]
end

function DF.SavedVars.GetCurrentSavedTableName(dbTable)
    return dbTable.currentSavedTableName
end

--duplicate savedTable
function DF.SavedVars.DuplicateSavedTable(dbTable, savedTableName)
    local originalSavedTable = dbTable:GetSavedTable(savedTableName)
    if (originalSavedTable) then
        local newSavedTable = DF.table.copy({}, originalSavedTable)

    end
end

--callbacks
function DF.SavedVars.TriggerCallback(dbTable, callbackName, savedTable)
    local registeredCallbacksTable = dbTable.registeredCallbacks[callbackName]
    for i = 1, #registeredCallbacksTable do
        local callback = registeredCallbacksTable[i]
        DF:CoreDispatch(dbTable.addonFrame.__name, callback.func, savedTable, unpack(callback.payload))
    end
end

function DF.SavedVars.RegisterCallback(dbTable, callbackName, func, ...)
    local registeredCallbacksTable = dbTable.registeredCallbacks[callbackName]
    if (registeredCallbacksTable) then
        --check for duplicates
        for i = 1, #registeredCallbacksTable do
            if (registeredCallbacksTable[i].func == func) then
                return
            end
        end

        --register
        registeredCallbacksTable[#registeredCallbacksTable+1] = {func = func, payload = {...}}

        return true
    end
end

function DF.SavedVars.UnregisterCallback(dbTable, callbackName, func)
    local registeredCallbacksTable = dbTable.registeredCallbacks[callbackName]
    if (registeredCallbacksTable) then
        for i = 1, #registeredCallbacksTable do
            if (registeredCallbacksTable[i].func == func) then
                tremove(registeredCallbacksTable, i)
                return true
            end
        end
    end
end

function DF.SavedVars.CreateSavedVarsTable(addonFrame, templateTable)
    local dbTable = {
        profiles = {},
        defaultSavedVars = templateTable,
        currentSavedTableName = "",
        addonFrame = addonFrame,

        --methods
        GetSavedTable = DF.SavedVars.GetSavedTable,
        SetSavedTable = DF.SavedVars.SetSavedTable,
        GetSavedTables = DF.SavedVars.GetSavedTables,
        GetCurrentSavedTableName = DF.SavedVars.GetCurrentSavedTableName,
        CreateNewSavedTable = DF.SavedVars.CreateNewSavedTable,
        TriggerCallback = DF.SavedVars.TriggerCallback,

        --back compatibility with ace3DB
        GetCurrentProfile = DF.SavedVars.GetCurrentSavedTableName,
        GetProfile = DF.SavedVars.GetSavedTable,
        GetProfiles = DF.SavedVars.GetSavedTables,
        SetProfile = DF.SavedVars.SetSavedTable,
        RegisterCallback = DF.SavedVars.RegisterCallback,

        registeredCallbacks = {
            ["OnProfileLoad"]  = {},
            ["OnProfileUnload"]  = {},
            ["OnProfileCopied"]  = {},
            ["OnProfileReset"]  = {},
            ["OnDatabaseLoad"]  = {},
            ["OnDatabaseShutdown"]  = {},
        },
    }

    return dbTable
end
