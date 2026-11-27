-- Variante A: Fabriken auf Planeten per Forschung (Liste aus prototypes/variant-a.lua, mod-data "ncs-planet-rules").
-- Ob ein Gebaeude auf einer Oberflaeche stehen darf, kann Factorio nicht an eine Forschung knuepfen. Deshalb wird
-- ein gesperrtes Gebaeude auf einem Planeten sofort wieder abgebaut (Item zurueck an Spieler bzw. Roboter), ein
-- gesperrter Geist entfernt, mit Hinweis auf die noetige Forschung. Im All gilt nichts davon.

local planet_rules = {}

-- Typen der betroffenen Fabriken (fuer die Ereignis-Filter)
local TYPES = {"assembling-machine", "furnace", "beacon", "lab"}
-- Super-Hardcore und Super-Duper-Hardcore (1.0.16): fast alle Gebaeude sind gesperrt, deshalb alle Bau-Typen
local variant = settings.startup["ncs-rules-variant"].value
if variant == "super-hardcore" or variant == "super-duper-hardcore" then
  for _, type_name in pairs({
    "mining-drill", "offshore-pump", "agricultural-tower", "transport-belt", "underground-belt", "splitter",
    "lane-splitter", "loader", "loader-1x1", "inserter", "container", "logistic-container", "pipe", "pipe-to-ground",
    "pump", "storage-tank", "valve", "roboport", "electric-pole", "power-switch", "boiler", "generator",
    "burner-generator", "solar-panel", "accumulator", "reactor", "heat-pipe", "fusion-reactor", "fusion-generator",
    "lightning-attractor", "turret", "ammo-turret", "electric-turret", "fluid-turret", "artillery-turret", "wall",
    "gate", "land-mine", "radar", "straight-rail", "curved-rail-a", "curved-rail-b", "half-diagonal-rail",
    "elevated-straight-rail", "elevated-curved-rail-a", "elevated-curved-rail-b", "elevated-half-diagonal-rail",
    "rail-ramp", "rail-support", "rail-signal", "rail-chain-signal", "train-stop", "locomotive", "cargo-wagon",
    "fluid-wagon", "artillery-wagon", "car", "spider-vehicle", "arithmetic-combinator", "decider-combinator",
    "constant-combinator", "selector-combinator", "programmable-speaker", "lamp", "display-panel", "rocket-silo",
    "cargo-landing-pad", "cargo-bay", "unit-spawner"
  }) do
    table.insert(TYPES, type_name)
  end
end

planet_rules.FILTER = {}
for _, type_name in pairs(TYPES) do
  table.insert(planet_rules.FILTER, {filter = "type", type = type_name})
  table.insert(planet_rules.FILTER, {filter = "ghost_type", type = type_name})
end

local gated_cache
local function gated()
  if gated_cache == nil then
    local mod_data = prototypes.mod_data["ncs-planet-rules"]
    gated_cache = mod_data and mod_data.data.gated or false
  end
  return gated_cache
end

-- Noetige Forschung, wenn das Gebaeude hier (noch) gesperrt ist, sonst nil
local function blocking_tech(entity)
  local list = gated()
  if not list then return nil end
  local surface = entity.surface
  if surface.platform or not surface.planet then return nil end
  local name = entity.type == "entity-ghost" and entity.ghost_name or entity.name
  local tech_name = list[name]
  if not tech_name then return nil end
  local tech = entity.force.technologies[tech_name]
  if tech and tech.researched then return nil end
  return tech_name
end

-- Mit T.H.U.D (1.0.10): Labore, die Nomad nur im All erlaubt (prototypes/lab-rules.lua), sonst nil
local lab_cache
local function script_labs()
  if lab_cache == nil then
    local mod_data = prototypes.mod_data["ncs-lab-rules"]
    lab_cache = mod_data and mod_data.data.labs or false
  end
  return lab_cache
end

