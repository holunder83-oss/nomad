-- Variante F "Super-Duper-Hardcore" (1.0.16, Wunsch des Users): Auf Planeten nur das Allernoetigste.
-- Grundausstattung wie in E (prototypes/variant-a.lua, SUPER_ALWAYS) plus Raketensilo. Dazu als Paket-Forschung:
--   * Planeten-Pakete nach Entdeckung des Planeten: Vulcanus Pumpe + Rohre (Lava fuer die Kapsel), Fulgora
--     Blitzableiter + Akku, Gleba Agrarturm, Aquilo Heizturm + Waermerohr + Pumpjack. Auf Gleba sind alle
--     Geschuetztuerme erlaubt: jeder Turm eine eigene Forschung nach "Gleba entdecken".
--   * Baender und Greifarme nach jedem Planeten, je eine eigene Forschung (gelbes Band ab Start): gelb (Untergrund/
--     Splitter bzw. Greifarm + langer Greifarm) frueh, rot (schneller Greifarm) mit Metallurgie-, blau (Massengreifer)
--     mit EM-, Turbo (Stapelgreifer) mit Agrar-Science.
--   * Extraktor-Pakete: was die Herausforderung eines Planeten mindestens braucht (Nauvis Geschuetz + Mauer gegen
--     Beisser, Vulcanus Chemieanlage + Tank fuer Wasser/Dampf, Fulgora Assembler 1 zum Stabilisieren). Gleba und
--     Aquilo haben es schon in ihren Planeten-Paketen.
--   * Komfort-Paket frueh auf Nauvis (Radar, Lampe, Kombinatoren, Schalter, Lautsprecher, Anzeige,
--     Selektor-Kombinator; 200 x Rot/Gruen; 1.0.20).
--   * Uebrige Grundspiel-Gebaeude erst nach Aquilo (Kryo-Science), Space-Age-Gebaeude erst mit Promethium-Science,
--     gebuendelt nach Bereichen (Logistik, Fluessigkeiten, Strom, Produktion ...).
-- Gleiche Schnittstelle wie prototypes/variant-d.lua: tech_for liefert den Namen, finalize legt die Forschungen an.

local costs = require("prototypes.upgrade-costs")
local hardcore = require("prototypes.variant-d")

local f = {super = true, craftable = hardcore.craftable}

local RGBW = {"automation-science-pack", "logistic-science-pack", "chemical-science-pack", "space-science-pack"}
local function unit_of(count, packs)
  local ingredients = {}
  for _, pack in pairs(packs) do table.insert(ingredients, {pack, 1}) end
  return {count = count, ingredients = ingredients, time = 60}
end
local function plus(list, ...)
  local result = {}
  for _, pack in pairs(list) do table.insert(result, pack) end
  for _, pack in pairs({...}) do table.insert(result, pack) end
  return result
end
-- Alle Packs bis Kryo bzw. bis Promethium
local function all_until_cryo(count)
  local unit = costs.unit("cryogenic-science-pack")
  unit.count = count
  return unit
end
local function all_until_promethium(count)
  local unit = all_until_cryo(count)
  table.insert(unit.ingredients, {"promethium-science-pack", 1})
  return unit
end

