-- RS Visual Director v2.8.0 - Client
-- Focused cinematic phone UI, layered mood application, compare mode and developer scanner.

local activeStyle = nil
local activeStrength = 0.0
local activeScreenEffect = nil
local activeShake = false
local activeExtraTimecycle = false
local activeBlackout = false
local fadeToken = 0
local menuOpen = false
local nuiReady = false
local nuiReadyLogged = false
local lastMenuPayload = nil
local compareSnapshot = nil
-- Temporary previews never go through the server, and are cancelled by new sync events.
local previewBaseline = nil
local previewActive = false
local captureSequence = 0
local captureBusy = false
local lastReadyRequest = 0

local scannerActive = false
local scannerName = nil
local scannerStrength = 0.0
local scannerIndex = 0
local scannerPrevious = nil

local comfort = {
    overlays = Config.Comfort == nil or Config.Comfort.overlays ~= false,
    screenEffects = Config.Comfort == nil or Config.Comfort.screenEffects ~= false,
    cameraShake = Config.Comfort ~= nil and Config.Comfort.cameraShake == true,
    blackout = Config.Comfort == nil or Config.Comfort.blackout ~= false
}

local applyExtras

local function dprint(msg)
    if Config.Debug then
        print(('[rs-visualdirector] %s'):format(msg))
    end
end

local function notify(msg, notifyType, duration)
    msg = tostring(msg or ''):gsub('%^%d', '')
    if RSVD_Bridge and RSVD_Bridge.Client and RSVD_Bridge.Client.Notify then
        RSVD_Bridge.Client.Notify(msg, notifyType or 'inform', duration or 5000)
    else
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName(msg)
        EndTextCommandThefeedPostTicker(false, false)
    end
    if Config.Debug then print(('[rs-visualdirector] %s'):format(msg)) end
end

local function boolFromKvp(key, fallback)
    local raw = GetResourceKvpString(key)
    if raw == nil then return fallback end
    return raw == '1' or raw == 'true'
end

local function loadComfort()
    comfort.overlays = boolFromKvp('rs_vd_overlays', comfort.overlays)
    comfort.screenEffects = boolFromKvp('rs_vd_screenfx', comfort.screenEffects)
    comfort.cameraShake = boolFromKvp('rs_vd_shake', comfort.cameraShake)
    comfort.blackout = boolFromKvp('rs_vd_blackout', comfort.blackout)
end

local function setComfort(key, value)
    comfort[key] = value == true
    local kvp = ({
        overlays = 'rs_vd_overlays',
        screenEffects = 'rs_vd_screenfx',
        cameraShake = 'rs_vd_shake',
        blackout = 'rs_vd_blackout'
    })[key]
    if kvp then SetResourceKvp(kvp, value and '1' or '0') end
end


local function effectiveFeature(key)
    if key == 'extraTimecycle' then return true end
    if comfort[key] == nil then return true end
    return comfort[key] == true
end

local function sendOverlay(style)
    local overlay = style and style.overlay or nil
    if not effectiveFeature('overlays') or not overlay then
        SendNUIMessage({ action = 'worldOverlay', enabled = false })
        return
    end

    local overlayType = type(overlay) == 'table' and overlay.type or tostring(overlay)
    local opacity = type(overlay) == 'table' and tonumber(overlay.opacity) or 0.10
    if not overlayType or overlayType == '' then
        SendNUIMessage({ action = 'worldOverlay', enabled = false })
        return
    end

    if not opacity then opacity = 0.10 end
    if opacity < 0.0 then opacity = 0.0 end
    if opacity > 0.45 then opacity = 0.45 end

    SendNUIMessage({
        action = 'worldOverlay',
        enabled = true,
        overlayType = overlayType,
        opacity = opacity
    })
end

local function stopExtras()
    if activeScreenEffect then
        StopScreenEffect(activeScreenEffect)
        activeScreenEffect = nil
    end

    if activeShake then
        StopGameplayCamShaking(true)
        activeShake = false
    end

    if activeExtraTimecycle and type(ClearExtraTimecycleModifier) == 'function' then
        ClearExtraTimecycleModifier()
        activeExtraTimecycle = false
    end

    if activeBlackout then
        if type(SetArtificialLightsState) == 'function' then
            SetArtificialLightsState(false)
        end
        if type(SetArtificialLightsStateAffectsVehicles) == 'function' then
            SetArtificialLightsStateAffectsVehicles(true)
        end
        activeBlackout = false
    end

    SendNUIMessage({ action = 'worldOverlay', enabled = false })
