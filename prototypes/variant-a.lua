-- Phase 7, Variante A (Standard): Auf Planeten wird nur abgebaut, verarbeitet wird auf dem Schiff.
--   1. Auf Planeten: Abbau, Logistik, Strom, Verteidigung, Zuege, Schaltungen, Roboter, Raketensilo, Landefeld und
--      seit 1.22.0 einfache Fabriken (Assembler 1+2, Stein-/Stahlofen, Chemieanlage, Raffinerie). Alle anderen
--      Fabriken aus Grundspiel und Space Age erst per Forschung ("Planeten-Fabriken" bzw. spaet
--      "Planeten-Industrie"), durchgesetzt von scripts/planet-rules.lua. Gebaeude, die nur im All oder nur auf
--      Planeten stehen koennen, und Gebaeude aus Planeten-Mods bleiben unveraendert.
--   2. Rezepte, die an einen Planeten gebunden sind (Planeten-Science, Giesserei, Biokammer, EM-Anlage,
--      Kryo-Anlage, Fusion, Bakterien ..., auch von Mod-Planeten), gehen auch im All.
--   3. Aquilo hat nur Fluessigkeiten, die sich nicht abfuellen lassen. Die Forschungen fuer Ammoniak-Becken,
--      Lithium- und Fluor-Quelle gibt es deshalb schon ab der Entdeckung von Aquilo, ohne Kryo-Pack.
--   (Die Abfuellstation gab es bis 1.24.0; seit Assembler 2 auf Planeten erlaubt ist (1.22.0), war sie ueberfluessig.
--    Alte Stationen werden zu Assembler 2: migrations/1.24.1-barrel-station.json.)
--   (Die Kapselladung aus Rohstoffen gilt seit 1.21.0 in allen Varianten: prototypes/supply-capsule.lua.)
-- Laeuft in data-final-fixes, damit alle Prototypen fertig sind.

-- Variante D "Hardcore" (seit 1.0.5) nutzt denselben Code: keine einfachen Fabriken ab Start, jedes Gebaeude mit
-- eigener Forschung (prototypes/variant-d.lua).
-- Variante E "Super-Hardcore" (1.0.16): wie D, aber auf Planeten ab Start nur die Grundausstattung (SUPER_ALWAYS),
-- jedes andere Gebaeude (auch Logistik, Strom, Verteidigung) mit eigener Forschung ab Rot.
local variant = settings.startup["ncs-rules-variant"].value
-- Variante F "Super-Duper-Hardcore" (1.0.16): Grundausstattung wie E, sonst Paket-Forschungen (prototypes/variant-f.lua)
if variant ~= "mining" and variant ~= "hardcore" and variant ~= "super-hardcore" and variant ~= "super-duper-hardcore" then
  return
end
local super = variant == "super-hardcore" or variant == "super-duper-hardcore"
local hardcore
if variant == "super-duper-hardcore" then
  hardcore = require("prototypes.variant-f")
elseif variant == "hardcore" or super then
  hardcore = require("prototypes.variant-d")
  if super then hardcore.super = true end
end

local surface_util = require("prototypes.surface-util")
local costs = require("prototypes.upgrade-costs")

---------------------------------------------------------------------------
-- 1. Gebaeude auf Planeten

