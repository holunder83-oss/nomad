-- Kapsel-Steuerung (jede Sekunde aus control.lua fuer alle Versorgungskapseln):
--   1. Ladung pro Planet: Die Kapsel hat kein festes Rezept. Sie bekommt die Ladung ihres Planeten (aus dessen
--      Rohstoffen), auf anderen Planeten die generische (nur Strom, langsam). Setzt das Rezept neu, wenn es nicht
--      passt (neu gebaut, nach dem Traglast-Tausch oder im GUI verstellt).
--   2. Ueberschuss an Zutaten wird zur Fracht: Die Zutaten sind oft genau das, was man hochschicken will. Die Kapsel
--      behielt bis 1.0.11 den Bedarf fuer 2 Ladungen (KEEP_LOADS), der Rest kommt in den Frachtraum der Rakete (die Traglast
--      begrenzt, wie viel hineinpasst).
--   3. Haekchen "Ueberschuss hochschicken" im Fenster der Kapsel (1.0.9, Wunsch des Users): ausgeschaltet bleiben
--      alle Zutaten im Zutaten-Platz (Greifarme fuellen dann nur bis zum normalen Limit). storage.capsule_keep
--      [unit_number] = true heisst ausgeschaltet; beim Traglast-Tausch uebernimmt scripts/rocket-capacity.lua es.
--   4. Seit 1.0.12 ein Haekchen pro Zutat, "Fracht zuerst" (Meldung: Kohle kam nie hoch). Headless gemessen: Ist der
--      Zutaten-Platz voll (Greifarm-Limit = 2 Ladungen), legen Greifarme den Rest selbst in den Frachtraum (deshalb kam
--      Eisenerz hoch). Kohle (40 pro Teil) wird aber so schnell verbaut, wie sie kommt, der Platz wird nie voll, und
--      ueber KEEP_LOADS blieb nie etwas. Jetzt: Eine angehakte Zutat kommt komplett in den Frachtraum, bis er voll ist
--      (Traglast); erst danach wird sie verbaut. storage.capsule_keep[unit_number] = Tabelle {[item] = true} der
--      Zutaten ohne Haekchen; true (alter Stand) = alle ohne Haekchen.
--      Gleich danach auf Wunsch des Users umgedreht: "Teile zuerst". Solange die Rakete gebaut wird, bleibt alles fuer
--      die Teile; erst wenn sie bereitsteht (rocket_silo_status = rocket_ready), kommen angehakte Zutaten in den
--      Frachtraum, bis er voll ist (die Rakete wartet auf den Startbefehl, das reicht zum Befuellen).
--      Kapsel waehrend des Baus: alles ueber 2 Ladungen geht schon hoch (= Greifarm-Limit, nimmt den Teilen also
--      nichts; holt z. B. von Hand eingelegte Kohle hoch, wenn Eisenerz fehlt und die Rakete nie fertig wird).
--   5. Raketensilo (seit 1.0.12, Wunsch des Users): gleiche Haekchen fuer die Zutaten der Raketenteile (Prozessoren,
--      Leichtbauteile, Raketentreibstoff), Standard aus (Grundspiel unveraendert), nur bei bereitstehender Rakete.
--      storage.capsule_keep[unit] gilt fuer beide: Tabelle {[item] = true (ohne Haken) / false (mit Haken)},
--      fehlt ein Item, gilt der Standard (Kapsel an, Silo aus); true (alter Stand) = alle ohne Haken.

local surface_planet = require("scripts.surface-planet")

local capsule_cargo = {}


