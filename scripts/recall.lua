-- Zurueck aufs Schiff ohne Raketensilo:
--   Rueckholstrahl: Nach der Forschung "Rueckholstrahl" erscheint auf Planeten ein Knopf oben links. Er holt den
--                   Spieler samt Inventar in den Hub eines Schiffs im Orbit dieses Planeten. Bei mehreren Schiffen
--                   im Orbit erscheint eine Auswahl (Mutterschiff oben, seit 1.0.12).
--   Wiedereinstieg: Wer auf einem Planeten stirbt, wacht im Hub des Mutterschiffs auf (Einstellung, Standard an).
--                   Die Leiche mit dem Inventar bleibt auf dem Planeten.
-- Das Versetzen selbst macht suit.move_to_ship (scripts/spacesuit.lua).

local mod_gui = require("mod-gui")
local suit = require("scripts.spacesuit")
local achievements = require("scripts.achievements")

local recall = {}

local TECH = "ncs-recall-beam"
local BUTTON = "ncs_recall_button"
local CHOICE = "ncs_recall_choice"       -- Auswahl-Fenster bei mehreren Schiffen im Orbit (seit 1.0.12)
local SHIP_BUTTON = "ncs_recall_ship"

-- Planet, auf dem der Spieler mit seiner Figur steht (nil auf Plattformen oder ohne Figur)
local function planet_of(player)
  if player.controller_type ~= defines.controllers.character then return nil end
  local surface = player.physical_surface
  if not surface or surface.platform then return nil end
  return surface.planet
end

local function mothership(force)
  local ship = storage.ships and storage.ships[force.index]
  if ship and ship.valid and ship.hub and ship.hub.valid then return ship end
  return nil
end

-- Alle Schiffe der Force im Orbit dieses Planeten, Mutterschiff zuerst
local function ships_in_orbit(force, planet)
  local function here(platform)
    return platform and platform.valid and platform.hub and platform.hub.valid and platform.space_location
      and platform.space_location.name == planet.name
  end
  local list = {}
  local ship = mothership(force)
  if here(ship) then table.insert(list, ship) end
  for _, platform in pairs(force.platforms) do
    if here(platform) and not (ship and platform.index == ship.index) then table.insert(list, platform) end
  end
  return list
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

local function close_choice(player)
  local frame = mod_gui.get_frame_flow(player)[CHOICE]
  if frame then frame.destroy() end
end

function recall.update_button(player)
  local tech = player.force.technologies[TECH]
  local show = tech and tech.researched and planet_of(player) ~= nil
  local button = find_button(player)
  if not show then
    if button then button.destroy() remember_button(player, nil) end
    close_choice(player)
    return
  end
  if not button then
    button = mod_gui.get_button_flow(player).add{type = "sprite-button", name = BUTTON, style = mod_gui.button_style,
      sprite = "entity/space-platform-hub", tooltip = {"ncs-recall.button"}}
    remember_button(player, button)
  end
end

function recall.update_all()
  for _, player in pairs(game.players) do
    recall.update_button(player)
  end
end

local function recall_to(player, ship)
  close_choice(player)
  if suit.move_to_ship(player, ship) then
    player.print({"ncs-recall.done", ship.name})
    achievements.on_recall(player)
  else
    player.print({"ncs-recall.failed"})
  end
  recall.update_button(player)
end

-- Mehrere Schiffe im Orbit: kleines Fenster unter den Knoepfen, ein Knopf pro Schiff.
local function open_choice(player, ships)
  close_choice(player)
  local frame = mod_gui.get_frame_flow(player).add{type = "frame", name = CHOICE, direction = "vertical",
    caption = {"ncs-recall.choose"}, style = mod_gui.frame_style}
  local mother = mothership(player.force)
  for _, ship in pairs(ships) do
    local caption = ship.name
    if mother and ship.index == mother.index then caption = {"ncs-recall.mothership", ship.name} end
    frame.add{type = "button", name = SHIP_BUTTON, caption = caption, tags = {platform = ship.index},
      tooltip = {"ncs-recall.ship-tooltip", ship.name}}.style.horizontally_stretchable = true
  end
end

function recall.on_gui_click(event)
  local element = event.element
  if not (element and element.valid) then return end
  if element.name ~= BUTTON and element.name ~= SHIP_BUTTON then return end
  local player = game.get_player(event.player_index)
  local planet = planet_of(player)
  if not planet then close_choice(player) return end
  local ships = ships_in_orbit(player.force, planet)

  if element.name == SHIP_BUTTON then
    local index = element.tags and element.tags.platform
    for _, ship in pairs(ships) do
      if ship.index == index then return recall_to(player, ship) end
    end
    player.print({"ncs-recall.left-orbit"})
    if #ships > 0 then open_choice(player, ships) else close_choice(player) end
    return
  end

  if mod_gui.get_frame_flow(player)[CHOICE] then close_choice(player) return end -- zweiter Klick schliesst
  if #ships == 0 then
    player.print({"ncs-recall.no-ship"})
  elseif #ships == 1 then
    recall_to(player, ships[1])
  else
    open_choice(player, ships)
  end
end

-- Wiedereinstieg: nach dem Tod auf einem Planeten ins Mutterschiff
function recall.on_player_respawned(event)
  if not settings.global["ncs-respawn-on-ship"].value then return end
  local player = game.get_player(event.player_index)
  if not (player and player.valid) then return end
  local planet = planet_of(player)
  if not planet then return end
  local ship = mothership(player.force)
  if not ship then return end
  if suit.move_to_ship(player, ship) then
    player.print({"ncs-recall.respawned", ship.name})
  end
  recall.update_button(player)
end

return recall