-- Typen, die auf Planeten erlaubt bleiben
local PLANET_TYPES = {}
for _, type_name in pairs(
{
  -- Abbau
  "mining-drill", "offshore-pump", "agricultural-tower",
  -- Logistik
  "transport-belt", "underground-belt", "splitter", "lane-splitter", "loader", "loader-1x1", "linked-belt",
  "inserter", "container", "logistic-container", "linked-container", "infinity-container", "proxy-container",
  "pipe", "pipe-to-ground", "pump", "storage-tank", "valve", "infinity-pipe",
  "roboport", "construction-robot", "logistic-robot",
  -- Strom und Waerme
  "electric-pole", "power-switch", "boiler", "generator", "burner-generator", "solar-panel", "accumulator",
  "reactor", "heat-pipe", "heat-interface", "fusion-reactor", "fusion-generator", "lightning-attractor",
  "electric-energy-interface",
  -- Verteidigung
  "turret", "ammo-turret", "electric-turret", "fluid-turret", "artillery-turret", "wall", "gate", "land-mine",
  "radar",
  -- Zuege und Fahrzeuge
  "straight-rail", "curved-rail-a", "curved-rail-b", "half-diagonal-rail", "legacy-straight-rail",
  "legacy-curved-rail", "elevated-straight-rail", "elevated-curved-rail-a", "elevated-curved-rail-b",
  "elevated-half-diagonal-rail", "rail-ramp", "rail-support", "rail-signal", "rail-chain-signal", "train-stop",
  "locomotive", "cargo-wagon", "fluid-wagon", "artillery-wagon", "infinity-cargo-wagon", "car", "spider-vehicle",
  -- Schaltungen
  "arithmetic-combinator", "decider-combinator", "constant-combinator", "selector-combinator",
  "programmable-speaker", "lamp", "display-panel", "simple-entity-with-owner", "simple-entity-with-force",
  -- Verbindung zum Schiff
  "rocket-silo", "cargo-landing-pad", "cargo-bay",
  -- Labore regelt prototypes/lab-rules.lua
  "lab",
  -- Pflanzen (Agrarturm auf Gleba muss weiter pflanzen koennen)
  "plant", "tree"
}) do
  PLANET_TYPES[type_name] = true
end

-- Nur Grundspiel und Space Age. Gebaeude aus Planeten-Mods bleiben auf ihren Planeten erlaubt.
local VANILLA_MODS = {"base", "space-age", "quality", "elevated-rails", "recycler"}

local function icon_path(prototype)
  if prototype.icon then return prototype.icon end
  if prototype.icons and prototype.icons[1] then return prototype.icons[1].icon end
  return nil
end

