-- Kapsel-Steuerung (jede Sekunde aus control.lua fuer alle Versorgungskapseln):
--   1. Ladung pro Planet: Die Kapsel hat kein festes Rezept. Sie bekommt die Ladung ihres Planeten (aus dessen
--      Rohstoffen), auf anderen Planeten die generische (nur Strom, langsam). Setzt das Rezept neu, wenn es nicht
--      passt (neu gebaut, nach dem Traglast-Tausch oder im GUI verstellt).
--   2. Ueberschuss an Zutaten wird zur Fracht: Die Zutaten sind oft genau das, was man hochschicken will. Die Kapsel
--      behaelt nur den Bedarf fuer KEEP_LOADS Ladungen, der Rest kommt in den Frachtraum der Rakete (die Traglast
--      begrenzt, wie viel hineinpasst).
--   3. Haekchen "Ueberschuss hochschicken" im Fenster der Kapsel (1.0.9, Wunsch des Users): ausgeschaltet bleiben
--      alle Zutaten im Zutaten-Platz (Greifarme fuellen dann nur bis zum normalen Limit). storage.capsule_keep
--      [unit_number] = true heisst ausgeschaltet; beim Traglast-Tausch uebernimmt scripts/rocket-capacity.lua es.

local surface_planet = require("scripts.surface-planet")

local capsule_cargo = {}

local KEEP_LOADS = 2

local LOAD_BY_PLANET =
{
  nauvis = "ncs-supply-capsule-load",
  vulcanus = "ncs-supply-capsule-load-vulcanus",
  gleba = "ncs-supply-capsule-load-gleba",
  fulgora = "ncs-supply-capsule-load-fulgora"
}
local GENERIC_LOAD = "ncs-supply-capsule-load-generic"

local function load_for(surface)
  return LOAD_BY_PLANET[surface_planet.name(surface)] or GENERIC_LOAD
end

local function ensure_recipe(capsule)
  local wanted = load_for(capsule.surface)
  local current = capsule.get_recipe()
  if not current or current.name ~= wanted then
    capsule.set_recipe(wanted)
  end
  return prototypes.recipe[wanted]
end

local GUI = "ncs-capsule-gui"
local CHECKBOX = "ncs-capsule-send-excess"

local function move_excess(capsule, recipe)
  if storage.capsule_keep and storage.capsule_keep[capsule.unit_number] then return end
  local input = capsule.get_inventory(defines.inventory.crafter_input)
  if not input or input.is_empty() then return end
  local rocket_inventory = capsule.get_inventory(defines.inventory.rocket_silo_rocket)
  if not rocket_inventory then return end
  local contents = input.get_contents()
  for _, ingredient in pairs(recipe.ingredients) do
    if ingredient.type == "item" then
      for _, stack in pairs(contents) do
        if stack.name == ingredient.name then
          local excess = stack.count - ingredient.amount * KEEP_LOADS
          if excess > 0 then
            local moved = rocket_inventory.insert{name = stack.name, quality = stack.quality, count = excess}
            if moved > 0 then
              input.remove{name = stack.name, quality = stack.quality, count = moved}
            end
          end
        end
      end
    end
  end
end

-- Kapseln werden gemerkt (storage.capsules), statt jede Sekunde alle Planeten zu durchsuchen (Optimierung 1.24.1).
-- Neue kommen beim Bauen dazu (capsule_cargo.add aus control.lua); alle RESCAN Ticks einmal komplett nachzaehlen,
-- falls eine per Skript (z. B. Traglast-Tausch) ohne Ereignis entstanden ist.
local RESCAN = 600

function capsule_cargo.add(entity)
  storage.capsules = storage.capsules or {}
  if entity and entity.valid and entity.unit_number then storage.capsules[entity.unit_number] = entity end
end

-- names = alle Kapsel-Namen inkl. Traglast-Varianten
function capsule_cargo.update_all(names)
  storage.capsules = storage.capsules or {}
  if game.tick >= (storage.capsules_rescan or 0) then
    storage.capsules_rescan = game.tick + RESCAN
    storage.capsules = {}
    for _, surface in pairs(game.surfaces) do
      if not surface.platform then
        for _, capsule in pairs(surface.find_entities_filtered{name = names}) do
          storage.capsules[capsule.unit_number] = capsule
        end
      end
    end
  end
  for id, capsule in pairs(storage.capsules) do
    if capsule.valid then
      move_excess(capsule, ensure_recipe(capsule))
    else
      storage.capsules[id] = nil
    end
  end
end

function capsule_cargo.is_keeping(entity)
  return storage.capsule_keep and entity.unit_number and storage.capsule_keep[entity.unit_number] or nil
end

function capsule_cargo.set_keeping(entity, keep)
  if not (entity and entity.valid and entity.unit_number) then return end
  storage.capsule_keep = storage.capsule_keep or {}
  storage.capsule_keep[entity.unit_number] = keep or nil
end

-- is_capsule(name): Kapsel oder Traglast-Variante (aus control.lua)
function capsule_cargo.on_gui_opened(event, is_capsule)
  local entity = event.entity
  if not (entity and entity.valid and is_capsule(entity.name)) then return end
  local player = game.get_player(event.player_index)
  if player.gui.relative[GUI] then player.gui.relative[GUI].destroy() end
  local frame = player.gui.relative.add{type = "frame", name = GUI, direction = "vertical", caption = {"ncs-capsule.title"},
    anchor = {gui = defines.relative_gui_type.rocket_silo_gui, position = defines.relative_gui_position.right, name = entity.name}}
  frame.add{type = "checkbox", name = CHECKBOX, caption = {"ncs-capsule.send-excess"}, tooltip = {"ncs-capsule.send-excess-tooltip"},
    state = not capsule_cargo.is_keeping(entity), tags = {unit = entity.unit_number}}
end

function capsule_cargo.on_gui_closed(event)
  local player = game.get_player(event.player_index)
  if player and player.gui.relative[GUI] then player.gui.relative[GUI].destroy() end
end

function capsule_cargo.on_gui_checked_state_changed(event)
  local element = event.element
  if not (element and element.valid and element.name == CHECKBOX) then return end
  local entity = game.get_player(event.player_index).opened
  if entity and entity.object_name == "LuaEntity" and entity.valid and entity.unit_number == element.tags.unit then capsule_cargo.set_keeping(entity, not element.state) end
end

-- Einstellungen kopieren (Shift-Rechtsklick / Shift-Linksklick) zwischen Kapseln
function capsule_cargo.on_entity_settings_pasted(event, is_capsule)
  local source, destination = event.source, event.destination
  if not (source.valid and destination.valid and is_capsule(source.name) and is_capsule(destination.name)) then return end
  capsule_cargo.set_keeping(destination, capsule_cargo.is_keeping(source))
end

return capsule_cargo
