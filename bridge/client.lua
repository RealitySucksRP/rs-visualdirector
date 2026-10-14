-- RS Visual Director - Framework Bridge (client)

local Bridge = RSVD_Bridge
Bridge.Client = Bridge.Client or {}

local qbCore
local esx

local function cleanText(message)
    return tostring(message or ''):gsub('%^%d', '')
end

local function mapType(provider, notifyType)
    notifyType = tostring(notifyType or 'inform'):lower()
    if notifyType == 'primary' or notifyType == 'info' then notifyType = 'inform' end

    if provider == 'qbcore' then
        if notifyType == 'inform' then return 'primary' end
        return notifyType
    elseif provider == 'esx' and notifyType == 'inform' then
        return 'info'
    end

    if notifyType ~= 'success' and notifyType ~= 'error' and notifyType ~= 'warning' then
        return 'inform'
    end
    return notifyType
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

local function nativeNotify(message)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(cleanText(message))
    EndTextCommandThefeedPostTicker(false, false)
end

function Bridge.Client.Notify(message, notifyType, duration)
    message = cleanText(message)
    duration = tonumber(duration) or 5000
    local provider = Bridge.DetectNotifications()

    if provider == 'qbox' and Bridge.ResourceStarted('qbx_core') then
        local ok = pcall(function()
            exports.qbx_core:Notify(message, mapType('qbox', notifyType), duration)
        end)
        if ok then return true end
    elseif provider == 'qbcore' then
        local core = getQBCore()
        if core and core.Functions and core.Functions.Notify then
            local ok = pcall(core.Functions.Notify, message, mapType('qbcore', notifyType), duration)
            if ok then return true end
        end
    elseif provider == 'esx' then
        local core = getESX()
        if core and core.ShowNotification then
            local ok = pcall(core.ShowNotification, message, mapType('esx', notifyType), duration)
            if ok then return true end
        end
        if Bridge.ResourceStarted('esx_notify') or Bridge.ResourceStarted('es_extended') then
            TriggerEvent('esx:showNotification', message, mapType('esx', notifyType), duration, 'Visual Director')
            return true
        end
    elseif provider == 'ox_lib' and Bridge.ResourceStarted('ox_lib') then
        TriggerEvent('ox_lib:notify', {
            title = 'Visual Director',
            description = message,
            type = mapType('ox_lib', notifyType),
            duration = duration
        })
        return true
    end

    nativeNotify(message)
    return true
end

function Bridge.Client.GetPlayerData()
    local framework = Bridge.DetectFramework()

    if framework == 'qbox' and Bridge.ResourceStarted('qbx_core') then
        if type(QBX) == 'table' and type(QBX.PlayerData) == 'table' then
            return QBX.PlayerData
        end
    elseif framework == 'qbcore' then
        local core = getQBCore()
        if core and core.Functions and core.Functions.GetPlayerData then
            local ok, data = pcall(core.Functions.GetPlayerData)
            if ok then return data end
        end
    elseif framework == 'esx' then
        local core = getESX()
        if core then return core.PlayerData end
    end

    return nil
end

local function bridgeReady()
    Bridge.Refresh()
    TriggerEvent('rs-visual:bridgeReady', Bridge.GetInfo())
end

RegisterNetEvent('rs-visual:bridgeNotify', function(message, notifyType, duration)
    Bridge.Client.Notify(message, notifyType, duration)
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', bridgeReady)
RegisterNetEvent('esx:playerLoaded', bridgeReady)
RegisterNetEvent('qbx_core:client:onGroupUpdate', function() Bridge.Refresh() end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        Bridge.Refresh()
    elseif resourceName == 'qbx_core' or resourceName == 'qb-core' or resourceName == 'es_extended' or resourceName == 'ox_lib' then
        if resourceName == 'qb-core' then qbCore = nil end
        if resourceName == 'es_extended' then esx = nil end
        bridgeReady()
    end
end)


AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName == 'qb-core' then qbCore = nil end
    if resourceName == 'es_extended' then esx = nil end
end)

exports('GetBridgeInfo', function() return Bridge.GetInfo() end)
exports('GetFramework', function() return Bridge.DetectFramework() end)
exports('BridgeNotify', function(message, notifyType, duration)
    return Bridge.Client.Notify(message, notifyType, duration)
end)
exports('GetBridgePlayerData', function() return Bridge.Client.GetPlayerData() end)
