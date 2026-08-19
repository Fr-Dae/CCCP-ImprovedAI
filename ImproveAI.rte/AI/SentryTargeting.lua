--[[
    ImproveAI - Sentry Passive

    Passive defensive behaviour for AI-controlled actors.

    Unlike the native Cortex Command Sentry mode, SentryPassive
    does not actively engage enemies.

    This file defines the ImproveAI profile and its parameters.
    The actual integration with the Human AI is handled separately.
]]

ImproveAI_SentryPassive = {};

ImproveAI_SentryPassive.Name = "SentryPassive";
ImproveAI_SentryPassive.AIMode = Actor.AIMODE_SENTRY;

-- Profile identifier.
ImproveAI_SentryPassive.Profile = "SENTRY_PASSIVE";

-- Passive sentry does not initiate combat.
ImproveAI_SentryPassive.EngageTargets = false;

-- Keep the actor at its sentry position.
ImproveAI_SentryPassive.HoldPosition = true;

-- Allow normal native sentry aiming / facing behaviour.
ImproveAI_SentryPassive.UseNativeSentry = true;

return ImproveAI_SentryPassive;
