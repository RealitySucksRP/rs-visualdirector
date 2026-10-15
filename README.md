# RS Visual Director 2.9.0

Direct the atmosphere from a movable phone or widescreen Director Studio. Choose from 12 moods, preview a look locally, capture real gameplay galleries, and save private Live Moments with their look and intensity. Global sync is an explicit action.

[Download original ZIP](https://github.com/RealitySucksRP/rs-visualdirector/releases/latest/download/rs-visualdirector.zip) | [Free Tebex listing](https://reality-sucks-rp-webstore.tebex.io/package/7556700) | [GitHub source](https://github.com/RealitySucksRP/rs-visualdirector) | [Website](https://realitysucksrp.github.io/) | [Tebex Store](https://reality-sucks-rp-webstore.tebex.io/) | [Discord](https://discord.gg/e9V3rPHySx) | [YouTube](https://www.youtube.com/@RealitySucksRP) | [Free scripts](https://reality-sucks-rp-webstore.tebex.io/category/free-scripts)

> **Supplied test build:** `Config.RequireAce = false` allows every player to change the server-wide look. Set it to `true` and grant `rs-visualdirector.admin` before using this package on a public server. The original ZIP and source settings are preserved.

<img src="docs/screenshots/preview-1.webp" width="900" alt="RS Visual Director — Listing artwork">

*Listing artwork; included previews are not evidence of a live FiveM test.*

<details>
<summary>More listing artwork</summary>

<img src="docs/screenshots/preview-2.webp" width="640" alt="RS Visual Director preview 2">

</details>

## Package documentation

# RS Visual Director

I create RealitySucksRP resources for cinematic FiveM roleplay, memorable scenes, and straightforward setup. **RS Visual Director** provides a movable phone and widescreen Director Studio for directing the visual atmosphere of the entire server.

The resource starts with the normal GTA/FiveM image. No custom mood is forced during startup.

## What players and staff can do

Open the Studio or phone, select a look, try it locally without changing anyone else's display, adjust safe intensity, and explicitly apply it globally. Hold **MOVE** in the header and drag the phone anywhere on screen. Use **−** and **+** to resize, or **↺** to recenter and restore default size. Layout is saved locally for each player.

Included features:

* 12 curated production moods
* Original GTA startup and instant restoration
* Server-synchronized visual changes
* Original Gummy Air phone artwork preserved, plus widescreen Director Studio
* Real GTA screenshot gallery capture workflow for all 12 moods; no AI/simulated mood screenshots
* Thumbnails stored locally on the staff member's computer and populated only after genuine in-game captures
* Local-only preview that restores the previous synced state on stop/close
* Redesigned screenshot-ready mood tiles with selected/live/local states and category filters
* Movable phone: hold MOVE and drag, resize with +/- and reset with the circular arrow
* Player-local phone position and size saved across menu opens/restarts
* Safe minimum and maximum strength for every mood
* Hold-to-compare Original GTA
* Smooth fade transitions
* Optional film, toxic, night, blood, paranormal, pursuit, scanline, and VHS overlays
* Optional screen effects, extra timecycles, camera shake, and blackout layers
* Configurable ACE-protected global controls (disabled in this testing package)
* Qbox, QBCore, ESX, and standalone bridge support
* Automatic framework and notification detection
* Optional job, framework-group, or identifier access
* Optional personal preferences and oxmysql persistence
* Developer exports for missions, events, horror, police, zombie, and cinematic integrations



## Installation

1. Keep the folder name exactly as:

```text
rs-visualdirector
```

2. Place it inside the server resources folder.
3. Add the following lines to `server.cfg`:

```cfg
add_ace group.admin rs-visualdirector.admin allow
ensure rs-visualdirector
```

4. Restart the server.
5. Open the phone with:

```text
/visualmenu
```

No framework is required. The bridge automatically detects Qbox, QBCore, ESX, or standalone mode.
**In this testing ZIP** `Config.RequireAce = false`, so everyone can open the menu and change the global style. To restrict public server access, set this to `true`, and grant the ACE object shown above to authorized staff.

**Optional for genuine gameplay thumbnails and saved Live Moments:** install and `ensure screenshot-basic` before `ensure rs-visualdirector`. The other mood, UI, local preview, and server sync features continue to work without `screenshot-basic`. No screenshot is uploaded to a server or external website.
Visual Director does not use inventory, target, banking, or item systems, so no unnecessary adapters or dependencies are loaded.

## Live Moments — individual gameplay scene saves

A **Live Moment** is a private, real GTA screenshot and a bookmark of the look and intensity active when it was captured. This is distinct from the **CAPTURE 12 LOOKS** preset gallery, which automatically cycles all moods.

1. Start `screenshot-basic` (optional screenshot dependency) and open `/visualmenu`.
2. Aim the camera at a scene worth saving. Apply or PREVIEW LOCAL a mood if desired.
3. In Studio or Phone, click **+ SAVE MOMENT**, or open **MY MOMENTS** and enter an optional name first.
4. The phone hides, `screenshot-basic` captures the actual gameplay scene, then the screenshot and look appear in **MY MOMENTS**.
5. Open a screenshot by clicking its image. Press **RECALL LOOK** to select its saved mood and intensity, then **PREVIEW LOCAL** to see it in-game. Only **APPLY LOOK / GLOBAL SYNC** changes other players' screens. **DELETE** requires a second click to confirm.

Up to **10** Live Moments are stored in local NUI storage on the machine that captured them. Neither images nor moment information goes to the server/database. NUI cache resets remove captures. A storage-full or unavailable error may limit persistence; in that case the moment is available for the current NUI session only. Screenshots are downscaled to 576 × 324 JPEG for storage and are not lossless original-resolution recordings. This is not a video-recording feature.

## Real gameplay gallery (12 moods)

The ZIP ships **no invented GTA look thumbnails**. Actual timecycle looks can only be captured inside running FiveM. The menu shows clearly labeled empty gallery slots on a new install. To build the gallery:

1. Ensure the optional `screenshot-basic` resource is running and open `/visualmenu` as authorized staff.
2. Stand in a well-lit GTA location, choose a scene with visible sky, vehicles, and buildings, and open **STUDIO VIEW**.
3. Click **CAPTURE 12 LOOKS**. Visual Director will change **only your own screen** through all twelve timecycles, briefly hide the menu, capture each GTA render target, and create 336 × 196 JPEG thumbnails in the local NUI cache.
4. The current synchronized look is restored when capture completes or is cancelled. Open the gallery to compare the true game captures.

The process takes several seconds, during which you should leave the camera steady. Only start it deliberately: some looks are intentionally intense. It sends no global events and never captures other players' games. The thumbnails are stored per computer rather than packaged in the resource or uploaded to the server. Clearing NUI site data clears them. A server owner who wants a **bundled, identical gallery for everybody** must supply verified GTA captures, which were not included in the supplied ZIP.

> \*\*TEST BUILD ACCESS:\*\* `Config.RequireAce = false` intentionally allows every player to open and change the global synchronized look. Do not leave this setting disabled on a public server. Change it to `true` and grant the `rs-visualdirector.admin` ACE for restricted use.

## In-game menu controls

* **PHONE VIEW / STUDIO VIEW:** switch between the original portrait device and the new widescreen dashboard.
* **MOVE:** hold and drag to reposition the active layout. Both positions are remembered on this machine.
* **− / +:** shrink or enlarge the phone within safe on-screen bounds.
* **↺:** restore centered placement and default size.
* **Category chips:** use **‹ / ›** or mouse wheel over the category strip to browse all available categories. In Studio, scroll the mood-card grid itself to see every mood under ALL LOOKS; changing a filter resets the list to the top.
* **Preset cards:** click to select; double-click will not send a global request.
* **PREVIEW LOCAL:** temporarily try the selected timecycle on your own client. **END PREVIEW** or close to restore the previous synced look.
* **APPLY LOOK:** explicitly request the selected mood for the entire server; ACE enforcement depends on `Config.RequireAce`. The distributed test build sets it to `false` as requested (so everyone can apply). Set it to `true` before public deployment.
* **CAPTURE 12 LOOKS:** optional, private GTA screenshot gallery builder, requiring `screenshot-basic`.
* **+ SAVE MOMENT / MY MOMENTS:** capture an individual real in-game scene and bookmark its visual look, view/delete saved scenes, or RECALL LOOK without server-wide changes.
* **COMPARE:** hold to preview the unmodified GTA look; release to return.
* **RESTORE GTA:** clear the globally applied mood; this is a server-wide action.
* **Esc / ×:** close the menu and release cursor focus.

Layout is stored with client resource KVP; gallery captures are stored locally in NUI storage. Neither requires SQL.

## Main commands

|Command|Purpose|
|-|-|
|`/visualmenu`|Opens the phone for authorized staff|
|`/vui`|Short menu alias|
|`/visual list`|Lists available production moods|
|`/visual <mood> \[strength]`|Applies a synchronized mood|
|`/visual off`|Restores Original GTA for everyone|
|`/vcomfort`|Shows personal comfort settings|
|`/vcomfort overlays on/off`|Enables or disables NUI overlays locally|
|`/vcomfort screenfx on/off`|Enables or disables screen effects locally|
|`/vcomfort shake on/off`|Enables or disables camera shake locally|
|`/vcomfort blackout on/off`|Enables or disables blackout locally|
|`/vclose`|Emergency mouse/focus release|

## Included moods

* Gummy Air Bright
* Candy Pop
* Sunset Gold
* Arctic Blue
* Neon Green
* Cinematic Clean
* Zombie Day
* Zombie Night
* Horror Blood
* Ghost Hunt
* Police Chase
* Noir Crime

Experimental creator presets remain included but hidden by default.

## Framework bridge

The bridge is internal and does not add a required dependency.

Default configuration:

```lua
Config.Bridge = {
    framework = 'auto',
    notifications = 'auto',
    identifier = 'framework'
}
```

Supported framework values:

```text
auto, qbox, qbcore, esx, standalone
```

Supported notification values:

```text
auto, qbox, qbcore, esx, ox\_lib, native
```

Automatic mode uses the active framework notification system first and falls back to the native GTA feed.

### Access control

ACE protection is **disabled for testing in this ZIP** and strongly recommended for public servers:

```lua
Config.RequireAce = true -- set true before a public release
Config.Bridge.permissions.useAce = true
```

Optional framework administrator groups:

```lua
Config.Bridge.permissions.useFrameworkGroups = true
```

Optional job access with minimum grades:

```lua
Config.Bridge.permissions.useJobs = true
Config.Bridge.permissions.requireOnDuty = true
Config.Bridge.permissions.jobs = {
    police = 4,
    government = 0
}
```

Optional citizen ID or license access:

```lua
Config.Bridge.permissions.useIdentifiers = true
Config.Bridge.permissions.identifiers = {
    'ABC12345',
    'license:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
}
```

All enabled access methods are additive. A player only needs to pass one enabled method.

## Important production defaults

```lua
Config.DefaultStyle = false
Config.RequireAce = false -- testing only; use true on a public server
Config.DeveloperTools = false
Config.AllowPersonalOverride = false
Config.Database.enabled = false
Config.Menu.showExperimental = false
Config.Menu.showWindowLabels = false
Config.Menu.allowGameplayCaptures = true
```

## Optional personal mode

Allow players to keep a personal visual preference:

```lua
Config.AllowPersonalOverride = true
```

Preferences remain active for the current session. To save them across reconnects, start `oxmysql` and enable:

```lua
Config.Database.enabled = true
```

The table is created automatically. Framework identifiers use citizen IDs where available so separate characters can keep separate preferences.

## Server exports

```lua
-- Apply a permanent synchronized mood
exports\['rs-visualdirector']:SetStyle('ghost\_hunt', 0.60)

-- Restore Original GTA
exports\['rs-visualdirector']:ClearStyle()

-- Read the synchronized state
local state = exports\['rs-visualdirector']:GetState()

-- Apply a temporary scene mood
local ok, token = exports\['rs-visualdirector']:PushStyle('police\_chase', 15000, 0.55)

-- End the temporary mood early
if ok then
    exports\['rs-visualdirector']:PopStyle(token)
end
```

Temporary mood tokens are revision-safe. An expired scene cannot restore an old mood after a newer manual change.

## Bridge exports

```lua
local info = exports\['rs-visualdirector']:GetBridgeInfo()
local framework = exports\['rs-visualdirector']:GetFramework()
local player = exports\['rs-visualdirector']:GetBridgePlayer(source)
local identifier = exports\['rs-visualdirector']:GetBridgeIdentifier(source)
local allowed = exports\['rs-visualdirector']:HasVisualAccess(source)

exports\['rs-visualdirector']:BridgeNotify(source, 'Visual mood applied.', 'success', 4000)
```

## Client exports

```lua
exports\['rs-visualdirector']:ApplyLocalStyle('noir\_crime', 0.70)
exports\['rs-visualdirector']:ClearLocalStyle()

local style, strength = exports\['rs-visualdirector']:GetActiveStyle()
exports\['rs-visualdirector']:BeginOriginalCompare()
exports\['rs-visualdirector']:EndOriginalCompare()

local bridge = exports\['rs-visualdirector']:GetBridgeInfo()
exports\['rs-visualdirector']:BridgeNotify('Preview enabled.', 'inform', 3500)
```

## Compatibility notes

RS Visual Director uses GTA/FiveM runtime timecycle natives. It does not include ENB, ReShade, VisualV, NaturalVision, replacement weather XML, `visualsettings.dat`, water files, lens flares, or another graphics overhaul.

Another resource that continuously forces its own timecycle may compete with Visual Director. Test character selection, death effects, drug effects, cameras, weather systems, and custom interiors on the target server.

When the mood is turned off or the resource stops, Visual Director clears its timecycle, extra timecycle, screen effect, camera shake, blackout state, NUI focus, and world overlay.

## License

The Lua, JavaScript, HTML, and CSS source code is released under the GNU General Public License v3.0 in `LICENSE`.

The RealitySucksRP name, RS branding, phone artwork, woman-phone artwork, and included promotional art remain RealitySucksRP brand assets. They may be used and modified as part of an installed or forked RS Visual Director resource, but may not be extracted and sold as standalone artwork or presented as another creator's branding. Server owners may replace the images with their own artwork.



[Previous release README and existing project links](PREVIOUS_README_2026-10-14.md)
