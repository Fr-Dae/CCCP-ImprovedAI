-- ============================================================
-- ImproveAI.rte
-- MinerOptimized.lua
--
-- Optimized tunnel-mining behaviour.
--
-- Design:
--   Surface = level 0
--   First gallery = level -1
--   Each gallery is 6 medium Constructor blocks high.
--   Medium reference block = 12 px.
--   Gallery floor / next gallery ceiling are shared.
--
-- The Constructor performs the actual construction and material
-- collection. This behaviour does not create resources.
--
-- The script deliberately remains small and timer-driven. Native
-- CCCP movement, tool search and digging behaviours are reused
-- instead of duplicating their implementations.
-- ============================================================

ImproveAI_MinerOptimized = ImproveAI_MinerOptimized or {};
local MinerOptimized = ImproveAI_MinerOptimized;


-- ============================================================
-- CONFIGURATION
-- ============================================================

MinerOptimized.BlockSize = 12;
MinerOptimized.TunnelHeightBlocks = 6;
MinerOptimized.StairWidthBlocks = 3;
MinerOptimized.SectionLengthBlocks = 12;
MinerOptimized.BottomSafetyPixels = 60;

-- One medium 12x12 block costs 200 Constructor resource units.
-- Keep an additional 200 units as a safety margin for the next
-- construction operation / minor repairs.
MinerOptimized.BlockCost = 200;
MinerOptimized.BuildReserveMargin = 200;

MinerOptimized.EquipmentCheckMS = 1000;
MinerOptimized.SectionCheckMS = 500;


-- ============================================================
-- BASIC VALIDATION
-- ============================================================

local function ValidActor(Owner)
	return Owner
		and MovableMan:ValidMO(Owner)
		and IsActor(Owner);
end


-- ============================================================
-- CONSTRUCTOR
-- ============================================================

local function IsConstructor(Device)
	return Device
		and Device.PresetName == "Constructor";
end


local function GetConstructor(Owner)
	if IsConstructor(Owner.EquippedItem) then
		return Owner.EquippedItem;
	end

	-- Native equipment search handles inventory contents.
	if Owner:EquipDeviceInGroup("Tools - Constructors", true)
		and IsConstructor(Owner.EquippedItem) then
		return Owner.EquippedItem;
	end

	return nil;
end


local function EnsureConstructor(AI, Owner)
	local Constructor = GetConstructor(Owner);
	if Constructor then
		return Constructor;
	end

	-- Reuse the native ToolSearch behaviour for a Constructor
	-- that is not currently in the actor's equipment.
	AI:CreateGetToolBehavior(Owner);
	return nil;
end


local function ConstructorHasReserve(Constructor)
	if not Constructor or Constructor.resource == nil then
		return false;
	end

	return Constructor.resource >=
		(MinerOptimized.BlockCost + MinerOptimized.BuildReserveMargin);
end


-- ============================================================
-- ANCHOR
-- ============================================================

local function GetAnchor(Owner)
	local Data = ImproveAI_MiningAnchors
		and ImproveAI_MiningAnchors[Owner.UniqueID or Owner.ID];

	if not Data then
		return nil;
	end

	return Vector(Data.X, Data.Y), Data.Direction;
end


function MinerOptimized.FindAnchor(Owner)
	return GetAnchor(Owner);
end


-- ============================================================
-- GALLERY GEOMETRY
-- ============================================================

function MinerOptimized.GetGalleryFloor(Anchor, Level)
	return Vector(
		Anchor.X,
		Anchor.Y + Level * MinerOptimized.TunnelHeightBlocks * MinerOptimized.BlockSize
	);
end


function MinerOptimized.GetMaximumGalleryY()
	return SceneMan.SceneHeight - MinerOptimized.BottomSafetyPixels;
end


function MinerOptimized.IsSafeDepth(Y)
	return Y < MinerOptimized.GetMaximumGalleryY();
end


function MinerOptimized.GetSectionTarget(Anchor, Level, Direction, Section)
	local Floor = MinerOptimized.GetGalleryFloor(Anchor, Level);
	return Vector(
		Floor.X + Direction * Section * MinerOptimized.SectionLengthBlocks * MinerOptimized.BlockSize,
		Floor.Y - MinerOptimized.BlockSize * 3
	);
end


