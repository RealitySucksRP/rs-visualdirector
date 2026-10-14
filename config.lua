Config = {}

-- ---------------------------------------------------------------
-- RS Visual Director v2.6.0
-- Open-source cinematic world mood director.
-- Starts with original GTA/FiveM visuals until a mood is applied.
-- ---------------------------------------------------------------

Config.Debug = false

-- false = clean/normal GTA startup.
Config.DefaultStyle = false

-- false = server controls everyone; /visual and the phone apply globally.
-- true  = players may use /myvisual and keep a personal preference.
Config.AllowPersonalOverride = false

Config.AdminAce      = 'rs-visualdirector.admin'
Config.RequireAce    = true
Config.AllowConsole  = true

-- Local-only creator/test commands are compiled in but not registered on live servers.
Config.DeveloperTools = false

Config.Command        = 'visual'
Config.CommandAliases = { 'vf', 'vfilter', 'visualdirector' }

Config.Fade = {
    enabled   = true,
    steps     = 20,
    stepDelay = 35
}

Config.ChatPrefix = '^5[RS Visual]^7'

-- Framework bridge. Auto-detects Qbox, QBCore, ESX, or standalone.
-- No framework is required; standalone is always the safe fallback.
Config.Bridge = {
    framework = 'auto',       -- auto, qbox, qbcore, esx, standalone
    notifications = 'auto',   -- auto, qbox, qbcore, esx, ox_lib, native
    identifier = 'framework', -- framework (citizenid where available) or license

    permissions = {
        useAce = true,
        useFrameworkGroups = false,
        useJobs = false,
        useIdentifiers = false,
        requireOnDuty = true,

        -- Used only when useFrameworkGroups = true.
        -- Qbox recommends ACE for administrator permissions.
        frameworkGroups = {
            qbox = {},
            qbcore = { 'god', 'admin' },
            esx = { 'superadmin', 'admin' }
        },

        -- Used only when useJobs = true. Values are minimum job grades.
        jobs = {
            -- police = 4,
            -- government = 0
        },

        -- Used only when useIdentifiers = true. Supports citizen IDs or licenses.
        identifiers = {
            -- 'license:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
        }
    }
}

-- oxmysql is optional. Global synchronized mode works without it.
-- When personal mode is enabled without oxmysql, preferences last for the session only.
Config.Database = {
    enabled  = false,
    resource = 'oxmysql',
    table    = 'rs_visual_preferences'
}

Config.Menu = {
    enabled = true,
    command = 'visualmenu',
    aliases = { 'vui', 'worldfilter' },
    title = 'Visual Director',
    subtitle = 'Cinematic World Mood Controller',
    closeAfterApply = false,
    showExperimental = false,
    showWindowLabels = false
}

-- Optional layers. Individual players can disable these with /vcomfort.
Config.Comfort = {
    overlays = true,
    screenEffects = true,
    cameraShake = false,
    blackout = true
}


-- Local developer scanner. It never syncs an arbitrary modifier to the server.
-- Use /vscan help in F8/chat.
Config.Scanner = {
    enabled = false,
    defaultStrength = 0.35,
    candidates = {
        'drug_flying_base',
        'MP_corona_heist',
        'TrevorColorCode',
        'MichaelColorCode',
        'FranklinColorCode',
        'NeutralColorCode',
        'hud_def_desat_Neutral',
        'hud_def_desat_cold',
        'REDMIST',
        'hud_def_desat_switch',
        'RaceTurboDark',
        'NG_filmic01',
        'NG_filmic02',
        'NG_filmic03',
        'NG_filmic04',
        'CAMERA_BW',
        'CAMERA_secuirity',
        'CAMERA_secuirity_FUZZ',
        'scanline_cam_cheap',
        'phone_cam1',
        'phone_cam2',
        'phone_cam3',
        'DRUG_gas_huffin',
        'prologue_ending_fog'
    }
}

Config.StyleOrder = {
    'gummy_air',
    'candy_pop',
    'sunset_gold',
    'arctic_blue',
    'neon_green',
    'cinematic_clean',
    'zombie_day',
    'zombie_night',
    'horror_blood',
    'ghost_hunt',
    'police_chase',
    'noir_crime'
}

-- Hidden research presets. Enable Config.Menu.showExperimental to show them.
Config.ExperimentalOrder = {
    'vintage_film',
    'moonlight_film',
    'cctv_watch',
    'security_fuzz',
    'bodycam_scan',
    'toxic_lab',
    'vhs_nightmare',
    'grid_blackout'
}

