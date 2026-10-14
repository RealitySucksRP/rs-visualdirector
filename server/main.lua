-- RS Visual Director v2.6.0 - Server
-- Global visual control, optional personal persistence and safe temporary scene pushes.

local serverStyle = Config.DefaultStyle or nil
local serverStrength = nil
local stateRevision = 0
local activePushes = {}
local sessionPreferences = {}
local databaseReady = false
local databaseWarned = false
local requestCooldowns = {}

-- ---------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------

local function trim(value)
    if value == nil then return '' end
    return tostring(value):match('^%s*(.-)%s*$') or ''
end

local function cleanText(msg)
    return tostring(msg or ''):gsub('%^%d', '')
end

local function dprint(msg)
    if Config.Debug then print(('[rs-visualdirector] %s'):format(cleanText(msg))) end
end

local function getIdentifier(source)
    local identifier = RSVD_Bridge and RSVD_Bridge.Server and RSVD_Bridge.Server.GetIdentifier
        and RSVD_Bridge.Server.GetIdentifier(source)
        or GetPlayerIdentifierByType(source, 'license')
        or GetPlayerIdentifier(source, 0)
        or ('source:' .. tostring(source))
    return identifier
end

local function isAdmin(source)
    if RSVD_Bridge and RSVD_Bridge.Server and RSVD_Bridge.Server.HasPermission then
        return RSVD_Bridge.Server.HasPermission(source)
    end
    if source == 0 then return Config.AllowConsole end
    if not Config.RequireAce then return true end
    return IsPlayerAceAllowed(source, Config.AdminAce)
end

local function isRateLimited(source, key, cooldownMs)
    if source == 0 then return false end
    local now = GetGameTimer()
    local bucket = requestCooldowns[source] or {}
    local last = bucket[key] or 0
    if now - last < (cooldownMs or 300) then return true end
    bucket[key] = now
    requestCooldowns[source] = bucket
    return false
end

local function notify(source, msg, notifyType, duration)
    if RSVD_Bridge and RSVD_Bridge.Server and RSVD_Bridge.Server.Notify then
        RSVD_Bridge.Server.Notify(source, msg, notifyType or 'inform', duration or 5000)
    elseif source == 0 then
        print('[rs-visualdirector] ' .. cleanText(msg))
    else
        TriggerClientEvent('rs-visual:notify', source, msg)
    end

    -- Long command output is also mirrored to chat so style lists are readable.
    if source ~= 0 and #cleanText(msg) > 140 then
        TriggerClientEvent('chat:addMessage', source, { args = { Config.ChatPrefix, msg } })
    end
end

local function styleExists(styleName)
    local style = styleName and Config.Styles and Config.Styles[styleName]
    return type(style) == 'table' and type(style.timecycle) == 'string' and style.timecycle ~= ''
end

local function normalizeStyleName(styleName)
    styleName = trim(styleName):lower():gsub('%-', '_')
    if styleName == 'clear' or styleName == 'none' then styleName = 'off' end
    return styleName
end

local function getStyleStrength(styleName, strength)
    local style = Config.Styles[styleName] or {}
    local finalStrength = tonumber(strength) or tonumber(style.strength) or 0.35
    local minStrength = tonumber(style.minStrength) or 0.0
    local maxStrength = tonumber(style.maxStrength) or 1.0

    if minStrength < 0.0 then minStrength = 0.0 end
    if maxStrength > 1.0 then maxStrength = 1.0 end
    if maxStrength < minStrength then maxStrength = minStrength end
    if finalStrength < minStrength then finalStrength = minStrength end
    if finalStrength > maxStrength then finalStrength = maxStrength end
    return finalStrength
end

local function databaseConfig()
    local cfg = Config.Database or {}
    local resource = tostring(cfg.resource or 'oxmysql')
    local tableName = tostring(cfg.table or 'rs_visual_preferences'):gsub('[^%w_]', '')
    if tableName == '' then tableName = 'rs_visual_preferences' end
    return cfg.enabled ~= false, resource, tableName
end

local function refreshDatabaseState()
    local enabled, resource = databaseConfig()
    databaseReady = enabled and GetResourceState(resource) == 'started'
    return databaseReady
end

local function dbQuery(sql, params, callback)
    local _, resource = databaseConfig()
    if not refreshDatabaseState() then
        return false
    end

    local ok, err = pcall(function()
        exports[resource]:query(sql, params or {}, callback)
    end)
    if not ok then
        databaseReady = false
        print(('[rs-visualdirector] oxmysql query failed: %s'):format(tostring(err)))
        return false
    end
    return true
end

