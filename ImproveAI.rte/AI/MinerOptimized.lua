-- ============================================================
-- ImproveAI.rte
-- MinerOptimized.lua
--
-- Structured mining behaviour.
--
-- Mining is based on a manually prepared reference:
--
--     vertical wall
--          |
--          |
--          |
--          +-------------------- ground
--          |
--          |
--
-- The intersection between the wall and the ground is the
-- origin of the mine.
--
-- Level  0 = surface
-- Level -1 = first underground gallery
-- Level -2 = second underground gallery
-- etc.
--
-- Horizontal floors are shared:
--
--     floor of level -1
--     =
--     ceiling of level -2
--
-- The miner therefore does not construct two horizontal layers
-- between two galleries.
--
-- IMPORTANT:
-- Constructor interaction is isolated in the Constructor
-- adapter at the end of this file. The exact native Constructor
-- API must be verified against the CCCP source before replacing
-- the adapter with direct Constructor commands.
-- ============================================================


ImproveAI_MinerOptimized =
    ImproveAI_MinerOptimized or {};

local Miner = ImproveAI_MinerOptimized;


-- ============================================================
-- CONFIGURATION
-- ============================================================

Miner.BlockSize = 12;

-- Six medium blocks of vertical clearance.
Miner.GalleryHeightBlocks = 6;

-- Width reserved for the vertical access / stairs.
Miner.StairWidthBlocks = 3;

-- Number of blocks mined horizontally before an access point.
Miner.SectionLengthBlocks = 24;

-- Maximum number of underground levels.
Miner.MaximumLevels = 64;

-- Safety margin above the actual bottom of the terrain.
Miner.BottomSafetyMargin = 24;

-- Maximum distance at which the reference wall can be found.
Miner.ReferenceWallSearchDistance = 80;

-- Maximum distance at which the reference floor can be found.
Miner.ReferenceFloorSearchDistance = 80;

-- How often structural maintenance is considered.
Miner.RepairIntervalMS = 300000;

-- Do not perform expensive geometry searches every frame.
Miner.GeometryCheckIntervalMS = 500;

-- How often the mining state is updated.
Miner.WorkIntervalMS = 100;


-- ============================================================
-- STATES
-- ============================================================

Miner.STATE_FIND_ORIGIN = 0;
Miner.STATE_PREPARE_LEVEL = 1;
Miner.STATE_BUILD_FLOOR = 2;
Miner.STATE_MINE_SECTION = 3;
Miner.STATE_BUILD_STAIR = 4;
Miner.STATE_DESCEND = 5;
Miner.STATE_REPAIR = 6;
Miner.STATE_FINISHED = 7;


-- ============================================================
-- BASIC VALIDATION
-- ============================================================

local function IsValidActor(Actor)

	if Actor == nil then
		return false;
	elseif not MovableMan:ValidMO(Actor) then
		return false;
	else
		return true;
	end

end


-- ============================================================
-- VECTOR COPY
-- ============================================================

local function CopyVector(Position)

	return Vector(
		Position.X,
		Position.Y
	);

end


-- ============================================================
-- DISTANCE
-- ============================================================

local function Distance(A, B)

	return SceneMan:ShortestDistance(
		A,
		B,
		false
	).Magnitude;

end


-- ============================================================
-- GROUND TEST
--
-- This does not attempt to identify a Constructor block.
-- It simply determines whether solid terrain exists below
-- the supplied point.
-- ============================================================

local function HasGroundAt(Position, Width)

	local HalfWidth = Width * 0.5;

	local Left = Vector(
		Position.X - HalfWidth,
		Position.Y
	);

	local Right = Vector(
		Position.X + HalfWidth,
		Position.Y
	);

	local Down = Vector(
		0,
		Miner.BlockSize * 0.75
	);

	local LeftTrace = SceneMan:CastObstacleRay(
		Left,
		Down,
		Vector(),
		Vector(),
		rte.NoMOID,
		Activity.NOTEAM,
		rte.grassID,
		0
	);

	if LeftTrace >= 0 then
		return true;
	end

	local RightTrace = SceneMan:CastObstacleRay(
		Right,
		Down,
		Vector(),
		Vector(),
		rte.NoMOID,
		Activity.NOTEAM,
		rte.grassID,
		0
	);

	return RightTrace >= 0;

