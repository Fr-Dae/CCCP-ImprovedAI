-- ============================================================
-- ImproveAI.rte
-- Anchor.lua
--
<<<<<<< HEAD
-- Places an explicit mining origin and direction for
-- MinerOptimized. The anchor is stored on the actor so the
-- optimized miner does not have to infer the wall/floor junction.
--
-- Explicit mining anchor for MinerOptimized.
=======
-- Explicit mining anchor: origin + left/right direction.
>>>>>>> origin/11-new-constructor-issue
-- ============================================================

ImproveAI_Anchor = ImproveAI_Anchor or {};
ImproveAI_MiningAnchors = ImproveAI_MiningAnchors or {};

local Anchor = ImproveAI_Anchor;

local function GetAnchorID(Owner)
	return Owner.UniqueID or Owner.ID;
end

function Anchor.Set(Owner, Position, Direction)
	if not Owner or not Position then
		return false;
	end

	local ID = GetAnchorID(Owner);
	ImproveAI_MiningAnchors[ID] = {
		X = Position.X,
		Y = Position.Y,
		Direction = Direction < 0 and -1 or 1
	};

	return true;
end

function Anchor.Clear(Owner)
	if Owner then
		ImproveAI_MiningAnchors[GetAnchorID(Owner)] = nil;
	end
end

function Anchor.Draw(AI, Owner, Screen)
	local Position = AI.MinerAnchor;
	if not Position then
		return;
	end

	local Direction = AI.MinerDirection or Anchor.DirectionRight;
	local Tip = Position + Vector(Direction * 18, 0);

	PrimitiveMan:DrawBoxPrimitive(Screen, Position - Vector(6, 6), Position + Vector(6, 6), 12);
	PrimitiveMan:DrawLinePrimitive(Screen, Position, Tip, 12);
	PrimitiveMan:DrawLinePrimitive(Screen, Tip, Tip + Vector(-Direction * 5, -4), 12);
	PrimitiveMan:DrawLinePrimitive(Screen, Tip, Tip + Vector(-Direction * 5, 4), 12);
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

function ImproveAI_SetMiningAnchor(pieMenuOwner, pieMenu, pieSlice)
	if not pieMenuOwner or not IsActor(pieMenuOwner) then
		return;
	end

	local Owner = ToActor(pieMenuOwner);
	local Trace = Vector(200, 0):RadRotate(Owner:GetAimAngle(true));
	local Hit = Vector();
	local Ray = SceneMan:CastObstacleRay(
		Owner.EyePos,
		Trace,
		Vector(),
		Hit,
		Owner.ID,
		Owner.IgnoresWhichTeam,
		rte.grassID,
		3
	);

	local Position = Ray < 0
		and Owner.EyePos + Trace
		or Hit;
	local Direction = Trace.X < 0 and -1 or 1;

	Anchor.Set(Owner, Position, Direction);
end
