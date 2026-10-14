-- RS Visual Director - Framework Bridge (server)

local Bridge = RSVD_Bridge
Bridge.Server = Bridge.Server or {}

local qbCore
local esx

local function cleanText(message)
    return tostring(message or ''):gsub('%^%d', '')
end

local function getQBCore()
    if qbCore then return qbCore end
    if not Bridge.ResourceStarted('qb-core') then return nil end
    local ok, core = pcall(function() return exports['qb-core']:GetCoreObject() end)
    if ok then qbCore = core end
    return qbCore
end

local function getESX()
    if esx then return esx end
    if not Bridge.ResourceStarted('es_extended') then return nil end
    local ok, core = pcall(function() return exports['es_extended']:getSharedObject() end)
    if ok then esx = core end
    return esx
end

local function gradeNumber(grade)
    if type(grade) == 'table' then
        return tonumber(grade.level or grade.grade or grade.id) or 0
    end
    return tonumber(grade) or 0
end

local function normalizeJob(job)
    job = type(job) == 'table' and job or {}
    local onDuty = job.onduty
    if onDuty == nil then onDuty = job.onDuty end
    -- ESX jobs do not normally expose a duty field. Treat an absent field as
    -- on-duty so optional job-grade access works consistently across bridges.
    if onDuty == nil then onDuty = true end

    return {
        name = tostring(job.name or 'unemployed'),
        label = tostring(job.label or job.name or 'Unemployed'),
        grade = gradeNumber(job.grade),
        gradeName = tostring((type(job.grade) == 'table' and job.grade.name) or job.grade_name or ''),
        onDuty = onDuty == true
    }
end

function Bridge.Server.GetPlayer(source)
    source = tonumber(source)
    if not source then return nil end

    local framework = Bridge.DetectFramework()
    if framework == 'qbox' and Bridge.ResourceStarted('qbx_core') then
        local ok, player = pcall(function() return exports.qbx_core:GetPlayer(source) end)
        if ok and player then
            local data = player.PlayerData or player
            return {
                source = source,
                framework = framework,
                raw = player,
                data = data,
                identifier = data.citizenid or data.license,
                citizenid = data.citizenid,
                name = (data.charinfo and ((data.charinfo.firstname or '') .. ' ' .. (data.charinfo.lastname or '')):match('^%s*(.-)%s*$'))
                    or data.name or GetPlayerName(source),
                job = normalizeJob(data.job)
            }
        end
    elseif framework == 'qbcore' then
        local core = getQBCore()
        if core and core.Functions and core.Functions.GetPlayer then
            local ok, player = pcall(core.Functions.GetPlayer, source)
            if ok and player then
                local data = player.PlayerData or {}
                return {
                    source = source,
                    framework = framework,
                    raw = player,
                    data = data,
                    identifier = data.citizenid or data.license,
                    citizenid = data.citizenid,
                    name = (data.charinfo and ((data.charinfo.firstname or '') .. ' ' .. (data.charinfo.lastname or '')):match('^%s*(.-)%s*$')) or GetPlayerName(source),
                    job = normalizeJob(data.job)
                }
            end
        end
    elseif framework == 'esx' then
        local core = getESX()
        if core and core.GetPlayerFromId then
            local ok, player = pcall(core.GetPlayerFromId, source)
            if ok and player then
                local job = player.job
                if type(player.getJob) == 'function' then
                    local jobOk, value = pcall(player.getJob)
                    if jobOk and value then job = value end
                end
                local identifier = player.identifier
                if type(player.getIdentifier) == 'function' then
                    local idOk, value = pcall(player.getIdentifier)
                    if idOk and value then identifier = value end
                end
                local name = GetPlayerName(source)
                if type(player.getName) == 'function' then
                    local nameOk, value = pcall(player.getName)
                    if nameOk and value then name = value end
                end
                local group = player.group
                if type(player.getGroup) == 'function' then
                    local groupOk, value = pcall(player.getGroup)
                    if groupOk and value then group = value end
                end
                return {
                    source = source,
                    framework = framework,
                    raw = player,
                    data = player,
                    identifier = identifier,
                    citizenid = identifier,
                    name = name,
                    group = group,
                    job = normalizeJob(job)
                }
            end
        end
    end

    return {
        source = source,
        framework = 'standalone',
        raw = nil,
        data = nil,
        identifier = GetPlayerIdentifierByType(source, 'license') or GetPlayerIdentifier(source, 0),
        citizenid = nil,
        name = GetPlayerName(source),
        job = normalizeJob(nil)
    }
end

function Bridge.Server.GetIdentifier(source)
    source = tonumber(source)
    if not source then return nil end

    local mode = tostring(Config.Bridge and Config.Bridge.identifier or 'framework'):lower()
    if mode == 'framework' then
        local player = Bridge.Server.GetPlayer(source)
        if player and player.identifier and player.identifier ~= '' then
            return tostring(player.identifier)
        end
    end

    return GetPlayerIdentifierByType(source, 'license')
        or GetPlayerIdentifier(source, 0)
        or ('source:' .. tostring(source))
end

local function tableContains(values, target)
    target = tostring(target or ''):lower()
    for key, value in pairs(values or {}) do
        local candidate = type(key) == 'number' and value or key
        if tostring(candidate):lower() == target then return true end
    end
    return false
end

