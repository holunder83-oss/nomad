-- Variante D "Hardcore" (seit 1.0.5, Wunsch des Users): Bis nach Vulcanus auf Planeten keine Fabriken und Oefen.
-- Jedes Fabrikgebaeude bekommt eine eigene Forschung "Planetenbau: <Gebaeude>", alle setzen Metallurgie-Science
-- voraus. Wird von prototypes/variant-a.lua aufgerufen (gleiche Erkennung der Gebaeude, gleiche Durchsetzung durch
-- scripts/planet-rules.lua). Zahlen laut Konzept vom 2026-11-15.

local costs = require("prototypes.upgrade-costs")

local hardcore = {}

local BASE = {"automation-science-pack", "logistic-science-pack", "chemical-science-pack", "space-science-pack",
  "metallurgic-science-pack"}

-- Gebaeude -> Anzahl und zusaetzliche Packs. "all" = alle Packs bis Kryo.
local TIERS =
{
  -- I Grundversorgung
  ["stone-furnace"] = {count = 500},
  ["assembling-machine-1"] = {count = 500},
  ["steel-furnace"] = {count = 1000},
  ["assembling-machine-2"] = {count = 1500},
  ["chemical-plant"] = {count = 1500},
  ["oil-refinery"] = {count = 2000},
  -- II Ausbau
  ["electric-furnace"] = {count = 3000},
  ["foundry"] = {count = 5000},
  ["centrifuge"] = {count = 5000, packs = {"production-science-pack"}},
  ["assembling-machine-3"] = {count = 5000, packs = {"production-science-pack"}},
  ["beacon"] = {count = 8000, packs = {"production-science-pack", "utility-science-pack"}},
  -- III Space Age
  ["recycler"] = {count = 5000, packs = {"electromagnetic-science-pack"}},
  ["electromagnetic-plant"] = {count = 10000, packs = {"electromagnetic-science-pack"}},
  ["biochamber"] = {count = 10000, packs = {"agricultural-science-pack"}},
  ["cryogenic-plant"] = {count = 20000, all = true},
}
local DEFAULT = {count = 10000, all = true}

-- Variante E "Super-Hardcore" (1.0.16, Wunsch des Users): Auf Planeten ab Start nur die Grundausstattung
-- (prototypes/variant-a.lua, SUPER_ALWAYS), jedes andere Gebaeude mit eigener Forschung, gestaffelt ab Rot.
-- packs = Packs ausser Rot (Rot ist immer dabei). Gebaeude ohne Eintrag: SUPER_DEFAULT.
local R, RG, RGB = {}, {"logistic-science-pack"}, {"logistic-science-pack", "chemical-science-pack"}
local RGBW = {"logistic-science-pack", "chemical-science-pack", "space-science-pack"}
local function plus(list, ...)
  local result = {}
  for _, pack in pairs(list) do table.insert(result, pack) end
  for _, pack in pairs({...}) do table.insert(result, pack) end
  return result
end
local SUPER = {}
local function super_group(count, packs, names)
  for _, name in pairs(names) do SUPER[name] = {count = count, packs = packs} end
end
-- I Erste Upgrades (nur Rot)
super_group(50, R, {"inserter", "iron-chest", "small-lamp"})
super_group(100, R, {"underground-belt", "splitter", "pipe", "pipe-to-ground", "stone-wall"})
super_group(150, R, {"medium-electric-pole", "offshore-pump", "gun-turret"})
super_group(200, R, {"radar", "stone-furnace"})
super_group(300, R, {"assembling-machine-1"})
-- II Rot + Gruen
super_group(200, RG, {"long-handed-inserter", "steel-chest", "gate", "land-mine", "arithmetic-combinator",
  "decider-combinator", "constant-combinator", "selector-combinator", "power-switch", "programmable-speaker",
  "display-panel"})
super_group(300, RG, {"fast-inserter", "fast-transport-belt", "fast-underground-belt", "fast-splitter", "boiler",
  "steam-engine", "accumulator", "pump", "storage-tank", "car"})
super_group(400, RG, {"big-electric-pole"})
super_group(500, RG, {"steel-furnace", "assembling-machine-2", "pumpjack", "straight-rail", "half-diagonal-rail",
  "curved-rail-a", "curved-rail-b", "rail-signal", "rail-chain-signal", "train-stop", "locomotive", "cargo-wagon",
  "fluid-wagon", "rail-ramp", "rail-support", "elevated-straight-rail", "elevated-half-diagonal-rail",
  "elevated-curved-rail-a", "elevated-curved-rail-b"})
-- III Rot + Gruen + Blau
super_group(800, RGB, {"substation"})
super_group(1000, RGB, {"bulk-inserter", "express-transport-belt", "express-underground-belt", "express-splitter",
  "chemical-plant", "laser-turret", "flamethrower-turret", "tank", "passive-provider-chest", "active-provider-chest",
  "storage-chest", "buffer-chest", "requester-chest"})
