-- ============================================================
-- ImproveAI.rte
-- MinerOptimized.lua
--
<<<<<<< HEAD
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
=======
-- Structured tunnel mining using an explicit Anchor.
-- Heavy work is delegated to native AI/navigation whenever
-- possible. The optimized constructor unit is medium (12 px).
>>>>>>> origin/11-new-constructor-issue
-- ============================================================

ImproveAI_MinerOptimized = ImproveAI_MinerOptimized or {};
local Miner = ImproveAI_MinerOptimized;

Miner.BlockSize = 12;
Miner.TunnelHeightBlocks = 6;
Miner.SectionLengthBlocks = 12;
Miner.BottomSafetyPixels = 60;
Miner.ConstructorBlockCost = 200;
Miner.ConstructorReserveMargin = 200;
Miner.EquipmentCheckMS = 1000;
Miner.SectionCheckMS = 500;

local function ValidActor(Owner)
	return Owner and MovableMan:ValidMO(Owner) and IsActor(Owner);
end

local function IsConstructor(Device)
	return Device
		and (Device.PresetName == "Constructor"
		or Device:GetStringValue("ConstructorMode") ~= nil);
end

local function GetConstructor(Owner)
	local Item = Owner.EquippedItem;
	if IsConstructor(Item) then
		return Item;
	end

	if Owner:HasObject("Constructor") then
		Owner:EquipNamedDevice("Constructor", true);
		Item = Owner.EquippedItem;
		if IsConstructor(Item) then
			return Item;
		end
	end

	if Owner:HasObjectInGroup("Tools - Constructors") then
		Owner:EquipDeviceInGroup("Tools - Constructors", true);
		Item = Owner.EquippedItem;
		if IsConstructor(Item) then
			return Item;
		end
	end
end

local function GetAnchor(Owner)
	if not ImproveAI_MiningAnchors then
		return nil;
	end

	local Data = ImproveAI_MiningAnchors[Owner.UniqueID or Owner.ID];
	if not Data then
		return nil;
	end

	return Vector(Data.X, Data.Y), Data.Direction;
end

local function MoveTo(AI, Owner, Position)
	Owner:ClearAIWaypoints();
	Owner:AddAISceneWaypoint(Position);
	AI:CreateGoToBehavior(Owner);
end

local function HasConstructorReserve(Constructor)
	return Constructor
		and Constructor.resource ~= nil
		and Constructor.resource >= Miner.ConstructorBlockCost + Miner.ConstructorReserveMargin;
end

function Miner.GetGalleryFloor(Anchor, Level)
	return Vector(
		Anchor.X,
		Anchor.Y + Level * Miner.TunnelHeightBlocks * Miner.BlockSize
	);
end

function Miner.GetMaximumGalleryY()
	return SceneMan.SceneHeight - Miner.BottomSafetyPixels;
end

function Miner.FindAnchor(Owner)
	return GetAnchor(Owner);
end

function Miner(AI, Owner, Abort)
	if not ValidActor(Owner) then
		return true;
	end

	local Anchor, Direction = Miner.FindAnchor(Owner);
	if not Anchor then
		return true;
	end

	AI.MinerAnchor = Anchor;
	AI.MinerLevel = AI.MinerLevel or 1;
	AI.MinerDirection = AI.MinerDirection
		or Direction
		or (Owner.HFlipped and -1 or 1);

	local EquipmentTimer = Timer();
	local SectionTimer = Timer();
	local Constructor = nil;

	while not Abort() do
		if not ValidActor(Owner) then
			break;
		end

		if EquipmentTimer:IsPastSimMS(Miner.EquipmentCheckMS) then
			EquipmentTimer:Reset();
			Constructor = GetConstructor(Owner) or Constructor;
			AI.MinerConstructor = Constructor;
		end

		local Floor = Miner.GetGalleryFloor(
			AI.MinerAnchor,
			AI.MinerLevel
		);

		if Floor.Y >= Miner.GetMaximumGalleryY() then
			break;
		end

		if SectionTimer:IsPastSimMS(Miner.SectionCheckMS) then
			SectionTimer:Reset();

			Constructor = GetConstructor(Owner) or Constructor;
			AI.MinerConstructor = Constructor;

			if HasConstructorReserve(Constructor) then
				Owner.AIMode = Actor.AIMODE_GOLDDIG;
				AI.Ctrl:SetState(Controller.WEAPON_FIRE, true);
			else
				AI.Ctrl:SetState(Controller.WEAPON_FIRE, true);
			end

			local Target = Vector(
				Floor.X + AI.MinerDirection * Miner.SectionLengthBlocks * Miner.BlockSize,
				Floor.Y - Miner.BlockSize * 3
			);

			MoveTo(AI, Owner, Target);
		end

		coroutine.yield();
	end

	AI.Ctrl:SetState(Controller.WEAPON_FIRE, false);
	AI.MinerConstructor = nil;
	return true;
end
