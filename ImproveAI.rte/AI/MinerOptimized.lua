-- ============================================================
-- ImproveAI.rte
-- MinerOptimized.lua
--
-- Optimized tunnel-mining behaviour.
--
-- Design:
--
--   Surface = level 0
--   First gallery = level -1
--   Each gallery is 6 Constructor blocks high.
--   Gallery floor / next gallery ceiling are shared.
--
-- Structured tunnel mining. Heavy work is deliberately delegated
-- to native CCCP behaviours whenever possible.
--
-- The Constructor is responsible for the actual construction
-- and material collection.
--
-- This behaviour only controls:
--
--   - equipment
--   - anchor detection
--   - safe depth
--   - horizontal excavation
--   - gallery progression
--   - Constructor activation
--
-- Native AI pathfinding and native mining are deliberately
-- reused whenever possible.
--
-- Geometry:
--   surface = level 0
--   first gallery = level 1
--   tunnel height = 6 x 12 px
--   gallery floor is shared with the ceiling of the next level
-- ============================================================

ImproveAI_MinerOptimized = ImproveAI_MinerOptimized or {};
local Config = ImproveAI_MinerOptimized;

Config.BlockSize = 12;
Config.TunnelHeightBlocks = 6;
Config.SectionLengthBlocks = 12;
Config.BottomSafetyPixels = 60;
Config.ConstructorBlockCost = 200;
Config.ConstructorReserve = 200;
Config.EquipmentCheckMS = 1000;
Config.SectionCheckMS = 500;
Config.ConstructorSearchRadius = 100;
Config.Debug = false;

local function ValidActor(Owner)
	return Owner and MovableMan:ValidMO(Owner) and IsActor(Owner);
end

local function IsConstructor(Device)
	return Device and (Device.PresetName == "Constructor" or Device:GetStringValue("ConstructorMode") ~= nil);
end

local function GetConstructor(Owner)
	if Owner.EquippedItem and IsConstructor(Owner.EquippedItem) then
		return Owner.EquippedItem;
	end

	if Owner:HasObject("Constructor") then
		Owner:EquipNamedDevice("Constructor", true);
		if Owner.EquippedItem and IsConstructor(Owner.EquippedItem) then
			return Owner.EquippedItem;
		end
	end

	if Owner:HasObjectInGroup("Tools - Constructors") then
		Owner:EquipDeviceInGroup("Tools - Constructors", true);
		if Owner.EquippedItem and IsConstructor(Owner.EquippedItem) then
			return Owner.EquippedItem;
		end
	end
end

local function SearchConstructor(AI, Owner)
	if AI.PickupHD then
		return true;
	end

	AI.NextBehavior = coroutine.create(HumanBehaviors.ToolSearch);
	AI.NextBehaviorName = "ToolSearch";
	return true;
end

local function EnsureConstructor(AI, Owner)
	local Constructor = GetConstructor(Owner);
	if Constructor then
		return Constructor;
	end
	SearchConstructor(AI, Owner);
end

local function GetExplicitAnchor(Owner)
	local anchors = ImproveAI_MiningAnchors;
	if anchors then
		local Anchor = anchors[Owner.UniqueID or Owner.ID];
		if Anchor then
			return Vector(Anchor.X, Anchor.Y), Anchor.Direction;
		end
	end
end

function Config.FindAnchor(Owner)
	local Anchor, Direction = GetExplicitAnchor(Owner);
	if Anchor then
		return Anchor, Direction;
	end

	local Origin = Owner.Pos;
	local left = SceneMan:CastObstacleRay(Origin, Vector(-48, 0), Vector(), Vector(), Owner.ID, Owner.IgnoresWhichTeam, rte.grassID, 3);
	local right = SceneMan:CastObstacleRay(Origin, Vector(48, 0), Vector(), Vector(), Owner.ID, Owner.IgnoresWhichTeam, rte.grassID, 3);
	local wallX;

	if left >= 0 then
		wallX = Origin.X - left;
		Direction = 1;
	elseif right >= 0 then
		wallX = Origin.X + right;
		Direction = -1;
	else
		return nil;
	end

	local floorHit = Vector();
	if SceneMan:CastObstacleRay(Origin, Vector(0, math.max(Owner.Height * 0.75, 24)), Vector(), floorHit, Owner.ID, Owner.IgnoresWhichTeam, rte.grassID, 3) < 0 then
		return nil;
	end

	return Vector(wallX, floorHit.Y), Direction;
end

function Config.GetMaximumGalleryY()
	return SceneMan.SceneHeight - Config.BottomSafetyPixels;
end

function Config.GetGalleryFloor(Anchor, Level)
	return Vector(Anchor.X, Anchor.Y + Level * Config.TunnelHeightBlocks * Config.BlockSize);
end

local function ActivateConstructor(AI, Owner, Constructor)
	if not Constructor then
		return false;
	end

	-- Never invent material. Let the miner dig if the next medium
	-- construction unit cannot be paid for.
	if Constructor.resource ~= nil and Constructor.resource < Config.ConstructorBlockCost + Config.ConstructorReserve then
		return false;
	end

	Owner.AIMode = Actor.AIMODE_GOLDDIG;
	AI.Ctrl:SetState(Controller.WEAPON_FIRE, true);
	return true;
end

local function MoveTo(AI, Owner, Position)
	Owner:ClearAIWaypoints();
	Owner:AddAISceneWaypoint(Position);
	AI:CreateGoToBehavior(Owner);
end

function MinerOptimized(AI, Owner, Abort)
	if not ValidActor(Owner) then
		return true;
	end

	local Anchor, Direction = Config.FindAnchor(Owner);
	if not Anchor then
		return true;
	end

	AI.MinerAnchor = Anchor;
	AI.MinerLevel = AI.MinerLevel or 1;
	AI.MinerDirection = AI.MinerDirection or Direction or (Owner.HFlipped and -1 or 1);

	local EquipmentTimer = Timer();
	local SectionTimer = Timer();
	local Target;

	while not Abort() do
		if not ValidActor(Owner) then
			break;
		end

		if EquipmentTimer:IsPastSimMS(Config.EquipmentCheckMS) then
			EquipmentTimer:Reset();
			local Constructor = EnsureConstructor(AI, Owner);
			if Constructor then
				AI.MinerConstructor = Constructor;
			end
		end

		local Floor = Config.GetGalleryFloor(AI.MinerAnchor, AI.MinerLevel);
		if Floor.Y >= Config.GetMaximumGalleryY() then
			break;
		end

		if SectionTimer:IsPastSimMS(Config.SectionCheckMS) then
			SectionTimer:Reset();

			local Constructor = AI.MinerConstructor;
			if not Constructor or not MovableMan:ValidMO(Constructor) then
				Constructor = EnsureConstructor(AI, Owner);
				AI.MinerConstructor = Constructor;
			end

			ActivateConstructor(AI, Owner, Constructor);

			Target = Vector(
				Floor.X + AI.MinerDirection * Config.SectionLengthBlocks * Config.BlockSize,
				Floor.Y - Config.BlockSize * 3
			);

			MoveTo(AI, Owner, Target);
		end

		coroutine.yield();
	end

	AI.Ctrl:SetState(Controller.WEAPON_FIRE, false);
	AI.MinerConstructor = nil;
	return true;
end