super_group(1500, RGB, {"oil-refinery", "roboport"})
super_group(2000, RGB, {"electric-furnace"})
-- IV mit Weltraum-Science (Agrarturm und Heizturm ohne Agrar-Pack, sonst Kreis auf Gleba bzw. Aquilo)
super_group(500, RGBW, {"heat-pipe"})
super_group(1000, RGBW, {"cargo-bay", "agricultural-tower", "heating-tower"})
super_group(3000, RGBW, {"rocket-silo"})
-- V Produktion / Hilfsmittel
super_group(3000, plus(RGB, "production-science-pack"), {"centrifuge", "heat-exchanger", "steam-turbine"})
super_group(5000, plus(RGB, "production-science-pack"), {"assembling-machine-3", "nuclear-reactor"})
super_group(3000, plus(RGB, "utility-science-pack"), {"artillery-turret", "artillery-wagon"})
super_group(8000, plus(RGB, "production-science-pack", "utility-science-pack"), {"beacon"})
-- VI Planeten-Packs
super_group(2000, plus(RGBW, "metallurgic-science-pack"), {"big-mining-drill"})
super_group(3000, plus(RGBW, "metallurgic-science-pack"), {"turbo-transport-belt", "turbo-underground-belt",
  "turbo-splitter"})
super_group(5000, plus(RGBW, "metallurgic-science-pack"), {"foundry"})
super_group(500, plus(RGBW, "electromagnetic-science-pack"), {"lightning-rod"})
super_group(1500, plus(RGBW, "electromagnetic-science-pack"), {"lightning-collector"})
super_group(3000, plus(RGBW, "electromagnetic-science-pack"), {"recycler", "tesla-turret"})
super_group(10000, plus(RGBW, "electromagnetic-science-pack"), {"electromagnetic-plant"})
super_group(3000, plus(RGBW, "agricultural-science-pack"), {"rocket-turret"})
super_group(10000, plus(RGBW, "agricultural-science-pack"), {"biochamber"})
super_group(10000, plus(RGBW, "cryogenic-science-pack"), {"railgun-turret"})
super_group(20000, plus(RGBW, "cryogenic-science-pack"), {"cryogenic-plant", "fusion-reactor", "fusion-generator"})
local SUPER_DEFAULT = {count = 2000, packs = RGBW}

-- true in Variante E (von prototypes/variant-a.lua gesetzt)
hardcore.super = false

-- Forschung, die ein Pack freischaltet (im Grundspiel gleichnamig)
local function pack_tech(pack)
  return data.raw.technology[pack] and pack or nil
end

-- Item, das das Gebaeude platziert
local function placing_item(entity_name)
  for _, items in pairs(data.raw) do
    for item_name, item in pairs(items) do
      if type(item) == "table" and item.place_result == entity_name then return item_name, item end
      -- Schienen baut der Schienenplaner (Liste rails statt place_result)
      if type(item) == "table" and item.type == "rail-planner" then
        for _, rail in pairs(item.rails or {}) do
          if rail == entity_name then return item_name, item end
        end
      end
    end
  end
end

-- Forschung, die das Rezept des Items freischaltet (nil, wenn es ab Start da ist)
local function unlocking_tech(item_name)
  local recipes = {}
  local own_recipe = data.raw.recipe[item_name]
  if own_recipe then
    if own_recipe.enabled ~= false then return nil end -- ab Start (Steinofen)
    recipes[item_name] = true
  else
    -- Recycling-Rezepte liefern auch Gebaeude, zaehlen aber nicht
    for recipe_name, recipe in pairs(data.raw.recipe) do
      if not string.find(recipe_name, "%-recycling$") then
        for _, result in pairs(recipe.results or {}) do
          if result.name == item_name then recipes[recipe_name] = true end
        end
      end
    end
  end
  for tech_name, tech in pairs(data.raw.technology) do
    for _, effect in pairs(tech.effects or {}) do
      if effect.type == "unlock-recipe" and recipes[effect.recipe] then return tech_name end
    end
  end
end

local function item_icons(item)
  if item and item.icons then return table.deepcopy(item.icons) end
  if item and item.icon then return {{icon = item.icon, icon_size = item.icon_size or 64}} end
  return {{icon = "__base__/graphics/icons/assembling-machine-1.png", icon_size = 64}}
end

-- true, wenn das Gebaeude ueber ein Item gebaut wird, das man im Spiel herstellen kann (ab Start oder per Forschung).
-- Editor-Gebaeude (Unendlich-Kiste, Lader, Waerme-Schnittstelle) bleiben frei.
function hardcore.craftable(entity_name)
  local item_name = placing_item(entity_name)
  if not item_name then return false end
  local recipes = {}
  for recipe_name, recipe in pairs(data.raw.recipe) do
    if not string.find(recipe_name, "%-recycling$") and not recipe.hidden then
      for _, result in pairs(recipe.results or {}) do
        if result.name == item_name then
          if recipe.enabled ~= false then return true end
          recipes[recipe_name] = true
        end
      end
    end
  end
  for _, tech in pairs(data.raw.technology) do
    for _, effect in pairs(tech.effects or {}) do
      if effect.type == "unlock-recipe" and recipes[effect.recipe] then return true end
    end
  end
  return false
