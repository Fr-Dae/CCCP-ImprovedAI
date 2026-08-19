-- ============================================================
-- ImproveAI.rte
-- Anchor.lua
--
-- Explicit mining anchor for MinerOptimized.
-- ============================================================

ImproveAI_Anchor = ImproveAI_Anchor or {};
ImproveAI_MiningAnchors = ImproveAI_MiningAnchors or {};

local Anchor = ImproveAI_Anchor;

local function GetAnchorID(Owner)
	return Owner.UniqueID or Owner.ID;
end

function Anchor.Set(Owner, Position, Direction)
	ImproveAI_MiningAnchors[GetAnchorID(Owner)] = {
		X = Position.X,
		Y = Position.Y,
		Direction = Direction < 0 and -1 or 1
	};
end

function Anchor.Clear(Owner)
	ImproveAI_MiningAnchors[GetAnchorID(Owner)] = nil;
end

function Anchor.Get(Owner)
	local Data = ImproveAI_MiningAnchors[GetAnchorID(Owner)];
	if not Data then
		return nil;
	end
	return Vector(Data.X, Data.Y), Data.Direction;
end

function ImproveAI_SetMiningAnchor(pieMenuOwner, pieMenu, pieSlice)
	if not pieMenuOwner or not IsActor(pieMenuOwner) then
		return;
	end

	local Owner = ToActor(pieMenuOwner);
	local Trace = Vector(200, 0):RadRotate(Owner:GetAimAngle(true));
	local Hit = Vector();
	local Ray = SceneMan:CastObstacleRay(Owner.EyePos, Trace, Vector(), Hit, Owner.ID, Owner.IgnoresWhichTeam, rte.grassID, 3);
	local Position = Ray < 0 and Owner.EyePos + Trace or Hit;
	local Direction = Trace.X < 0 and -1 or 1;

	Anchor.Set(Owner, Position, Direction);
end
