RegisterNetEvent("PowerAC:ForceSocialClubUpdate", function()
    ForceSocialClubUpdate()
end)

RegisterNetEvent("PowerAC:ForceUpdate", function()
    ForceSocialClubUpdate()
    NetworkIsPlayerActive(PlayerId())
    NetworkIsPlayerConnected(PlayerId())
end)

-- Fix: we echo back the received nonce to prove the client is actually running; a cheater who removed PowerAC never receives the nonce and cannot guess it.
RegisterNetEvent("checkalive", function (nonce)
    TriggerServerEvent("addalive", nonce)
end)