end


-- ============================================================
-- VERTICAL WALL TEST
-- ============================================================

local function HasVerticalWallAt(Position)

	local Left = Vector(
		-Miner.ReferenceWallSearchDistance,
		0
	);

	local Right = Vector(
		Miner.ReferenceWallSearchDistance,
		0
	);

	local LeftHit = SceneMan:CastObstacleRay(
		Position,
		Left,
		Vector(),
		Vector(),
		rte.NoMOID,
		Activity.NOTEAM,
		rte.grassID,
		0
	);

	if LeftHit >= 0 then
		return true;
	end

	local RightHit = SceneMan:CastObstacleRay(
		Position,
		Right,
		Vector(),
		Vector(),
		rte.NoMOID,
		Activity.NOTEAM,
		rte.grassID,
		0
	);

	return RightHit >= 0;

end


-- ============================================================
-- REFERENCE ORIGIN
--
-- The origin is deliberately detected locally around the actor.
--
-- The intended situation is:
--
--          WALL
--            |
--            |
--            +----------- GROUND
--            ^
--          origin
--
-- The actor must therefore be standing on the reference floor
-- and close to the reference wall.
-- ============================================================

local function FindReferenceOrigin(Owner)

	local Origin = CopyVector(Owner.Pos);

	local GroundY = nil;

	local GroundTrace = SceneMan:CastObstacleRay(
		Owner.Pos,
		Vector(
			0,
			Miner.ReferenceFloorSearchDistance
		),
		Vector(),
		Vector(),
		rte.NoMOID,
		Activity.NOTEAM,
		rte.grassID,
		0
	);

	if GroundTrace < 0 then
		return nil;
	end

	GroundY =
		Owner.Pos.Y +
		GroundTrace;

	Origin.Y = GroundY;

	-- Search both horizontal directions for the reference wall.
	local WallDistance = nil;

	local LeftTrace = SceneMan:CastObstacleRay(
		Origin,
		Vector(
			-Miner.ReferenceWallSearchDistance,
			0
		),
		Vector(),
		Vector(),
		rte.NoMOID,
		Activity.NOTEAM,
		rte.grassID,
		0
	);

	local RightTrace = SceneMan:CastObstacleRay(
		Origin,
		Vector(
			Miner.ReferenceWallSearchDistance,
			0
		),
		Vector(),
		Vector(),
		rte.NoMOID,
		Activity.NOTEAM,
		rte.grassID,
		0
	);

	if LeftTrace >= 0 then
		WallDistance = LeftTrace;
		Origin.X = Origin.X - LeftTrace;
	elseif RightTrace >= 0 then
		WallDistance = RightTrace;
		Origin.X = Origin.X + RightTrace;
	else
		return nil;
	end

	if WallDistance >
		Miner.ReferenceWallSearchDistance then
		return nil;
	end

	return Origin;

end


-- ============================================================
-- LEVEL GEOMETRY
-- ============================================================

function Miner.GetLevelHeight()

	return Miner.GalleryHeightBlocks *
		Miner.BlockSize;

end


function Miner.GetLevelY(AI, Level)

	return AI.MinerOrigin.Y +
		(Level * Miner.GetLevelHeight());

end


function Miner.GetGalleryFloorY(AI, Level)

	-- Level -1 uses the first underground floor.
	return Miner.GetLevelY(AI, Level);

end


function Miner.GetGalleryCeilingY(AI, Level)

	return Miner.GetLevelY(
		AI,
		Level + 1
	);

end


-- ============================================================
-- BOTTOM LIMIT
-- ============================================================

function Miner.GetBottomLimit()

	-- SceneMan provides the terrain dimensions in pixels.
	--
	-- Keep a safety margin because reaching the absolute last
	-- terrain pixel is not a safe place for an actor.
	return SceneMan.SceneHeight -
		Miner.BottomSafetyMargin;

end


