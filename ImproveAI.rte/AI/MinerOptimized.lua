-- ============================================================
-- ImproveAI.rte
-- MinerOptimized.lua
--
-- Optimized constructor/miner behaviour.
--
-- Objective:
--   - Create regular horizontal galleries.
--   - Gallery height: 6 blocks.
--   - Stair opening: 3 blocks wide.
--   - Maintain a safe depth above the lethal map boundary.
--   - Periodically repair nearby structures.
--
-- The behaviour is deliberately kept lightweight.
-- Expensive terrain checks are performed only when required.
-- ============================================================


ImproveAI_MinerOptimized =
    ImproveAI_MinerOptimized or {};

local Miner = ImproveAI_MinerOptimized;


-- ============================================================
-- CONFIGURATION
-- ============================================================

Miner.GalleryHeight = 6;

Miner.StairWidth = 3;

Miner.BlockSpacing = 12;

Miner.RepairIntervalMS = 300000;

Miner.RepairRadius = 3;

Miner.GallerySpacing = 45;

Miner.SafeDepth = 6;

Miner.GroundMaterial = rte.grassID;


-- ============================================================
-- INITIALISATION
-- ============================================================

function Miner.Initialize(AI, Owner)

	if AI.MinerOptimizedInitialized then
		return;
	end

	AI.MinerOptimizedInitialized = true;

	AI.MinerOptimizedPos =
		Vector(
			Owner.Pos.X,
			Owner.Pos.Y
		);

	AI.MinerOptimizedDirection =
		Owner.HFlipped;

	AI.MinerOptimizedNextRepair =
		Timer();

	AI.MinerOptimizedGalleryY =
		Owner.Pos.Y;

end


-- ============================================================
-- VALIDATION
-- ============================================================

function Miner.IsValidOwner(Owner)

	if Owner == nil then
		return false;
	end

	return MovableMan:ValidMO(Owner);

end


-- ============================================================
-- MAP BOUNDS
-- ============================================================

function Miner.IsInsideMap(Position)

	return SceneMan:IsWithinBounds(
		Position.X,
		Position.Y
	);

end


function Miner.GetSceneHeight()

	return SceneMan.SceneHeight;

end


-- ============================================================
-- SAFE DEPTH
-- ============================================================
--
-- The miner must never create a gallery too close to the
-- bottom of the map.
--
-- SafeDepth is measured in blocks rather than pixels.
-- The exact conversion will be centralized here so it can
-- easily be adjusted after testing.
-- ============================================================

function Miner.GetSafeBottomY()

	return Miner.GetSceneHeight()
		- Miner.SafeDepth * Miner.BlockSpacing;

end


function Miner.IsSafeDepth(Position)

	return Position.Y <
		Miner.GetSafeBottomY();

end


-- ============================================================
-- GALLERY POSITION
-- ============================================================

function Miner.GetGalleryFloorY(Owner)

	return Owner.Pos.Y;

end


function Miner.GetGalleryCeilingY(FloorY)

	return FloorY -
		Miner.GalleryHeight * Miner.BlockSpacing;

end


-- ============================================================
-- TERRAIN TEST
-- ============================================================

function Miner.IsSolid(Position)

	local Material =
		SceneMan:GetTerrMatter(
			Position.X,
			Position.Y
		);

	return Material ~= rte.airID;

end


function Miner.IsAir(Position)

	local Material =
		SceneMan:GetTerrMatter(
			Position.X,
			Position.Y
		);

	return Material == rte.airID;

end


-- ============================================================
-- GALLERY SAFETY
-- ============================================================

function Miner.IsGallerySafe(FloorY)

	local BottomY =
		FloorY +
		Miner.SafeDepth * Miner.BlockSpacing;

	return BottomY <
		Miner.GetSceneHeight();

end


-- ============================================================
-- FIND STARTING POSITION
-- ============================================================
--
-- We first search vertically for a suitable gallery level.
--
-- This function does not excavate anything yet.
-- ============================================================

function Miner.FindGalleryLevel(Owner)

	local Y =
		Owner.Pos.Y;

	local SafeBottom =
		Miner.GetSafeBottomY();

	while Y < SafeBottom do

		local TestPosition =
			Vector(
				Owner.Pos.X,
				Y
			);

		if Miner.IsSolid(TestPosition) then
			return Y;
		end

		Y = Y + Miner.BlockSpacing;

	end

	return nil;

end


-- ============================================================
-- GALLERY OPENING TEST
-- ============================================================

function Miner.IsGalleryOpen(
	Position,
	Direction
)

	local X =
		Position.X;

	local Y =
		Position.Y;

	local Step =
		Miner.BlockSpacing;

	local Height =
		Miner.GalleryHeight;

	for Level = 0, Height - 1 do

		local Test =
			Vector(
				X + Direction * Step,
				Y - Level * Step
			);

		if not Miner.IsAir(Test) then
			return false;
		end

	end

	return true;

end


-- ============================================================
-- NAVIGATION
-- ============================================================

