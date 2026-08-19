-- ============================================================
-- ImproveAI.rte
-- PieMenus.lua
--
-- Pie Menu callbacks for mining modes.
--
-- NativeHumanAI already selects HumanBehaviors.GoldDig when the
-- actor enters AIMODE_GOLDDIG. MinerOptimized.lua dispatches that
-- native entry point to the optimized behaviour only when the
-- ImproveAI_MinerOptimized flag is set.
-- ============================================================

local function GetActor(pieMenuOwner)
	if not pieMenuOwner or not IsActor(pieMenuOwner) then
		return nil;
	end

	return ToActor(pieMenuOwner);
end


function ImproveAI_StartNativeMining(pieMenuOwner, pieMenu, pieSlice)
	local Owner = GetActor(pieMenuOwner);
	if not Owner then
		return;
	end

	Owner:SetNumberValue("ImproveAI_MinerOptimized", 0);
	Owner.AIMode = Actor.AIMODE_GOLDDIG;
end


function ImproveAI_StartOptimizedMining(pieMenuOwner, pieMenu, pieSlice)
	local Owner = GetActor(pieMenuOwner);
	if not Owner then
		return;
	end

	Owner:SetNumberValue("ImproveAI_MinerOptimized", 1);
	Owner.AIMode = Actor.AIMODE_GOLDDIG;
end