function Miner.IsLevelPossible(AI, Level)

	if Level >= 0 then
		return true;
	end

	local FloorY =
		Miner.GetGalleryFloorY(
			AI,
			Level
		);

	local CeilingY =
		Miner.GetGalleryCeilingY(
			AI,
			Level
		);

	if CeilingY >=
		Miner.GetBottomLimit() then
		return false;
	end

	if FloorY >=
		Miner.GetBottomLimit() then
		return false;
	end

	return true;

end


-- ============================================================
-- SECTION GEOMETRY
-- ============================================================

function Miner.GetSectionStartX(AI)

	return AI.MinerOrigin.X;

end


function Miner.GetSectionEndX(AI)

	return AI.MinerOrigin.X +
		(
			AI.MinerSection *
			Miner.SectionLengthBlocks *
			Miner.BlockSize
		);

end


function Miner.GetSectionStairX(AI)

	return Miner.GetSectionEndX(AI);

end


-- ============================================================
-- CONSTRUCTOR DETECTION
-- ============================================================

function Miner.GetConstructor(Owner)

	local Item = Owner.EquippedItem;

	if Item == nil then
		return nil;
	end

	-- The exact Constructor identification should ultimately be
	-- replaced by the identifier used by the CCCP Constructor.
	--
	-- Keep this intentionally conservative.
	if Item.ClassName ~= "HDFirearm" then
		return nil;
	end

	if Item.PresetName == "Constructor" then
		return Item;
	end

	return nil;

end


function Miner.HasConstructor(Owner)

	return Miner.GetConstructor(Owner) ~= nil;

end


-- ============================================================
-- CONSTRUCTOR ADAPTER
--
-- These functions are deliberately isolated from the mining
-- state machine.
--
-- Once the exact CCCP Constructor implementation is confirmed,
-- only this section needs to be changed.
-- ============================================================

function Miner.SelectMediumBlock(Constructor)

	if Constructor == nil then
		return false;
	end

	-- TODO:
	-- Replace with the real CCCP Constructor block-selection
	-- mechanism after verifying the Constructor source.
	--
	-- Do NOT guess the engine API here.

	return false;

end


function Miner.PlaceBlock(AI, Owner, Position)

	local Constructor =
		Miner.GetConstructor(Owner);

	if Constructor == nil then
		return false;
	end

	if not Miner.SelectMediumBlock(
		Constructor
	) then
		return false;
	end

	-- TODO:
	-- Aim the Constructor at Position and use its actual
	-- construction command.
	--
	-- This is intentionally not implemented with a fabricated
	-- API.

	return false;

end


function Miner.RemoveTerrain(AI, Owner, Position)

	-- Excavation is performed through the equipped Constructor
	-- once its actual digging/building interface is confirmed.
	--
	-- Keeping terrain manipulation out of this state machine
	-- prevents the optimized behaviour from bypassing the
	-- Constructor.

	return false;

end


-- ============================================================
-- MOVEMENT
-- ============================================================

function Miner.MoveTo(AI, Owner, Position)

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
-- LEVEL PREPARATION
-- ============================================================

function Miner.PrepareLevel(AI, Owner)

	if not Miner.IsLevelPossible(
		AI,
		AI.MinerLevel
	) then

		AI.MinerState =
			Miner.STATE_FINISHED;

		return false;
	end

	AI.MinerSection = 0;

	AI.MinerState =
		Miner.STATE_BUILD_FLOOR;

	return true;

end


-- ============================================================
-- FLOOR
-- ============================================================

function Miner.BuildFloor(AI, Owner)

	local Y =
		Miner.GetGalleryFloorY(
			AI,
			AI.MinerLevel
		);

	local X =
		Miner.GetSectionStartX(AI);

	local Position = Vector(
		X,
		Y
	);

	-- If the floor already exists, do not rebuild it.
	if HasGroundAt(
		Position,
		Miner.BlockSize
	) then

		AI.MinerState =
			Miner.STATE_MINE_SECTION;

		return true;
	end

	if Miner.PlaceBlock(
		AI,
		Owner,
		Position
	) then

		AI.MinerState =
			Miner.STATE_MINE_SECTION;

		return true;
	end

	return false;

