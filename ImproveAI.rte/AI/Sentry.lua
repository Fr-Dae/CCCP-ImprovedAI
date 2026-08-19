-- ============================================================
-- ImproveAI.rte
-- Sentry.lua
--
-- Improved Sentry behaviour.
--
-- Signature intentionally matches the native behaviour:
--
--     Sentry(AI, Owner, Abort)
--
-- NativeHumanAI / NativeCrabAI create this function as a
-- coroutine.
-- ============================================================


-- Make sure the targeting module exists.
ImproveAI_SentryTargeting =
		ImprooveAI_SentryTargeting
		or ImproveAI_SentryTargeting;


local Targeting = ImproveAI_SentryTargeting;


-- ============================================================
-- CONFIGURATION
-- ============================================================

local SEARCH_RADIUS = 900;

-- How frequently a new target search is performed.
local SEARCH_INTERVAL = 100;

-- How long a temporarily lost target is retained.
local TARGET_MEMORY = 350;

-- Distance at which the actor is considered to have left
-- its sentry position.
local RETURN_DISTANCE_MULTIPLIER = 0.7;


-- ============================================================
-- SENTRY INITIALISATION
-- ============================================================

local function InitialiseSentry(AI, Owner)

	AI.Ctrl = Owner:GetController();

	-- Native Sentry stores its position when entering Sentry mode.
	if not AI.SentryPos then
		AI.SentryPos = Vector(
			Owner.Pos.X,
			Owner.Pos.Y
		);
	end

	-- Store the direction in which the unit was ordered to guard.
	if AI.SentryFacing == nil then
		AI.SentryFacing = Owner.HFlipped;
	end

end


-- ============================================================
-- RETURN TO SENTRY POSITION
-- ============================================================

local function ReturnToSentryPosition(AI, Owner)

	if not AI.SentryPos then
		return false;
	end

	local Distance =
		SceneMan:ShortestDistance(
			Owner.Pos,
			AI.SentryPos,
			false
		);

	if Distance:MagnitudeIsGreaterThan(
		Owner.Height * RETURN_DISTANCE_MULTIPLIER
	) then

		-- Put the stored sentry position back onto the ground.
		AI.SentryPos =
			SceneMan:MovePointToGround(
				AI.SentryPos,
				Owner.Height * 0.25,
				3
			);

		Owner:ClearAIWaypoints();

		Owner:AddAISceneWaypoint(
			AI.SentryPos
		);

		-- Let the native AI's navigation behaviour handle the
		-- actual movement.
		AI:CreateGoToBehavior(Owner);

		return true;
	end

	-- We are back at the post.
	if AI.SentryFacing ~= nil
		and Owner.HFlipped ~= AI.SentryFacing then

		Owner.HFlipped = AI.SentryFacing;

	end

	return false;

end


-- ============================================================
-- AIMING
-- ============================================================

local function AimAtTarget(AI, Owner, Target)

	local Trace =
		SceneMan:ShortestDistance(
			Owner.EyePos,
			Target.Pos,
			false
		);

	-- Enable sharp aiming.
	AI.Ctrl:SetState(
		Controller.AIM_SHARP,
		true
	);

	-- Reset vertical states first.
	AI.Ctrl:SetState(
		Controller.AIM_UP,
		false
	);

	AI.Ctrl:SetState(
		Controller.AIM_DOWN,
		false
	);

	-- Horizontal facing.
	if Trace.X < 0 then

		Owner.HFlipped = true;

	else

		Owner.HFlipped = false;

	end

	-- In Cortex Command Y grows downwards.
	if Trace.Y < -2 then

		AI.Ctrl:SetState(
			Controller.AIM_UP,
			true
		);

	elseif Trace.Y > 2 then

		AI.Ctrl:SetState(
			Controller.AIM_DOWN,
			true
		);

	end

end


-- ============================================================
-- STOP AIM / FIRE
-- ============================================================

local function ClearCombatControls(AI)

	AI.Ctrl:SetState(
		Controller.WEAPON_FIRE,
		false
	);

	AI.Ctrl:SetState(
		Controller.AIM_UP,
		false
	);

	AI.Ctrl:SetState(
		Controller.AIM_DOWN,
		false
	);