end

local function clearTimecycles()
    ClearTimecycleModifier()
    if type(ClearExtraTimecycleModifier) == 'function' then
        ClearExtraTimecycleModifier()
    end
    activeExtraTimecycle = false
end

local function fadeStrength(fromStrength, toStrength, token)
    local fade = Config.Fade or {}

    if fade.enabled == false then
        SetTimecycleModifierStrength(toStrength)
        return
    end

    local steps = tonumber(fade.steps) or 20
    local delay = tonumber(fade.stepDelay) or 35
    if steps < 1 then steps = 1 end

    for i = 1, steps do
        if fadeToken ~= token then return end
        local progress = i / steps
        SetTimecycleModifierStrength(fromStrength + ((toStrength - fromStrength) * progress))
        Wait(delay)
    end
end

applyExtras = function(style)
    stopExtras()

    if effectiveFeature('extraTimecycle') and style.extraTimecycle and type(SetExtraTimecycleModifier) == 'function' then
        local name = type(style.extraTimecycle) == 'table' and style.extraTimecycle.name or style.extraTimecycle
        if name and tostring(name) ~= '' then
            SetExtraTimecycleModifier(tostring(name))
            activeExtraTimecycle = true
        end
    end

    if effectiveFeature('screenEffects') and style.screenEffect then
        local effectName = nil
        local duration = 0
        local looped = true

        if type(style.screenEffect) == 'table' then
            effectName = style.screenEffect.name
            duration = tonumber(style.screenEffect.duration) or 0
            if style.screenEffect.looped == false then looped = false end
        else
            effectName = tostring(style.screenEffect)
        end

        if effectName and effectName ~= '' then
            StartScreenEffect(effectName, duration, looped)
            activeScreenEffect = effectName
        end
    end

    if effectiveFeature('cameraShake') and style.shake then
        local shakeName = nil
        local intensity = 0.25

        if type(style.shake) == 'table' then
            shakeName = style.shake.name
            intensity = tonumber(style.shake.intensity) or intensity
        else
            shakeName = tostring(style.shake)
        end

        if shakeName and shakeName ~= '' then
            ShakeGameplayCam(shakeName, intensity)
            activeShake = true
        end
    end

    if effectiveFeature('blackout') and style.blackout == true and type(SetArtificialLightsState) == 'function' then
        SetArtificialLightsState(true)
        if type(SetArtificialLightsStateAffectsVehicles) == 'function' then
            SetArtificialLightsStateAffectsVehicles(style.vehiclesAffected ~= false)
        end
        activeBlackout = true
    end

    sendOverlay(style)
end

local function sendMenuState()
    if not menuOpen then return end
    SendNUIMessage({
        action = 'state',
        currentStyle = activeStyle,
        currentStrength = activeStrength or 0.0,
        comparing = compareSnapshot ~= nil,
        previewActive = previewActive,
        previewStyle = previewActive and activeStyle or nil
    })
end

local function cancelScannerWithoutRestore()
    scannerActive = false
    scannerName = nil
    scannerStrength = 0.0
    scannerPrevious = nil
end

