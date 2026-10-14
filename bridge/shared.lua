-- RS Visual Director - Framework Bridge (shared)
-- Detects Qbox, QBCore, ESX, optional ox_lib notifications, or standalone mode.

RSVD_Bridge = RSVD_Bridge or {}
local Bridge = RSVD_Bridge

local frameworkCache
local notificationCache

local function started(resource)
    local state = GetResourceState(resource)
    return state == 'started' or state == 'starting'
end

local function normalize(value)
    return tostring(value or ''):lower():gsub('%s+', ''):gsub('%-', '_')
end

function Bridge.ResourceStarted(resource)
    return started(resource)
end

function Bridge.DetectFramework(force)
    if frameworkCache and not force then return frameworkCache end

    local configured = normalize(Config.Bridge and Config.Bridge.framework or 'auto')
    if configured ~= '' and configured ~= 'auto' then
        local valid = configured == 'qbox' or configured == 'qbcore' or configured == 'esx' or configured == 'standalone'
        frameworkCache = valid and configured or 'standalone'
        return frameworkCache
    end

    if started('qbx_core') then
        frameworkCache = 'qbox'
    elseif started('qb-core') then
        frameworkCache = 'qbcore'
    elseif started('es_extended') then
        frameworkCache = 'esx'
    else
        frameworkCache = 'standalone'
    end

    return frameworkCache
end

function Bridge.DetectNotifications(force)
    if notificationCache and not force then return notificationCache end

    local configured = normalize(Config.Bridge and Config.Bridge.notifications or 'auto')
    if configured ~= '' and configured ~= 'auto' then
        local valid = configured == 'ox_lib' or configured == 'qbox' or configured == 'qbcore'
            or configured == 'esx' or configured == 'native'
        notificationCache = valid and configured or 'native'
        return notificationCache
    end

    local framework = Bridge.DetectFramework(force)
    if framework == 'qbox' and started('qbx_core') then
        notificationCache = 'qbox'
    elseif framework == 'qbcore' and started('qb-core') then
        notificationCache = 'qbcore'
    elseif framework == 'esx' and started('es_extended') then
        notificationCache = 'esx'
    elseif started('ox_lib') then
        notificationCache = 'ox_lib'
    else
        notificationCache = 'native'
    end

    return notificationCache
end

function Bridge.Refresh()
    frameworkCache = nil
    notificationCache = nil
    return Bridge.DetectFramework(true), Bridge.DetectNotifications(true)
end

function Bridge.GetInfo()
    return {
        framework = Bridge.DetectFramework(),
        notifications = Bridge.DetectNotifications(),
        standalone = Bridge.DetectFramework() == 'standalone'
    }
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == 'qbx_core' or resourceName == 'qb-core' or resourceName == 'es_extended' or resourceName == 'ox_lib' then
        Bridge.Refresh()
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == 'qbx_core' or resourceName == 'qb-core' or resourceName == 'es_extended' or resourceName == 'ox_lib' then
        Bridge.Refresh()
    end
end)