end


-- ============================================================
-- MINE SECTION
-- ============================================================

function Miner.MineSection(AI, Owner)

	local StartX =
		Miner.GetSectionStartX(AI);

	local EndX =
		Miner.GetSectionEndX(AI);

	local Y =
		Miner.GetGalleryFloorY(
			AI,
			AI.MinerLevel
		);

	-- The miner works from the current position toward the end
	-- of the section.
	local Target = Vector(
		EndX,
		Y -
		(
			Miner.GetLevelHeight() *
			0.5
		)
	);

	if Distance(
		Owner.Pos,
		Target
	) >
		Miner.BlockSize * 2 then

		Miner.MoveTo(
			AI,
			Owner,
			Target
		);

		return true;
	end

	-- Actual terrain removal is delegated to the Constructor
	-- adapter.
	if Miner.RemoveTerrain(
		AI,
		Owner,
		Target
	) then

		return true;
	end

	-- Until the Constructor implementation is connected, do not
	-- falsely consider the section complete.
	return false;

end


-- ============================================================
-- STAIR
-- ============================================================

function Miner.BuildStair(AI, Owner)

	local X =
		Miner.GetSectionStairX(AI);

	local CurrentLevel =
		AI.MinerLevel;

	local NextLevel =
		CurrentLevel - 1;

	if not Miner.IsLevelPossible(
		AI,
		NextLevel
	) then

		AI.MinerState =
			Miner.STATE_FINISHED;

		return false;
	end

	-- Reserve the three-block-wide access.
	--
	-- The actual Constructor commands are delegated to the
	-- Constructor adapter.
	local StairPosition = Vector(
		X,
		Miner.GetGalleryFloorY(
			AI,
			CurrentLevel
		)
	);

	if Miner.PlaceBlock(
		AI,
		Owner,
		StairPosition
	) then

		AI.MinerState =
			Miner.STATE_DESCEND;

		return true;
	end

	return false;

end


-- ============================================================
-- DESCEND
-- ============================================================

function Miner.Descend(AI, Owner)

	local NextLevel =
		AI.MinerLevel - 1;

	if not Miner.IsLevelPossible(
		AI,
		NextLevel
	) then

		AI.MinerState =
			Miner.STATE_FINISHED;

		return false;
	end

	local X =
		Miner.GetSectionStairX(AI);

	local Y =
		Miner.GetGalleryFloorY(
			AI,
			NextLevel
		);

	local Target = Vector(
		X,
		Y -
		(
			Miner.GetLevelHeight() *
			0.5
		)
	);

	if Distance(
		Owner.Pos,
		Target
	) >
		Miner.BlockSize * 2 then

		Miner.MoveTo(
			AI,
			Owner,
			Target
		);

		return true;
	end

	AI.MinerLevel =
		NextLevel;

	AI.MinerSection = 0;

	AI.MinerState =
		Miner.STATE_BUILD_FLOOR;

	return true;

end


-- ============================================================
-- REPAIR
-- ============================================================

function Miner.Repair(AI, Owner)

	-- Only repair the immediate structural area around the
	-- current gallery.
	--
	-- This deliberately does NOT scan the whole mine.
	--
	-- The actual block replacement is delegated to the
	-- Constructor adapter.

	local Y =
		Miner.GetGalleryFloorY(
			AI,
			AI.MinerLevel
		);

	local Position = Vector(
		Owner.Pos.X,
		Y
	);

	if not HasGroundAt(
		Position,
		Miner.BlockSize
	) then

		Miner.PlaceBlock(
			AI,
			Owner,
			Position
		);

	end

	AI.MinerState =
		Miner.STATE_MINE_SECTION;

	return true;

end


-- ============================================================
-- INITIALISATION
-- ============================================================

function Miner.Initialize(AI, Owner)

	if AI.MinerInitialized then
		return true;
	end

	if not IsValidActor(Owner) then
		return false;
	end

	AI.MinerInitialized = true;

	AI.MinerState =
		Miner.STATE_FIND_ORIGIN;

	AI.MinerLevel = -1;

	AI.MinerSection = 0;

	AI.MinerOrigin = nil;

	AI.MinerGeometryTimer = Timer();
	AI.MinerWorkTimer = Timer();
	AI.MinerRepairTimer = Timer();

	return true;