local function applyStyle(styleName, strength, reason)
    local style = Config.Styles and Config.Styles[styleName]
    if not style then
        dprint(('unknown style from server: %s'):format(tostring(styleName)))
        return false
    end

    compareSnapshot = nil
    cancelScannerWithoutRestore()

    local finalStrength = tonumber(strength) or tonumber(style.strength) or 0.35
    local minStrength = tonumber(style.minStrength) or 0.0
    local maxStrength = tonumber(style.maxStrength) or 1.0

    if minStrength < 0.0 then minStrength = 0.0 end
    if maxStrength > 1.0 then maxStrength = 1.0 end
    if maxStrength < minStrength then maxStrength = minStrength end
    if finalStrength < minStrength then finalStrength = minStrength end
    if finalStrength > maxStrength then finalStrength = maxStrength end

    fadeToken = fadeToken + 1
    local myToken = fadeToken

    CreateThread(function()
        local fromStrength = activeStrength or 0.0

        if activeStyle and activeStyle ~= styleName then
            fadeStrength(fromStrength, 0.0, myToken)
            if fadeToken ~= myToken then return end
            fromStrength = 0.0
        end

        SetTimecycleModifier(style.timecycle)
        SetTimecycleModifierStrength(fromStrength)
        applyExtras(style)
        fadeStrength(fromStrength, finalStrength, myToken)

        if fadeToken ~= myToken then return end

        activeStyle = styleName
        activeStrength = finalStrength
        dprint(('active style=%s strength=%.2f reason=%s'):format(styleName, finalStrength, reason or 'server'))
        sendMenuState()
    end)

    return true
end

local function clearStyle(reason)
    compareSnapshot = nil
    cancelScannerWithoutRestore()
    fadeToken = fadeToken + 1
    local myToken = fadeToken

    CreateThread(function()
        local fromStrength = activeStrength or 0.0
        if activeStyle then fadeStrength(fromStrength, 0.0, myToken) end
        if fadeToken ~= myToken then return end

        stopExtras()
        clearTimecycles()
        activeStyle = nil
        activeStrength = 0.0
        dprint(('cleared reason=%s'):format(reason or 'server'))
        sendMenuState()
    end)
end

local function beginCompare()
    if compareSnapshot or scannerActive or not activeStyle then return false end

    compareSnapshot = { style = activeStyle, strength = activeStrength }
    fadeToken = fadeToken + 1
    stopExtras()
    clearTimecycles()
    sendMenuState()
    return true
end

local function endCompare()
    if not compareSnapshot then return false end

    local snapshot = compareSnapshot
    compareSnapshot = nil
    local style = Config.Styles and Config.Styles[snapshot.style]
    if not style or activeStyle ~= snapshot.style then
        sendMenuState()
        return false
    end

    SetTimecycleModifier(style.timecycle)
    SetTimecycleModifierStrength(snapshot.strength or style.strength or 0.35)
    applyExtras(style)
    sendMenuState()
    return true
end

-- Local preview is intentionally never sent to server events or preferences.
-- The baseline represents this client's pre-preview visual state.
local function beginLocalPreview(styleName, strength)
    if not menuOpen or scannerActive then return false end
    if styleName ~= 'off' and not (Config.Styles and Config.Styles[styleName]) then return false end
    if compareSnapshot then endCompare() end
    if not previewActive then
        previewBaseline = { style = activeStyle, strength = activeStrength }
    end
    previewActive = true
    if styleName == 'off' then
        clearStyle('local_preview_original')
    else
        applyStyle(styleName, strength, 'local_preview')
    end
    sendMenuState()
    return true
end

local function stopLocalPreview(restore)
    if not previewActive then return false end
    local previous = previewBaseline
    previewActive = false
    previewBaseline = nil
    captureSequence = captureSequence + 1 -- invalidate any pending screenshot callback
    captureBusy = false
    if restore ~= false then
        if previous and previous.style and Config.Styles[previous.style] then
            applyStyle(previous.style, previous.strength, 'preview_restored')
        else
            clearStyle('preview_restored_original')
        end
    end
    sendMenuState()
    return true
end

local function styleLayers(style)
    return {
        extraTimecycle = style.extraTimecycle ~= nil,
        screenEffect = style.screenEffect ~= nil,
        shake = style.shake ~= nil,
        overlay = style.overlay ~= nil,
        blackout = style.blackout == true
    }
end

