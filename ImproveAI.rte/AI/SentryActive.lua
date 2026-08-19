-- ============================================================
-- ImproveAI.rte
-- SentryActive.lua
--
-- Active sentry:
--   * searches for enemies
--   * may leave the sentry position
--   * returns when the engagement ends
--   * never wanders without a target
-- ============================================================

ImproveAI_SentryActive = ImproveAI_SentryActive or {};

local Active = ImproveAI_SentryActive;


-- ============================================================
-- CONFIGURATION
-- ============================================================

Active.MaximumEngagementDistance = 900;
Active.ReturnDistanceMultiplier = 1.5;


-- ============================================================
-- INITIALISATION
-- ============================================================

function Active.Initialize(AI, Owner)

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

function Active.ReturnToPost(AI, Owner)

	if not AI.SentryPos then
		return true;
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

		Owner:ClearAIWaypoints();

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
-- ENGAGEMENT LIMIT
-- ============================================================

function Active.CanEngage(Owner, Target)

	if not Target then
		return false;
	end

	local Radius =
		ImproveAI_SentryTargeting.GetSearchRadius(
			Owner
		);

	local Limit = math.min(
		Radius,
		Active.MaximumEngagementDistance
	);

	return ImproveAI_SentryTargeting.GetDistance(
		Owner,
		Target
	) <= Limit;

end


-- ============================================================
-- AIM
-- ============================================================

function Active.AimAt(AI, Owner, Target)

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
-- MOVE TO TARGET
-- ============================================================

function Active.MoveToTarget(Owner, Target)

	if not Target then
		return;
	end

	Owner:ClearAIWaypoints();

	Owner:AddAIMOWaypoint(Target);

end


-- ============================================================
-- MAIN BEHAVIOUR
-- ============================================================

function SentryActive(AI, Owner, Abort)

	Active.Initialize(AI, Owner);

	while not Abort() do

		if not MovableMan:ValidMO(Owner) then
			return;
		end

		local Target = AI.Target;

		if Target
			and ImproveAI_SentryTargeting.IsTargetStillValid(
				Owner,
				Target
			)
			and Active.CanEngage(Owner, Target) then

			Active.AimAt(
				AI,
				Owner,
				Target
			);

			local Distance =
				ImproveAI_SentryTargeting.GetDistance(
					Owner,
					Target
				);

			local Weapon =
				ImproveAI_SentryTargeting.GetEquippedWeapon(
					Owner
				);

			local WeaponRange =
				ImproveAI_SentryTargeting.GetWeaponRange(
					Weapon
				);

			if Distance > WeaponRange * 0.9 then
				Active.MoveToTarget(
					Owner,
					Target
				);
			else
				Owner:ClearAIWaypoints();
			end

		else

			AI.Target = nil;

			AI.Target =
				ImproveAI_SentryTargeting.FindBestTarget(
					Owner
				);

			if not AI.Target then
				Active.ReturnToPost(
					AI,
					Owner
				);
			end

		end

		coroutine.yield();

	end

end
