-- Raumanzug: Nach der Forschung "Raumanzug" kann der Spieler auf dem Schiff aus dem Hub aussteigen
-- und mit einer Anzug-Figur herumlaufen, die ueber Gebaeude schwebt (Knopf oben links). Nur, solange das Schiff
-- im Orbit steht: Fliegt das Schiff los, kommen alle, die draussen sind, automatisch zurueck in den Hub.
-- Mit der Forschung "Raumanzug: Flugtauglich" (1.0.11) auch im Flug.

local mod_gui = require("mod-gui")
local achievements = require("scripts.achievements")

local suit = {}

local TECH = "ncs-spacesuit"
local FLIGHT_TECH = "ncs-spacesuit-flight" -- seit 1.0.11: auch im Flug draussen
local BUTTON = "ncs_spacesuit_button"
local SUIT_CHARACTER = "ncs-spacesuit-character" -- schwebt ueber Gebaeude (prototypes/spacesuit-character.lua)

-- Plattform, auf der der Spieler koerperlich ist (im Hub oder draussen), sonst nil.
local function physical_platform(player)
  local surface = player.physical_surface
  return surface and surface.platform
end

-- physical_controller_type: in der Fernansicht (z. B. Kartenansicht eines Planeten) ist controller_type "remote",
-- die Figur steht aber trotzdem draussen.
-- Draussen ist man immer in der Anzug-Figur (leave_hub), beim Einsteigen wird sie gegen eine normale getauscht.
-- Darauf pruefen: Im Hub ist zwar sonst physical_controller_type "god" (Log "7/2" = remote/god), im Sandkasten
-- bleibt nach enter_space_platform aber eine normale Figur im Hub stecken ("7/1" = remote/character, Log 2026-11-04),
-- und der Knopf blieb auf "Zurueck in den Hub".
local function is_outside(player)
  if player.physical_controller_type ~= defines.controllers.character then return false end
  local character = player.character
  if not (character and character.valid and character.name == SUIT_CHARACTER) then return false end
  return physical_platform(player) ~= nil
end

-- Den Spieler auf die Oberflaeche `surface` bringen, bevor er dort eine neue Figur bekommt: set_controller verlangt
-- die neue Figur auf der Oberflaeche, die der Spieler gerade ansieht (player.surface). Abstuerze in 1.24.1:
-- Aussteigen im Hub und Einsteigen im Anzug, jeweils mit offener Karte von Nauvis. Betrifft auch Rueckholstrahl und
-- Wiedereinstieg (Figur auf dem Planeten, neue Figur auf dem Schiff).
--   1. Fernansicht verlassen (exit_remote_view; geht laut API im Hub nicht).
--   2. Mit eigener Figur: Spieler samt Figur auf die Ziel-Oberflaeche teleportieren.
--   3. Ohne Figur (im Hub, Steuerung 7 = remote): Ansicht per Fernsteuerung auf die Ziel-Oberflaeche setzen.
-- Gibt true zurueck, wenn der Spieler danach die Ziel-Oberflaeche ansieht.
local function match_view(player, surface, position)
  if player.surface == surface then return true end
  if player.controller_type == defines.controllers.remote then
    pcall(function() player.exit_remote_view() end)
    if player.surface == surface then return true end
  end
  local character = player.character
  if character and character.valid and player.controller_type == defines.controllers.character then
    pcall(function() player.teleport(position, surface) end)
  else
    pcall(function() player.set_controller{type = defines.controllers.remote, surface = surface, position = position} end)
  end
  return player.surface == surface
end

-- Aussteigen/Draussenbleiben erlaubt: im Orbit immer, im Flug erst mit der Forschung "Raumanzug: Flugtauglich"
local function in_orbit(platform)
  if platform.space_location ~= nil then return true end
  local tech = platform.force.technologies[FLIGHT_TECH]
  return tech ~= nil and tech.researched
end

-- nil (kein Knopf), "inside" oder "outside"
local function state(player)
  if not physical_platform(player) then return nil end
  local tech = player.force.technologies[TECH]
  if not (tech and tech.researched) then return nil end
  return is_outside(player) and "outside" or "inside"
end

local function search_button(element)
  for _, child in pairs(element.children) do
    if child.name == BUTTON then return child end
    local found = search_button(child)
    if found then return found end
  end
  return nil