local function buildMenuStyles()
    local list = {
        {
            name = 'off', label = 'Original GTA',
            description = 'No world mood filter. Restores the normal GTA/FiveM image.',
            category = 'Original', intensity = 'None',
            timecycle = 'none', strength = 0.0, minStrength = 0.0, maxStrength = 0.0,
            color = '#e5e7eb', glowColor = '#ffffff', clear = true,
            ratings = { day = 10, night = 10, interior = 10 },
            layers = {}
        }
    }
    local seen = { off = true }
    local showExperimental = Config.Menu and Config.Menu.showExperimental == true

    local function addStyle(name)
        if not name or seen[name] then return end
        local style = Config.Styles and Config.Styles[name]
        if not style then return end
        if style.enabled == false then return end
        if style.experimental == true and not showExperimental then return end

        seen[name] = true
        list[#list + 1] = {
            name = name,
            label = style.label or name,
            description = style.description or '',
            category = style.category or 'Other',
            intensity = style.intensity or 'Medium',
            experimental = style.experimental == true,
            timecycle = style.timecycle or '',
            strength = tonumber(style.strength) or 0.35,
            minStrength = tonumber(style.minStrength) or 0.0,
            maxStrength = tonumber(style.maxStrength) or 1.0,
            color = style.color or '#43c6e8',
            glowColor = style.glowColor or style.color or '#80e8ff',
            clear = style.clear == true,
            ratings = style.ratings or {},
            layers = styleLayers(style)
        }
    end

    for _, name in ipairs(Config.StyleOrder or {}) do addStyle(name) end
    if showExperimental then
        for _, name in ipairs(Config.ExperimentalOrder or {}) do addStyle(name) end
    end
    for name in pairs(Config.Styles or {}) do addStyle(name) end

    return list
end

local function releaseNuiFocus(reason)
    stopLocalPreview(true)
    endCompare()
    menuOpen = false
    SetNuiFocus(false, false)
    if type(SetNuiFocusKeepInput) == 'function' then SetNuiFocusKeepInput(false) end
    SendNUIMessage({ action = 'close' })
    dprint(('NUI focus released reason=%s'):format(reason or 'unknown'))
end

local function closeMenu(reason)
    releaseNuiFocus(reason or 'close')
end

-- Saved on the player's machine, not as global weather/state and not in a server DB.
local function loadPhoneLayout()
    local raw = GetResourceKvpString('rs_vd_director_layout_v2')
    if raw and raw ~= '' then
        local ok, value = pcall(json.decode, raw)
        if ok and type(value) == 'table' then return value end
    end
    -- Migrate the old phone position instead of silently discarding it.
    raw = GetResourceKvpString('rs_vd_phone_layout_v1')
    if not raw or raw == '' then return nil end
    local ok, legacy = pcall(json.decode, raw)
    if not ok or type(legacy) ~= 'table' then return nil end
    return { view = 'studio', phone = legacy, studio = { x = 0.5, y = 0.5, scale = 1.0 } }
end

local function makeMenuPayload(serverStyle, serverStrength, mode)
    local menu = Config.Menu or {}
    return {
        action = 'open',
        title = menu.title or 'RS Visual Director',
        subtitle = menu.subtitle or 'Server-Wide World Mood Controller',
        closeAfterApply = menu.closeAfterApply == true,
        showWindowLabels = menu.showWindowLabels ~= false,
        styles = buildMenuStyles(),
        currentStyle = serverStyle or activeStyle,
        currentStrength = tonumber(serverStrength) or activeStrength or 0.0,
        mode = mode or (Config.AllowPersonalOverride and 'personal' or 'sync'),
        comfort = comfort,
        uiLayout = loadPhoneLayout(),
        allowGameplayCaptures = menu.allowGameplayCaptures ~= false
    }
end

local function focusMenu(reason)
    SetNuiFocus(true, true)
    if type(SetNuiFocusKeepInput) == 'function' then SetNuiFocusKeepInput(false) end
    dprint(('NUI focus enabled reason=%s'):format(reason or 'open'))
end

local function openMenu(serverStyle, serverStrength, mode)
    local payload = makeMenuPayload(serverStyle, serverStrength, mode)
    lastMenuPayload = payload
    menuOpen = true
    SendNUIMessage(payload)

    if nuiReady then
        focusMenu('open_ready')
    else
        dprint('NUI not ready yet; sent open payload without mouse focus')
    end

    CreateThread(function()
        local attempts = 0
        while menuOpen and attempts < 20 do
            attempts = attempts + 1
            Wait(150)
            if not menuOpen then return end
            SendNUIMessage(payload)
            if nuiReady then
                focusMenu(('ready_attempt_%s'):format(attempts))
                return
            end
        end

        if menuOpen and not nuiReady then
            releaseNuiFocus('nui_not_ready_timeout')
            notify('RS Visual Director UI did not load. Check the html files and F8 console errors.')
        end
    end)
