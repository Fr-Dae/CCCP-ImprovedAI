function ConstructorWrapPos(checkPos)
	if SceneMan.SceneWrapsX then
		if checkPos.X > SceneMan.SceneWidth then
			checkPos = Vector(checkPos.X - SceneMan.SceneWidth, checkPos.Y);
		elseif checkPos.X < 0 then
			checkPos = Vector(SceneMan.SceneWidth + checkPos.X, checkPos.Y);
		end
	end

	return checkPos;
end

-- recursive flood filling function
function ConstructorFloodFill(x, y, startnum, maxnum, array, realposition, realspacing)
	array[x][y] = startnum;

	if startnum < maxnum then
		if array[x + 1][y] == -1 or array[x + 1][y] > startnum then
			local checkPos = ConstructorWrapPos(realposition + Vector(realspacing, 0));
			if SceneMan:GetTerrMatter(checkPos.X + (realspacing * 0.5), checkPos.Y + (realspacing * 0.5)) == rte.airID then
				ConstructorFloodFill(x + 1, y, startnum + 1, maxnum, array, checkPos, realspacing);
			end
		end

		if array[x - 1][y] == -1 or array[x - 1][y] > startnum then
			local checkPos = ConstructorWrapPos(realposition + Vector(-realspacing, 0));
			if SceneMan:GetTerrMatter(checkPos.X + (realspacing * 0.5), checkPos.Y + (realspacing * 0.5)) == rte.airID then
				ConstructorFloodFill(x - 1, y, startnum + 1, maxnum, array, checkPos, realspacing);
			end
		end

		if array[x][y + 1] == -1 or array[x][y + 1] > startnum then
			local checkPos = ConstructorWrapPos(realposition + Vector(0, realspacing));
			if SceneMan:GetTerrMatter(checkPos.X + (realspacing * 0.5), checkPos.Y + (realspacing * 0.5)) == rte.airID then
				ConstructorFloodFill(x, y + 1, startnum + 1, maxnum, array, checkPos, realspacing);
			end
		end

		if array[x][y - 1] == -1 or array[x][y - 1] > startnum then
			local checkPos = ConstructorWrapPos(realposition + Vector(0, -realspacing));
			if SceneMan:GetTerrMatter(checkPos.X + (realspacing * 0.5), checkPos.Y + (realspacing * 0.5)) == rte.airID then
				ConstructorFloodFill(x, y - 1, startnum + 1, maxnum, array, checkPos, realspacing);
			end
		end
	end
end

--TODO: Figure out how to snap different sizes properly
function ConstructorSnapPos(checkPos, blockSize)
	return Vector(math.floor((checkPos.X - blockSize/2)/blockSize) * blockSize + blockSize/2, math.floor((checkPos.Y - blockSize/2)/blockSize) * blockSize + blockSize/2);
end

function ConstructorTerrainRay(start, trace, skip)
	local hitPos = start + trace;
	SceneMan:CastStrengthRay(start, trace, 0, hitPos, skip, rte.airID, SceneMan.SceneWrapsX);	
	return hitPos;
end

