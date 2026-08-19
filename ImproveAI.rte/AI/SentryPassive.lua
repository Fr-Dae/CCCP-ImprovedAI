-- ============================================================
-- ImproveAI.rte
-- SentryPassive.lua
--
-- Passive sentry:
--   * never pursues a target
--   * never abandons the sentry position
--   * may rotate / aim / fire
--   * returns to the sentry position after displacement
-- ============================================================

ImproveAI_SentryPassive = ImproveAI_SentryPassive or {};

local Passive = ImproveAI_SentryPassive;


-- ============================================================
-- INITIALISATION
-- ============================================================

function Passive.Initialize(AI, Owner)

	if not AI.SentryPos then
		AI.SentryPos = Vector(
			Owner.Pos.X,
			Owner.Pos.Y
		);
	end

	if AI.SentryFacing == nil then
		AI.SentryFacing = Owner.HFlipped;
	end

end


-- ============================================================
-- RETURN TO POST
-- ============================================================

function Passive.ReturnToPost(AI, Owner)

	if not AI.SentryPos then
		return false;
	end

	local Dist = SceneMan:ShortestDistance(
		Owner.Pos,
		AI.SentryPos,
		false
	);

	if Dist.Magnitude <= Owner.Height * 0.7 then

		if AI.SentryFacing ~= nil then
			Owner.HFlipped = AI.SentryFacing;
		end

		return true;
	end

	Owner:ClearAIWaypoints();
	Owner:AddAISceneWaypoint(
		SceneMan:MovePointToGround(
			AI.SentryPos,
			Owner.Height * 0.25,
			3
		)
	);

	return false;

end


-- ============================================================
-- AIM
-- ============================================================

function Passive.AimAt(AI, Owner, Target)

	if not Target then
		return;
	end

	local Trace = SceneMan:ShortestDistance(
		Owner.EyePos,
		Target.Pos,
		false
	);

	if Trace.X > 0 then
		Owner.HFlipped = false;
	elseif Trace.X < 0 then
		Owner.HFlipped = true;
	end

	AI.Ctrl:SetState(
		Controller.AIM_SHARP,
		true
	);

end


-- ============================================================
-- MAIN BEHAVIOUR
-- ============================================================

function SentryPassive(AI, Owner, Abort)

	Passive.Initialize(AI, Owner);

	while not Abort() do

		if not MovableMan:ValidMO(Owner) then
			return;
		end

		local Target = AI.Target;

		if Target
			and ImproveAI_SentryTargeting.IsTargetStillValid(
				Owner,
				Target
			) then

			Passive.AimAt(
				AI,
				Owner,
				Target
			);

		else
			AI.Target = nil;

			AI.Target = ImproveAI_SentryTargeting.FindBestTarget(
				Owner
			);
		end

		Passive.ReturnToPost(
			AI,
			Owner
		);

		coroutine.yield();

	end

end