end

-- Super-Hardcore: alle Schienenstuecke teilen sich eine Forschung (Schienen bzw. Hochschienen)
local SUPER_ALIAS =
{
  ["curved-rail-a"] = "straight-rail", ["curved-rail-b"] = "straight-rail", ["half-diagonal-rail"] = "straight-rail",
  ["elevated-curved-rail-a"] = "elevated-straight-rail", ["elevated-curved-rail-b"] = "elevated-straight-rail",
  ["elevated-half-diagonal-rail"] = "elevated-straight-rail", ["rail-ramp"] = "elevated-straight-rail",
  ["rail-support"] = "elevated-straight-rail"
}

-- Legt die Forschung fuer ein Gebaeude an und gibt ihren Namen zurueck.
-- Name endet nicht auf eine Zahl, sonst haelt Factorio sie fuer eine Stufen-Forschung (assembling-machine-2).
function hardcore.tech_for(entity_name, prototype)
  if hardcore.super and SUPER_ALIAS[entity_name] then
    local alias = SUPER_ALIAS[entity_name]
    for _, prototypes_of_type in pairs(data.raw) do
      local main = prototypes_of_type[alias]
      if type(main) == "table" and main.collision_box then return hardcore.tech_for(alias, main) end
    end
  end
  local tech_name = "ncs-planet-" .. entity_name .. "-build"
  if data.raw.technology[tech_name] then return tech_name end
  local tier
  if hardcore.super then
    tier = SUPER[entity_name] or SUPER_DEFAULT
  else
    tier = TIERS[entity_name] or DEFAULT
  end

  local unit
  if tier.all then
    unit = costs.unit("cryogenic-science-pack")
  else
    local ingredients = {}
    for _, pack in pairs(hardcore.super and {"automation-science-pack"} or BASE) do
      table.insert(ingredients, {pack, 1})
    end
    for _, pack in pairs(tier.packs or {}) do table.insert(ingredients, {pack, 1}) end
    unit = {ingredients = ingredients, time = 60}
  end
  unit.count = tier.count

  -- Hardcore: alle nach Metallurgie-Science; Super-Hardcore: nur nach den Forschungen der Packs
  local prerequisites = hardcore.super and {} or {"metallurgic-science-pack"}
  for _, ingredient in pairs(unit.ingredients) do
    local tech = pack_tech(ingredient[1])
    if tech and tech ~= prerequisites[1] and tech ~= "automation-science-pack" then
      table.insert(prerequisites, tech)
    end
  end
  local item_name, item = placing_item(entity_name)
  local own = item_name and unlocking_tech(item_name)
  if own and own ~= tech_name then
    local known = false
    for _, name in pairs(prerequisites) do if name == own then known = true end end
    if not known then table.insert(prerequisites, own) end
  end

  -- Gebaeude gross, Planet in der Ecke (Forschungsbilder 256, Item-Bilder 64: Ebenen x4)
  local icons = {}
  for _, layer in pairs(item_icons(item)) do
    local size = layer.icon_size or 64
    layer.icon_size = size
    layer.scale = (layer.scale or (32 / size)) * 4
    if layer.shift then layer.shift = {layer.shift[1] * 4, layer.shift[2] * 4} end
    table.insert(icons, layer)
  end
  table.insert(icons, {icon = "__base__/graphics/icons/nauvis.png", icon_size = 64, scale = 0.75, shift = {38, 38}})

  local entity_label = prototype.localised_name or {"entity-name." .. entity_name}
  if hardcore.super and entity_name == "straight-rail" then entity_label = {"item-name.rail"} end
  if hardcore.super and entity_name == "elevated-straight-rail" then entity_label = {"technology-name.elevated-rail"} end
  data:extend({{
    type = "technology",
    name = tech_name,
    localised_name = {"ncs-tech.planet-build", entity_label},
    localised_description = {"ncs-tech.planet-build-description", entity_label},
    icons = icons,
    effects = {{type = "nothing", effect_description = {"ncs-tech.planet-build-effect", "[entity=" .. entity_name .. "]"}}},
    prerequisites = prerequisites,
    unit = unit,
    order = "z[ncs]-q[planet-build]-" .. string.format("%06d", tier.count) .. "-" .. entity_name
  }})
  return tech_name
end

-- Fuer Variante F (prototypes/variant-f.lua)
hardcore.placing_item = placing_item
hardcore.unlocking_tech = unlocking_tech
hardcore.item_icons = item_icons
hardcore.pack_tech = pack_tech

return hardcore