-- ============================================================
-- MINING CONTROLS
-- ============================================================

local function ClearMiningControls(AI)
	AI.Ctrl:SetState(Controller.WEAPON_FIRE, false);
	AI.Ctrl:SetState(Controller.AIM_UP, false);
	AI.Ctrl:SetState(Controller.AIM_DOWN, false);
	AI.Ctrl:SetState(Controller.AIM_SHARP, false);
end


-- ============================================================
-- GOLD DIG DISPATCH
--
-- NativeHumanAI selects HumanBehaviors.GoldDig for AIMODE_GOLDDIG.
-- We keep the native function for normal miners and dispatch to
-- MinerOptimized only when the Pie Menu explicitly enabled the
-- ImproveAI flag on that actor.
-- ============================================================

if not ImproveAI_NativeGoldDig then
	ImproveAI_NativeGoldDig = HumanBehaviors.GoldDig;
end


local function GoldDigDispatch(AI, Owner, Abort)
	if Owner
		and Owner.NumberValueExists
		and Owner:NumberValueExists("ImproveAI_MinerOptimized")
		and Owner:GetNumberValue("ImproveAI_MinerOptimized") == 1 then
		return MinerOptimized(AI, Owner, Abort);
	end

	return ImproveAI_NativeGoldDig(AI, Owner, Abort);
end


HumanBehaviors.GoldDig = GoldDigDispatch;


-- ============================================================
-- MAIN BEHAVIOUR
-- ============================================================

function MinerOptimized(AI, Owner, Abort)
	if not ValidActor(Owner) then
		return true;
	end

	AI.Ctrl = AI.Ctrl or Owner:GetController();

	local Anchor, Direction = MinerOptimized.FindAnchor(Owner);
	if not Anchor then
		ClearMiningControls(AI);
		return true;
	end

	AI.MinerAnchor = Anchor;
	AI.MinerLevel = AI.MinerLevel or 1;
	AI.MinerDirection = AI.MinerDirection
		or Direction
		or (Owner.HFlipped and -1 or 1);
	AI.MinerSection = AI.MinerSection or 1;

	local EquipmentTimer = Timer();
	local SectionTimer = Timer();
	local Constructor = nil;

	while not Abort() do
		if not ValidActor(Owner) then
			break;
		end

		if EquipmentTimer:IsPastSimMS(MinerOptimized.EquipmentCheckMS) then
			EquipmentTimer:Reset();
			Constructor = EnsureConstructor(AI, Owner);
			AI.MinerConstructor = Constructor;
			AI.MinerNeedsMaterial = not ConstructorHasReserve(Constructor);
		end

		if not Constructor then
			ClearMiningControls(AI);
			coroutine.yield();
		else
			local Floor = MinerOptimized.GetGalleryFloor(
				AI.MinerAnchor,
				AI.MinerLevel
			);

			if not MinerOptimized.IsSafeDepth(Floor.Y) then
				break;
			end

			if SectionTimer:IsPastSimMS(MinerOptimized.SectionCheckMS) then
				SectionTimer:Reset();

				local Target = MinerOptimized.GetSectionTarget(
					AI.MinerAnchor,
					AI.MinerLevel,
					AI.MinerDirection,
					AI.MinerSection
				);

				AI.MinerSectionTarget = Target;

				local Distance = SceneMan:ShortestDistance(
					Owner.Pos,
					Target,
					SceneMan.SceneWrapsX
				);

				if Distance:MagnitudeIsLessThan(MinerOptimized.BlockSize * 2) then
					AI.MinerSection = AI.MinerSection + 1;
				else
					Owner:ClearAIWaypoints();
					Owner:AddAISceneWaypoint(Target);
					AI:CreateGoToBehavior(Owner);
				end
			end

			-- With insufficient material the Constructor cannot build the
			-- next section. The miner is still allowed to continue the
			-- native digging/movement path; resources must be collected
			-- from terrain and are never fabricated by this script.
			if ConstructorHasReserve(Constructor) then
				AI.Ctrl:SetState(Controller.WEAPON_FIRE, true);
			else
				AI.Ctrl:SetState(Controller.WEAPON_FIRE, false);
			end
		end

		coroutine.yield();
	end

	ClearMiningControls(AI);
	AI.MinerConstructor = nil;
	AI.MinerSectionTarget = nil;
	return true;
end
