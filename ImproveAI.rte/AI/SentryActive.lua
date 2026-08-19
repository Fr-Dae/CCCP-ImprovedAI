--[[
    ImproveAI - Sentry Active

    Active defensive behaviour for AI-controlled actors.

    The actor actively searches for enemies inside its effective
    engagement range and attempts to engage them.

    Target selection and firing logic are implemented separately
    in SentryTargeting.lua.
]]

ImproveAI_SentryActive = {};

ImproveAI_SentryActive.Name = "SentryActive";
ImproveAI_SentryActive.AIMode = Actor.AIMODE_SENTRY;

-- Profile identifier.
ImproveAI_SentryActive.Profile = "SENTRY_ACTIVE";

-- Active sentry may initiate combat.
ImproveAI_SentryActive.EngageTargets = true;

-- Keep the actor near its sentry position.
ImproveAI_SentryActive.HoldPosition = true;

-- Use ImproveAI targeting instead of relying exclusively
-- on the native target selection.
ImproveAI_SentryActive.UseImproveAITargeting = true;

-- Do not use the full native Sentry targeting behaviour.
ImproveAI_SentryActive.UseNativeSentryTargeting = false;

return ImproveAI_SentryActive;
