local logger = require("server/core/logger")
local ban_manager = require("server/core/ban_manager")

---@class AntiServerCfgOptionsModule
local AntiServerCfgOptions = {}

---@return void This function will apply the server security settings to the server
function AntiServerCfgOptions.initialize()
    -- Check if server security settings are enabled
    if not PowerAC.ServerSecurity or not PowerAC.ServerSecurity.Enabled then
        logger.info("[PowerAC] Server security configuration not enabled")
        return
    end
    
    -- CONNECTION & AUTHENTICATION SETTINGS
    if PowerAC.ServerSecurity.Connection then
        -- Timeout settings
        SetConvar("sv_kick_players_cnl_timeout_sec", tostring(PowerAC.ServerSecurity.Connection.KickTimeout or 600))
        SetConvar("sv_kick_players_cnl_update_rate_sec", tostring(PowerAC.ServerSecurity.Connection.UpdateRate or 60))
        SetConvar("sv_kick_players_cnl_consecutive_failures", tostring(PowerAC.ServerSecurity.Connection.ConsecutiveFailures or 2))
        
        -- Authentication settings
        SetConvar("sv_authMaxVariance", tostring(PowerAC.ServerSecurity.Connection.AuthMaxVariance or 1))
        SetConvar("sv_authMinTrust", tostring(PowerAC.ServerSecurity.Connection.AuthMinTrust or 5))
        
        -- Client verification
        SetConvar("sv_pure_verify_client_settings", PowerAC.ServerSecurity.Connection.VerifyClientSettings and "1" or "0")
    end
    
    -- NETWORK EVENT SECURITY
    if PowerAC.ServerSecurity.NetworkEvents then
        -- Block REQUEST_CONTROL_EVENT routing (supports values -1 to 4, 2 recommended for your use case)
        SetConvar("sv_filterRequestControl", tostring(PowerAC.ServerSecurity.NetworkEvents.FilterRequestControl or 0))
        
        -- Block NETWORK_PLAY_SOUND_EVENT routing
        SetConvar("sv_enableNetworkedSounds", PowerAC.ServerSecurity.NetworkEvents.DisableNetworkedSounds and "false" or "true")
        
        -- Block REQUEST_PHONE_EXPLOSION_EVENT
        SetConvar("sv_enableNetworkedPhoneExplosions", PowerAC.ServerSecurity.NetworkEvents.DisablePhoneExplosions and "false" or "true")
        
        -- Block SCRIPT_ENTITY_STATE_CHANGE_EVENT
        SetConvar("sv_enableNetworkedScriptEntityStates", PowerAC.ServerSecurity.NetworkEvents.DisableScriptEntityStates and "false" or "true")
    end
    
    -- CLIENT MODIFICATION PROTECTION
    if PowerAC.ServerSecurity.ClientProtection then
        -- Pure level setting
        SetConvar("sv_pureLevel", tostring(PowerAC.ServerSecurity.ClientProtection.PureLevel or 2))
        
        -- Disable client replays
        SetConvar("sv_disableClientReplays", PowerAC.ServerSecurity.ClientProtection.DisableClientReplays and "1" or "0")
        
        -- Script hook settings
        SetConvar("sv_scriptHookAllowed", PowerAC.ServerSecurity.ClientProtection.ScriptHookAllowed and "1" or "0")
    end
    
    -- MISC SECURITY SETTINGS
    if PowerAC.ServerSecurity.Misc then
        -- Enable chat sanitization
        SetConvar("sv_enableChatTextSanitization", PowerAC.ServerSecurity.Misc.EnableChatSanitization and "1" or "0")
        
        -- Rate limits
        if PowerAC.ServerSecurity.Misc.ResourceKvRateLimit then
            SetConvar("sv_defaultResourceKvRateLimit", tostring(PowerAC.ServerSecurity.Misc.ResourceKvRateLimit))
        end
        
        if PowerAC.ServerSecurity.Misc.EntityKvRateLimit then
            SetConvar("sv_defaultEntityKvRateLimit", tostring(PowerAC.ServerSecurity.Misc.EntityKvRateLimit))
        end
    end
    
    logger.info("[PowerAC] Server security configuration applied successfully")
end

return AntiServerCfgOptions