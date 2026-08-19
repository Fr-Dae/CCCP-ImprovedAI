-- ============================================================
-- ImproveAI.rte
-- Sentry.lua
--
-- Improved Sentry behaviour dispatcher.
--
-- CCCP's NativeHumanAI creates the Sentry coroutine from
-- HumanBehaviors.Sentry.  We replace that native function here
-- and select the requested ImproveAI profile through a per-actor
-- value set by the Pie Menu.
-- ============================================================

ImproveAI_Sentry = ImproveAI_Sentry or {};

local Sentry = ImproveAI_Sentry;

Sentry.ModePassive = 1;
Sentry.ModeActive = 2;


function Sentry.Initialize(AI, Owner)

	if not AI.SentryPos then
		AI.SentryPos = Vector(Owner.Pos.X, Owner.Pos.Y);
	end

	if AI.SentryFacing == nil then
		AI.SentryFacing = Owner.HFlipped;
	end

end


function Sentry.GetMode(Owner)

	if Owner:NumberValueExists("ImproveAI_SentryMode") then
		return Owner:GetNumberValue("ImproveAI_SentryMode");
	end

	return Sentry.ModePassive;

end


function Sentry.Run(AI, Owner, Abort)

	Sentry.Initialize(AI, Owner);

	if Sentry.GetMode(Owner) == Sentry.ModeActive then
		return SentryActive(AI, Owner, Abort);
	end

	return SentryPassive(AI, Owner, Abort);

end


-- CCCP NativeHumanAI explicitly creates HumanBehaviors.Sentry.
-- Install the dispatcher there so the native AIMODE_SENTRY path
-- remains intact while ImproveAI selects the profile per actor.
if HumanBehaviors then
	HumanBehaviors.Sentry = Sentry.Run;
end
