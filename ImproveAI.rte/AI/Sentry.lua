-- ============================================================
-- ImproveAI.rte
-- Sentry.lua
--
-- Sentry behaviour dispatcher.
-- ============================================================

ImproveAI_Sentry = ImproveAI_Sentry or {};

local Sentry = ImproveAI_Sentry;


function Sentry.Initialize(AI, Owner)

	if not AI.SentryPos then
		AI.SentryPos = Vector(Owner.Pos.X, Owner.Pos.Y);
	end

	if AI.SentryFacing == nil then
		AI.SentryFacing = Owner.HFlipped;
	end

end


function Sentry.Passive(AI, Owner, Abort)

	Sentry.Initialize(AI, Owner);

	return SentryPassive(AI, Owner, Abort);

end


function Sentry.Active(AI, Owner, Abort)

	Sentry.Initialize(AI, Owner);

	return SentryActive(AI, Owner, Abort);

end
