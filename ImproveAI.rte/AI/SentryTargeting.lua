-- ============================================================
-- ImproveAI.rte
-- SentryTargeting.lua
--
-- Target acquisition for Sentry behaviours.
--
-- Target selection is separated from Sentry behaviour.
--
-- Search distance is primarily derived from HDFirearm.SharpLength
-- because Sentry uses AIM_SHARP when engaging targets.
--
-- Expensive operations are deliberately performed only after
-- inexpensive candidate filters.
-- ============================================================


ImproveAI_SentryTargeting =
		ImproveAI_SentryTargeting or {};

local Targeting = ImproveAI_SentryTargeting;


-- ============================================================
-- LOCAL ENGINE FUNCTIONS
--
-- Local references avoid repeated Lua binding lookups.
-- SceneMan / MovableMan must be passed explicitly when using
-- the localized functions.
-- ============================================================

local ShortestDistance = SceneMan.ShortestDistance;
local CastObstacleRay = SceneMan.CastObstacleRay;
local GetMOsInRadius = MovableMan.GetMOsInRadius;


-- ============================================================
-- CONFIGURATION
-- ============================================================

Targeting.DefaultSearchRadius = 500;
Targeting.MinimumSearchRadius = 120;
Targeting.MaximumSearchRadius = 2500;

Targeting.RayMaterial = rte.grassID;

Targeting.ActorScoreMultiplier = 0.70;

Targeting.SearchIntervalMS = 250;
Targeting.TargetValidationIntervalMS = 100;

Targeting.RequireEnemyTeam = true;


-- ============================================================
-- BASIC VALIDATION
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
-- ACTOR
-- ============================================================

function Targeting.IsActor(MO)

	if not Targeting.IsValidMO(MO) then
		return false;
	end

	return MO.ClassName == "AHuman"
		or MO.ClassName == "ACrab";

end


-- ============================================================
-- TEAM
-- ============================================================

function Targeting.IsEnemy(Owner, MO)

	if not Targeting.IsValidMO(MO) then
		return false;
	end

	local OwnerID = Owner.ID;
	local OwnerRootID = Owner.RootID;
	local OwnerTeam = Owner.Team;

	local MOID = MO.ID;
	local MORootID = MO.RootID;
	local MOTeam = MO.Team;

	if MOID == OwnerID then
		return false;
	elseif MORootID == OwnerRootID then
		return false;
	elseif MOTeam == Activity.NOTEAM then
		return false;
	elseif Targeting.RequireEnemyTeam
		and MOTeam == OwnerTeam then
		return false;
	end

	return true;

end


-- ============================================================
-- LIFE
-- ============================================================

function Targeting.IsAlive(MO)

	if not Targeting.IsValidMO(MO) then
		return false;
	end

	if MO.IsDead ~= nil and MO:IsDead() then
		return false;
	elseif MO.Health ~= nil and MO.Health <= 0 then
		return false;
	end

	return true;

end


-- ============================================================
-- TRACE
-- ============================================================

function Targeting.GetTrace(Owner, Target)

	local OwnerEyePos = Owner.EyePos;
	local TargetPos = Target.Pos;

	return ShortestDistance(
		SceneMan,
		OwnerEyePos,
		TargetPos,
		false
	);

end


function Targeting.GetDistance(Owner, Target)

	if not Targeting.IsValidMO(Target) then
		return math.huge;
	end

	return Targeting.GetTrace(
		Owner,
		Target
	).Magnitude;

end


-- ============================================================
-- TERRAIN LINE OF SIGHT
--
-- Trace may be supplied when it has already been calculated.
-- This avoids performing ShortestDistance twice for the same
-- candidate during target acquisition.
-- ============================================================

function Targeting.HasTerrainLOS(
	Owner,
	Target,
	Trace
)

	if not Targeting.IsValidMO(Owner)
		or not Targeting.IsValidMO(Target) then
		return false;
	end

	Trace = Trace or Targeting.GetTrace(
		Owner,
		Target
	);

	if Trace.Magnitude <= 1 then
		return true;
	end

	local OwnerEyePos = Owner.EyePos;
	local IgnoreTeam = Owner.IgnoresWhichTeam;

	local RayLength = CastObstacleRay(
		SceneMan,
		OwnerEyePos,
		Trace,
		Vector(),
		Vector(),
		Target.ID,
		IgnoreTeam,
		Targeting.RayMaterial,
		9
	);

	return RayLength < 0;

end


-- ============================================================
-- COMPLETE LOS
-- ============================================================