local function dbUpdate(sql, params, callback)
    local _, resource = databaseConfig()
    if not refreshDatabaseState() then
        return false
    end

    local ok, err = pcall(function()
        exports[resource]:update(sql, params or {}, callback)
    end)
    if not ok then
        databaseReady = false
        print(('[rs-visualdirector] oxmysql update failed: %s'):format(tostring(err)))
        return false
    end
    return true
end

local function setupDatabase()
    local enabled, resource, tableName = databaseConfig()
    if not enabled then
        dprint('database persistence disabled in config')
        return
    end

    if GetResourceState(resource) ~= 'started' then
        if Config.AllowPersonalOverride and not databaseWarned then
            databaseWarned = true
            print(('[rs-visualdirector] oxmysql is not running. Personal preferences will be session-only.'))
        end
        return
    end

    databaseReady = true
    local sql = ([=[
        CREATE TABLE IF NOT EXISTS `%s` (
            `identifier` VARCHAR(80) NOT NULL,
            `style` VARCHAR(50) NOT NULL,
            `strength` FLOAT NOT NULL DEFAULT -1,
            PRIMARY KEY (`identifier`)
        )
    ]=]):format(tableName)

    dbQuery(sql, {}, function()
        databaseReady = true
        dprint(('preference table ready: %s'):format(tableName))
    end)
end

local function sendCurrentStyle(target)
    if serverStyle and styleExists(serverStyle) then
        TriggerClientEvent('rs-visual:applyStyle', target, serverStyle, serverStrength, true)
    else
        TriggerClientEvent('rs-visual:clear', target, 'sync')
    end
end

local function clearGlobalStyle(reason)
    stateRevision = stateRevision + 1
    serverStyle = nil
    serverStrength = nil
    dprint(('clearing global style reason=%s revision=%s'):format(reason or 'server', stateRevision))
    TriggerClientEvent('rs-visual:clear', -1, reason or 'server')
    return true, stateRevision
end

local function pushStyleToPlayer(playerId, style, strength, force)
    TriggerClientEvent('rs-visual:applyStyle', playerId, style, strength, force == true)
end

local function setGlobalStyle(styleName, strength, reason, forceAll)
    styleName = normalizeStyleName(styleName)
    if styleName == 'off' then return clearGlobalStyle(reason or 'server') end
    if not styleExists(styleName) then
        return false, ('Unknown style "%s". Use /%s list.'):format(styleName, Config.Command or 'visual')
    end

    local finalStrength = getStyleStrength(styleName, strength)
    stateRevision = stateRevision + 1
    serverStyle = styleName
    serverStrength = finalStrength

    dprint(('setting style=%s strength=%.2f reason=%s forceAll=%s revision=%s'):format(
        styleName, finalStrength, reason or 'server', tostring(forceAll == true), stateRevision))

    for _, playerId in ipairs(GetPlayers()) do
        local pid = tonumber(playerId)
        local identifier = getIdentifier(pid)
        local hasPersonal = sessionPreferences[identifier] ~= nil

        if forceAll or not Config.AllowPersonalOverride or not hasPersonal then
            pushStyleToPlayer(pid, styleName, finalStrength, forceAll == true)
        end
    end

    return true, stateRevision
end

