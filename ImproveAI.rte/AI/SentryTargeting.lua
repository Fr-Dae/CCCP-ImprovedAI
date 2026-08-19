-- ============================================================
-- ImproveAI.rte
-- SentryTargeting.lua
--
-- Target acquisition for the ImproveAI Sentry behaviour.
--
-- This file deliberately uses only APIs already observed in
-- CCCP/Base.rte and in the ImproveAI documentation.
-- ============================================================

ImproveAI_SentryTargeting = ImproveAI_SentryTargeting or {};

local Targeting = ImproveAI_SentryTargeting;


-- ============================================================
-- CONFIGURATION
-- ============================================================

Targeting.DefaultSearchRadius = 900;

-- Material used by the native AI raycasts.
Targeting.RayMaterial = rte.grassID;

-- Skip radius results belonging to the same root object.
Targeting.RequireEnemyTeam = true;


-- ============================================================
-- BASIC MO VALIDATION
-- ============================================================

function Targeting.IsValidMO(MO)

	if MO == nil then
		return false;
	end

	return MovableMan:ValidMO(MO);

end


function Targeting.GetRootMO(MO)

	if not Targeting.IsValidMO(MO) then
		return nil;
	end

	local RootID = MO.RootID;

	if RootID == nil then
		return MO;
	end

	local Root = MovableMan:GetMOFromID(RootID);

	if Targeting.IsValidMO(Root) then
		return Root;
	end

	return MO;

end


-- ============================================================
-- ACTOR TEST
-- ============================================================

function Targeting.IsActor(MO)

	if not Targeting.IsValidMO(MO) then
		return false;
	end

	return MO.ClassName == "AHuman"
		or MO.ClassName == "ACrab";

end


-- ============================================================
-- TEAM FILTER
-- ============================================================

function Targeting.IsEnemy(Owner, MO)

	if not Targeting.IsValidMO(MO) then
		return false;
	end

	if MO.ID == Owner.ID then
		return false;
	end

	if MO.RootID == Owner.RootID then
		return false;
	end

	-- Neutral objects are not enemies.
	if MO.Team == Activity.NOTEAM then
		return false;
	end

	if Targeting.RequireEnemyTeam then
		if MO.Team == Owner.Team then
			return false;
		end
	end

	return true;

end


-- ============================================================
-- TARGET HEALTH / STATE
-- ============================================================

function Targeting.IsAlive(MO)

	if not Targeting.IsValidMO(MO) then
		return false;
	end

	-- Actors expose IsDead().
	if MO.IsDead ~= nil then
		if MO:IsDead() then
			return false;
		end
	end

	-- Some MOs expose Health.
	if MO.Health ~= nil then
		if MO.Health <= 0 then
			return false;
		end
	end

	return true;

end


-- ============================================================
-- DISTANCE
-- ============================================================

function Targeting.GetDistance(Owner, Target)

	if not Targeting.IsValidMO(Target) then
		return math.huge;
	end

	local Trace = SceneMan:ShortestDistance(
		Owner.EyePos,
		Target.Pos,
		false
	);

	return Trace.Magnitude;

end


-- ============================================================
-- TERRAIN LINE OF SIGHT
-- ============================================================

function Targeting.HasTerrainLOS(Owner, Target)

	if not Targeting.IsValidMO(Owner) then
		return false;
	end

	if not Targeting.IsValidMO(Target) then
		return false;
	end

	local Trace = SceneMan:ShortestDistance(
		Owner.EyePos,
		Target.Pos,
		false
	);

	if Trace.Magnitude <= 1 then
		return true;
	end

	-- Native CCCP AI uses CastObstacleRay with a negative result
	-- meaning that no obstacle was encountered.
	--
	-- We deliberately exclude the target MO itself using target.ID.
	local RayLength = SceneMan:CastObstacleRay(
		Owner.EyePos,
		Trace,
		Vector(),
		Vector(),
		Target.ID,
		Owner.IgnoresWhichTeam,
		rte.grassID,
		9
	);

	return RayLength < 0;

end


-- ============================================================
-- COMPLETE LINE OF SIGHT
--
-- First checks terrain.
-- Then checks whether the target can actually be reached by an
-- MO ray.
-- ============================================================

function Targeting.HasLOS(Owner, Target)

	if not Targeting.IsEnemy(Owner, Target) then
		return false;
	end

	if not Targeting.IsAlive(Target) then
		return false;
	end

	if not Targeting.HasTerrainLOS(Owner, Target) then
		return false;
	end

	return true;

end


-- ============================================================
-- RAYCAST
--
-- Returns the root MO hit by a CastMORay.
-- ============================================================

function Targeting.CastTargetRay(Owner, Trace)

	local ID = SceneMan:CastMORay(
		Owner.EyePos,
		Trace,
		Owner.ID,
		Owner.IgnoresWhichTeam,
		rte.grassID,
		false,
		5
	);

	if ID == rte.NoMOID then
		return nil;
	end

	local MO = MovableMan:GetMOFromID(ID);

	if not Targeting.IsValidMO(MO) then
		return nil;
	end

	return Targeting.GetRootMO(MO);

end


-- ============================================================
-- TARGET SCORE
-- ============================================================

function Targeting.ScoreTarget(Owner, Target)

	local Trace = SceneMan:ShortestDistance(
		Owner.EyePos,
		Target.Pos,
		false
	);

	local Distance = Trace.Magnitude;

	-- Distance is the base score.
	local Score = Distance;

	-- Prefer actual actors over miscellaneous MOs.
	if Targeting.IsActor(Target) then
		Score = Score * 0.70;
	end

	return Score;

end


-- ============================================================
-- FIND BEST TARGET
--
-- Uses GetMOsInRadius(), which is already used extensively by
-- the native HumanBehaviors code.
-- ============================================================

function Targeting.FindBestTarget(Owner, SearchRadius)

	SearchRadius = SearchRadius or Targeting.DefaultSearchRadius;

	local BestTarget = nil;
	local BestScore = math.huge;

	-- Avoid evaluating the same root actor several times when
	-- the radius iterator encounters limbs/attachments.
	local SeenRoots = {};

	for MO in MovableMan:GetMOsInRadius(
		Owner.Pos,
		SearchRadius,
		-1,
		true
	) do

		if Targeting.IsValidMO(MO) then

			local Root = Targeting.GetRootMO(MO);

			if Targeting.IsValidMO(Root) then

				if not SeenRoots[Root.ID] then

					SeenRoots[Root.ID] = true;

					if Targeting.IsEnemy(Owner, Root)
						and Targeting.IsAlive(Root)
						and Targeting.HasLOS(Owner, Root) then

						local Score =
							Targeting.ScoreTarget(
								Owner,
								Root
							);

						if Score < BestScore then

							BestScore = Score;
							BestTarget = Root;

						end

					end

				end

			end

		end

	end

	return BestTarget;

end


-- ============================================================
-- KEEP / VALIDATE EXISTING TARGET
-- ============================================================

function Targeting.IsTargetStillValid(Owner, Target)

	if not Targeting.IsValidMO(Target) then
		return false;
	end

	local Root = Targeting.GetRootMO(Target);

	if not Targeting.IsValidMO(Root) then
		return false;
	end

	if not Targeting.IsEnemy(Owner, Root) then
		return false;
	end

	if not Targeting.IsAlive(Root) then
		return false;
	end

	return Targeting.HasLOS(Owner, Root);

end
