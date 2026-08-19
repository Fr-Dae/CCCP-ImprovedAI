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
-- ============================================================

ImproveAI_MinerOptimized =
		ImprooveAI_MinerOptimized or {};

local MinerOptimized = ImproveAI_MinerOptimized;


-- ============================================================
-- CONFIGURATION
-- ============================================================

MinerOptimized.BlockSize = 12;

-- Six 12 px blocks = 72 px tunnel height.
MinerOptimized.TunnelHeightBlocks = 6;

-- Three blocks reserved for the stair opening.
MinerOptimized.StairWidthBlocks = 3;

-- Distance travelled before another gallery section is planned.
MinerOptimized.SectionLengthBlocks = 12;

-- Keep a safety margin above the absolute bottom of the map.
MinerOptimized.BottomSafetyPixels = 60;

-- Do not construct if the Constructor has less than this
-- amount available.
--
-- 12x12 theoretical full cost:
--     16 cells * 10 = 160
--
-- Extra margin is deliberately reserved for repairs.
MinerOptimized.BuildReserveMargin = 80;

-- Constructor resource costs from Constructor.lua.
MinerOptimized.BlockCost = 160;

-- Search/pickup radius for a Constructor lying on the ground.
MinerOptimized.ConstructorSearchRadius = 100;

-- How often equipment is checked.
MinerOptimized.EquipmentCheckMS = 1000;

-- How often the current tunnel section is checked.
MinerOptimized.SectionCheckMS = 500;

-- Debug display.
MinerOptimized.Debug = false;


-- ============================================================
-- BASIC VALIDATION
-- ============================================================

local function ValidActor(Owner)

	return Owner
		and MovableMan:ValidMO(Owner)
		and IsActor(Owner);

end


-- ============================================================
-- CONSTRUCTOR DETECTION
-- ============================================================

local function IsConstructor(Device)

	if not Device then
		return false;
	end

	return Device.PresetName == "Constructor"
		or Device:GetStringValue("ConstructorMode") ~= nil;

end


local function GetConstructor(Owner)

	-- The native inventory system should be used first.
	--
	-- EquipNamedDevice / EquipDeviceInGroup already search
	-- inventory and equip devices without us reproducing the
	-- inventory implementation.

	if Owner.EquippedItem
		and IsConstructor(Owner.EquippedItem) then

		return Owner.EquippedItem;

	end

	if Owner:HasObject("Constructor") then

		if Owner:EquipNamedDevice("Constructor", true) then

			if Owner.EquippedItem
				and IsConstructor(Owner.EquippedItem) then

				return Owner.EquippedItem;

			end

		end

	end

	-- Constructor may be registered as a tool.
	if Owner:EquipDeviceInGroup("Tools - Constructors", true) then

		if Owner.EquippedItem
			and IsConstructor(Owner.EquippedItem) then

			return Owner.EquippedItem;

		end

	end

	return nil;

end


-- ============================================================
-- GROUND CONSTRUCTOR SEARCH
--
-- The native WeaponSearch / ToolSearch behaviour already
-- contains the complete pickup/pathfinding implementation.
--
-- We deliberately delegate to it instead of duplicating it.
-- ============================================================

local function SearchConstructor(AI, Owner)

	-- If the native AI has a pending pickup, let it finish.
	if AI.PickupHD then
		return true;
	end

	-- Native tool search already searches nearby MOs,
	-- validates pickupability and calculates a path.
	AI.NextBehavior =
		coroutine.create(HumanBehaviors.ToolSearch);

	AI.NextBehaviorName = "ToolSearch";

	return true;

end


-- ============================================================
-- EQUIPMENT
-- ============================================================

local function EnsureConstructor(AI, Owner)

	local Constructor = GetConstructor(Owner);

	if Constructor then
		return Constructor;
	end

	SearchConstructor(AI, Owner);

	return nil;

end


-- ============================================================
-- ANCHOR
--
-- The anchor is the intersection between:
--
--   - the artificial vertical wall
--   - the artificial horizontal floor
--
-- The miner is expected to be standing on the floor close to
-- the wall when MinerOptimized starts.
--
-- The first tunnel is therefore level -1.
-- ============================================================

function MinerOptimized.FindAnchor(Owner)

	local Origin = Vector(
		Owner.Pos.X,
		Owner.Pos.Y
	);

	local left = SceneMan:CastObstacleRay(
		Origin,
		Vector(-48, 0),
		Vector(),
		Vector(),
		Owner.ID,
		Owner.IgnoresWhichTeam,
		rte.grassID,
		3
	);

	local right = SceneMan:CastObstacleRay(
		Origin,
		Vector(48, 0),
		Vector(),
		Vector(),
		Owner.ID,
		Owner.IgnoresWhichTeam,
		rte.grassID,
		3
	);

	local wallPoint = nil;

	if left >= 0 then

		wallPoint = Origin + Vector(-left, 0);

	elseif right >= 0 then

		wallPoint = Origin + Vector(right, 0);

	end

	if not wallPoint then
		return nil;
	end

	-- Find the artificial floor immediately below the actor.
	local floorHit = Vector();

	local floorTrace = Vector(
		0,
		math.max(Owner.Height * 0.75, 24)
	);

	if SceneMan:CastObstacleRay(
		Origin,
		floorTrace,
		Vector(),
		floorHit,
		Owner.ID,
		Owner.IgnoresWhichTeam,
		rte.grassID,
		3
	) < 0 then

		return nil;

	end

	return Vector(
		wallPoint.X,
		floorHit.Y
	);

end