local LOAD_BY_PLANET =
{
  nauvis = "ncs-supply-capsule-load",
  vulcanus = "ncs-supply-capsule-load-vulcanus",
  gleba = "ncs-supply-capsule-load-gleba",
  fulgora = "ncs-supply-capsule-load-fulgora",
  aquilo = "ncs-supply-capsule-load-aquilo" -- seit 1.0.12: Ammoniak-Loesung + Lithium-Sole (Rohre)
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

local KEEP_LOADS = 2 -- Kapsel waehrend des Baus

-- kind(name) aus control.lua: "capsule", "silo" oder nil (Traglast-Varianten eingeschlossen)
local kind_of = function() return nil end
function capsule_cargo.set_kind(fn) kind_of = fn end

-- Zutat ohne Haekchen (bleibt komplett fuer die Teile)?
local function is_held(entity, item)
  local keep = storage.capsule_keep and storage.capsule_keep[entity.unit_number]
  if keep == true then return true end
  if type(keep) == "table" and keep[item] ~= nil then return keep[item] == true end
  return kind_of(entity.name) == "silo"
end

local function move_excess(capsule, recipe)
  if not recipe then return end
  local unit = capsule.unit_number
  if storage.capsule_keep and storage.capsule_keep[unit] == true then return end
  local ready = capsule.rocket_silo_status == defines.rocket_silo_status.rocket_ready -- Teile zuerst
  local is_capsule = kind_of(capsule.name) == "capsule"
  if not (ready or is_capsule) then return end
  local input = capsule.get_inventory(defines.inventory.crafter_input)
  if not input or input.is_empty() then return end
  local rocket_inventory = capsule.get_inventory(defines.inventory.rocket_silo_rocket)
  if not rocket_inventory then return end
  local contents = input.get_contents()
  for _, ingredient in pairs(recipe.ingredients) do
    if ingredient.type == "item" then
      for _, stack in pairs(contents) do
        if stack.name == ingredient.name and not is_held(capsule, ingredient.name) then
          local excess = ready and stack.count or stack.count - ingredient.amount * KEEP_LOADS
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

-- names = alle Kapsel- und Silo-Namen inkl. Traglast-Varianten
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
      if kind_of(capsule.name) == "capsule" then
        move_excess(capsule, ensure_recipe(capsule))
      else
        move_excess(capsule, capsule.get_recipe())
      end
    else
      storage.capsules[id] = nil
    end
  end
end

-- Gespeicherter Stand der Haekchen (nil = Standard, true = alle aus, Tabelle = pro Zutat, siehe oben)
function capsule_cargo.is_keeping(entity)
  return storage.capsule_keep and entity.unit_number and storage.capsule_keep[entity.unit_number] or nil
end

function capsule_cargo.set_keeping(entity, keep)
  if not (entity and entity.valid and entity.unit_number) then return end
  storage.capsule_keep = storage.capsule_keep or {}
  if type(keep) == "table" then
    local copy = {}
    for item, value in pairs(keep) do copy[item] = value end
    keep = next(copy) and copy or nil
  end
  storage.capsule_keep[entity.unit_number] = keep or nil
end

function capsule_cargo.on_gui_opened(event)
  local entity = event.entity
  if not (entity and entity.valid and kind_of(entity.name)) then return end
  local is_capsule = kind_of(entity.name) == "capsule"
  local player = game.get_player(event.player_index)
  if player.gui.relative[GUI] then player.gui.relative[GUI].destroy() end
  local frame = player.gui.relative.add{type = "frame", name = GUI, direction = "vertical",
    caption = is_capsule and {"ncs-capsule.title"} or {"ncs-capsule.title-silo"},
    anchor = {gui = defines.relative_gui_type.rocket_silo_gui, position = defines.relative_gui_position.right, name = entity.name}}
  frame.add{type = "label", caption = {"ncs-capsule.send-excess"},
    tooltip = is_capsule and {"ncs-capsule.send-excess-tooltip"} or {"ncs-capsule.send-excess-tooltip-silo"}, style = "caption_label"}
  local recipe = is_capsule and ensure_recipe(entity) or entity.get_recipe()
  local any = false
  for _, ingredient in pairs(recipe and recipe.ingredients or {}) do
    local item = ingredient.type == "item" and prototypes.item[ingredient.name]
    if item then
      any = true
      frame.add{type = "checkbox", name = CHECKBOX .. "/" .. item.name, state = not is_held(entity, item.name),
        caption = {"", "[item=" .. item.name .. "] ", item.localised_name},
        tooltip = is_capsule and {"ncs-capsule.send-item-tooltip", item.localised_name, ingredient.amount}
          or {"ncs-capsule.send-item-tooltip-silo", item.localised_name},
        tags = {unit = entity.unit_number, item = item.name}}
    end
  end
  if not any then frame.add{type = "label", caption = {"ncs-capsule.no-ingredients"}} end
end

function capsule_cargo.on_gui_closed(event)
  local player = game.get_player(event.player_index)
  if player and player.gui.relative[GUI] then player.gui.relative[GUI].destroy() end
end

function capsule_cargo.on_gui_checked_state_changed(event)
  local element = event.element
  -- Ein Haekchen pro Zutat: Name "ncs-capsule-send-excess/<item>" (Namen muessen im Fenster eindeutig sein)
  if not (element and element.valid and element.type == "checkbox" and element.tags and element.tags.item
    and string.sub(element.name, 1, #CHECKBOX + 1) == CHECKBOX .. "/") then return end
  local entity = game.get_player(event.player_index).opened
  if not (entity and entity.object_name == "LuaEntity" and entity.valid and entity.unit_number == element.tags.unit) then return end
  local item = element.tags.item
  if not item then return end
  local keep = capsule_cargo.is_keeping(entity)
  local held = {}
  if keep == true then
    -- alter Stand "alles aus": jetzt einzeln, alle Zutaten ohne Haekchen
    local recipe = kind_of(entity.name) == "capsule" and ensure_recipe(entity) or entity.get_recipe()
    for _, ingredient in pairs(recipe and recipe.ingredients or {}) do held[ingredient.name] = true end
  elseif type(keep) == "table" then
    for name, value in pairs(keep) do held[name] = value end
  end
  held[item] = not element.state
  capsule_cargo.set_keeping(entity, held)
end

-- Einstellungen kopieren (Shift-Rechtsklick / Shift-Linksklick) zwischen Kapseln bzw. zwischen Silos
function capsule_cargo.on_entity_settings_pasted(event)
  local source, destination = event.source, event.destination
  if not (source.valid and destination.valid and kind_of(source.name)
    and kind_of(source.name) == kind_of(destination.name)) then return end
  capsule_cargo.set_keeping(destination, capsule_cargo.is_keeping(source))
end

return capsule_cargo