-- Pakete: key -> Forschung. icon = Gebaeude fuers Bild, pre = zusaetzliche Voraussetzungen.
local GROUPS =
{
  -- Baender
  ["belts-yellow"] = {icon = "underground-belt", unit = unit_of(100, {"automation-science-pack"}), pre = {}},
  ["belts-red"] = {icon = "fast-transport-belt", unit = unit_of(1000, plus(RGBW, "metallurgic-science-pack")),
    pre = {"metallurgic-science-pack"}},
  ["belts-blue"] = {icon = "express-transport-belt", unit = unit_of(2000, plus(RGBW, "electromagnetic-science-pack")),
    pre = {"electromagnetic-science-pack"}},
  ["belts-turbo"] = {icon = "turbo-transport-belt", unit = unit_of(3000, plus(RGBW, "agricultural-science-pack")),
    pre = {"agricultural-science-pack"}},
  -- Greifarme
  ["inserters-yellow"] = {icon = "inserter", unit = unit_of(100, {"automation-science-pack"}), pre = {}},
  ["inserters-red"] = {icon = "fast-inserter", unit = unit_of(1000, plus(RGBW, "metallurgic-science-pack")),
    pre = {"metallurgic-science-pack"}},
  ["inserters-blue"] = {icon = "bulk-inserter", unit = unit_of(2000, plus(RGBW, "electromagnetic-science-pack")),
    pre = {"electromagnetic-science-pack"}},
  ["inserters-turbo"] = {icon = "stack-inserter", unit = unit_of(3000, plus(RGBW, "agricultural-science-pack")),
    pre = {"agricultural-science-pack"}},
  -- Komfort auf Nauvis (1.0.20, Wunsch des Users): Radar, Lampen, Schaltungen frueh
  -- Selektor-Kombinator braucht im Grundspiel Blau (advanced-combinators): nicht als Voraussetzung, sonst kaeme das
  -- ganze Paket erst nach Blau. Bauen darf man ihn ab dem Paket, herstellen erst nach der Grundspiel-Forschung.
  ["qol"] = {icon = "radar", unit = unit_of(200, {"automation-science-pack", "logistic-science-pack"}), pre = {},
    skip_own = {["selector-combinator"] = true}},
  -- Extraktor-Pakete
  ["extractor-nauvis"] = {icon = "gun-turret", unit = unit_of(500, RGBW), pre = {"ncs-extractor"}},
  ["extractor-vulcanus"] = {icon = "chemical-plant", unit = unit_of(500, RGBW),
    pre = {"ncs-extractor", "planet-discovery-vulcanus"}},
  ["extractor-fulgora"] = {icon = "assembling-machine-1", unit = unit_of(500, RGBW),
    pre = {"ncs-extractor", "planet-discovery-fulgora"}},
  -- Planeten-Pakete
  ["vulcanus"] = {icon = "offshore-pump", unit = unit_of(500, RGBW), pre = {"planet-discovery-vulcanus"}},
  ["fulgora"] = {icon = "lightning-rod", unit = unit_of(500, RGBW), pre = {"planet-discovery-fulgora"}},
  ["gleba"] = {icon = "agricultural-tower", unit = unit_of(500, RGBW), pre = {"planet-discovery-gleba"}},
  ["aquilo"] = {icon = "heating-tower", unit = unit_of(500, RGBW), pre = {"planet-discovery-aquilo"}},
  -- Grundspiel nach Aquilo
  ["logistics"] = {icon = "fast-inserter", unit = all_until_cryo(5000), pre = {"cryogenic-science-pack"}},
  ["fluids"] = {icon = "storage-tank", unit = all_until_cryo(5000), pre = {"cryogenic-science-pack"}},
  ["power"] = {icon = "steam-engine", unit = all_until_cryo(5000), pre = {"cryogenic-science-pack"}},
  ["production"] = {icon = "assembling-machine-2", unit = all_until_cryo(10000), pre = {"cryogenic-science-pack"}},
  ["defense"] = {icon = "stone-wall", unit = all_until_cryo(3000), pre = {"cryogenic-science-pack"}},
  ["trains"] = {icon = "locomotive", unit = all_until_cryo(5000), pre = {"cryogenic-science-pack"}},
  ["vehicles"] = {icon = "car", unit = all_until_cryo(3000), pre = {"cryogenic-science-pack"}},
  ["robots"] = {icon = "roboport", unit = all_until_cryo(5000), pre = {"cryogenic-science-pack"}},
  ["circuits"] = {icon = "decider-combinator", unit = all_until_cryo(2000), pre = {"cryogenic-science-pack"}},
  ["rockets"] = {icon = "cargo-bay", unit = all_until_cryo(5000), pre = {"cryogenic-science-pack"}},
  ["base-other"] = {icon = "iron-chest", unit = all_until_cryo(5000), pre = {"cryogenic-science-pack"}},
  -- Space Age mit Promethium-Science
  ["sa-production"] = {icon = "foundry", unit = all_until_promethium(30000), pre = {"promethium-science-pack"}},
  ["sa-power"] = {icon = "fusion-reactor", unit = all_until_promethium(20000), pre = {"promethium-science-pack"}},
  ["sa-mining"] = {icon = "big-mining-drill", unit = all_until_promethium(20000), pre = {"promethium-science-pack"}},
  ["sa-other"] = {icon = "captive-biter-spawner", unit = all_until_promethium(20000), pre = {"promethium-science-pack"}},
}
-- Reihenfolge im Forschungsbaum
local ORDER = {"belts-yellow", "inserters-yellow", "qol", "extractor-nauvis", "vulcanus", "extractor-vulcanus", "belts-red", "inserters-red", "fulgora", "extractor-fulgora", "belts-blue", "inserters-blue", "gleba", "belts-turbo", "inserters-turbo", "aquilo",
  "logistics", "fluids", "power", "production", "defense", "trains", "vehicles", "robots", "circuits", "rockets",
  "base-other", "sa-production", "sa-power", "sa-mining", "sa-other"}