-- ============================================================
-- SAFE DEPTH
-- ============================================================

function MinerOptimized.GetMaximumGalleryY()

	-- Cortex Command coordinates increase downward.
	--
	-- Never use SceneHeight itself as a construction point.
	return SceneMan.SceneHeight
		- MinerOptimized.BottomSafetyPixels;

end


function MinerOptimized.IsSafeDepth(Y)

	return Y < MinerOptimized.GetMaximumGalleryY();

end


-- ============================================================
-- GALLERY GEOMETRY
-- ============================================================

function MinerOptimized.GetGalleryFloor(Anchor, Level)

	return Vector(
		Anchor.X,
		Anchor.Y
			+ Level
			* MinerOptimized.TunnelHeightBlocks
			* MinerOptimized.BlockSize
	);

end


function MinerOptimized.GetGalleryCeiling(Anchor, Level)

	return Vector(
		Anchor.X,
		Anchor.Y
			+ (Level - 1)
			* MinerOptimized.TunnelHeightBlocks
			* MinerOptimized.BlockSize
	);

end


-- ============================================================
-- HORIZONTAL DIG TARGET
-- ============================================================

function MinerOptimized.GetDigTarget(
	Anchor,
	Level,
	Direction
)

	local Floor =
		MinerOptimized.GetGalleryFloor(
			Anchor,
			Level
		);

	local distance =
		MinerOptimized.SectionLengthBlocks
		* MinerOptimized.BlockSize;

	local target = Vector(
		Floor.X + Direction * distance,
		Floor.Y - MinerOptimized.BlockSize * 3
	);

	-- Never request a target beyond the safe bottom.
	if target.Y > MinerOptimized.GetMaximumGalleryY() then

		target.Y =
			MinerOptimized.GetMaximumGalleryY();

	end

	return target;

end


-- ============================================================
-- MOVE / DIG
-- ============================================================

local function MoveTo(AI, Owner, Position)

	Owner:ClearAIWaypoints();

	Owner:AddAISceneWaypoint(
		Position
	);

	AI:CreateGoToBehavior(Owner);

	return true;

end


-- ============================================================
-- CONSTRUCTOR ACTIVATION
--
-- The native Constructor AI mode is used.
--
-- Constructor.lua already contains the complete AI autobuild
-- state machine. It reacts to:
--
--   Actor.AIMODE_GOLDDIG
--   Controller.WEAPON_FIRE
--
-- and then creates its own buildList.
-- ============================================================

local function ActivateConstructor(AI, Owner)

	local Constructor =
		EnsureConstructor(AI, Owner);

	if not Constructor then
		return false;
	end

	-- Native Constructor requires GoldDig mode for its AI
	-- autobuild logic.
	Owner.AIMode = Actor.AIMODE_GOLDDIG;

	AI.Ctrl:SetState(
		Controller.WEAPON_FIRE,
		true
	);

	return true;

end


-- ============================================================
-- SECTION LOOP
-- ============================================================

function MinerOptimized(AI, Owner, Abort)

	if not ValidActor(Owner) then
		return true;
	end

	local Anchor =
		MinerOptimized.FindAnchor(Owner);

	if not Anchor then

		-- We cannot safely determine the gallery origin.
		--
		-- Do not start blind excavation.
		return true;

	end

	AI.MinerAnchor = Anchor;
	AI.MinerLevel =
		AI.MinerLevel or 1;

	AI.MinerDirection =
		AI.MinerDirection or
		(Owner.HFlipped and -1 or 1);

	local EquipmentTimer = Timer();
	local SectionTimer = Timer();

	while not Abort() do

		if not ValidActor(Owner) then
			return true;
		end

		-- ----------------------------------------------------
		-- Constructor
		-- ----------------------------------------------------

		if EquipmentTimer:IsPastSimMS(
			MinerOptimized.EquipmentCheckMS
		) then

			EquipmentTimer:Reset();

			local Constructor =
				EnsureConstructor(
					AI,
					Owner
				);

			if not Constructor then

				-- No Constructor available.
				--
				-- Do not fabricate resources and do not attempt
				-- to construct without the actual device.
				coroutine.yield();

			end

		end


		-- ----------------------------------------------------
		-- DEPTH LIMIT
		-- ----------------------------------------------------

		local Floor =
			MinerOptimized.GetGalleryFloor(
				AI.MinerAnchor,
				AI.MinerLevel
			);

		if not MinerOptimized.IsSafeDepth(
			Floor.Y
		) then

			-- Absolute bottom reached.
			--
			-- Stop before the character can be sent outside
			-- the playable scene.
			break;

		end


		-- ----------------------------------------------------
		-- CONSTRUCTOR
		-- ----------------------------------------------------

		if SectionTimer:IsPastSimMS(
			MinerOptimized.SectionCheckMS
		) then

			SectionTimer:Reset();

			ActivateConstructor(
				AI,
				Owner
			);

		end


		-- ----------------------------------------------------
		-- DIG FORWARD
		--
		-- The native GoTo behaviour will use the digging tool
		-- when an obstacle blocks the path.
		-- ----------------------------------------------------

		local Target =
			MinerOptimized.GetDigTarget(
				AI.MinerAnchor,
				AI.MinerLevel,
				AI.MinerDirection
			);

		MoveTo(
			AI,
			Owner,
			Target
		);

		coroutine.yield();

	end


	-- --------------------------------------------------------
	-- CLEANUP
	-- --------------------------------------------------------

	AI.Ctrl:SetState(
		Controller.WEAPON_FIRE,
		false
	);

	AI.MinerAnchor = nil;

	return true;

end
