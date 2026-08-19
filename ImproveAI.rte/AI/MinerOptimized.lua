-- ============================================================
-- ImproveAI.rte
-- MinerOptimized.lua
--
-- Structured mining behaviour using an explicit Anchor.
--
-- Geometry reference:
--   - surface = level 0
--   - first gallery = level 1
--   - medium Constructor block = 12 px
--   - tunnel height = 6 blocks = 72 px
--   - gallery floor is shared with the ceiling below
--
-- This file plans the mining sections and delegates movement and
-- digging to native CCCP behaviour whenever possible. It does not
-- assume Constructor resources refill automatically.
-- ============================================================

ImproveAI_MinerOptimized = ImproveAI_MinerOptimized or {};
local Miner = ImproveAI_MinerOptimized;

Miner.BlockSize = 12;
Miner.TunnelHeightBlocks = 6;
Miner.SectionLengthBlocks = 12;
Miner.BottomSafetyPixels = 60;
Miner.ConstructorBlockCost = 200;
Miner.ConstructorReserveMargin = 200;
Miner.EquipmentCheckMS = 1000;

local function ValidActor(Owner)
	return Owner
		and MovableMan:ValidMO(Owner)
		and IsActor(Owner);
end

local function GetConstructor(Owner)
	local Item = Owner.EquippedItem;

	if Item and Item.PresetName == "Constructor" then
		return Item;
	end

	-- These are the native Actor equipment functions used by CCCP AI.
	-- EquipNamedDevice searches the actor's available equipment, while
	-- the group search also covers Constructor variants added by mods.
	if Owner:EquipNamedDevice("Constructor", true) then
		Item = Owner.EquippedItem;
		if Item and Item.PresetName == "Constructor" then
			return Item;
		end
	end

	if Owner:EquipDeviceInGroup("Tools - Constructors", true) then
		Item = Owner.EquippedItem;
		if Item and Item.PresetName == "Constructor" then
			return Item;
		end
	end
end

local function GetAnchor(Owner)
	local Data = ImproveAI_MiningAnchors
		and ImproveAI_MiningAnchors[Owner.UniqueID or Owner.ID];

	if not Data then
		return nil;
	end

	return Vector(Data.X, Data.Y), Data.Direction;
end

local function SetMiningControls(AI, Owner)
	local Direction = AI.MinerDirection;

	Owner.HFlipped = Direction < 0;
	AI.Ctrl:SetState(Controller.AIM_UP, false);
	AI.Ctrl:SetState(Controller.AIM_DOWN, false);
	AI.Ctrl:SetState(Controller.AIM_SHARP, true);
	AI.Ctrl:SetState(Controller.WEAPON_FIRE, true);
end

local function ClearMiningControls(AI)
	AI.Ctrl:SetState(Controller.WEAPON_FIRE, false);
	AI.Ctrl:SetState(Controller.AIM_UP, false);
	AI.Ctrl:SetState(Controller.AIM_DOWN, false);
	AI.Ctrl:SetState(Controller.AIM_SHARP, false);
end

function Miner.GetGalleryFloor(Anchor, Level)
	return Vector(
		Anchor.X,
		Anchor.Y + Level * Miner.TunnelHeightBlocks * Miner.BlockSize
	);
end

function Miner.GetMaximumGalleryY()
	return SceneMan.SceneHeight - Miner.BottomSafetyPixels;
end

function Miner.FindAnchor(Owner)
	return GetAnchor(Owner);
end

function Miner(AI, Owner, Abort)
	if not ValidActor(Owner) then
		return true;
	end

	AI.Ctrl = AI.Ctrl or Owner:GetController();

	local Anchor, Direction = Miner.FindAnchor(Owner);
	if not Anchor then
		return true;
	end

	AI.MinerAnchor = Anchor;
	AI.MinerLevel = AI.MinerLevel or 1;
	AI.MinerDirection = AI.MinerDirection or Direction or (Owner.HFlipped and -1 or 1);
	AI.MinerSection = AI.MinerSection or 0;

	local EquipmentTimer = Timer();
	local Constructor = nil;

	while not Abort() do
		if not ValidActor(Owner) then
			break;
		end

		if EquipmentTimer:IsPastSimMS(Miner.EquipmentCheckMS) then
			EquipmentTimer:Reset();
			Constructor = GetConstructor(Owner);
			AI.MinerConstructor = Constructor;

			if Constructor and Constructor.resource ~= nil then
				AI.MinerNeedsMaterial = Constructor.resource <
					(Miner.ConstructorBlockCost + Miner.ConstructorReserveMargin);
			else
				AI.MinerNeedsMaterial = true;
			end
		end

		if not Constructor or not MovableMan:ValidMO(Constructor) then
			Constructor = GetConstructor(Owner);
			AI.MinerConstructor = Constructor;
		end

		if not Constructor then
			ClearMiningControls(AI);
			coroutine.yield();
		else
			local Floor = Miner.GetGalleryFloor(
				AI.MinerAnchor,
				AI.MinerLevel
			);

			if Floor.Y >= Miner.GetMaximumGalleryY() then
				break;
			end

			local Target = Vector(
				Floor.X + AI.MinerDirection * (
					AI.MinerSection + 1
				) * Miner.SectionLengthBlocks * Miner.BlockSize,
				Floor.Y - Miner.BlockSize * 3
			);

			AI.MinerSectionTarget = Target;

			local Distance = SceneMan:ShortestDistance(
				Owner.Pos,
				Target,
				SceneMan.SceneWrapsX
			);

			if Distance:MagnitudeIsLessThan(Miner.BlockSize * 2) then
				AI.MinerSection = AI.MinerSection + 1;
				AI.MinerSectionTarget = nil;
			else
				SetMiningControls(AI, Owner);
				Owner:ClearAIWaypoints();
				Owner:AddAISceneWaypoint(Target);
				AI:CreateGoToBehavior(Owner);
				return true;
			end
		end

		coroutine.yield();
	end

	ClearMiningControls(AI);
	AI.MinerConstructor = nil;
	AI.MinerSectionTarget = nil;
	return true;
end
