local BanManager = require("server/core/ban_manager")
local logger = require("server/core/logger")

local DashboardURL = GetConvar("powerac_dashboard_url", "http://localhost:3000")
_G.PowerACAuthenticated = false

local function get_license_key()
    local convarKey = GetConvar("powerac_key", "")
    if convarKey ~= "" then return convarKey end

    local fileContent = LoadResourceFile(GetCurrentResourceName(), "powerac.key")
    if fileContent then
        -- trim whitespace/newlines
        local trimmed = fileContent:gsub("%s+", "")
        if trimmed ~= "" then return trimmed end
    end
    return nil
end

local function apply_web_config(webConfig)
    if not _G.PowerAC or not webConfig then return end
    
    -- Dynamic protection flags overrides
    local mapping = {
        ["antiNoclip"] = "Anti Noclip",
        ["antiSpectate"] = "Anti Spectate",
        ["antiGiveWeapon"] = "Anti Give Weapon",
        ["antiCheatEngine"] = "Anti Speed Hack",
    }
    
    _G.PowerAC.Detections = _G.PowerAC.Detections or {}
    _G.PowerAC.Detections.ClientProtections = _G.PowerAC.Detections.ClientProtections or {}

    for webField, gameName in pairs(mapping) do
        if webConfig[webField] ~= nil then
            _G.PowerAC.Detections.ClientProtections[gameName] = _G.PowerAC.Detections.ClientProtections[gameName] or { action = "Ban" }
            _G.PowerAC.Detections.ClientProtections[gameName].enabled = webConfig[webField]
        end
    end

    -- Dynamic Entity Spam / Vehicle Spam Module Override
    if webConfig.antiVehicleSpam ~= nil then
        _G.PowerAC.Module = _G.PowerAC.Module or {}
        _G.PowerAC.Module.ModuleEnabled = webConfig.antiVehicleSpam
    end

    -- Trigger Event protection / EventProtector override
    if webConfig.antiTriggerEvent ~= nil then
        _G.PowerAC.EventProtector = _G.PowerAC.EventProtector or {}
        _G.PowerAC.EventProtector.Enabled = webConfig.antiTriggerEvent
    end

    -- Sensitivity overrides
    if webConfig.detectionSensitivity then
        local sens = tonumber(webConfig.detectionSensitivity) or 7
        local speedHack = _G.PowerAC.Detections.ClientProtections["Anti Speed Hack"]
        if speedHack then
            speedHack.tolerance = 12.0 - sens
        end
    end

    -- Webhooks override
    if webConfig.discordLogWebhook and webConfig.discordLogWebhook ~= "" then
        _G.PowerAC.Logs = _G.PowerAC.Logs or {}
        _G.PowerAC.Logs.system = webConfig.discordLogWebhook
        _G.PowerAC.Logs.detection = webConfig.discordLogWebhook
        _G.PowerAC.Logs.ban = webConfig.discordLogWebhook
        _G.PowerAC.Logs.kick = webConfig.discordLogWebhook
        _G.PowerAC.Logs.screenshot = webConfig.discordLogWebhook
        _G.PowerAC.Logs.adminMenu = webConfig.discordLogWebhook
    end
end

local function sync_web_admins(adminsList)
    if not _G.PowerAC then return end
    _G.PowerAC.Admins = _G.PowerAC.Admins or {}
    local synced = {}
    for _, adm in ipairs(adminsList) do
        table.insert(synced, {
            identifier = adm.steamHex,
            permission = "all"
        })
    end
    _G.PowerAC.Admins = synced
end

local function sync_web_bans(bansList)
    if not BanManager or not BanManager.bans then return end
    
    local updatedBans = {}
    
    for _, webBan in ipairs(bansList) do
        if webBan.active then
            local banObj = {
                id = webBan.id,
                player_name = webBan.playerName,
                reason = webBan.reason,
                identifiers = {
                    steam = webBan.steamId ~= "N/A" and webBan.steamId or nil,
                    discord = webBan.discordId ~= "N/A" and webBan.discordId or nil,
                },
                timestamp = os.time(),
                expires = 0,
                admin = webBan.bannedBy or "Dashboard Admin",
                detection = webBan.reason
            }
            table.insert(updatedBans, banObj)
        end
    end

    -- Combine with existing local bans
    for _, localBan in ipairs(BanManager.bans) do
        local exists = false
        for _, webBan in ipairs(updatedBans) do
            if tostring(webBan.id) == tostring(localBan.id) then
                exists = true
                break
            end
        end
        if not exists then
            table.insert(updatedBans, localBan)
        end
    end

    BanManager.bans = updatedBans
    
    -- Rebuild identifiers index for fast lookup
    BanManager.bans_index = {}
    for _, ban in ipairs(BanManager.bans) do
        if ban.identifiers then
            for _, id_value in pairs(ban.identifiers) do
                if type(id_value) == "string" then
                    BanManager.bans_index[id_value] = ban
                end
            end
        end
    end
end

