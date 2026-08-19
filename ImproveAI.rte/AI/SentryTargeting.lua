-- ============================================================
-- ImproveAI.rte
-- SentryTargeting.lua
--
-- Target acquisition for Sentry behaviours.
--
-- The search range is derived from the weapon currently usable
-- by the actor whenever possible.
-- ============================================================

ImproveAI_SentryTargeting = ImproveAI_SentryTargeting or {};

local Targeting = ImproveAI_SentryTargeting;


-- ============================================================
-- CONFIGURATION
-- ============================================================

Targeting.DefaultSearchRadius = 500;
Targeting.MaximumSearchRadius = 2500;
Targeting.MinimumSearchRadius = 120;

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
	else
		return MO;
	end

end


-- ============================================================
-- ACTOR
-- ============================================================

function Targeting.IsActor(MO)

	if not Targeting.IsValidMO(MO) then
		return false;
	elseif MO.ClassName == "AHuman" then
		return true;
	elseif MO.ClassName == "ACrab" then
		return true;
	else
		return false;
	end

end


-- ============================================================
-- TEAM
-- ============================================================

function Targeting.IsEnemy(Owner, MO)

	if not Targeting.IsValidMO(MO) then
		return false;
	elseif MO.ID == Owner.ID then
		return false;
	elseif MO.RootID == Owner.RootID then
		return false;
	elseif MO.Team == Activity.NOTEAM then
		return false;
	elseif Targeting.RequireEnemyTeam
		and MO.Team == Owner.Team then
		return false;
	else
		return true;
	end

end


-- ============================================================
-- LIFE
-- ============================================================

function Targeting.IsAlive(MO)

	if not Targeting.IsValidMO(MO) then
		return false;
	elseif MO.IsDead ~= nil and MO:IsDead() then
		return false;
	elseif MO.Health ~= nil and MO.Health <= 0 then
		return false;
	else
		return true;
	end

end


-- ============================================================
-- DISTANCE
-- ============================================================

function Targeting.GetTrace(Owner, Target)

	return SceneMan:ShortestDistance(
		Owner.EyePos,
		Target.Pos,
		false
	);

end


function Targeting.GetDistance(Owner, Target)

	if not Targeting.IsValidMO(Target) then
		return math.huge;
	end

	return Targeting.GetTrace(Owner, Target).Magnitude;

end


-- ============================================================
-- TERRAIN LOS
-- ============================================================

function Targeting.HasTerrainLOS(Owner, Target)

	if not Targeting.IsValidMO(Owner)
		or not Targeting.IsValidMO(Target) then
		return false;
	end

	local Trace = Targeting.GetTrace(Owner, Target);

	if Trace.Magnitude <= 1 then
		return true;
	end

	local RayLength = SceneMan:CastObstacleRay(
		Owner.EyePos,
		Trace,
		Vector(),
		Vector(),
		Target.ID,
		Owner.IgnoresWhichTeam,
		Targeting.RayMaterial,
		9
	);

	return RayLength < 0;

end


-- ============================================================
-- MO RAY
-- ============================================================

function Targeting.CastTargetRay(Owner, Trace)

	local ID = SceneMan:CastMORay(
		Owner.EyePos,
		Trace,
		Owner.ID,
		Owner.IgnoresWhichTeam,
		Targeting.RayMaterial,
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
-- COMPLETE LOS
-- ============================================================

function Targeting.HasLOS(Owner, Target)

	if not Targeting.IsEnemy(Owner, Target)
		or not Targeting.IsAlive(Target) then
		return false;
	end

	return Targeting.HasTerrainLOS(Owner, Target);

end


-- ============================================================
-- WEAPON IDENTIFICATION
-- ============================================================

function Targeting.GetEquippedWeapon(Owner)

	if not Owner.EquippedItem then
		return nil;
	end

	if IsHDFirearm(Owner.EquippedItem) then
		return Owner.EquippedItem;
	end

	return nil;

end


-- ============================================================
-- WEAPON RANGE
--
-- There is intentionally no hard-coded "900 pixel" search
-- radius here.
--
-- The weapon is used as the primary source of range information.
-- If the engine/mod does not expose enough information for the
-- weapon, the conservative fallback is used.
-- ============================================================

function Targeting.GetWeaponRange(Weapon)

	if not Weapon then
		return Targeting.DefaultSearchRadius;
	end

	local Range = nil;

	-- Prefer explicitly exposed projectile/range information
	-- when available.

	if Weapon.Range ~= nil then
		Range = Weapon.Range;
	end

	if Range == nil and Weapon.ProjectileRange ~= nil then
		Range = Weapon.ProjectileRange;
	end

	if Range == nil and Weapon.MaxRange ~= nil then
		Range = Weapon.MaxRange;
	end

	if Range == nil then
		Range = Targeting.DefaultSearchRadius;
	end

	if Range < Targeting.MinimumSearchRadius then
		Range = Targeting.MinimumSearchRadius;
	elseif Range > Targeting.MaximumSearchRadius then
		Range = Targeting.MaximumSearchRadius;
	end

	return Range;

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
-- ============================================================

function Targeting.ScoreTarget(Owner, Target)

	local Distance = Targeting.GetDistance(Owner, Target);

	local Score = Distance;

	if Targeting.IsActor(Target) then
		Score = Score * Targeting.ActorScoreMultiplier;
	end

	return Score;

end


-- ============================================================
-- FIND TARGET
-- ============================================================

function Targeting.FindBestTarget(Owner, SearchRadius)

	SearchRadius = SearchRadius or Targeting.GetSearchRadius(Owner);

	local BestTarget = nil;
	local BestScore = math.huge;

	local SeenRoots = {};

	for MO in MovableMan:GetMOsInRadius(
		Owner.Pos,
		SearchRadius,
		-1,
		true
	) do

		if Targeting.IsValidMO(MO) then

			local Root = Targeting.GetRootMO(MO);

			if Targeting.IsValidMO(Root)
				and not SeenRoots[Root.ID] then

				SeenRoots[Root.ID] = true;

				if Targeting.IsEnemy(Owner, Root)
					and Targeting.IsAlive(Root)
					and Targeting.HasLOS(Owner, Root) then

					local Score = Targeting.ScoreTarget(
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

	return BestTarget;

end


-- ============================================================
-- EXISTING TARGET
-- ============================================================

function Targeting.IsTargetStillValid(Owner, Target)

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
	else
		return Targeting.HasLOS(Owner, Root);
	end

end