function Create(self)
	self.displayTimer = Timer();

	self.buildTimer = Timer();
	self.buildList = {};
	self.buildCost = 10;	--How much resource is required per one build 3 x 3 px piece
	self.sprayCost = self.buildCost * 0.5;

	-- ImproveAI uses the medium 12x12 px construction block.
	-- The 3x3 px cell remains an internal construction unit.
	self.buildSize = 12;
	self.buildSizeMin = 12;
	self.buildSizeMax = 12;
	self.fullBlock = 64 * self.buildCost;	-- Resource capacity unit used by the native Constructor model.
	self.maxResource = 12 * self.fullBlock;
	self.startResource = 3;
	self.resource = self.startResource * self.fullBlock;
	self.tunnelFillTimer = Timer();

	self.clearer = CreateMOSRotating("Constructor Terrain Clearer");

	self.digStrength = 200;	--The StructuralIntegrity limit of harvestable materials

	self.digLength = 40;
	self.spreadRange = math.rad(self.ParticleSpreadRange);
	self.buildsPerSecond = 100;
	self.buildSound = CreateSoundContainer("Geiger Click", "Base.rte");

	self.buildDistance = 400; -- pixel distance
	self.minFillDistance = 5; -- block distance
	self.maxFillDistance = 6; -- block distance
	self.tunnelFillDelay = 30000 + 30000 * (1 - ActivityMan:GetActivity().Difficulty/GameActivity.MAXDIFFICULTY);

	self.menu_ignore = false; -- ignore the pie menu button until it's released

	-- don't change these
	self.toAutoBuild = false;
	self.operatedByAI = false;
	self.cursorMoveSpeed = 2;
	self.maxCursorDist = Vector(FrameMan.PlayerScreenWidth * 0.5 - 6, FrameMan.PlayerScreenHeight * 0.5 - 6);

	-- autobuild for standard units
	self.autoBuildList = {
		Vector(-3, 1),
		Vector(-2, 1),
		Vector(-1, 1),
		Vector(2, 1),
		Vector(3, 1),
		Vector(4, 1),

		Vector(-4, -2),
		Vector(-3, -2),
		Vector(0, -2),
		Vector(1, -2),
		Vector(4, -2),
		Vector(5, -2),

		Vector(-3, -3),
		Vector(4, -3),

		Vector(-3, -4),
		Vector(4, -4),

		Vector(-3, -5),
		Vector(-2, -5),
		Vector(-1, -5),
		Vector(2, -5),
		Vector(3, -5),
		Vector(4, -5),

		Vector(-3, -8),
		Vector(-2, -8),
		Vector(-1, -8),
		Vector(0, -8),
		Vector(1, -8),
		Vector(2, -8),
		Vector(3, -8),
		Vector(4, -8)
	};

	-- autobuild for brain units
	self.autoBuildListBrain = {
		Vector(-2, 2),
		Vector(-2, 1),
		Vector(-2, 0),
		Vector(-2, -1),
		Vector(2, 2),
		Vector(2, 1),
		Vector(2, 0),
		Vector(2, -1),

		Vector(-2, -2),
		Vector(-1, -2),
		Vector(0, -2),
		Vector(1, -2),
		Vector(2, -2),

		Vector(-3, 3),
		Vector(-3, 2),
		Vector(-3, 1),
		Vector(-3, 0),
		Vector(-3, -1),

		Vector(3, 3),
		Vector(3, 2),
		Vector(3, 1),
		Vector(3, 0),
		Vector(3, -1),

		Vector(-1, -1),
		Vector(0, -1),
		Vector(1, -1),
	};
end

function OnAttach(self, newParent)
	local rootParent = self:GetRootParent();
	if IsActor(rootParent) and MovableMan:IsActor(rootParent) then
		local pieMenu = ToActor(rootParent).PieMenu;
		local subPieMenuPieSlice = pieMenu:GetFirstPieSliceByPresetName("Constructor Options");
		if subPieMenuPieSlice ~= nil then
			pieMenu = subPieMenuPieSlice.SubPieMenu;
		end

		local mode = self:GetStringValue("ConstructorMode");
		local pieSliceToAddPresetName = mode == "Dig" and "Constructor Spray Mode" or "Constructor Dig Mode";
		pieMenu:AddPieSliceIfPresetNameIsUnique(CreatePieSlice(pieSliceToAddPresetName, self.ModuleName), self);
	end
end