function Miner.GoTo(AI, Owner, Position)

	Owner:ClearAIWaypoints();

	Owner:AddAISceneWaypoint(
		Position
	);

	AI:CreateGoToBehavior(
		Owner
	);

	return true;

end


-- ============================================================
-- CONSTRUCTOR VALIDATION
-- ============================================================
--
-- Constructor handling is deliberately isolated.
--
-- This is important because the exact Constructor API should
-- not be duplicated throughout the behaviour.
-- ============================================================

function Miner.GetConstructor(Owner)

	if not Owner.EquippedItem then
		return nil;
	end

	if IsHDFirearm(Owner.EquippedItem) then
		return nil;
	end

	-- Constructor-specific detection will be added here.
	--
	-- Example:
	--   IsHeldDevice(...)
	--   PresetName(...)
	--   ClassName(...)
	--
	-- after verification against the installed CCCP version.

	return nil;

end


function Miner.HasConstructor(Owner)

	return Miner.GetConstructor(
		Owner
	) ~= nil;

end


-- ============================================================
-- CONSTRUCTION
-- ============================================================
--
-- Construction itself is kept behind one function.
--
-- This prevents the main AI loop from knowing how the
-- Constructor operates.
-- ============================================================

function Miner.PlaceBlock(
	AI,
	Owner,
	Position
)

	local Constructor =
		Miner.GetConstructor(
			Owner
		);

	if not Constructor then
		return false;
	end

	-- Constructor operation to be implemented after verifying
	-- the exact CCCP Constructor API.

	return false;

end


-- ============================================================
-- GALLERY FLOOR
-- ============================================================

function Miner.BuildGalleryFloor(
	AI,
	Owner,
	StartX,
	EndX,
	FloorY
)

	local Direction = 1;

	if EndX < StartX then
		Direction = -1;
	end

	local X = StartX;

	while true do

		local Position =
			Vector(
				X,
				FloorY
			);

		Miner.PlaceBlock(
			AI,
			Owner,
			Position
		);

		if X == EndX then
			break;
		end

		X = X + Direction *
			Miner.BlockSpacing;

		if (Direction > 0 and X > EndX)
			or (Direction < 0 and X < EndX) then

			X = EndX;

		end

	end

end


-- ============================================================
-- GALLERY
-- ============================================================

function Miner.BuildGallery(
	AI,
	Owner,
	StartX,
	EndX,
	FloorY
)

	if not Miner.IsGallerySafe(
		FloorY
	) then

		return false;

	end

	-- Floor first.
	Miner.BuildGalleryFloor(
		AI,
		Owner,
		StartX,
		EndX,
		FloorY
	);

	return true;

end


-- ============================================================
-- STAIR OPENING
-- ============================================================

function Miner.CreateStairOpening(
	AI,
	Owner,
	CenterX,
	FloorY
)

	local HalfWidth =
		math.floor(
			Miner.StairWidth / 2
		);

	for X = -HalfWidth, HalfWidth do

		local Position =
			Vector(
				CenterX +
					X * Miner.BlockSpacing,
				FloorY
			);

		-- Opening means leaving this position empty.
		--
		-- The surrounding structure will be built later.

	end

	return true;

end


-- ============================================================
-- REPAIR
-- ============================================================

function Miner.RepairBlock(
	AI,
	Owner,
	Position
)

	-- Do not repair outside the map.
	if not Miner.IsInsideMap(
		Position
	) then

		return false;

	end

	-- Repair operation will use the Constructor.
	return Miner.PlaceBlock(
		AI,
		Owner,
		Position
	);

end


function Miner.RepairNearby(
	AI,
	Owner
)

	local Center =
		Owner.Pos;

	local Radius =
		Miner.RepairRadius;

	local Step =
		Miner.BlockSpacing;

	for X = -Radius, Radius do

		for Y = -Radius, Radius do

			local Position =
				Vector(
					Center.X + X * Step,
					Center.Y + Y * Step
				);

			Miner.RepairBlock(
				AI,
				Owner,
				Position
			);

		end

	end

end


-- ============================================================
-- PERIODIC REPAIR
-- ============================================================

function Miner.UpdateRepair(
	AI,
	Owner
)

	if not AI.MinerOptimizedNextRepair then
		return;
	end

	if AI.MinerOptimizedNextRepair:IsPastSimMS(
		Miner.RepairIntervalMS
	) then

		AI.MinerOptimizedNextRepair:Reset();

		Miner.RepairNearby(
			AI,
			Owner
		);

	end

end


-- ============================================================
-- MAIN BEHAVIOUR
-- ============================================================

function Miner.Run(
	AI,
	Owner,
	Abort
)

	Miner.Initialize(
		AI,
		Owner
	);

	while not Abort() do

		if not Miner.IsValidOwner(
			Owner
		) then

			break;

		end

		-- Periodic maintenance.
		Miner.UpdateRepair(
			AI,
			Owner
		);

		-- Main mining/construction logic will be added here.

		coroutine.yield();

	end

end