local MEMBERS = {}
local function put(key, names)
  for _, name in pairs(names) do MEMBERS[name] = key end
end
put("belts-yellow", {"underground-belt", "splitter"})
put("belts-red", {"fast-transport-belt", "fast-underground-belt", "fast-splitter"})
put("belts-blue", {"express-transport-belt", "express-underground-belt", "express-splitter"})
put("belts-turbo", {"turbo-transport-belt", "turbo-underground-belt", "turbo-splitter"})
put("inserters-yellow", {"inserter", "long-handed-inserter"})
put("inserters-red", {"fast-inserter"})
put("inserters-blue", {"bulk-inserter"})
put("inserters-turbo", {"stack-inserter"})
put("extractor-nauvis", {"gun-turret", "stone-wall"})
put("extractor-vulcanus", {"chemical-plant", "storage-tank"})
put("extractor-fulgora", {"assembling-machine-1"})
put("vulcanus", {"offshore-pump"})
put("fulgora", {"lightning-rod", "accumulator"})
put("gleba", {"agricultural-tower"})
put("aquilo", {"heating-tower", "heat-pipe"})
put("logistics", {"iron-chest", "steel-chest"})
put("fluids", {"pump"})
put("power", {"medium-electric-pole", "big-electric-pole", "substation", "boiler", "steam-engine",
  "steam-turbine", "heat-exchanger", "nuclear-reactor"})
put("production", {"assembling-machine-2", "assembling-machine-3", "stone-furnace", "steel-furnace",
  "electric-furnace", "oil-refinery", "centrifuge", "beacon"})
put("defense", {"gate", "land-mine", "artillery-turret"})
put("trains", {"straight-rail", "half-diagonal-rail", "curved-rail-a", "curved-rail-b", "rail-signal",
  "rail-chain-signal", "train-stop", "locomotive", "cargo-wagon", "fluid-wagon", "artillery-wagon", "rail-ramp",
  "rail-support", "elevated-straight-rail", "elevated-half-diagonal-rail", "elevated-curved-rail-a",
  "elevated-curved-rail-b"})
put("vehicles", {"car", "tank", "spidertron"})
put("robots", {"roboport", "passive-provider-chest", "active-provider-chest", "storage-chest", "buffer-chest",
  "requester-chest"})
put("qol", {"radar", "small-lamp", "arithmetic-combinator", "decider-combinator", "constant-combinator",
  "power-switch", "programmable-speaker", "display-panel", "selector-combinator"})
-- Raketensilo, Frachtraum und Landeplatz-Entladeraum ab Start (Wunsch des Users, prototypes/variant-a.lua)
put("sa-production", {"foundry", "electromagnetic-plant", "biochamber", "cryogenic-plant", "recycler"})
put("sa-power", {"fusion-reactor", "fusion-generator", "lightning-collector"})
put("sa-mining", {"big-mining-drill"})

-- Geschuetztuerme: auf Gleba alle erlaubt, jeder mit eigener Forschung nach "Gleba entdecken"
local TURRET_TYPES = {["ammo-turret"] = true, ["electric-turret"] = true, ["fluid-turret"] = true}

local registered = {} -- key -> Liste der Gebaeude
local turrets = {} -- Gebaeude -> Prototyp