end

RegisterNetEvent('rs-visual:applyStyle', function(style, strength, force)
    stopLocalPreview(false)
    if style == 'off' or not style then
        clearStyle('server')
        return
    end
    applyStyle(style, strength, force and 'server_force' or 'server')
end)

RegisterNetEvent('rs-visual:loadSaved', function(style, strength)
    stopLocalPreview(false)
    if style and Config.Styles[style] then applyStyle(style, strength, 'saved_preference') end
end)

RegisterNetEvent('rs-visual:clear', function(reason) stopLocalPreview(false); clearStyle(reason or 'server') end)
RegisterNetEvent('rs-visual:notify', function(msg) notify(msg) end)
RegisterNetEvent('rs-visual:openMenu', function(serverStyle, serverStrength, mode)
    openMenu(serverStyle, serverStrength, mode)
end)

RegisterNUICallback('ready', function(_, cb)
    nuiReady = true
    if not nuiReadyLogged then
        nuiReadyLogged = true
        dprint('NUI ready')
    end
    if activeStyle and Config.Styles[activeStyle] then sendOverlay(Config.Styles[activeStyle]) end
    if menuOpen and lastMenuPayload then
        SendNUIMessage(lastMenuPayload)
        focusMenu('nui_ready_callback')
    end
    cb({ ok = true })
end)

RegisterNUICallback('saveLayout', function(data, cb)
    if not menuOpen or type(data) ~= 'table' then cb({ ok = false }); return end
    local function sanitizedLayout(input)
        if type(input) ~= 'table' then return nil end
        local x, y, scale = tonumber(input.x), tonumber(input.y), tonumber(input.scale)
        if not x or not y or not scale or x ~= x or y ~= y or scale ~= scale then return nil end
        return {
            x = math.max(0, math.min(1, x)),
            y = math.max(0, math.min(1, y)),
            scale = math.max(0.72, math.min(1.15, scale))
        }
    end
    local phone = sanitizedLayout(data.phone)
    local studio = sanitizedLayout(data.studio)
    if not phone or not studio then cb({ ok = false }); return end
    SetResourceKvp('rs_vd_director_layout_v2', json.encode({
        view = data.view == 'phone' and 'phone' or 'studio',
        phone = phone, studio = studio
    }))
    cb({ ok = true })
end)

RegisterNUICallback('previewStart', function(data, cb)
    data = type(data) == 'table' and data or {}
    cb({ ok = beginLocalPreview(tostring(data.style or ''), tonumber(data.strength)) })
end)
RegisterNUICallback('previewStop', function(_, cb)
    cb({ ok = stopLocalPreview(true) })
end)

-- Optional private screenshot capture. No screenshot data is ever posted to the server.
RegisterNUICallback('captureThumbnail', function(data, cb)
    data = type(data) == 'table' and data or {}
    local name = tostring(data.style or '')
    if not menuOpen or captureBusy or (Config.Menu and Config.Menu.allowGameplayCaptures == false)
        or (name ~= 'off' and not (Config.Styles and Config.Styles[name])) then
        cb({ ok = false, reason = 'Unavailable or busy' }); return
    end
    if GetResourceState('screenshot-basic') ~= 'started' then
        cb({ ok = false, reason = 'Start screenshot-basic before capturing real thumbnails' }); return
    end
    captureBusy = true
    captureSequence = captureSequence + 1
    local ticket = captureSequence
    if not beginLocalPreview(name, tonumber(data.strength)) then
        captureBusy = false
        cb({ ok = false, reason = 'Local preview unavailable' }); return
    end
    cb({ ok = true })
    CreateThread(function()
        -- Let the existing fade finish and allow NUI to hide its chrome.
        Wait(1550)
        if not menuOpen or not captureBusy or ticket ~= captureSequence then return end
        local success, failure = pcall(function()
            exports['screenshot-basic']:requestScreenshot({ encoding = 'jpg', quality = 0.76 }, function(image)
                if not menuOpen or ticket ~= captureSequence then return end
                captureBusy = false
                if type(image) == 'string' and image:sub(1, 11) == 'data:image/' then
                    SendNUIMessage({ action = 'captureResult', style = name, image = image })
                else
                    SendNUIMessage({ action = 'captureResult', style = name, error = 'Screenshot service returned no image' })
                end
            end)
        end)
        if not success and ticket == captureSequence then
            captureBusy = false
            SendNUIMessage({ action = 'captureResult', style = name, error = tostring(failure) })
        end
    end)
    CreateThread(function()
        Wait(11000)
        if captureBusy and captureSequence == ticket then
            captureBusy = false
            captureSequence = captureSequence + 1
            if menuOpen then SendNUIMessage({ action = 'captureResult', style = name, error = 'Screenshot timed out' }) end
        end
    end)
end)