end

-- Knopf merken statt jede Sekunde die ganze obere GUI zu durchsuchen (Optimierung 1.24.1).
-- storage.gui_buttons[Spieler/Knopf]: Element, false = weiss, dass keiner da ist, nil = noch nie gesucht.
local function find_button(player)
  storage.gui_buttons = storage.gui_buttons or {}
  local key = player.index .. "/" .. BUTTON
  local button = storage.gui_buttons[key]
  if button == nil then
    button = search_button(player.gui.top) or false
    storage.gui_buttons[key] = button
  end
  if button and button.valid then return button end
  return nil
end

local function remember_button(player, button)
  storage.gui_buttons = storage.gui_buttons or {}
  storage.gui_buttons[player.index .. "/" .. BUTTON] = button or false
end

function suit.update_button(player)
  local current = state(player)
  local button = find_button(player)
  if not current then
    if button then button.destroy() remember_button(player, nil) end
    return
  end
  if not button then
    button = mod_gui.get_button_flow(player).add{type = "sprite-button", name = BUTTON, style = mod_gui.button_style}
    remember_button(player, button)
  end
  -- Nur schreiben, wenn sich etwas aendert (laeuft jede Sekunde fuer jeden Spieler)
  local sprite = current == "inside" and "entity/character" or "entity/space-platform-hub"
  if button.sprite ~= sprite then
    button.sprite = sprite
    button.tooltip = current == "inside" and {"ncs-suit.leave"} or {"ncs-suit.enter"}
  end
end

function suit.update_all()
  for _, player in pairs(game.players) do
    suit.update_button(player)
  end
end

local function describe(player)
  local character = player.character
  return "Steuerung " .. tostring(player.controller_type) .. "/" .. tostring(player.physical_controller_type)
    .. ", Figur " .. (character and (character.surface.name .. " " .. serpent.line(character.position)) or "keine")
    .. ", Position " .. serpent.line(player.physical_position) .. " auf " .. player.physical_surface.name
    .. ", Ansicht " .. player.surface.name
end

-- Inventare von einer Figur auf eine andere uebertragen.
-- Die Ruestung vergroessert das Hauptinventar: Sie wird deshalb zuerst nur kopiert (die neue Figur hat sofort
-- genug Platz) und bei der alten Figur erst am Schluss entfernt, sonst wirft das Spiel deren Rest auf den Boden.
-- set_stack behaelt Ausruestungsgitter, Bauplaene usw. bei; was nicht in den gleichen Platz passt, wird eingefuegt.
local INVENTORIES =
{
  defines.inventory.character_guns,
  defines.inventory.character_ammo,
  defines.inventory.character_main,
  defines.inventory.character_trash
}

