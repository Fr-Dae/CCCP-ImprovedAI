--[[
    ImproveAI
    Sentry AI profiles

    This file contains the common Sentry management used by
    ImproveAI's SentryPassive and SentryActive modes.

    Native Cortex Command Sentry behaviour remains untouched.
    ImproveAI adds its own profiles on top of the native AI system.

    Profiles:
        SENTRY_PASSIVE
        SENTRY_ACTIVE
]]

ImproveAI = ImproveAI or {};
ImproveAI.Sentry = ImproveAI.Sentry or {};

local Sentry = ImproveAI.Sentry;

-- ---------------------------------------------------------------------------
-- Constants
-- ---------------------------------------------------------------------------

Sentry.ProfilePassive = "SENTRY_PASSIVE";
Sentry.ProfileActive = "SENTRY_ACTIVE";

-- Maximum distance used by the active sentry when searching for a target.
-- This is deliberately expressed as a percentage of the weapon's effective
-- range rather than as a fixed distance.
Sentry.ActiveRangeFactor = 0.90;

-- ---------------------------------------------------------------------------
-- Profile management
-- ---------------------------------------------------------------------------

function Sentry.SetPassive(actor)

    if actor == nil then
        return false;
    end

    actor.ImproveAI_SentryProfile = Sentry.ProfilePassive;

    return true;
end


function Sentry.SetActive(actor)

    if actor == nil then
        return false;
    end

    actor.ImproveAI_SentryProfile = Sentry.ProfileActive;

    return true;
end


function Sentry.ClearProfile(actor)

    if actor == nil then
        return false;
    end

    actor.ImproveAI_SentryProfile = nil;

    return true;
end


function Sentry.IsPassive(actor)

    return actor ~= nil
        and actor.ImproveAI_SentryProfile == Sentry.ProfilePassive;
end


function Sentry.IsActive(actor)

    return actor ~= nil
        and actor.ImproveAI_SentryProfile == Sentry.ProfileActive;
end


-- ---------------------------------------------------------------------------
-- Behaviour update
-- ---------------------------------------------------------------------------

function Sentry.Update(actor)

    if actor == nil then
        return;
    end

    if Sentry.IsPassive(actor) then

        Sentry.UpdatePassive(actor);

    elseif Sentry.IsActive(actor) then

        Sentry.UpdateActive(actor);

    end
end


-- ---------------------------------------------------------------------------
-- Passive Sentry
-- ---------------------------------------------------------------------------

function Sentry.UpdatePassive(actor)

    -- Passive Sentry deliberately does not search for enemies here.
    --
    -- The actor should retain its position and native Sentry behaviour,
    -- but ImproveAI must prevent this profile from initiating combat.
    --
    -- The actual interception of NativeHumanAI's attack decision will
    -- be implemented by the global AI integration layer.

end


-- ---------------------------------------------------------------------------
-- Active Sentry
-- ---------------------------------------------------------------------------

function Sentry.UpdateActive(actor)

    local target = ImproveAI.SentryTargeting.FindTarget(actor);

    if target == nil then
        return;
    end

    -- The target has been selected by ImproveAI's targeting system.
    --
    -- Actual engagement / firing is intentionally not performed here.
    -- This keeps target selection separate from weapon control.

    actor.ImproveAI_SentryTarget = target;
end