-- Save an actual Live Moment without altering the current synced or local-preview
-- visual. The NUI hides its chrome and stores an image + look locally.
RegisterNUICallback('captureMoment', function(_, cb)
    if not menuOpen or captureBusy or (Config.Menu and Config.Menu.allowGameplayCaptures == false) then
        cb({ ok = false, reason = 'Unavailable or busy' }); return
    end
    if GetResourceState('screenshot-basic') ~= 'started' then
        cb({ ok = false, reason = 'Start screenshot-basic to save Live Moments' }); return
    end
    captureBusy = true
    captureSequence = captureSequence + 1
    local ticket = captureSequence
    cb({ ok = true })
    CreateThread(function()
        -- NUI hides the phone / Studio before the screenshot begins.
        Wait(850)
        if not menuOpen or not captureBusy or captureSequence ~= ticket then return end
        local success, failure = pcall(function()
            exports['screenshot-basic']:requestScreenshot({ encoding = 'jpg', quality = 0.78 }, function(image)
                if not menuOpen or not captureBusy or captureSequence ~= ticket then return end
                captureBusy = false
                if type(image) == 'string' and image:sub(1, 11) == 'data:image/' then
                    SendNUIMessage({ action = 'momentCaptureResult', image = image })
                else
                    SendNUIMessage({ action = 'momentCaptureResult', error = 'No valid screenshot returned by screenshot-basic' })
                end
            end)
        end)
        if not success and captureSequence == ticket then
            captureBusy = false
            SendNUIMessage({ action = 'momentCaptureResult', error = tostring(failure) })
        end
    end)
    CreateThread(function()
        Wait(11000)
        if captureBusy and captureSequence == ticket then
            captureBusy = false
            captureSequence = captureSequence + 1 -- reject late callbacks
            if menuOpen then SendNUIMessage({ action = 'momentCaptureResult', error = 'Screenshot timed out' }) end
        end
    end)
end)

RegisterNUICallback('close', function(_, cb) closeMenu('nui_close'); cb({ ok = true }) end)
RegisterNUICallback('applyStyle', function(data, cb)
    if not menuOpen then cb({ ok = false }); return end
    stopLocalPreview(true)
    data = data or {}
    TriggerServerEvent('rs-visual:menuSetStyle', tostring(data.style or ''), tonumber(data.strength) or nil)
    cb({ ok = true })
end)
RegisterNUICallback('clearStyle', function(_, cb)
    if not menuOpen then cb({ ok = false }); return end
    stopLocalPreview(true)
    TriggerServerEvent('rs-visual:menuClearStyle')
    cb({ ok = true })
end)
RegisterNUICallback('compareStart', function(_, cb) cb({ ok = beginCompare() }) end)
RegisterNUICallback('compareEnd', function(_, cb) cb({ ok = endCompare() }) end)