end


-- ============================================================
-- FIRE
-- ============================================================

local function FireAtTarget(AI, Owner, Target)

	if not Targeting.IsTargetStillValid(
		Owner,
		Target
	) then

		return false;

	end

	AimAtTarget(
		AI,
		Owner,
		Target
	);

	AI.Ctrl:SetState(
		Controller.WEAPON_FIRE,
		true
	);

	return true;

end


-- ============================================================
-- MAIN SENTRY BEHAVIOUR
-- ============================================================

function ImproveAI_Sentry(AI, Owner, Abort)

	InitialiseSentry(
		AI,
		Owner
	);

	local SearchTimer = Timer();
	local LostTargetTimer = Timer();

	local Target = nil;


	while not Abort() do

		-- ----------------------------------------------------
		-- Validate owner.
		-- ----------------------------------------------------

		if not MovableMan:ValidMO(Owner) then
			break;
		end


		-- ----------------------------------------------------
		-- Keep controller reference valid.
		-- ----------------------------------------------------

		if not AI.Ctrl then
			AI.Ctrl = Owner:GetController();
		end


		-- ----------------------------------------------------
		-- SENTRY POSITION
		-- ----------------------------------------------------

		-- If another behaviour moved us away from our guard
		-- position, return there.
		if Target == nil then

			if ReturnToSentryPosition(
				AI,
				Owner
			) then

				-- Movement behaviour has been created.
				return;

			end

		end


		-- ----------------------------------------------------
		-- TARGET VALIDATION
		-- ----------------------------------------------------

		if Target ~= nil then

			if not Targeting.IsTargetStillValid(
				Owner,
				Target
			) then

				-- Keep the target for a short period in case
				-- LOS was temporarily interrupted.
				if LostTargetTimer:IsPastSimMS(
					TARGET_MEMORY
				) then

					Target = nil;
					AI.Target = nil;
					AI.UnseenTarget = nil;

				end

			else

				-- Target is visible again.
				LostTargetTimer:Reset();

			end

		end


		-- ----------------------------------------------------
		-- ACQUIRE NEW TARGET
		-- ----------------------------------------------------

		if Target == nil then

			AI.Ctrl:SetState(
				Controller.WEAPON_FIRE,
				false
			);

			if SearchTimer:IsPastSimMS(
				SEARCH_INTERVAL
			) then

				SearchTimer:Reset();

				-- Sharp aim is intentionally maintained while
				-- scanning. This is also how the native Sentry
				-- improves spotting range.
				AI.Ctrl:SetState(
					Controller.AIM_SHARP,
					true
				);

				Target =
					Targeting.FindBestTarget(
						Owner,
						SEARCH_RADIUS
					);

				if Target ~= nil then

					AI.Target = Target;
					AI.UnseenTarget = Target;

					LostTargetTimer:Reset();

				end

			end

		end


		-- ----------------------------------------------------
		-- ENGAGE
		-- ----------------------------------------------------

		if Target ~= nil then

			if FireAtTarget(
				AI,
				Owner,
				Target
			) then

				LostTargetTimer:Reset();

			else

				AI.Ctrl:SetState(
					Controller.WEAPON_FIRE,
					false
				);

			end

		else

			-- No enemy: maintain sentry orientation.
			AI.Ctrl:SetState(
				Controller.WEAPON_FIRE,
				false
			);

			AI.Ctrl:SetState(
				Controller.AIM_UP,
				false
			);

			AI.Ctrl:SetState(
				Controller.AIM_DOWN,
				false
			);

			if AI.SentryFacing ~= nil
				and Owner.HFlipped ~= AI.SentryFacing then

				Owner.HFlipped =
					AI.SentryFacing;

			end

		end


		-- ----------------------------------------------------
		-- RETURN CONTROL TO AI SYSTEM
		-- ----------------------------------------------------

		coroutine.yield();

	end


	-- ========================================================
	-- CLEANUP
	-- ========================================================

	ClearCombatControls(AI);

	AI.Ctrl:SetState(
		Controller.AIM_SHARP,
		false
	);

	AI.Target = nil;
	AI.UnseenTarget = nil;

end
