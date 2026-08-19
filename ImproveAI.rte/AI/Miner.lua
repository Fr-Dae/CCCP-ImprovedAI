-- ============================================================
-- ImproveAI.rte
-- Miner.lua
--
-- Native mining behaviour.
--
-- This deliberately does NOT modify the native Cortex Command
-- mining behaviour.
--
-- Native behaviour:
--
--     HumanBehaviors.GoldDig
--
-- This wrapper exists so ImproveAI can reference a dedicated
-- Miner behaviour without replacing the game's implementation.
-- ============================================================

ImproveAI_Miner = ImproveAI_Miner or {};

local Miner = ImproveAI_Miner;


function Miner(AI, Owner, Abort)

	return HumanBehaviors.GoldDig(
		AI,
		Owner,
		Abort
	);

end