end


-- ============================================================
-- MAIN BEHAVIOUR
-- ============================================================

function Miner.Run(AI, Owner, Abort)

	if not Miner.Initialize(
		AI,
		Owner
	) then
		return;
	end

	local Controller =
		Owner:GetController();

	while not Abort() do

		if not IsValidActor(Owner) then
			break;
		end


		-- ----------------------------------------------------
		-- CONSTRUCTOR
		-- ----------------------------------------------------

		if not Miner.HasConstructor(
			Owner
		) then

			-- No Constructor.
			--
			-- Do not attempt to mine. The actor remains alive and
			-- the behaviour can be resumed if a Constructor is
			-- equipped later.

			Controller:SetState(
				Controller.MOVE_LEFT,
				false
			);

			Controller:SetState(
				Controller.MOVE_RIGHT,
				false
			);

			coroutine.yield();

		else


			-- ------------------------------------------------
			-- PERIODIC REPAIR
			-- ------------------------------------------------

			if AI.MinerRepairTimer:IsPastSimMS(
				Miner.RepairIntervalMS
			) then

				AI.MinerRepairTimer:Reset();

				AI.MinerState =
					Miner.STATE_REPAIR;

			end


			-- ------------------------------------------------
			-- THROTTLE WORK
			-- ------------------------------------------------

			if AI.MinerWorkTimer:IsPastSimMS(
				Miner.WorkIntervalMS
			) then

				AI.MinerWorkTimer:Reset();


				-- --------------------------------------------
				-- FIND ORIGIN
				-- --------------------------------------------

				if AI.MinerState ==
					Miner.STATE_FIND_ORIGIN then

					local Origin =
						FindReferenceOrigin(
							Owner
						);

					if Origin then

						AI.MinerOrigin =
							Origin;

						AI.MinerLevel = -1;
						AI.MinerSection = 0;

						AI.MinerState =
							Miner.STATE_PREPARE_LEVEL;

					end


				-- --------------------------------------------
				-- PREPARE LEVEL
				-- --------------------------------------------

				elseif AI.MinerState ==
					Miner.STATE_PREPARE_LEVEL then

					Miner.PrepareLevel(
						AI,
						Owner
					);


				-- --------------------------------------------
				-- BUILD FLOOR
				-- --------------------------------------------

				elseif AI.MinerState ==
					Miner.STATE_BUILD_FLOOR then

					Miner.BuildFloor(
						AI,
						Owner
					);


				-- --------------------------------------------
				-- MINE
				-- --------------------------------------------

				elseif AI.MinerState ==
					Miner.STATE_MINE_SECTION then

					Miner.MineSection(
						AI,
						Owner
					);


				-- --------------------------------------------
				-- STAIR
				-- --------------------------------------------

				elseif AI.MinerState ==
					Miner.STATE_BUILD_STAIR then

					Miner.BuildStair(
						AI,
						Owner
					);


				-- --------------------------------------------
				-- DESCEND
				-- --------------------------------------------

				elseif AI.MinerState ==
					Miner.STATE_DESCEND then

					Miner.Descend(
						AI,
						Owner
					);


				-- --------------------------------------------
				-- REPAIR
				-- --------------------------------------------

				elseif AI.MinerState ==
					Miner.STATE_REPAIR then

					Miner.Repair(
						AI,
						Owner
					);


				-- --------------------------------------------
				-- FINISHED
				-- --------------------------------------------

				elseif AI.MinerState ==
					Miner.STATE_FINISHED then

					Controller:SetState(
						Controller.WEAPON_FIRE,
						false
					);

				end

			end

			coroutine.yield();

		end

	end


	-- ========================================================
	-- CLEANUP
	-- ========================================================

	Controller:SetState(
		Controller.WEAPON_FIRE,
		false
	);

	Controller:SetState(
		Controller.MOVE_LEFT,
		false
	);

	Controller:SetState(
		Controller.MOVE_RIGHT,
		false
	);

end
