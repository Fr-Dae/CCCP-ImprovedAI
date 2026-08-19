-- ============================================================
-- ImproveAI.rte
-- Anchor.lua
--
-- Explicit mining anchor for MinerOptimized.
--
-- The anchor stores one origin and one horizontal direction per
-- actor. Placing either the left or right anchor replaces the
-- previous anchor for that actor.
--
-- Two Pie Menu entries are used temporarily because a reliable
-- user-configurable keyboard binding for rotating an anchor has
-- not yet been established in CCCP. If a dedicated rotate key
-- is later supported, these two entries can be replaced by one
-- anchor + rotate action without changing MinerOptimized.
-- ============================================================

ImproveAI_Anchor = ImproveAI_Anchor or {};
ImproveAI_MiningAnchors = ImproveAI_MiningAnchors or {};

local Anchor = ImproveAI_Anchor;

Anchor.DirectionLeft = -1;
Anchor.DirectionRight = 1;

local function GetAnchorID(Owner)
	return Owner.UniqueID or Owner.ID;
end

function Anchor.Set(Owner, Position, Direction)
	if not Owner or not Position then
		return false;
	end

	ImproveAI_MiningAnchors[GetAnchorID(Owner)] = {
		X = Position.X,
		Y = Position.Y,
		Direction = Direction < 0 and Anchor.DirectionLeft or Anchor.DirectionRight
	};

	return true;
end

function Anchor.Clear(Owner)
	if Owner then
		ImproveAI_MiningAnchors[GetAnchorID(Owner)] = nil;
	end
end

function Anchor.Get(Owner)
	if not Owner then
		return nil;
	end

	local Data = ImproveAI_MiningAnchors[GetAnchorID(Owner)];
	if not Data then
		return nil;
	end

	return Vector(Data.X, Data.Y), Data.Direction;
end

function Anchor.Place(Owner, Direction)
	if not Owner then
		return false;
	end

	local Trace = Vector(200, 0):RadRotate(Owner:GetAimAngle(true));
	local Hit = Vector();
	local RayLength = SceneMan:CastObstacleRay(
		Owner.EyePos,
		Trace,
		Vector(),
		Hit,
		Owner.ID,
		Owner.IgnoresWhichTeam,
		rte.grassID,
		3
	);

	local Position;
	if RayLength < 0 then
		Position = Owner.EyePos + Trace;
	else
		Position = Hit;
	end

	return Anchor.Set(Owner, Position, Direction);
end

function Anchor.PlaceLeft(pieMenuOwner, pieMenu, pieSlice)
	if not pieMenuOwner or not IsActor(pieMenuOwner) then
		return;
	end

	Anchor.Place(ToActor(pieMenuOwner), Anchor.DirectionLeft);
end

function Anchor.PlaceRight(pieMenuOwner, pieMenu, pieSlice)
	if not pieMenuOwner or not IsActor(pieMenuOwner) then
		return;
	end

	Anchor.Place(ToActor(pieMenuOwner), Anchor.DirectionRight);
end

function Anchor.Draw(Owner, Screen)
	local Position, Direction = Anchor.Get(Owner);
	if not Position or Screen == -1 then
		return;
	end

	local Size = 6;
	local End = Position + Vector(Direction * 18, 0);
	local Color = 13;

	PrimitiveMan:DrawBoxPrimitive(
		Screen,
		Position - Vector(Size, Size),
		Position + Vector(Size, Size),
		Color
	);
	PrimitiveMan:DrawLinePrimitive(Screen, Position, End, Color);
	PrimitiveMan:DrawLinePrimitive(
		Screen,
		End,
		End - Vector(Direction * 5, 4),
		Color
	);
	PrimitiveMan:DrawLinePrimitive(
		Screen,
		End,
		End - Vector(Direction * 5, -4),
		Color
	);
end