local function identifierAllowed(source, permissions)
    local player = Bridge.Server.GetPlayer(source)
    local identifiers = permissions.identifiers or {}
    if player then
        if player.identifier and tableContains(identifiers, player.identifier) then return true end
        if player.citizenid and tableContains(identifiers, player.citizenid) then return true end
    end

    for _, identifier in ipairs(GetPlayerIdentifiers(source)) do
        if tableContains(identifiers, identifier) then return true end
    end
    return false
end

local function frameworkAdminAllowed(source, permissions)
    local framework = Bridge.DetectFramework()
    local groups = permissions.frameworkGroups and permissions.frameworkGroups[framework] or nil
    if type(groups) ~= 'table' or next(groups) == nil then return false end

    if framework == 'qbcore' then
        local core = getQBCore()
        if core and core.Functions and core.Functions.HasPermission then
            local ok, allowed = pcall(core.Functions.HasPermission, source, groups)
            return ok and allowed == true
        end
    elseif framework == 'esx' then
        local player = Bridge.Server.GetPlayer(source)
        return player and tableContains(groups, player.group)
    elseif framework == 'qbox' then
        -- Qbox recommends ACE for admin permissions. Group checks remain available
        -- here only when a server owner explicitly lists Qbox job/gang groups.
        local ok, allowed = pcall(function() return exports.qbx_core:HasGroup(source, groups) end)
        return ok and allowed == true
    end

    return false
end

local function jobAllowed(source, permissions)
    local jobs = permissions.jobs or {}
    if type(jobs) ~= 'table' or next(jobs) == nil then return false end

    local player = Bridge.Server.GetPlayer(source)
    local job = player and player.job
    if not job then return false end

    local minimum
    for name, grade in pairs(jobs) do
        if tostring(name):lower() == tostring(job.name):lower() then
            minimum = grade
            break
        end
    end
    if minimum == nil then return false end
    if permissions.requireOnDuty == true and not job.onDuty then return false end
    return job.grade >= (tonumber(minimum) or 0)
end

function Bridge.Server.HasPermission(source)
    source = tonumber(source) or 0
    if source == 0 then return Config.AllowConsole == true end
    if Config.RequireAce == false then return true end

    local permissions = (Config.Bridge and Config.Bridge.permissions) or {}

    if permissions.useAce ~= false and IsPlayerAceAllowed(source, Config.AdminAce or 'rs-visualdirector.admin') then
        return true
    end
    if permissions.useIdentifiers == true and identifierAllowed(source, permissions) then
        return true
    end
    if permissions.useFrameworkGroups == true and frameworkAdminAllowed(source, permissions) then
        return true
    end
    if permissions.useJobs == true and jobAllowed(source, permissions) then
        return true
    end

    return false
end

local function mappedType(provider, notifyType)
    notifyType = tostring(notifyType or 'inform'):lower()
    if notifyType == 'primary' or notifyType == 'info' then notifyType = 'inform' end
    if provider == 'qbcore' and notifyType == 'inform' then return 'primary' end
    if provider == 'esx' and notifyType == 'inform' then return 'info' end
    if notifyType ~= 'success' and notifyType ~= 'error' and notifyType ~= 'warning' then return 'inform' end
    return notifyType
end

function Bridge.Server.Notify(source, message, notifyType, duration)
    source = tonumber(source) or 0
    message = cleanText(message)
    duration = tonumber(duration) or 5000

    if source == 0 then
        print('[rs-visualdirector] ' .. message)
        return true
    end

    local provider = Bridge.DetectNotifications()
    if provider == 'qbox' and Bridge.ResourceStarted('qbx_core') then
        local ok = pcall(function()
            exports.qbx_core:Notify(source, message, mappedType('qbox', notifyType), duration)
        end)
        if ok then return true end
    elseif provider == 'qbcore' then
        local core = getQBCore()
        if core and core.Functions and core.Functions.Notify then
            local ok = pcall(core.Functions.Notify, source, message, mappedType('qbcore', notifyType), duration)
            if ok then return true end
        end
    elseif provider == 'esx' then
        local player = Bridge.Server.GetPlayer(source)
        if player and player.raw and type(player.raw.showNotification) == 'function' then
            local ok = pcall(player.raw.showNotification, message, mappedType('esx', notifyType), duration, 'Visual Director')
            if ok then return true end
        end
        TriggerClientEvent('esx:showNotification', source, message, mappedType('esx', notifyType), duration, 'Visual Director')
        return true
    elseif provider == 'ox_lib' and Bridge.ResourceStarted('ox_lib') then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Visual Director',
            description = message,
            type = mappedType('ox_lib', notifyType),
            duration = duration
        })
        return true
    end

    TriggerClientEvent('rs-visual:bridgeNotify', source, message, notifyType or 'inform', duration)
    return true
end


AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == 'qb-core' then qbCore = nil end
    if resourceName == 'es_extended' then esx = nil end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == 'qb-core' then qbCore = nil end
    if resourceName == 'es_extended' then esx = nil end
end)

exports('GetBridgeInfo', function() return Bridge.GetInfo() end)
exports('GetFramework', function() return Bridge.DetectFramework() end)
exports('GetBridgePlayer', function(source) return Bridge.Server.GetPlayer(source) end)
exports('GetBridgeIdentifier', function(source) return Bridge.Server.GetIdentifier(source) end)
exports('HasVisualAccess', function(source) return Bridge.Server.HasPermission(source) end)
exports('BridgeNotify', function(source, message, notifyType, duration)
    return Bridge.Server.Notify(source, message, notifyType, duration)
end)