local function handle_polled_commands(commands)
    if not commands or #commands == 0 then return end
    for _, cmd in ipairs(commands) do
        if cmd.action == "kick" then
            local targetId = tostring(cmd.target)
            DropPlayer(targetId, cmd.reason or "Kicked from Power Anticheat Dashboard")
            logger.info("Successfully dropped player ID: " .. targetId .. " per dashboard RCON command.")
        elseif cmd.action == "ban" then
            local targetId = tostring(cmd.target)
            BanManager.ban_player(targetId, cmd.reason or "Banned from Power Anticheat Dashboard", { admin = "Console Admin" })
            logger.warn("Permanently banned player ID: " .. targetId .. " per dashboard RCON command.")
        elseif cmd.action == "sync_admins" then
            sync_web_admins(cmd.admins or {})
            logger.info("Admin bypass configurations updated dynamically.")
        end
    end
end

-- Heartbeat Loop
local function start_heartbeat_loop(licenseKey)
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(10000) -- every 10 seconds
            if _G.PowerACAuthenticated then
                local players = {}
                local rawPlayers = GetPlayers()
                for _, pId in ipairs(rawPlayers) do
                    local steam = "N/A"
                    local discord = "N/A"
                    local hwid = "N/A"
                    for _, id in ipairs(GetPlayerIdentifiers(pId)) do
                        if string.match(id, "^steam:") then steam = id
                        elseif string.match(id, "^discord:") then discord = id
                        end
                    end
                    if GetPlayerToken then
                        hwid = GetPlayerToken(pId, 0) or "N/A"
                    end
                    table.insert(players, {
                        id = pId,
                        name = GetPlayerName(pId) or "Unknown",
                        ping = GetPlayerPing(pId) or 0,
                        steamId = steam,
                        discord = discord,
                        hardwareId = hwid,
                        joinTime = "Active"
                    })
                end

                local payload = json.encode({
                    license = licenseKey,
                    playersCount = #players,
                    activePlayers = players
                })

                PerformHttpRequest(DashboardURL .. "/api/servers/heartbeat", function(statusCode, responseText, headers)
                    if statusCode == 200 and responseText then
                        local responseData = json.decode(responseText)
                        if responseData and responseData.success then
                            handle_polled_commands(responseData.commands)
                        end
                    end
                end, "POST", payload, { ["Content-Type"] = "application/json" })
            end
        end
    end)
end

-- Startup Validation
Citizen.CreateThread(function()
    Citizen.Wait(1500) -- Wait for everything else to boot
    local licenseKey = get_license_key()
    if not licenseKey then
        _G.PowerACAuthenticated = false
        print("\n^1===========================================================")
        print("  [Power Anticheat] ERROR: LICENSE KEY NOT DETECTED!")
        print("  Please create a file named 'powerac.key' in the root directory")
        print("  and paste your license key inside it.")
        print("  Anticheat protections will remain OFFLINE!")
        print("===========================================================^7\n")
        return
    end

    print("^3[Power Anticheat] Verifying license key with dashboard: " .. licenseKey .. "^7")

    local payload = json.encode({ license = licenseKey, ip = "127.0.0.1" })
    PerformHttpRequest(DashboardURL .. "/api/validate", function(statusCode, responseText, headers)
        if statusCode == 200 and responseText then
            local responseData = json.decode(responseText)
            if responseData and responseData.success then
                _G.PowerACAuthenticated = true
                print("\n^2===========================================================")
                print("  [Power Anticheat] ✓ LICENSE KEY VALIDATED SUCCESSFULLY!")
                print("  Tier: " .. (responseData.license.tier or "Standard") .. " | Duration: " .. (responseData.license.duration or "Lifetime"))
                print("  Syncing Dynamic Rules and Whitelist configurations online...")
                print("===========================================================^7\n")

                -- Apply web configurations, bans, and admins
                apply_web_config(responseData.config)
                sync_web_bans(responseData.bans)
                sync_web_admins(responseData.admins)

                -- Start periodic RCON heartbeat bridge
                start_heartbeat_loop(licenseKey)
            else
                _G.PowerACAuthenticated = false
                local msg = responseData and responseData.message or "Unknown verification error."
                print("\n^1===========================================================")
                print("  [Power Anticheat] ERROR: LICENSE KEY DENIED!")
                print("  Details: " .. msg)
                print("  All protections are disabled, connecting players will be kicked.")
                print("===========================================================^7\n")
            end
        else
            _G.PowerACAuthenticated = false
            print("\n^1===========================================================")
            print("  [Power Anticheat] ERROR: CONNECTION TO DASHBOARD FAILED!")
            print("  Status code: " .. tostring(statusCode))
            print("  Anticheat security will remain in fail-safe offline mode.")
            print("===========================================================^7\n")
        end
    end, "POST", payload, { ["Content-Type"] = "application/json" })
end)

-- Kick players if license is not authenticated
AddEventHandler("playerConnecting", function(name, setKickReason, deferrals)
    if not _G.PowerACAuthenticated then
        CancelEvent()
        setKickReason("Power Anticheat: This server is currently unlicensed. Please insert a valid license key.")
    end
end)