function Update(self)
	local actor = self:GetRootParent();
	if actor and IsActor(actor) then

		actor = ToActor(actor);
		local ctrl = actor:GetController();
		local playerControlled = actor:IsPlayerControlled();
		local screen = ActivityMan:GetActivity():ScreenOfPlayer(ctrl.Player);

		if playerControlled and self.menu_ignore then
			if not ctrl:IsState(Controller.PIE_MENU_ACTIVE) then
				self.menu_ignore = false;
			end
		end

		if self.Magazine then
			self.Magazine.RoundCount = math.max(self.resource, 1);

			self.Magazine.Mass = 1 + 29 * (self.resource/self.maxResource);
			self.Magazine.Scale = 0.5 + (self.resource/self.maxResource) * 0.5;

			local parentWidth = ToMOSprite(actor):GetSpriteWidth();
			local parentHeight = ToMOSprite(actor):GetSpriteHeight();
			self.Magazine.Pos = actor.Pos + Vector(-(self.Magazine.Radius * 0.3 + parentWidth * 0.2 - 0.5) * self.FlipFactor, -(self.Magazine.Radius * 0.15 + parentHeight * 0.2)):RadRotate(actor.RotAngle);
			self.Magazine.RotAngle = actor.RotAngle;
		end

		if ctrl:IsState(Controller.PIE_MENU_ACTIVE) then
			PrimitiveMan:DrawTextPrimitive(screen, actor.AboveHUDPos + Vector(0, 26), "Mode: ".. self:GetStringValue("ConstructorMode"), true, 1);
		end

		-- constructor actions if the user is in gold dig mode
		if playerControlled then
			self.operatedByAI = false;
			self.toAutoBuild = true;
		elseif actor.AIMode == Actor.AIMODE_GOLDDIG then
			if self.toAutoBuild == false then
				if self:GetStringValue("ConstructorMode") == "Spray" then
					self:SetStringValue("ConstructorMode", "Dig");
				end
				if ctrl:IsState(Controller.WEAPON_FIRE) and SceneMan:ShortestDistance(actor.Pos, ConstructorTerrainRay(actor.Pos, Vector(0, 50), 3), SceneMan.SceneWrapsX):MagnitudeIsLessThan(30) then
					self.tunnelFillTimer:Reset();
					self.operatedByAI = true;
					self.aiSkillRatio = 1.5 - ActivityMan:GetActivity():GetTeamAISkill(actor.Team)/100;
					self.toAutoBuild = true;
					self.buildList = {};
					local buildscheme = self.autoBuildList;
					if actor:HasObjectInGroup("Brains") then
						buildscheme = self.autoBuildListBrain;
					end
					self.buildSize = 12;
					local snappos = ConstructorSnapPos(actor.Pos, self.buildSize);
					for i = 1, #buildscheme do
						local temppos = snappos + Vector(buildscheme[i].X * self.buildSize, buildscheme[i].Y * self.buildSize);
						local buildThis = {};
						buildThis[1] = temppos.X;
						buildThis[2] = temppos.Y;
						buildThis[3] = 0;
						buildThis[4] = self.buildSize;
						self.buildList[#self.buildList + 1] = buildThis;
					end
				end
			end

			-- constructor actions if it's AI controlled
			if self.operatedByAI then
				if self.tunnelFillTimer:IsPastSimMS(self.tunnelFillDelay * self.aiSkillRatio) and #self.buildList == 0 then
					self.buildSize = 12;
					self.tunnelFillTimer:Reset();

					-- create an empty 2D array, call cells having -1
					local floodFillListX = {};
					for x = 1, (self.maxFillDistance * 2) + 1 do
						floodFillListX[x] = {};
						for y = 1, (self.maxFillDistance * 2) + 1 do
							floodFillListX[x][y] = -1;
						end
					end

					-- figure out the center of the grid
					local center = math.ceil(((self.maxFillDistance * 2) + 1) * 0.5);

					-- FLOOD FILL!
					ConstructorFloodFill(center, center, 0, self.maxFillDistance, floodFillListX, ConstructorSnapPos(actor.Pos, self.buildSize), self.buildSize);

					-- dump the correctly numbered cells into the build table
					for x = 1, #floodFillListX do
						for y = 1, #floodFillListX do
							if floodFillListX[x][y] >= self.minFillDistance and floodFillListX[x][y] <= self.maxFillDistance then
								local mapX = ConstructorSnapPos(actor.Pos, self.buildSize).X + ((center - x) * -self.buildSize);
								local mapY = ConstructorSnapPos(actor.Pos, self.buildSize).Y + ((center - y) * -self.buildSize);
								local freeSlot = true;
								for i = 1, #self.buildList do
									if self.buildList[i] ~= nil and self.buildList[i][1] == mapX and self.buildList[i][2] == mapY then
										freeSlot = false;
										break;
									end
								end

								if freeSlot then
									local buildThis = {};
									buildThis[1] = mapX;
									buildThis[2] = mapY;
									buildThis[3] = 0;
									buildThis[4] = self.buildSize;
									self.buildList[#self.buildList + 1] = buildThis;
								end
							end
						end
					end
				end
			end
		else
			self.toAutoBuild = false;
		end

		local mode = self:GetNumberValue("BuildMode");
		if mode == 0 and not self.cursor then
			-- activation
			if ctrl:IsState(Controller.WEAPON_FIRE) then

				local angle = actor:GetAimAngle(true);

				if self:GetStringValue("ConstructorMode") == "Spray" then
					if self.resource >= self.sprayCost then
						local particleCount = 9;
						for i = 1, particleCount do
							local spray = CreateMOPixel("Particle Concrete " .. math.random(4), "Base.rte");
							spray.Pos = self.MuzzlePos;
							spray.Vel = self.Vel + Vector(RangeRand(11, 13), 0):RadRotate(angle + RangeRand(-0.5, 0.5) * self.spreadRange);
							spray.Team = self.Team;
							spray.IgnoresTeamHits = true;
							MovableMan:AddParticle(spray);
						end
						self.resource = self.resource - self.sprayCost;
					else
						self:Deactivate();
					end
				else
					local trace = Vector(self.digLength, 0):RadRotate(angle);
					local digPos = ConstructorTerrainRay(self.MuzzlePos, trace, 0);
					local found = 0;
					local totalVel = Vector();
					local digWeightTotal = 0;
					for x = -2, 2 do
						for y = -2, 2 do
							local checkPos = ConstructorWrapPos(Vector(digPos.X - 2 + x, digPos.Y - 2 + y));
							if SceneMan:IsWithinBounds(checkPos.X, checkPos.Y, 0) then
								local matID = SceneMan:GetTerrMatter(checkPos.X, checkPos.Y);
								if matID ~= rte.airID then
									local digWeight = 1;
									local material = SceneMan:GetMaterialFromID(matID);
									if material and material.StructuralIntegrity < self.digStrength then
										digWeight = material.StructuralIntegrity / self.digStrength;
									end
									local px = CreateMOPixel("Particle Constructor Gather Material");
									px.Pos = checkPos;
									px.Sharpness = self.ID;
									px.IgnoreTerrain = true;
									px.Vel = Vector(trace.X, trace.Y):SetMagnitude(-10):RadRotate(RangeRand(-0.5, 0.5));
									px:AddScript("Base.rte/Devices/Tools/Constructor/ConstructorCollect.lua");
									MovableMan:AddParticle(px);
									found = found + 1;
									digWeightTotal = digWeightTotal + digWeight;
									totalVel = totalVel + px.Vel;
								end
							end
						end
						if found > 0 then
							digWeightTotal = digWeightTotal / found;
							self.resource = math.min(self.resource + digWeightTotal * self.buildCost, self.maxResource);
							local collectFX = CreateMOPixel("Particle Constructor Gather Material");
							collectFX.Vel = totalVel / found;
							collectFX.Pos = Vector(digPos.X, digPos.Y) + collectFX.Vel * rte.PxTravelledPerFrame;
							MovableMan:AddParticle(collectFX);
						end
					end
				end
			end
		end
	end
end