local function from_vanilla(prototype)
  local path = icon_path(prototype)
  if not path then return false end
  for _, mod_name in pairs(VANILLA_MODS) do
    local prefix = "__" .. mod_name .. "__/"
    if string.sub(path, 1, #prefix) == prefix then return true end
  end
  return false
end

-- Alle Entities, die ein Item platziert
local placed = {}
for _, prototypes_of_type in pairs(data.raw) do
  for _, prototype in pairs(prototypes_of_type) do
    if type(prototype) == "table" and prototype.place_result then
      placed[prototype.place_result] = true
    end
    -- Schienen baut der Schienenplaner
    if type(prototype) == "table" and prototype.type == "rail-planner" then
      for _, rail in pairs(prototype.rails or {}) do placed[rail] = true end
    end
  end
end

local function planet_value(planet, property)
  local value = planet.surface_properties and planet.surface_properties[property]
  if value ~= nil then return value end
  local definition = data.raw["surface-property"] and data.raw["surface-property"][property]
  return definition and definition.default_value or 0
end

local function planet_allows(planet, conditions)
  for _, condition in pairs(conditions) do
    local value = planet_value(planet, condition.property)
    if (condition.min and value < condition.min) or (condition.max and value > condition.max) then
      return false
    end
  end
  return true
end

local function on_some_planet(conditions)
  for _, planet in pairs(data.raw.planet) do
    if planet_allows(planet, conditions or {}) then return true end
  end
  return false
end

-- Einfache Fabriken (seit 1.22.0): immer auf Planeten erlaubt.
local ALWAYS =
{
  ["assembling-machine-1"] = true, ["assembling-machine-2"] = true,
  ["stone-furnace"] = true, ["steel-furnace"] = true,
  ["chemical-plant"] = true, ["oil-refinery"] = true
}
if hardcore then ALWAYS = {} end
-- Super-Hardcore: Grundausstattung (Wunsch des Users). Versorgungskapsel und kleines MG-Geschuetz sind ncs-Gebaeude
-- und deshalb ohnehin nicht gesperrt.
local SUPER_ALWAYS =
{
  ["solar-panel"] = true, ["electric-mining-drill"] = true, ["burner-mining-drill"] = true,
  ["small-electric-pole"] = true, ["transport-belt"] = true, ["burner-inserter"] = true,
  ["wooden-chest"] = true, ["cargo-landing-pad"] = true
}
if super then ALWAYS = SUPER_ALWAYS end
-- Super-Duper-Hardcore: zusaetzlich Raketensilo und die Anbauten des Frachtlandeplatzes (Frachtraum,
-- Landeplatz-Entladeraum) ab Start (Wunsch des Users)
if variant == "super-duper-hardcore" then
  ALWAYS = table.deepcopy(SUPER_ALWAYS)
  ALWAYS["rocket-silo"] = true
  ALWAYS["cargo-bay"] = true
  ALWAYS["landing-pad-unloading-bay"] = true
end
-- Typen, die in Super-Hardcore trotzdem nie gesperrt werden: Labore (prototypes/lab-rules.lua), Pflanzen
local SUPER_FREE_TYPES = {lab = true, plant = true, tree = true, ["construction-robot"] = true,
  ["logistic-robot"] = true}
-- Alle anderen Fabriken duerfen per Forschung auf Planeten: Grundspiel-Gebaeude mit "Planeten-Fabriken",
-- Space-Age-Gebaeude erst spaet mit "Planeten-Industrie". Ob ein Gebaeude auf einer Oberflaeche stehen darf, laesst
-- sich nicht an eine Forschung knuepfen; scripts/planet-rules.lua entfernt deshalb gesperrte Gebaeude beim Bauen.
local TECH_BASE = "ncs-planet-factories"
local TECH_SPACE_AGE = "ncs-planet-industry"

-- Mit T.H.U.D (seit 1.0.15): T.H.U.D nimmt Triebwerk, Asteroidensammler, Brecher usw. die Bedingungen ab und merkt
-- sie in mod-data "thud-surface-conditions". Ohne diese Liste galten sie als planetentauglich und bekamen in
-- Hardcore je eine Forschung "Planetenbau: Triebwerk". Deshalb zaehlen die urspruenglichen Bedingungen; was nur
-- ins All darf, bleibt unveraendert (auf Planetenboden legt T.H.U.D es still).
local thud_mod_data = mods["Thud"] and data.raw["mod-data"] and data.raw["mod-data"]["thud-surface-conditions"]
local thud_conditions = thud_mod_data and thud_mod_data.data or {}
-- Den Brecher macht T.H.U.D ohne Eintrag in der Liste ueberall baubar (data/crusher/crusher.lua); im Grundspiel
-- nur im All (Schwerkraft 0).
local THUD_UNRECORDED = {crusher = {{property = "gravity", min = 0, max = 0}}}
local function original_conditions(name, prototype)
  if prototype.surface_conditions then return prototype.surface_conditions end
  if mods["Thud"] then return thud_conditions[name] or THUD_UNRECORDED[name] end
end

local gated, gated_log, skipped = {}, {}, {}
for type_name, prototypes_of_type in pairs(data.raw) do
  if (super and not SUPER_FREE_TYPES[type_name]) or (not super and not PLANET_TYPES[type_name]) then
    for name, prototype in pairs(prototypes_of_type) do
      -- collision_box: nur echte Gebaeude, nicht gleichnamige Items, Rezepte oder Technologien
      if type(prototype) == "table" and placed[name] and prototype.type == type_name and prototype.collision_box
        and string.sub(name, 1, 4) ~= "ncs-" and string.sub(name, 1, 5) ~= "thud-"
        and from_vanilla(prototype) and not ALWAYS[name] and (not super or hardcore.craftable(name)) then
        local conditions = original_conditions(name, prototype)
        -- Super-Hardcore sperrt auch Gebaeude, die nur auf Planeten stehen (Raketensilo, Agrarturm ...)
        if on_some_planet(conditions) and (super or surface_util.allowed_in_space(conditions)) then
          if hardcore then
            gated[name] = hardcore.tech_for(name, prototype)
          else
            local base_game = string.sub(icon_path(prototype), 1, #"__base__/") == "__base__/"
            gated[name] = base_game and TECH_BASE or TECH_SPACE_AGE
          end
          table.insert(gated_log, name .. "=" .. gated[name])
        else
          table.insert(skipped, name) -- kann nur ins All oder nur auf Planeten, bleibt wie im Grundspiel
        end
      end
    end
  end
end

if hardcore and hardcore.finalize then hardcore.finalize() end

table.sort(gated_log)
table.sort(skipped)
log("[nomad] Variante A, auf Planeten erst per Forschung: " .. table.concat(gated_log, ", "))
log("[nomad] Variante A, unveraendert: " .. table.concat(skipped, ", "))

local factories_ingredients =
{
  {"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1},
  {"production-science-pack", 1}, {"utility-science-pack", 1}, {"space-science-pack", 1}
}
local industry_unit = costs.unit("cryogenic-science-pack")
industry_unit.count = 20000

data:extend({{type = "mod-data", name = "ncs-planet-rules", data = {gated = gated}}})
if not hardcore then
data:extend(
{
  {
    type = "technology",
    name = TECH_BASE,
    icon = "__base__/graphics/technology/automation-3.png",
    icon_size = 256,
    effects = {{type = "nothing", effect_description = {"ncs-tech.planet-factories"}}},
    prerequisites = {"production-science-pack", "utility-science-pack", "space-science-pack"},
    unit = {count = 10000, ingredients = factories_ingredients, time = 60},
    order = "z[ncs]-p[planet-factories]"
  },
  {
    type = "technology",
    name = TECH_SPACE_AGE,
    icon = "__space-age__/graphics/technology/foundry.png",
    icon_size = 256,
    effects = {{type = "nothing", effect_description = {"ncs-tech.planet-industry"}}},
    prerequisites = {TECH_BASE, "cryogenic-science-pack"},
    unit = industry_unit,
    order = "z[ncs]-p[planet-industry]"
  }
})
end

---------------------------------------------------------------------------
-- 2. Planetengebundene Rezepte auch im All

-- Gebunden = im All nicht erlaubt, aber auf einem Planeten (auch Mod-Planeten, seit 1.16.0: z. B. Cerys-Science
-- und Cerys-Labor waeren sonst blockiert, weil Assembler auf Cerys nicht mehr stehen duerfen). Reine Weltraum-Rezepte
-- und Rezepte, die nirgends gehen, bleiben so.
local function bound_to_planet(conditions)
  if surface_util.allowed_in_space(conditions) then return false end
  for _, planet in pairs(data.raw.planet) do
    if planet_allows(planet, conditions) then return true end
  end
  return false
end

local freed = {}
for name, recipe in pairs(data.raw.recipe) do
  if recipe.surface_conditions and bound_to_planet(recipe.surface_conditions) then
    recipe.surface_conditions = nil
    table.insert(freed, name)
  end
end
table.sort(freed)
log("[nomad] Variante A, Rezepte jetzt auch im All: " .. table.concat(freed, ", "))

local living_metal = data.raw.item["ncs-living-metal"]
if living_metal then
  living_metal.localised_description = {"item-description.ncs-living-metal-anywhere"}
end
if data.raw.technology["ncs-living-metal"] then
  data.raw.technology["ncs-living-metal"].localised_description = {"technology-description.ncs-living-metal-anywhere"}
end

---------------------------------------------------------------------------
-- 3. Aquilo: ab Entdeckung, ohne Aquilo-Zutaten

-- (Die Extraktor-Laeufe fuer Aquilo brauchen seit 1.24.0 ohnehin keine Aquilo-Zutaten, scripts/extractor-config.lua.)
for _, name in pairs({"ncs-ammonia-zone", "ncs-lithium-source", "ncs-fluorine-source"}) do
  local aquilo_tech = data.raw.technology[name]
  if aquilo_tech and data.raw.technology["planet-discovery-aquilo"] then
    aquilo_tech.prerequisites = {"planet-discovery-aquilo", "ncs-extractor"}
    local unit = costs.unit("cryogenic-science-pack")
    for i = #unit.ingredients, 1, -1 do
      if unit.ingredients[i][1] == "cryogenic-science-pack" then table.remove(unit.ingredients, i) end
    end
    aquilo_tech.unit = unit
  end
end