local function parseArgs(args, raw, commandName)
    args = args or {}
    if #args > 0 then return args end
    raw = tostring(raw or ''):gsub('^/', '')
    commandName = tostring(commandName or ''):lower()
    local first, rest = raw:match('^(%S+)%s*(.*)$')
    if first and first:lower() == commandName then raw = rest or '' end
    local parsed = {}
    for token in tostring(raw or ''):gmatch('%S+') do parsed[#parsed + 1] = token end
    return parsed
end

local function handleMyVisualCommand(args)
    args = args or {}
    local sub = tostring(args[1] or ''):lower()

    if sub == '' then
        if activeStyle then
            notify(('Current: %s (strength: %.2f)'):format(activeStyle, activeStrength or 0.0))
        else
            notify('No visual active. Use /myvisual list to see options.')
        end
        return
    end

    if sub == 'list' then
        local names = {}
        for _, name in ipairs(Config.StyleOrder or {}) do names[#names + 1] = name end
        notify('Available styles: ' .. table.concat(names, ', '))
        return
    end

    if sub == 'off' or sub == 'clear' then
        clearStyle('personal_command')
        TriggerServerEvent('rs-visual:clearPreference')
        notify('Personal visual removed.')
        return
    end

    if not Config.AllowPersonalOverride then
        notify('Personal override is disabled. Admins should use /visualmenu or /visual <style>.')
        return
    end

    if not Config.Styles[sub] then notify(('Unknown style: %s'):format(sub)); return end
    local strength = tonumber(args[2]) or Config.Styles[sub].strength
    applyStyle(sub, strength, 'personal_command')
    TriggerServerEvent('rs-visual:savePreference', sub, strength)
    notify(('Personal visual set to %s.'):format(sub))
end

RegisterCommand('myvisual', function(_, args, raw)
    handleMyVisualCommand(parseArgs(args, raw, 'myvisual'))
end, false)

if Config.Menu and Config.Menu.enabled ~= false then
    RegisterCommand(Config.Menu.command or 'visualmenu', function() TriggerServerEvent('rs-visual:requestMenu') end, false)
    for _, alias in ipairs(Config.Menu.aliases or {}) do
        RegisterCommand(alias, function() TriggerServerEvent('rs-visual:requestMenu') end, false)
    end
end

RegisterCommand('vclose', function() closeMenu('vclose_command') end, false)
RegisterCommand('vfixmouse', function() closeMenu('vfixmouse_command') end, false)
RegisterCommand('visualclose', function() closeMenu('visualclose_command') end, false)
if Config.DeveloperTools == true then
    RegisterCommand('vmenulocal', function() openMenu(activeStyle, activeStrength, 'local') end, false)

    RegisterCommand('vlocal', function(_, args)
        local styleName = tostring(args[1] or ''):lower()
        if styleName == '' or styleName == 'help' then
            print('[rs-visualdirector] Local test: vlocal gummy_air 0.35 | vlocal off')
            return
        end
        if styleName == 'off' or styleName == 'clear' then clearStyle('local_command'); return end
        applyStyle(styleName, args[2], 'local_command')
    end, false)
end

local function scannerCandidates()
    return (Config.Scanner and Config.Scanner.candidates) or {}
end

local function applyScanner(name, strength)
    if not name or name == '' then return false end
    if not scannerActive then scannerPrevious = { style = activeStyle, strength = activeStrength } end

    compareSnapshot = nil
    fadeToken = fadeToken + 1
    stopExtras()
    clearTimecycles()

    scannerStrength = tonumber(strength) or tonumber(Config.Scanner and Config.Scanner.defaultStrength) or 0.35
    if scannerStrength < 0.0 then scannerStrength = 0.0 end
    if scannerStrength > 1.0 then scannerStrength = 1.0 end
    scannerName = tostring(name)
    scannerActive = true

    SetTimecycleModifier(scannerName)
    SetTimecycleModifierStrength(scannerStrength)
    notify(('Scanner: %s @ %.2f'):format(scannerName, scannerStrength))
    return true
end

local function stopScanner(restore)
    if not scannerActive then return end
    fadeToken = fadeToken + 1
    stopExtras()
    clearTimecycles()
    local previous = scannerPrevious
    cancelScannerWithoutRestore()

    if restore and previous and previous.style and Config.Styles[previous.style] then
        applyStyle(previous.style, previous.strength, 'scanner_restore')
    elseif restore and previous and not previous.style then
        activeStyle = nil
        activeStrength = 0.0
    end
end

if Config.DeveloperTools == true and Config.Scanner and Config.Scanner.enabled ~= false then
    RegisterCommand('vscan', function(_, args)
        if not Config.Scanner or Config.Scanner.enabled == false then
            notify('Developer scanner is disabled in config.lua.')
            return
        end

        local action = tostring(args[1] or 'help')
        local lower = action:lower()
        local candidates = scannerCandidates()

        if lower == 'help' then
            print('[rs-visualdirector] /vscan <modifier> [strength] | next | prev | current | save | off')
            return
        end

        if lower == 'off' or lower == 'clear' then stopScanner(true); notify('Scanner closed and previous mood restored.'); return end
        if lower == 'current' then
            notify(scannerActive and (('Scanner: %s @ %.2f'):format(scannerName, scannerStrength)) or 'Scanner is not active.')
            return
        end
        if lower == 'save' then
            if not scannerActive then notify('Nothing to export.'); return end
            print(('[rs-visualdirector] Candidate snippet:\n    timecycle = %q,\n    strength = %.2f,\n    minStrength = 0.05,\n    maxStrength = 0.90,'):format(scannerName, scannerStrength))
            notify('Candidate Lua snippet printed to F8.')
            return
        end

        if lower == 'next' or lower == 'prev' then
            if #candidates == 0 then notify('No scanner candidates configured.'); return end
            if scannerIndex < 1 then
                scannerIndex = lower == 'next' and 0 or 1
            end
            scannerIndex = scannerIndex + (lower == 'next' and 1 or -1)
            if scannerIndex > #candidates then scannerIndex = 1 end
            if scannerIndex < 1 then scannerIndex = #candidates end
            applyScanner(candidates[scannerIndex], args[2] or scannerStrength)
            return
        end

        for i, name in ipairs(candidates) do
            if name == action then scannerIndex = i; break end
        end
        applyScanner(action, args[2])
    end, false)
end

RegisterCommand('vcomfort', function(_, args)
    local key = tostring(args[1] or ''):lower()
    local value = tostring(args[2] or ''):lower()

    local keyMap = { overlay = 'overlays', overlays = 'overlays', screenfx = 'screenEffects', shake = 'cameraShake', blackout = 'blackout' }
    local mapped = keyMap[key]
    if not mapped then
        notify(('Comfort: overlays=%s screenfx=%s shake=%s blackout=%s'):format(
            tostring(comfort.overlays), tostring(comfort.screenEffects), tostring(comfort.cameraShake), tostring(comfort.blackout)))
        notify('Usage: /vcomfort [overlays|screenfx|shake|blackout] [on|off]')
        return
    end

    if value ~= 'on' and value ~= 'off' then notify('Use on or off.'); return end
    setComfort(mapped, value == 'on')
    notify(('Comfort %s: %s'):format(key, value))

    if activeStyle and Config.Styles[activeStyle] then
        applyExtras(Config.Styles[activeStyle])
    end
end, false)


local function requestServerState(delayMs)
    CreateThread(function()
        Wait(tonumber(delayMs) or 0)
        local now = GetGameTimer()
        if now - lastReadyRequest < 1500 then return end
        lastReadyRequest = now
        TriggerServerEvent('rs-visual:playerReady')
    end)
end

AddEventHandler('rs-visual:bridgeReady', function()
    requestServerState(1500)
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    loadComfort()
    requestServerState(1500)
end)

AddEventHandler('playerSpawned', function()
    requestServerState(2500)
end)


CreateThread(function()
    while true do
        Wait(0)
        if menuOpen then
            if IsControlJustReleased(0, 322) or IsControlJustReleased(0, 177) then closeMenu('keyboard_failsafe') end
        else
            Wait(500)
        end
    end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    releaseNuiFocus('resource_stop')
    stopExtras()
    clearTimecycles()
end)

exports('ApplyLocalStyle', function(styleName, strength) return applyStyle(styleName, strength, 'local_export') end)
exports('ClearLocalStyle', function() clearStyle('local_export'); return true end)
exports('GetActiveStyle', function() return activeStyle, activeStrength end)
exports('BeginOriginalCompare', function() return beginCompare() end)
exports('EndOriginalCompare', function() return endCompare() end)