local function space_age_building(prototype)
  local path = prototype.icon or (prototype.icons and prototype.icons[1] and prototype.icons[1].icon) or ""
  return string.sub(path, 1, #"__space-age__/") == "__space-age__/"
end

function f.tech_for(entity_name, prototype)
  if TURRET_TYPES[prototype.type] and not MEMBERS[entity_name] then
    turrets[entity_name] = prototype
    return "ncs-planet-" .. entity_name .. "-build"
  end
  local key = MEMBERS[entity_name] or (space_age_building(prototype) and "sa-other" or "base-other")
  registered[key] = registered[key] or {}
  table.insert(registered[key], entity_name)
  return "ncs-planet-group-" .. key .. "-build"
end

local function add_unique(list, name)
  if not name then return end
  for _, known in pairs(list) do if known == name then return end end
  table.insert(list, name)
end

local function entity_prototype(name)
  for _, prototypes_of_type in pairs(data.raw) do
    local prototype = prototypes_of_type[name]
    if type(prototype) == "table" and prototype.collision_box then return prototype end
  end
end

-- Bild: Gebaeude gross, Planet in der Ecke (wie prototypes/variant-d.lua)
local function tech_icons(entity_name)
  local _, item = hardcore.placing_item(entity_name)
  local icons = {}
  for _, layer in pairs(hardcore.item_icons(item)) do
    local size = layer.icon_size or 64
    layer.icon_size = size
    layer.scale = (layer.scale or (32 / size)) * 4
    if layer.shift then layer.shift = {layer.shift[1] * 4, layer.shift[2] * 4} end
    table.insert(icons, layer)
  end
  table.insert(icons, {icon = "__base__/graphics/icons/nauvis.png", icon_size = 64, scale = 0.75, shift = {38, 38}})
  return icons
end

local function make_tech(tech_name, members, unit, pre, icon_entity, localised_name, order, skip_own)
  local prerequisites = {}
  for _, name in pairs(pre) do add_unique(prerequisites, name) end
  for _, ingredient in pairs(unit.ingredients) do
    local tech = hardcore.pack_tech(ingredient[1])
    if tech ~= "automation-science-pack" then add_unique(prerequisites, tech) end
  end
  local effects = {}
  for _, name in pairs(members) do
    local item_name = hardcore.placing_item(name)
    local own = item_name and hardcore.unlocking_tech(item_name)
    if own ~= tech_name and not (skip_own and skip_own[name]) then add_unique(prerequisites, own) end
    -- Schienenteile nur einmal anzeigen
    if not (string.find(name, "rail") and name ~= "straight-rail" and name ~= "elevated-straight-rail"
      and name ~= "rail-ramp") then
      table.insert(effects, {type = "nothing", effect_description = {"ncs-tech.planet-build-effect", "[entity=" .. name .. "]"}})
    end
  end
  for i = #prerequisites, 1, -1 do
    if not data.raw.technology[prerequisites[i]] then table.remove(prerequisites, i) end
  end
  data:extend({{
    type = "technology",
    name = tech_name,
    localised_name = localised_name,
    localised_description = {"ncs-tech.planet-group-description"},
    icons = tech_icons(entity_prototype(icon_entity) and icon_entity or members[1]),
    effects = effects,
    prerequisites = prerequisites,
    unit = unit,
    order = order
  }})
end

-- Nach dem Durchlauf in prototypes/variant-a.lua: Forschungen anlegen
function f.finalize()
  for index, key in pairs(ORDER) do
    local members = registered[key]
    if members then
      table.sort(members)
      local group = GROUPS[key]
      make_tech("ncs-planet-group-" .. key .. "-build", members, table.deepcopy(group.unit), group.pre, group.icon,
        {"ncs-tech.planet-build", {"ncs-tech.group-" .. key}}, "z[ncs]-q[planet-build]-" .. string.format("%02d", index), group.skip_own)
    end
  end
  for name, prototype in pairs(turrets) do
    make_tech("ncs-planet-" .. name .. "-build", {name}, unit_of(500, RGBW), {"planet-discovery-gleba"}, name,
      {"ncs-tech.planet-build", prototype.localised_name or {"entity-name." .. name}},
      "z[ncs]-q[planet-build]-06-" .. name)
  end
end

return f
