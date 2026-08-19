-- ============================================================
-- ImproveAI.rte
-- Anchor.lua
--
-- Mining anchor command.
--
-- Places an explicit mining origin and direction for
-- MinerOptimized. The anchor is stored on the actor so the
-- optimized miner does not have to infer the wall/floor junction.
-- ============================================================

ImproveAI_Anchor = ImproveAI_Anchor or {};
local Anchor = ImproveAI_Anchor;

Anchor.DirectionRight = 1;
Anchor.DirectionLeft = -1;

function Anchor.Set(AI, Owner, Position, Direction)
	AI.MinerAnchor = Vector(Position.X, Position.Y);
	AI.MinerDirection = Direction < 0 and Anchor.DirectionLeft or Anchor.DirectionRight;
end

function Anchor.Clear(AI)
	AI.MinerAnchor = nil;
	AI.MinerDirection = nil;
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

-- Pie-menu callback. The actual screen-space cursor position is
-- intentionally resolved here rather than by MinerOptimized.
function ImproveAI_SetMiningAnchor(pieMenuOwner, pieMenu, pieSlice)
	local actor = pieMenuOwner;
	if actor and IsActor(actor) then
		actor = ToActor(actor);
		local AI = actor:GetController();
		-- The persistent anchor is owned by the AI behaviour state.
		-- The behaviour can replace this temporary anchor when needed.
		actor:SetStringValue("ImproveAI_MiningAnchor", "Set");
	end
end