-- Boden eines mit T.H.U.D gelandeten Schiffs (auch gepflastert: dann liegt er als verborgene Kachel darunter).
-- Dort gilt alles wie auf dem Schiff (Wunsch des Users, 1.0.10).
local LANDED_FLOOR = "thud-landed-foundation"
local landed_floor_exists
local function on_landed_floor(entity)
  if landed_floor_exists == nil then landed_floor_exists = prototypes.tile[LANDED_FLOOR] ~= nil end
  if not landed_floor_exists then return false end
  local box = entity.bounding_box
  local area = {{box.left_top.x + 0.01, box.left_top.y + 0.01}, {box.right_bottom.x - 0.01, box.right_bottom.y - 0.01}}
  local tiles = entity.surface.find_tiles_filtered{area = area}
  if not tiles[1] then return false end
  for _, tile in pairs(tiles) do
    if tile.name ~= LANDED_FLOOR and tile.hidden_tile ~= LANDED_FLOOR then return false end
  end
  return true
end
planet_rules.on_landed_floor = on_landed_floor

local function notify(player, entity, tech_name)
  if not (player and player.valid) then return end
  player.create_local_flying_text{text = {"ncs-planet-rules.blocked", "[technology=" .. tech_name .. "]"},
    position = entity.position, create_at_cursor = true}
  player.print({"ncs-planet-rules.blocked", "[technology=" .. tech_name .. "]"})
end

-- Gebaeude, die zusaetzlich ins All duerfen (prototypes/space-also.lua): auf Planeten gelten ihre alten Bedingungen.
local space_also_cache
local function space_also()
  if space_also_cache == nil then
    local mod_data = prototypes.mod_data["ncs-space-also"]
    space_also_cache = mod_data and mod_data.data.conditions or false
  end
  return space_also_cache
end

-- true, wenn das Gebaeude auf diesem Planeten nicht stehen darf
local function space_also_blocked(entity)
  local list = space_also()
  if not list then return false end
  local surface = entity.surface
  if surface.platform or not surface.planet then return false end
  local name = entity.type == "entity-ghost" and entity.ghost_name or entity.name
  local conditions = list[name]
  if not conditions then return false end
  for _, condition in pairs(conditions) do
    local value = surface.get_property(condition.property)
    if (condition.min and value < condition.min) or (condition.max and value > condition.max) then return true end
  end
  return false
end

local function remove(event, entity, player)
  if entity.type == "entity-ghost" then
    entity.destroy()
  elseif player and player.valid then
    if not player.mine_entity(entity, true) and entity.valid then entity.destroy() end
  elseif event.robot and event.robot.valid then
    local cargo = event.robot.get_inventory(defines.inventory.robot_cargo)
    if not entity.mine{inventory = cargo, force = true, ignore_minable = true} and entity.valid then entity.destroy() end
  else
    entity.destroy()
  end
end

function planet_rules.on_built(event)
  local entity = event.entity
  if not (entity and entity.valid) then return end
  -- Nur Bauen durch Spieler und Roboter, nicht Skripte anderer Mods
  if not (event.player_index or event.robot) then return end
  local player = event.player_index and game.get_player(event.player_index)
  local surface = entity.surface
  if surface.platform or not surface.planet then return end
  if on_landed_floor(entity) then return end

  local labs = script_labs()
  local name = entity.type == "entity-ghost" and entity.ghost_name or entity.name
  if labs and labs[name] then
    if player and player.valid then
      local text = {"ncs-planet-rules.lab", "[entity=" .. name .. "]"}
      player.create_local_flying_text{text = text, position = entity.position, create_at_cursor = true}
      player.print(text)
    end
    remove(event, entity, player)
    return
  end

  if space_also_blocked(entity) then
    if player and player.valid then
      local name = entity.type == "entity-ghost" and entity.ghost_name or entity.name
      local text = {"ncs-planet-rules.space-also", "[entity=" .. name .. "]"}
      player.create_local_flying_text{text = text, position = entity.position, create_at_cursor = true}
      player.print(text)
    end
    remove(event, entity, player)
    return
  end

  local tech_name = blocking_tech(entity)
  if not tech_name then return end

  if entity.type == "entity-ghost" then
    notify(player, entity, tech_name)
    entity.destroy()
    return
  end

  notify(player, entity, tech_name)
  if player and player.valid then
    if not player.mine_entity(entity, true) and entity.valid then entity.destroy() end
  elseif event.robot and event.robot.valid then
    local cargo = event.robot.get_inventory(defines.inventory.robot_cargo)
    if not entity.mine{inventory = cargo, force = true, ignore_minable = true} and entity.valid then entity.destroy() end
  else
    entity.destroy()
  end
end

return planet_rules