local function move_inventories(from, to)
  local armor_from = from.get_inventory(defines.inventory.character_armor)
  local armor_to = to.get_inventory(defines.inventory.character_armor)
  if armor_from and armor_to then
    for i = 1, math.min(#armor_from, #armor_to) do
      if armor_from[i].valid_for_read and not armor_from[i].swap_stack(armor_to[i]) then armor_to[i].set_stack(armor_from[i]) end
    end
  end

  for _, id in pairs(INVENTORIES) do
    local source = from.get_inventory(id)
    local target = to.get_inventory(id)
    if source and target then
      for i = 1, #source do
        local stack = source[i]
        if stack.valid_for_read then
          -- swap_stack verschiebt das Item selbst (gleiche item_number), damit Verweise in der Schnellleiste
          -- (Blaupausen, Planer) erhalten bleiben; set_stack wuerde eine Kopie anlegen.
          if i <= #target and not target[i].valid_for_read and stack.swap_stack(target[i]) then
            -- verschoben
          elseif i <= #target and not target[i].valid_for_read and target[i].set_stack(stack) then
            stack.clear()
          else
            local inserted = target.insert(stack)
            if inserted >= stack.count then
              stack.clear()
            else
              stack.count = stack.count - inserted
            end
          end
        end
      end
      -- Was nicht passt, landet im Hauptinventar bzw. am Boden neben der Figur.
      for i = 1, #source do
        local stack = source[i]
        if stack.valid_for_read then
          local inserted = to.insert(stack)
          if inserted < stack.count then
            to.surface.spill_item_stack{position = to.position, stack = {name = stack.name, count = stack.count - inserted, quality = stack.quality.name}}
          end
          stack.clear()
        end
      end
    end
  end

  if armor_from then armor_from.clear() end
end

---------------------------------------------------------------------------
-- Anzug-Ruestungen (prototypes/spacesuit-character.lua): gleiche Ruestung, aber mit Flug.
-- Draussen traegt die Anzug-Figur die Anzug-Variante ihrer Ruestung (ohne Ruestung: "ncs-suit-none").
-- Ueberall sonst werden Anzug-Varianten sofort zurueckgetauscht, damit es den Flug nur auf dem Schiff gibt.

local SUIT_ARMOR_PREFIX = "ncs-suit-"
local NO_ARMOR = "ncs-suit-none"

local function is_suit_armor(name)
  return string.sub(name, 1, #SUIT_ARMOR_PREFIX) == SUIT_ARMOR_PREFIX
end

-- Normale Ruestung zu einer Anzug-Variante, nil bei "keine Ruestung"
local function normal_armor(name)
  if name == NO_ARMOR then return nil end
  return string.sub(name, #SUIT_ARMOR_PREFIX + 1)
end

-- Item in einem Platz austauschen, Qualitaet und Ausruestung (auch Geister, Energie, Schild) bleiben erhalten.
-- new_name nil: Platz leeren.
local function convert_stack(stack, new_name)
  if not new_name then
    stack.clear()
    return
  end
  if not prototypes.item[new_name] then return end
  local equipment = {}
  if stack.grid then
    for _, item in pairs(stack.grid.equipment) do
      local ghost = item.type == "equipment-ghost" -- ghost_name ist nur bei Geistern lesbar
      table.insert(equipment, {name = ghost and item.ghost_name or item.name, ghost = ghost, quality = item.quality.name,
        position = item.position, energy = not ghost and item.energy or nil, shield = not ghost and item.shield or nil})
    end
  end
  stack.set_stack{name = new_name, quality = stack.quality.name, count = 1}
  if stack.grid then
    for _, item in pairs(equipment) do
      local placed = stack.grid.put{name = item.name, quality = item.quality, position = item.position, ghost = item.ghost}
      if placed and not item.ghost then
        placed.energy = item.energy
        if placed.max_shield > 0 then placed.shield = item.shield end
      end
    end
  end
end

-- Ruestung der Anzug-Figur auf die Anzug-Variante setzen.
local function wear_suit_armor(character)
  local inventory = character.get_inventory(defines.inventory.character_armor)
  if not inventory then return end
  local stack = inventory[1]
  if not stack.valid_for_read then
    stack.set_stack{name = NO_ARMOR}
  elseif not is_suit_armor(stack.name) then
    convert_stack(stack, SUIT_ARMOR_PREFIX .. stack.name)
  end
end

-- Alle Anzug-Varianten einer Figur zurueck zu normalen Ruestungen (bzw. entfernen bei "keine Ruestung").
local function restore_armor(character, inventories)
  for _, id in pairs(inventories or {defines.inventory.character_armor, defines.inventory.character_main, defines.inventory.character_trash}) do
    local inventory = character.get_inventory(id)
    if inventory then
      for i = 1, #inventory do
        local stack = inventory[i]
        if stack.valid_for_read and is_suit_armor(stack.name) then
          convert_stack(stack, normal_armor(stack.name))
        end
      end
    end
  end
end

---------------------------------------------------------------------------

-- Freies Feld neben dem Hub (fuer eine normale Spielfigur, also nicht auf Gebaeuden).
local function free_spot(platform)
  local center = platform.hub and platform.hub.valid and platform.hub.position or {x = 0, y = 0}
  return platform.surface.find_non_colliding_position("character", center, 40, 0.5)
end

-- Boni der Figur (von Mods gesetzt) auf die neue Figur uebernehmen. Laufgeschwindigkeit nicht: Mods wie
-- nb1-simple-bot-start binden sie an die Ruestung und setzen sie beim Ruestungswechsel selbst neu (sonst doppelt).
local BONUSES = {"character_crafting_speed_modifier", "character_mining_speed_modifier",
  "character_build_distance_bonus", "character_item_drop_distance_bonus", "character_reach_distance_bonus",
  "character_resource_reach_distance_bonus", "character_item_pickup_distance_bonus",
  "character_loot_pickup_distance_bonus", "character_inventory_slots_bonus", "character_trash_slot_count_bonus",
  "character_maximum_following_robot_count_bonus", "character_health_bonus"}

local function copy_bonuses(from, to)
  for _, key in pairs(BONUSES) do
    pcall(function() to[key] = from[key] end)
  end
end

-- Schnellleisten-Plaetze, die auf ein bestimmtes Item zeigen (Blaupause, Buch, Planer), mit item_number merken.
local QUICKBAR_PAGES, QUICKBAR_SLOTS = 10, 10

local function remember_quickbar(player)
  local refs = {}
  for page = 1, QUICKBAR_PAGES do
    for slot = 1, QUICKBAR_SLOTS do
      local ok, entry = pcall(player.get_quick_bar_slot, page, slot)
      if ok and entry and entry.type == "item" and entry.item and entry.item.valid and entry.item.item_number then
        table.insert(refs, {page = page, slot = slot, number = entry.item.item_number})
      end
    end
  end
  return refs
end

-- Nach dem Umzug wieder auf dieselben Items zeigen (swap_stack behaelt die item_number).
local function restore_quickbar(player, character, refs)
  if #refs == 0 then return end
  local stacks = {}
  for _, id in pairs({defines.inventory.character_main, defines.inventory.character_trash}) do
    local inventory = character.get_inventory(id)
    if inventory then
      for i = 1, #inventory do
        local stack = inventory[i]
        if stack.valid_for_read and stack.item and stack.item.item_number then stacks[stack.item.item_number] = stack end
      end
    end
  end
  for _, ref in pairs(refs) do
    local stack = stacks[ref.number]
    if stack then pcall(player.set_quick_bar_slot, ref.page, ref.slot, stack) end
  end
end

-- Spielfigur des Spielers gegen eine neue Figur des Typs `name` an `position` tauschen, Inventar uebertragen.
-- Die alte Figur (z. B. die im Hub eingelagerte, die sich nicht versetzen laesst) wird danach entfernt.
-- Gibt false zurueck, wenn die neue Figur nicht erzeugt werden konnte.
local function swap_character(player, surface, position, name)
  if not match_view(player, surface, position) then
    log("[nomad] Raumanzug: Ansicht nicht auf " .. surface.name .. " fuer " .. player.name .. ": " .. describe(player))
    return false
  end
  local old = player.character
  local new = surface.create_entity{name = name, position = position, force = player.force,
    direction = old and old.valid and old.direction or nil}
  if not new then return false end
  new.color = player.color
  local quickbar = remember_quickbar(player)
  if old and old.valid then copy_bonuses(old, new) end
  player.set_controller{type = defines.controllers.character, character = new}
  -- Inventar erst nach dem Wechsel: Dann meldet die Engine den Ruestungswechsel der neuen Figur, und Mods mit
  -- Boni an der Ruestung (z. B. Laufgeschwindigkeit von nb1-simple-bot-start) setzen sie dort neu.
  if old and old.valid then
    move_inventories(old, new)
  end
  restore_quickbar(player, new, quickbar)
  if old and old.valid then old.destroy() end
  return true
end

-- Aussteigen: Im Hub steckt die Spielfigur mitten im Hub-Gebaeude (Steuerung "im Hub") und laesst sich nicht
-- versetzen. Deshalb kommt eine Anzug-Figur neben den Hub; sie schwebt ueber Gebaeude.
local function leave_hub(player, platform)
  log("[nomad] Raumanzug: " .. player.name .. " vor dem Aussteigen: " .. describe(player))
  local position = free_spot(platform)
  if not (position and swap_character(player, platform.surface, position, SUIT_CHARACTER)) then
    player.print({"ncs-suit.no-space"})
    return
  end
  wear_suit_armor(player.character)
  log("[nomad] Raumanzug: " .. player.name .. " nach dem Aussteigen: " .. describe(player))
  achievements.on_spacewalk(player)
end

-- Einsteigen: Anzug-Figur zuerst gegen eine normale tauschen, damit man damit spaeter normal landet.
local function enter_hub(player, platform)
  local character = player.character
  if character and character.valid and character.name == SUIT_CHARACTER then
    restore_armor(character)
    local position = free_spot(platform) or character.position
    if not swap_character(player, platform.surface, position, "character") then
      log("[nomad] Raumanzug: normale Figur konnte nicht erzeugt werden fuer " .. player.name)
    end
  end
  if not player.enter_space_platform(platform) then
    log("[nomad] Raumanzug: enter_space_platform fehlgeschlagen fuer " .. player.name .. ": " .. describe(player))
  else
    log("[nomad] Raumanzug: " .. player.name .. " zurueck im Hub: " .. describe(player))
  end
end

-- Spieler von einem Planeten (oder sonstwo) in den Hub einer Plattform holen (Rueckholstrahl, Wiedereinstieg):
-- erst eine normale Figur neben dem Hub, Inventar mitnehmen, dann wie beim Einsteigen in den Hub.
-- Gibt true zurueck, wenn der Spieler danach im Hub ist.
function suit.move_to_ship(player, platform)
  if not (platform and platform.valid and platform.surface and platform.hub and platform.hub.valid) then return false end
  if player.vehicle then player.driving = false end
  local character = player.character
  if character and character.valid and character.name == SUIT_CHARACTER then restore_armor(character) end
  local position = free_spot(platform)
  if not (position and swap_character(player, platform.surface, position, "character")) then
    log("[nomad] Zum Schiff: keine Figur auf " .. platform.name .. " fuer " .. player.name .. ": " .. describe(player))
    return false
  end
  if not player.enter_space_platform(platform) then
    log("[nomad] Zum Schiff: enter_space_platform fehlgeschlagen fuer " .. player.name .. ": " .. describe(player))
    return false
  end
  suit.update_button(player)
  return true
end

function suit.on_gui_click(event)
  local element = event.element
  if not (element and element.valid and element.name == BUTTON) then return end
  local player = game.get_player(event.player_index)
  local platform = physical_platform(player)
  if not platform then return end

  local current = state(player)
  if current == "inside" then
    if not in_orbit(platform) then
      player.print({"ncs-suit.not-in-flight"})
      return
    end
    leave_hub(player, platform)
  elseif current == "outside" then
    enter_hub(player, platform)
  end
  suit.update_button(player)
end

-- Fliegt ein Schiff los, alle draussen zurueck in den Hub.
function suit.check_platform(platform)
  if not (platform and platform.valid) or in_orbit(platform) then return end
  for _, player in pairs(platform.force.players) do
    if is_outside(player) and physical_platform(player).index == platform.index then
      enter_hub(player, platform)
      player.print({"ncs-suit.back-in-hub"})
      suit.update_button(player)
    end
  end
end

-- Regelmaessig: Knoepfe aktuell halten und niemanden im Flug draussen lassen.
-- Absicherung: Eine Anzug-Figur ausserhalb eines Schiffs wird gegen eine normale getauscht.
function suit.check_all()
  for _, player in pairs(game.players) do
    local character = player.character
    if character and character.valid and character.name == SUIT_CHARACTER and not character.surface.platform then
      restore_armor(character)
      local position = character.surface.find_non_colliding_position("character", character.position, 40, 0.5)
      if position then swap_character(player, character.surface, position, "character") end
    elseif character and character.valid and character.name ~= SUIT_CHARACTER then
      restore_armor(character, {defines.inventory.character_armor})
    end
    local platform = physical_platform(player)
    if platform and is_outside(player) and not in_orbit(platform) then
      suit.check_platform(platform)
    end
    suit.update_button(player)
  end
end

-- Ruestung gewechselt: Die Anzug-Figur traegt immer eine Anzug-Variante (eine abgelegte Variante wird wieder normal),
-- jede andere Figur nie.
function suit.on_player_armor_inventory_changed(event)
  local player = game.get_player(event.player_index)
  local character = player and player.character
  if not (character and character.valid) then return end
  if character.name == SUIT_CHARACTER then
    restore_armor(character, {defines.inventory.character_main, defines.inventory.character_trash})
    wear_suit_armor(character)
  else
    restore_armor(character)
  end
end

-- Vor dem Tod: Anzug-Varianten zurueck, damit in der Leiche normale Ruestungen liegen.
function suit.on_pre_player_died(event)
  local player = game.get_player(event.player_index)
  local character = player and player.character
  if character and character.valid and character.name == SUIT_CHARACTER then
    restore_armor(character)
  end
end

return suit