function Targeting.HasLOS(
	Owner,
	Target,
	Trace
)

	if not Targeting.IsEnemy(Owner, Target)
		or not Targeting.IsAlive(Target) then
		return false;
	end

	return Targeting.HasTerrainLOS(
		Owner,
		Target,
		Trace
	);

end


-- ============================================================
-- WEAPON
-- ============================================================

function Targeting.GetEquippedWeapon(Owner)

	local EquippedItem = Owner.EquippedItem;

	if not EquippedItem then
		return nil;
	end

	if IsHDFirearm(EquippedItem) then
		return EquippedItem;
	end

	return nil;

end


-- ============================================================
-- WEAPON SEARCH RANGE
--
-- HDFirearm.SharpLength is the distance at which the weapon
-- can be aimed precisely.
--
-- This is preferable to an arbitrary global search radius for
-- Sentry because the Sentry uses AIM_SHARP while engaging.
--
-- SharpLength is not the physical projectile lifetime/range.
-- It is therefore treated as the effective targeting range,
-- not as a claim about the projectile's absolute maximum range.
-- ============================================================

function Targeting.GetWeaponRange(Weapon)

	if not Weapon then
		return Targeting.DefaultSearchRadius;
	end

	local SharpLength = Weapon.SharpLength;

	if SharpLength == nil or SharpLength <= 0 then
		return Targeting.DefaultSearchRadius;
	end

	if SharpLength < Targeting.MinimumSearchRadius then
		return Targeting.MinimumSearchRadius;
	elseif SharpLength > Targeting.MaximumSearchRadius then
		return Targeting.MaximumSearchRadius;
	end

	return SharpLength;

end


-- ============================================================
-- SEARCH RANGE
-- ============================================================

function Targeting.GetSearchRadius(Owner)

	local Weapon = Targeting.GetEquippedWeapon(Owner);

	if Weapon then
		return Targeting.GetWeaponRange(Weapon);
	end

	return Targeting.DefaultSearchRadius;

end


-- ============================================================
-- TARGET SCORE
--
-- Distance remains the primary factor.
--
-- Actors receive a small preference over miscellaneous MOs.
-- ============================================================

function Targeting.ScoreTarget(
	Owner,
	Target,
	Distance
)

	local Score = Distance;

	if Targeting.IsActor(Target) then
		Score = Score * Targeting.ActorScoreMultiplier;
	end

	return Score;

end


-- ============================================================
-- FIND BEST TARGET
--
-- Expensive operations are deliberately ordered:
--
--   1. Valid MO
--   2. Root MO
--   3. Duplicate root
--   4. Enemy
--   5. Alive
--   6. Distance
--   7. Terrain raycast
--   8. Target scoring
--
-- The trace is calculated once and reused by LOS and scoring.
-- ============================================================

function Targeting.FindBestTarget(
	Owner,
	SearchRadius
)

	SearchRadius =
		SearchRadius
		or Targeting.GetSearchRadius(Owner);

	local OwnerPos = Owner.Pos;

	local BestTarget = nil;
	local BestScore = math.huge;

	local SeenRoots = {};

	for MO in GetMOsInRadius(
		MovableMan,
		OwnerPos,
		SearchRadius,
		-1,
		true
	) do

		if Targeting.IsValidMO(MO) then

			local Root = Targeting.GetRootMO(MO);

			if Targeting.IsValidMO(Root)
				and not SeenRoots[Root.ID] then

				SeenRoots[Root.ID] = true;

				if Targeting.IsEnemy(
					Owner,
					Root
				)
					and Targeting.IsAlive(Root) then

					local Trace =
						Targeting.GetTrace(
							Owner,
							Root
						);

					local Distance =
						Trace.Magnitude;

					if Distance <= SearchRadius
						and Targeting.HasTerrainLOS(
							Owner,
							Root,
							Trace
						) then

						local Score =
							Targeting.ScoreTarget(
								Owner,
								Root,
								Distance
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
-- EXISTING TARGET
--
-- Used by SentryActive / SentryPassive to determine whether
-- the current target can still be engaged.
-- ============================================================

function Targeting.IsTargetStillValid(
	Owner,
	Target
)

	if not Targeting.IsValidMO(Target) then
		return false;
	end

	local Root = Targeting.GetRootMO(Target);

	if not Targeting.IsValidMO(Root) then
		return false;
	elseif not Targeting.IsEnemy(Owner, Root) then
		return false;
	elseif not Targeting.IsAlive(Root) then
		return false;
	end

	return Targeting.HasLOS(
		Owner,
		Root
	);

end
