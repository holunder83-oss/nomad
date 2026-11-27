-- Startforschung (seit 1.19.0): Beim neuen Spiel ist alles erforscht, was man auf Nauvis gebraucht haette, um
-- genau dieses Startschiff zu bauen und loszufliegen, und nur das. Berechnet aus dem Startschiff-Blueprint:
-- Forschungen, die die Rezepte seiner Gebaeude und Boeden freischalten, plus "Raumplattform", jeweils mit allen
-- Voraussetzungen. (Aktuell 40 Forschungen: Rot/Gruen/Blau bis Raketensilo, Weltraum-Science, Plattform, Triebwerk.)

local BLUEPRINT = require("scripts.start-ship-blueprint")

local start_research = {}

-- Vulcanus, Fulgora und Gleba seit 1.24.1 ab Start entdeckt (Wunsch des Users)
local EXTRA = {"space-platform", "planet-discovery-vulcanus", "planet-discovery-fulgora", "planet-discovery-gleba"}
-- Super-Hardcore (1.0.16, Wunsch des Users): nur Nauvis, die anderen Planeten muss man selbst entdecken
-- (ebenso in Variante F "Super-Duper-Hardcore")
local variant = settings.startup["ncs-rules-variant"].value
if variant == "super-hardcore" or variant == "super-duper-hardcore" then EXTRA = {"space-platform"} end
-- Rezepte, die zusaetzlich ab Start gehen sollen (ihre Forschung samt Voraussetzungen wird erforscht).
-- Rote Munition seit 1.24.1 (Wunsch des Users, fuer die Geschuetze auf dem Startschiff).
local EXTRA_RECIPES = {"piercing-rounds-magazine"}

-- Namen aller Gebaeude und Boeden im Startschiff-Blueprint
local function blueprint_names()
  local names = {}
  local inventory = game.create_inventory(1)
  inventory.insert{name = "blueprint"}
  local stack = inventory[1]
  if stack.import_stack(BLUEPRINT) ~= 1 then
    for _, entity in pairs(stack.get_blueprint_entities() or {}) do names[entity.name] = true end
    for _, tile in pairs(stack.get_blueprint_tiles() or {}) do names[tile.name] = true end
  end
  inventory.destroy()
  return names
end

-- Forschungen inkl. aller Voraussetzungen
function start_research.technologies(force)
  local unlocked_by = {}
  for name, tech in pairs(force.technologies) do
    for _, effect in pairs(tech.prototype.effects) do
      if effect.type == "unlock-recipe" then
        unlocked_by[effect.recipe] = unlocked_by[effect.recipe] or {}
        table.insert(unlocked_by[effect.recipe], name)
      end
    end
  end

  local queue = {}
  for name in pairs(blueprint_names()) do
    for _, tech in pairs(unlocked_by[name] or {}) do table.insert(queue, tech) end
  end
  for _, tech in pairs(EXTRA) do table.insert(queue, tech) end
  for _, recipe in pairs(EXTRA_RECIPES) do
    for _, tech in pairs(unlocked_by[recipe] or {}) do table.insert(queue, tech) end
  end

  local result = {}
  while #queue > 0 do
    local name = table.remove(queue)
    local tech = force.technologies[name]
    if tech and not result[name] then
      result[name] = tech
      for prerequisite in pairs(tech.prerequisites) do table.insert(queue, prerequisite) end
    end
  end
  return result
end

-- Beim neuen Spiel fuer die Spieler-Force. Waehrenddessen keine Chat-Hinweise zu neuen Upgrades (storage.silent_research).
function start_research.apply(force)
  storage.silent_research = true
  local count = 0
  for _, tech in pairs(start_research.technologies(force)) do
    if not tech.researched then
      tech.researched = true
      count = count + 1
    end
  end
  storage.silent_research = nil
  log("[nomad] Startforschung: " .. count .. " Forschungen erforscht")
end

return start_research
