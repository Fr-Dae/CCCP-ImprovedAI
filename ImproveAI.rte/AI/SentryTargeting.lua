--[[
    ImproveAI
    Sentry Targeting

    Target selection for SentryActive.

    Target priority:
        1. Enemy inside effective weapon range.
        2. Direct line of sight.
        3. Prefer head if visible.
        4. Otherwise prefer legs.

    The actual firing behaviour is intentionally kept outside this module.

    This module should only answer:

        "Who should this Sentry engage?"
]]

ImproveAI = ImproveAI or {};
ImproveAI.SentryTargeting = ImproveAI.SentryTargeting or {};

local Targeting = ImproveAI.SentryTargeting;

-- ---------------------------------------------------------------------------
-- Configuration
-- ---------------------------------------------------------------------------

Targeting.RangeFactor = 0.90;

-- ---------------------------------------------------------------------------
-- Target validation
-- ---------------------------------------------------------------------------

function Targeting.IsValidTarget(actor, target)

    if actor == nil or target == nil then
        return false;
    end

    if target == actor then
        return false;
    end

    -- Only actors can be valid targets.
    if not IsActor(target) then
        return false;
    end

    -- Dead actors are ignored.
    if target.Status == Actor.DYING then
        return false;
    end

    -- Friendly actors are ignored.
    if target.Team == actor.Team then
        return false;
    end

    return true;
end


-- ---------------------------------------------------------------------------
-- Distance
-- ---------------------------------------------------------------------------

function Targeting.GetDistance(actor, target)

    if actor == nil or target == nil then
        return math.huge;
    end

    return SceneMan:ShortestDistance(
        actor.Pos,
        target.Pos,
        SceneMan.SceneWrapsX
    ).Magnitude;
end


-- ---------------------------------------------------------------------------
-- Line of sight
-- ---------------------------------------------------------------------------

function Targeting.HasLineOfSight(actor, position)

    if actor == nil or position == nil then
        return false;
    end

    local ray = SceneMan:ShortestDistance(
        actor.EyePos,
        position,
        SceneMan.SceneWrapsX
    );

    local hitPos = Vector();

    local obstacle = SceneMan:CastObstacleRay(
        actor.EyePos,
        ray,
        hitPos,
        Vector(),
        actor.ID,
        actor.Team,
        0,
        0
    );

    return obstacle < 0;
end


-- ---------------------------------------------------------------------------
-- Aim points
-- ---------------------------------------------------------------------------

function Targeting.GetHeadPosition(target)

    if target == nil then
        return nil;
    end

    -- Head position is intentionally approximated from the actor's
    -- graphical position for the first implementation.
    --
    -- A later version should use the actual head limb / head primitive
    -- and verify whether helmets, armour and shields obstruct the shot.

    return target.Pos + Vector(0, -target.Radius * 0.65);
end


function Targeting.GetLegPosition(target)

    if target == nil then
        return nil;
    end

    return target.Pos + Vector(0, target.Radius * 0.55);
end


-- ---------------------------------------------------------------------------
-- Aim point selection
-- ---------------------------------------------------------------------------

function Targeting.FindAimPoint(actor, target)

    if not Targeting.IsValidTarget(actor, target) then
        return nil;
    end

    -- Prefer the head whenever it has a clear line of sight.
    local headPos = Targeting.GetHeadPosition(target);

    if headPos ~= nil and Targeting.HasLineOfSight(actor, headPos) then
        return headPos;
    end

    -- If the head cannot be seen, attempt the legs.
    local legPos = Targeting.GetLegPosition(target);

    if legPos ~= nil and Targeting.HasLineOfSight(actor, legPos) then
        return legPos;
    end

    return nil;
end


-- ---------------------------------------------------------------------------
-- Target search
-- ---------------------------------------------------------------------------

function Targeting.FindTarget(actor)

    if actor == nil then
        return nil;
    end

    local bestTarget = nil;
    local bestDistance = math.huge;

    -- Search the scene for actors.
    for actorIndex = 0, MovableMan.ActorsCount - 1 do

        local candidate = MovableMan.Actors[actorIndex];

        if Targeting.IsValidTarget(actor, candidate) then

            local distance = Targeting.GetDistance(actor, candidate);

            -- First select by distance.
            if distance < bestDistance then

                local aimPoint = Targeting.FindAimPoint(
                    actor,
                    candidate
                );

                -- A target without a usable firing solution is ignored.
                if aimPoint ~= nil then

                    bestTarget = candidate;
                    bestDistance = distance;

                    actor.ImproveAI_SentryAimPoint = aimPoint;
                end
            end
        end
    end

    return bestTarget;
end