Config.Styles = {
    gummy_air = {
        label = 'Gummy Air Bright',
        description = 'Dreamy candy-blue Gummy Air atmosphere with luminous highlights.',
        category = 'Colorful',
        intensity = 'Medium',
        timecycle = 'drug_flying_base',
        strength = 0.30,
        minStrength = 0.05,
        maxStrength = 0.55,
        color = '#43c6e8',
        glowColor = '#80e8ff',
        ratings = { day = 9, night = 8, interior = 7 }
    },

    candy_pop = {
        label = 'Candy Pop',
        description = 'Strong colorful contrast with bright arcade-style saturation.',
        category = 'Colorful',
        intensity = 'High',
        timecycle = 'MP_corona_heist',
        strength = 0.68,
        minStrength = 0.15,
        maxStrength = 0.90,
        color = '#ff3cac',
        glowColor = '#ff8bd8',
        ratings = { day = 8, night = 8, interior = 6 }
    },

    sunset_gold = {
        label = 'Sunset Gold',
        description = 'Major warm orange-gold grade for sunsets, deserts and street scenes.',
        category = 'Warm',
        intensity = 'High',
        timecycle = 'TrevorColorCode',
        strength = 0.68,
        minStrength = 0.15,
        maxStrength = 0.90,
        color = '#ff8a2a',
        glowColor = '#ffd166',
        ratings = { day = 9, night = 6, interior = 7 }
    },

    arctic_blue = {
        label = 'Arctic Blue',
        description = 'Distinct cool blue grade with crisp steel-toned highlights.',
        category = 'Cool',
        intensity = 'High',
        timecycle = 'MichaelColorCode',
        strength = 0.68,
        minStrength = 0.15,
        maxStrength = 0.90,
        color = '#38bdf8',
        glowColor = '#a5f3fc',
        ratings = { day = 8, night = 9, interior = 7 }
    },

    neon_green = {
        label = 'Neon Green',
        description = 'Bright green-cyan city grade with a clearly different color family.',
        category = 'Colorful',
        intensity = 'High',
        timecycle = 'FranklinColorCode',
        strength = 0.68,
        minStrength = 0.15,
        maxStrength = 0.90,
        color = '#22c55e',
        glowColor = '#86efac',
        ratings = { day = 7, night = 9, interior = 7 }
    },

    cinematic_clean = {
        label = 'Cinematic Clean',
        description = 'Balanced movie-grade contrast without the candy or horror tint.',
        category = 'Cinematic',
        intensity = 'Low',
        timecycle = 'NeutralColorCode',
        strength = 0.75,
        minStrength = 0.15,
        maxStrength = 1.00,
        color = '#e2e8f0',
        glowColor = '#ffffff',
        overlay = { type = 'film', opacity = 0.055 },
        ratings = { day = 9, night = 8, interior = 9 }
    },

    zombie_day = {
        label = 'Zombie Day',
        description = 'Dry, drained daylight with obvious apocalypse desaturation.',
        category = 'Survival',
        intensity = 'Medium',
        timecycle = 'hud_def_desat_Neutral',
        strength = 0.65,
        minStrength = 0.15,
        maxStrength = 0.90,
        color = '#a3e635',
        glowColor = '#d9f99d',
        overlay = { type = 'toxic', opacity = 0.065 },
        ratings = { day = 9, night = 6, interior = 7 }
    },

    zombie_night = {
        label = 'Zombie Night',
        description = 'Cold infected blue-gray night with heavy survival-game mood.',
        category = 'Survival',
        intensity = 'High',
        timecycle = 'hud_def_desat_cold',
        strength = 0.65,
        minStrength = 0.15,
        maxStrength = 0.90,
        color = '#64748b',
        glowColor = '#93c5fd',
        overlay = { type = 'night', opacity = 0.08 },
        ratings = { day = 6, night = 9, interior = 7 }
    },

    horror_blood = {
        label = 'Horror Blood',
        description = 'Aggressive blood-red horror grade for attacks and crisis scenes.',
        category = 'Horror',
        intensity = 'High',
        timecycle = 'REDMIST',
        strength = 0.35,
        minStrength = 0.10,
        maxStrength = 0.60,
        color = '#dc2626',
        glowColor = '#fb7185',
        overlay = { type = 'blood', opacity = 0.12 },
        ratings = { day = 7, night = 9, interior = 9 }
    },

    ghost_hunt = {
        label = 'Ghost Hunt',
        description = 'Pale paranormal wash with cold desaturated supernatural color.',
        category = 'Paranormal',
        intensity = 'Medium',
        timecycle = 'hud_def_desat_switch',
        strength = 0.65,
        minStrength = 0.15,
        maxStrength = 0.90,
        color = '#a78bfa',
        glowColor = '#ddd6fe',
        overlay = { type = 'ghost', opacity = 0.10 },
        ratings = { day = 7, night = 10, interior = 9 }
    },

    police_chase = {
        label = 'Police Chase',
        description = 'Dark high-speed pursuit contrast with intense action lighting.',
        category = 'Emergency',
        intensity = 'High',
        timecycle = 'RaceTurboDark',
        strength = 0.55,
        minStrength = 0.10,
        maxStrength = 0.75,
        color = '#2563eb',
        glowColor = '#ef4444',
        overlay = { type = 'pursuit', opacity = 0.055 },
        ratings = { day = 7, night = 10, interior = 6 }
    },

    noir_crime = {
        label = 'Noir Crime',
        description = 'Deep filmic shadows and restrained color for crime-story scenes.',
        category = 'Crime',
        intensity = 'Medium',
        timecycle = 'NG_filmic01',
        strength = 0.70,
        minStrength = 0.15,
        maxStrength = 0.90,
        color = '#6b7280',
        glowColor = '#d1d5db',
        overlay = { type = 'film', opacity = 0.09 },
        ratings = { day = 8, night = 9, interior = 9 }
    },

    -- Experimental research presets. These are hidden until enabled.
    vintage_film = {
        label = 'Vintage Film', description = 'Warm film research candidate.',
        category = 'Cinematic', intensity = 'Medium', experimental = true,
        timecycle = 'NG_filmic02', strength = 0.55, minStrength = 0.10, maxStrength = 0.85,
        color = '#d6a66a', glowColor = '#ffe0ad', overlay = { type = 'film', opacity = 0.11 }
    },
    moonlight_film = {
        label = 'Moonlight Film', description = 'Cool night film research candidate.',
        category = 'Cool', intensity = 'Medium', experimental = true,
        timecycle = 'NG_filmic03', strength = 0.55, minStrength = 0.10, maxStrength = 0.85,
        color = '#6ea8ff', glowColor = '#bfd7ff'
    },
    cctv_watch = {
        label = 'CCTV Watch', description = 'Security-camera research candidate.',
        category = 'Camera', intensity = 'High', experimental = true,
        timecycle = 'CAMERA_secuirity', strength = 0.70, minStrength = 0.20, maxStrength = 1.00,
        color = '#7de5c2', glowColor = '#d1fff1', overlay = { type = 'scanlines', opacity = 0.18 }
    },
    security_fuzz = {
        label = 'Security Fuzz', description = 'Noisy surveillance research candidate.',
        category = 'Camera', intensity = 'High', experimental = true,
        timecycle = 'CAMERA_secuirity_FUZZ', strength = 0.65, minStrength = 0.15, maxStrength = 0.90,
        color = '#a7f3d0', glowColor = '#ffffff', overlay = { type = 'vhs', opacity = 0.17 }
    },
    bodycam_scan = {
        label = 'Bodycam Scan', description = 'Body-camera scanline research candidate.',
        category = 'Camera', intensity = 'Medium', experimental = true,
        timecycle = 'scanline_cam_cheap', strength = 0.60, minStrength = 0.10, maxStrength = 0.90,
        color = '#67e8f9', glowColor = '#ecfeff', overlay = { type = 'scanlines', opacity = 0.13 }
    },
    toxic_lab = {
        label = 'Toxic Lab', description = 'Hazardous chemical-lab research candidate.',
        category = 'Survival', intensity = 'High', experimental = true,
        timecycle = 'DRUG_gas_huffin', strength = 0.30, minStrength = 0.05, maxStrength = 0.55,
        color = '#84cc16', glowColor = '#d9f99d', overlay = { type = 'toxic', opacity = 0.11 }
    },
    vhs_nightmare = {
        label = 'VHS Nightmare', description = 'Distorted horror-camera research candidate.',
        category = 'Horror', intensity = 'High', experimental = true,
        timecycle = 'phone_cam3', strength = 0.45, minStrength = 0.10, maxStrength = 0.75,
        color = '#f472b6', glowColor = '#fbcfe8', overlay = { type = 'vhs', opacity = 0.20 }
    },
    grid_blackout = {
        label = 'Grid Blackout', description = 'Cold outage mood with building lights disabled.',
        category = 'Emergency', intensity = 'High', experimental = true,
        timecycle = 'hud_def_desat_cold', strength = 0.48, minStrength = 0.10, maxStrength = 0.75,
        color = '#334155', glowColor = '#93c5fd', blackout = true, vehiclesAffected = false,
        overlay = { type = 'night', opacity = 0.11 }
    }
}
