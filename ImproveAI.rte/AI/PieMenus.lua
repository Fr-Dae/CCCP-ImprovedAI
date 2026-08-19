-- ============================================================
-- ImproveAI.rte
-- PieMenus.lua
--
-- Pie Menu callbacks for ImproveAI command modes.
--
-- These callbacks only change actor state. Long-running AI
-- behaviours remain owned by the native AI coroutine system.
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


local function SetSentryMode(pieMenuOwner, Mode)
	local Owner = GetActor(pieMenuOwner);
	if not Owner then
		return;
	end

	Owner:SetNumberValue("ImproveAI_SentryMode", Mode);
	Owner.AIMode = Actor.AIMODE_SENTRY;
end


function ImproveAI_StartSentryPassive(pieMenuOwner, pieMenu, pieSlice)
	SetSentryMode(pieMenuOwner, 1);
end


function ImproveAI_StartSentryActive(pieMenuOwner, pieMenu, pieSlice)
	SetSentryMode(pieMenuOwner, 2);
end