local function listStyles(src)
    local names = {}
    local seen = {}
    for _, name in ipairs(Config.StyleOrder or {}) do
        if styleExists(name) then names[#names + 1] = name; seen[name] = true end
    end
    if Config.Menu and Config.Menu.showExperimental == true then
        for _, name in ipairs(Config.ExperimentalOrder or {}) do
            if styleExists(name) and not seen[name] then names[#names + 1] = name; seen[name] = true end
        end
    end
    for name, style in pairs(Config.Styles or {}) do
        if not seen[name] and (style.experimental ~= true or (Config.Menu and Config.Menu.showExperimental == true)) then
            names[#names + 1] = name
        end
    end
    notify(src, ('Available styles: %s'):format(table.concat(names, ', ')))
end

local function showHelp(src)
    local command = Config.Command or 'visual'
    notify(src, ('Usage: /%s list | /%s <style> [strength] | /%s off | /%s menu'):format(command, command, command, command))
    notify(src, ('Example: /%s candy_pop 0.68 OR /%s gummy_air 0.30'):format(command, command))
end

local function openMenuFor(src)
    if src == 0 then notify(src, 'The visual menu can only open in-game.'); return end
    if Config.Menu and Config.Menu.enabled == false then notify(src, 'Visual menu is disabled in config.lua.'); return end
    if not isAdmin(src) then notify(src, 'You do not have permission to open the visual menu.'); return end
    TriggerClientEvent('rs-visual:openMenu', src, serverStyle, serverStrength, Config.AllowPersonalOverride and 'personal' or 'sync')
end

local function parseCommandArgs(args, rawCommand, commandName)
    args = args or {}
    if #args > 0 then return args end
    rawCommand = trim(rawCommand or '')
    if rawCommand == '' then return args end
    rawCommand = rawCommand:gsub('^/', '')
    commandName = tostring(commandName or Config.Command or ''):lower()
    local first, rest = rawCommand:match('^(%S+)%s*(.*)$')
    if first and first:lower() == commandName then rawCommand = trim(rest or '') end
    local parsed = {}
    for token in rawCommand:gmatch('%S+') do parsed[#parsed + 1] = token end
    return parsed
end

local function handleGlobalCommand(src, args, rawCommand, commandName)
    args = parseCommandArgs(args, rawCommand, commandName)
    dprint(('command src=%s command=%s args=%s'):format(tostring(src), tostring(commandName), json.encode(args or {})))
    if not isAdmin(src) then notify(src, 'You do not have permission for this command.'); return end

    local action = normalizeStyleName(args[1] or '')
    if action == '' or action == 'help' then showHelp(src); return end
    if action == 'list' or action == 'styles' then listStyles(src); return end
    if action == 'menu' or action == 'ui' or action == 'open' then openMenuFor(src); return end
    if action == 'default' then action = Config.DefaultStyle or 'off' end

    local ok, result = setGlobalStyle(action, args[2], ('command:%s'):format(src), true)
    if not ok then notify(src, result or 'Failed to set visual style.'); return end
    if action == 'off' then
        notify(src, 'Visual style cleared for all players.')
    else
        local style = Config.Styles[action]
        notify(src, ('Applied %s (%s) to all players.'):format(style.label or action, action))
    end
end

-- ---------------------------------------------------------------
-- Player ready / preference flow
-- ---------------------------------------------------------------

RegisterNetEvent('rs-visual:playerReady', function()
    local src = source
    if not Config.AllowPersonalOverride then sendCurrentStyle(src); return end

    local identifier = getIdentifier(src)
    local session = sessionPreferences[identifier]
    if session and styleExists(session.style) then
        TriggerClientEvent('rs-visual:loadSaved', src, session.style, session.strength)
        return
    end

    local _, _, tableName = databaseConfig()
    local sql = ('SELECT style, strength FROM `%s` WHERE identifier = ? LIMIT 1'):format(tableName)
    local started = dbQuery(sql, { identifier }, function(result)
        local row = result and result[1]
        if row and styleExists(row.style) then
            local savedStrength = tonumber(row.strength)
            if savedStrength == -1 then savedStrength = nil end
            sessionPreferences[identifier] = { style = row.style, strength = savedStrength }
            TriggerClientEvent('rs-visual:loadSaved', src, row.style, savedStrength)
        else
            sendCurrentStyle(src)
        end
    end)

    if not started then sendCurrentStyle(src) end
end)

RegisterNetEvent('rs-visual:savePreference', function(style, strength)
    local src = source
    if not Config.AllowPersonalOverride then return end
    style = normalizeStyleName(style)
    if not styleExists(style) then return end

    local identifier = getIdentifier(src)
    local saveStrength = getStyleStrength(style, strength)
    sessionPreferences[identifier] = { style = style, strength = saveStrength }

    local _, _, tableName = databaseConfig()
    local sql = ('INSERT INTO `%s` (identifier, style, strength) VALUES (?, ?, ?) '
        .. 'ON DUPLICATE KEY UPDATE style = VALUES(style), strength = VALUES(strength)'):format(tableName)
    dbUpdate(sql, { identifier, style, saveStrength })
end)

RegisterNetEvent('rs-visual:clearPreference', function()
    local src = source
    local identifier = getIdentifier(src)
    sessionPreferences[identifier] = nil

    local _, _, tableName = databaseConfig()
    dbUpdate(('DELETE FROM `%s` WHERE identifier = ?'):format(tableName), { identifier })
    sendCurrentStyle(src)
end)

AddEventHandler('playerDropped', function()
    requestCooldowns[source] = nil
end)

-- ---------------------------------------------------------------
-- Commands
-- ---------------------------------------------------------------

RegisterCommand(Config.Command or 'visual', function(src, args, rawCommand)
    handleGlobalCommand(src, args or {}, rawCommand, Config.Command or 'visual')
end, false)

for _, alias in ipairs(Config.CommandAliases or {}) do
    RegisterCommand(alias, function(src, args, rawCommand)
        handleGlobalCommand(src, args or {}, rawCommand, alias)
    end, false)
end

RegisterCommand('vset', function(src, args, rawCommand)
    handleGlobalCommand(src, args or {}, rawCommand, 'vset')
end, false)

-- ---------------------------------------------------------------
-- Menu events
-- ---------------------------------------------------------------

RegisterNetEvent('rs-visual:requestMenu', function()
    local src = source
    if isRateLimited(src, 'menu_open', 500) then return end
    openMenuFor(src)
end)

RegisterNetEvent('rs-visual:menuSetStyle', function(styleName, strength)
    local src = source
    if isRateLimited(src, 'menu_style', 300) then return end
    if not isAdmin(src) then notify(src, 'You do not have permission to change visual styles.'); return end

    styleName = normalizeStyleName(styleName or '')
    local ok, err = setGlobalStyle(styleName, strength, ('menu:%s'):format(src), true)
    if not ok then notify(src, err or 'Failed to set visual style from menu.'); return end

    if styleName == 'off' then
        notify(src, 'Visual style cleared for all players.')
    else
        local style = Config.Styles[styleName] or {}
        notify(src, ('Applied %s (%s) to all players from menu.'):format(style.label or styleName, styleName))
    end
end)

RegisterNetEvent('rs-visual:menuClearStyle', function()
    local src = source
    if isRateLimited(src, 'menu_clear', 300) then return end
    if not isAdmin(src) then notify(src, 'You do not have permission to clear visual styles.'); return end
    clearGlobalStyle(('menu:%s'):format(src))
    notify(src, 'Visual style cleared for all players.')
end)

-- ---------------------------------------------------------------
-- Exports for other resources
-- ---------------------------------------------------------------

exports('getServerStyle', function() return serverStyle, serverStrength end)
exports('GetCurrentStyle', function() return serverStyle, serverStrength end)
exports('GetState', function()
    return { style = serverStyle, strength = serverStrength, revision = stateRevision }
end)

exports('setServerStyle', function(style, strength)
    return setGlobalStyle(style, strength, ('export:%s'):format(GetInvokingResource() or 'unknown'), true)
end)
exports('SetStyle', function(style, strength)
    return setGlobalStyle(style, strength, ('export:%s'):format(GetInvokingResource() or 'unknown'), true)
end)
exports('ClearStyle', function()
    return clearGlobalStyle(('export:%s'):format(GetInvokingResource() or 'unknown'))
end)

-- PushStyle applies a temporary mood and returns a revision token.
-- A later manual/global change supersedes the push, so an old timer can never restore stale state.
exports('PushStyle', function(styleName, durationMs, strength)
    styleName = normalizeStyleName(styleName)
    if not styleExists(styleName) then return false, ('Unknown style "%s"'):format(styleName) end

    local previous = { style = serverStyle, strength = serverStrength }
    local ok, tokenOrError = setGlobalStyle(styleName, strength, ('push:%s'):format(GetInvokingResource() or 'unknown'), true)
    if not ok then return false, tokenOrError end

    local token = tokenOrError
    activePushes[token] = previous
    durationMs = tonumber(durationMs) or 0
    if durationMs > 0 then
        CreateThread(function()
            Wait(durationMs)
            local snapshot = activePushes[token]
            if not snapshot then return end
            activePushes[token] = nil
            if stateRevision ~= token then return end
            if snapshot.style and styleExists(snapshot.style) then
                setGlobalStyle(snapshot.style, snapshot.strength, 'push_return', true)
            else
                clearGlobalStyle('push_return')
            end
        end)
    end

    return true, token
end)

exports('PopStyle', function(token)
    token = tonumber(token)
    local snapshot = token and activePushes[token] or nil
    if not snapshot then return false, 'Unknown or expired style token.' end
    activePushes[token] = nil
    if stateRevision ~= token then return false, 'Temporary style was superseded by a newer change.' end

    if snapshot.style and styleExists(snapshot.style) then
        setGlobalStyle(snapshot.style, snapshot.strength, 'push_pop', true)
    else
        clearGlobalStyle('push_pop')
    end
    return true
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        local _, dbResource = databaseConfig()
        if resourceName == dbResource then setupDatabase() end
        return
    end

    setupDatabase()
    local bridgeInfo = RSVD_Bridge and RSVD_Bridge.GetInfo and RSVD_Bridge.GetInfo() or { framework = 'standalone', notifications = 'native' }
    print(('[rs-visualdirector] started v2.6.0 command=/%s menu=/%s framework=%s notify=%s aceRequired=%s mode=%s database=%s'):format(
        Config.Command or 'visual',
        (Config.Menu and Config.Menu.command) or 'visualmenu',
        bridgeInfo.framework or 'standalone',
        bridgeInfo.notifications or 'native',
        tostring(Config.RequireAce == true),
        Config.AllowPersonalOverride and 'personal' or 'sync',
        databaseReady and 'oxmysql' or 'optional/offline'))

    if serverStyle and not styleExists(serverStyle) then
        print(('[rs-visualdirector] WARNING: Config.DefaultStyle "%s" does not exist. Starting clean.'):format(tostring(serverStyle)))
        serverStyle = nil
        serverStrength = nil
    end
end)
