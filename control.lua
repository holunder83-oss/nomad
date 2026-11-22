-- Nomad
-- Phase 1: Start auf einem kleinen Schiff im Nauvis-Orbit, kein Absturz.
--          Versorgungskapsel nimmt seit 1.24.1 auch Spieler mit (vorher nicht).
-- Phase 3: Spezialboeden auf dem Mutterschiff (scripts/floors.lua). Das Schiff waechst frei, ohne Masse- oder
--          Schiffslimit (beide in 1.12.0 entfernt).
-- Phase 6: Lategame, Sprungantrieb (scripts/jump-drive.lua); Rest ueber Prototypen.

local floors = require("scripts.floors")
local sources = require("scripts.sources")
local jump = require("scripts.jump-drive")
local info = require("scripts.info-gui")
local suit = require("scripts.spacesuit")
local capacity = require("scripts.rocket-capacity")
local hub_logistics = require("scripts.hub-logistics")
local hub_supply = require("scripts.hub-supply")
local rocket_ride = require("scripts.rocket-ride")
local zoom = require("scripts.zoom")
local recall = require("scripts.recall")
local boost = require("scripts.thruster-boost")
local start_research = require("scripts.start-research")
local capsule_cargo = require("scripts.capsule-cargo")
local planet_rules = require("scripts.planet-rules")
local extractor = require("scripts.extractor")
local orbital_cannon = require("scripts.orbital-cannon")
local robot_shells = require("scripts.robot-shells")
local achievements = require("scripts.achievements")
local ending = require("scripts.ending")
local start_fluids = require("scripts.start-fluids")
local tungsten_drill = require("scripts.tungsten-drill")
local surface_planet = require("scripts.surface-planet")

local SHIP_NAME = "Mutterschiff"
local STARTER_PACK = "ncs-mothership-starter-pack"
local CAPSULE = "ncs-supply-capsule"

-- Startschiff als Blueprint (Hub im Blueprint bei {0, 0}). Das Schiff waechst nach hinten (+y).
local START_SHIP_BLUEPRINT = require("scripts.start-ship-blueprint")

-- Startmaschinen im Hub, damit die erste Basis auf Nauvis schnell steht.
-- Dampfstrom: 1 Pumpe : 10 Kessel : 20 Dampfmaschinen = 18 MW, reicht fuer 100 Bohrer (je 90 kW).
local START_ITEMS = {
  {name = "electric-mining-drill", count = 100},
  {name = "offshore-pump", count = 1},
  {name = "boiler", count = 10},
  {name = "steam-engine", count = 20},
  {name = "solid-fuel", count = 200},
  {name = "solar-panel", count = 50},
  {name = "accumulator", count = 50},
  {name = "small-electric-pole", count = 100},
  {name = "medium-electric-pole", count = 200},
  {name = "assembling-machine-1", count = 100},
  {name = "steel-furnace", count = 100},
  {name = "bulk-inserter", count = 100},
  {name = "fast-inserter", count = 200},
  {name = "fast-transport-belt", count = 500},
  {name = "fast-splitter", count = 200},
  {name = "fast-underground-belt", count = 200},
  {name = "pipe", count = 100},
  {name = "pipe-to-ground", count = 50},
  {name = "cargo-landing-pad", count = 1},
  {name = "copper-ore", count = 400},
}

-- Hardcore (Variante D): Auf Planeten gibt es keinen Ofen, also keine Steinziegel fuer die Kapsel. Deshalb eine
-- Versorgungskapsel ab Start (Wunsch des Users, 1.0.9).
if settings.startup["ncs-rules-variant"].value == "hardcore" then
  table.insert(START_ITEMS, {name = CAPSULE, count = 1})
end

-- Rote Munition in den obersten Stahlkisten des Startschiffs (siehe build_ship)
local START_AMMO = {chest = "steel-chest", chests = 2, item = "piercing-rounds-magazine", count = 300}

local function get_ship(force)
  local platform = storage.ships[force.index]
  if platform and platform.valid then return platform end
  return nil
end

-- planet_name: where the ship starts, default Nauvis. A force that has its own copy of Nauvis starts above that.
local function create_ship(force, planet_name)
  local platform = force.create_space_platform{name = SHIP_NAME, planet = planet_name or "nauvis",
    starter_pack = STARTER_PACK}
  if not platform then
    log("[nomad] create_space_platform fehlgeschlagen fuer Force " .. force.name)
    return nil
  end
  platform.apply_starter_pack(true)
  storage.ships[force.index] = platform
  -- A force created after the game started has not had the start research yet (no-op for one that has)
  start_research.apply(force)
  return platform
end

-- Startschiff-Blueprint auf die Plattform setzen: zuerst das Fundament, dann die Gebaeude als Geister,
-- die sofort fertig gebaut werden. Modul-Anforderungen bleiben als Anforderung bestehen.
-- build_blueprint richtet den Blueprint an seiner Mitte aus; die Verschiebung wird ueber den Hub korrigiert.
local function build_from_blueprint(platform)
  local surface = platform.surface
  local force = platform.force
  local inventory = game.create_inventory(1)
  inventory.insert{name = "blueprint"}
  local stack = inventory[1]
  if stack.import_stack(START_SHIP_BLUEPRINT) == 1 then
    log("[nomad] Startschiff-Blueprint konnte nicht importiert werden")
    inventory.destroy()
    return
  end

  -- Lage des Hubs im Blueprint (sollte {0, 0} sein)
  local hub_position = {x = 0, y = 0}
  for _, entity in pairs(stack.get_blueprint_entities() or {}) do
    if entity.name == "space-platform-hub" then hub_position = entity.position end
  end

  -- Fundament direkt setzen
  local tiles = {}
  for _, tile in pairs(stack.get_blueprint_tiles() or {}) do
    table.insert(tiles, {name = tile.name, position = {tile.position.x - hub_position.x, tile.position.y - hub_position.y}})
  end
  surface.set_tiles(tiles, true, false, true, false)

  local function build_at(position)
    return stack.build_blueprint{surface = surface, force = force, position = position,
      build_mode = defines.build_mode.forced, skip_fog_of_war = false}
  end

  -- Probe-Bau, um die Verschiebung zu messen: jeder Geist liegt bei Blueprint-Position + Verschiebung.
  local ghosts = build_at({0, 0})
  local shift = nil
  local blueprint_entities = stack.get_blueprint_entities() or {}
  for _, ghost in pairs(ghosts) do
    if ghost.valid and ghost.type == "entity-ghost" and not shift then
      for _, entity in pairs(blueprint_entities) do
        if entity.name == ghost.ghost_name then
          shift = {x = ghost.position.x - entity.position.x, y = ghost.position.y - entity.position.y}
          break
        end
      end
    end
  end
  for _, ghost in pairs(ghosts) do
    if ghost.valid then ghost.destroy() end
  end
  shift = shift or {x = 0, y = 0}
  -- Ziel: Hub des Blueprints landet auf dem echten Hub bei {0, 0}
  local target = {x = -shift.x - hub_position.x, y = -shift.y - hub_position.y}

  -- Gebaeude bauen und sofort fertigstellen
  local built, failed = 0, 0
  for _, ghost in pairs(build_at(target)) do
    if ghost.valid and ghost.type == "entity-ghost" then
      local _, entity = ghost.revive()
      if entity then built = built + 1 else failed = failed + 1 end
    elseif ghost.valid and ghost.type == "tile-ghost" then
      ghost.destroy()
    end
  end
  log("[nomad] Startschiff gebaut: " .. built .. " Gebaeude, " .. failed .. " fehlgeschlagen, Verschiebung "
    .. serpent.line(shift))
  inventory.destroy()
end

-- Baut das Startschiff, sobald Hub und Oberflaeche existieren. Gibt true zurueck, wenn das Schiff bereit ist.
local function build_ship(platform)
  if storage.ship_built[platform.index] then return true end
  local hub = platform.hub
  local surface = platform.surface
  if not (hub and hub.valid and surface) then return false end

  build_from_blueprint(platform)
  start_fluids.seed(platform) -- Tanks und Triebwerke fuellen sich eine Sekunde spaeter (scripts/start-fluids.lua)

  -- Rote Munition in die obersten Stahlkisten (seit 1.24.1, Wunsch des Users; beim Nomad-Schiff die Munitionskisten
  -- der Geschuetze). Nach Hoehe sortiert statt fester Koordinaten, damit es auch mit einem geaenderten Schiff passt.
  local chests = surface.find_entities_filtered{name = START_AMMO.chest}
  table.sort(chests, function(a, b) return a.position.y < b.position.y end)
  for i = 1, math.min(START_AMMO.chests, #chests) do
    chests[i].insert{name = START_AMMO.item, count = START_AMMO.count}
  end

  -- Startmaschinen fuer die erste Landung im Hub ablegen
  for _, item in pairs(START_ITEMS) do
    local inserted = hub.insert(item)
    if inserted < item.count then
      log("[nomad] Startgegenstand passt nicht in den Hub: " .. item.name .. " " .. inserted .. "/" .. item.count)
    end
  end

  storage.ship_built[platform.index] = true
  return true
end

-- The planet the player stands on, as the place for a new ship (nil on a platform or a surface without a planet)
local function planet_under(player)
  local surface = player.physical_surface
  if not surface or surface.platform then return nil end
  return surface.planet and surface.planet.name or nil
end

local function send_player_to_ship(player)
  local platform = get_ship(player.force) or create_ship(player.force, planet_under(player))
  if not platform then return true end -- nichts mehr zu tun, Fehler steht im Log
  if not build_ship(platform) then return false end -- naechsten Tick nochmal versuchen

  if not player.enter_space_platform(platform) then
    log("[nomad] enter_space_platform fehlgeschlagen fuer Spieler " .. player.name)
    player.print({"ncs-message.enter-ship-failed"})
  end
  return true
end

-- Neue Spieler werden einen Tick verzoegert aufs Schiff gesetzt,
-- damit Freeplay ihnen vorher die Startgegenstaende geben kann.
local function on_tick()
  for player_index in pairs(storage.pending_players) do
    local player = game.get_player(player_index)
    if not (player and player.valid) or send_player_to_ship(player) then
      storage.pending_players[player_index] = nil
    end
  end
  if not next(storage.pending_players) then
    script.on_event(defines.events.on_tick, nil)
  end
end

local function queue_player(player_index)
  storage.pending_players[player_index] = true
  script.on_event(defines.events.on_tick, on_tick)
end

-- A mod that puts players on their force later than on_player_created switches this off (remote
-- disable_auto_player_setup) and calls setup_player once the player is on the right force.
local function on_player_created(event)
  if storage.auto_player_setup_disabled then return end
  queue_player(event.player_index)
end

-- Kapsel oder eine ihrer Traglast-Varianten (scripts/rocket-capacity.lua)
-- Seit 1.24.1 nimmt die Kapsel auch Spieler mit (Wunsch des Users: mit allen Silos hochfliegen, damit die erste
-- Landung keine Falle ist). Bis dahin warf das Skript Passagiere wieder heraus.
local function is_capsule(name)
  return capacity.base_of(name) == CAPSULE
end

local CAPSULE_NAMES = {}
for _, filter in pairs(capacity.FILTER) do
  if is_capsule(filter.name) then table.insert(CAPSULE_NAMES, filter.name) end
end

-- Kapsel startet "explosionsartig": Wenn die Rakete abhebt (Arme fahren zurueck, nach dem Zuenden),
-- Explosionen am Boden. Reiner Effekt, die Explosions-Entities machen keinen Schaden.
local BLASTS = {{"massive-explosion", 0, 0}, {"big-explosion", -1.5, 1}, {"big-explosion", 1.5, 1},
  {"big-explosion", 0, 2}, {"medium-explosion", -2, -1}, {"medium-explosion", 2, -1}}
local IGNITED =
{
  [defines.rocket_silo_status.arms_retract] = true,
  [defines.rocket_silo_status.rocket_flying] = true,
  [defines.rocket_silo_status.lights_blinking_close] = true,
  [defines.rocket_silo_status.doors_closing] = true,
  [defines.rocket_silo_status.building_rocket] = true
}

local function on_rocket_launch_ordered(event)
  local silo = event.rocket_silo
  if silo and silo.valid and is_capsule(silo.name) then
    table.insert(storage.capsule_blasts, {silo = silo, surface = silo.surface, position = silo.position,
      timeout = game.tick + 600})
  end
end

local function process_blasts()
  local blasts = storage.capsule_blasts
  if not blasts or #blasts == 0 then return end
  for i = #blasts, 1, -1 do
    local blast = blasts[i]
    local silo = blast.silo
    local ignited = not (silo and silo.valid) or IGNITED[silo.rocket_silo_status]
    if ignited or game.tick >= blast.timeout then
      if blast.surface.valid then
        for _, b in pairs(BLASTS) do
          blast.surface.create_entity{name = b[1], position = {blast.position.x + b[2], blast.position.y + b[3]}}
        end
      end
      table.remove(blasts, i)
    end
  end
end

local function init_storage()
  storage.ships = storage.ships or {}
  storage.ship_built = storage.ship_built or {}
  storage.pending_players = storage.pending_players or {}
  storage.surface_planet = storage.surface_planet or {}
  storage.capsule_blasts = storage.capsule_blasts or {}
  capacity.init()
  boost.init()
  hub_logistics.init()
  hub_supply.init()
  rocket_ride.init()
  zoom.init()
  extractor.init()
  orbital_cannon.init()
  achievements.init()
  tungsten_drill.init()
  storage.elevators = nil -- Weltraumaufzug in 1.24.0 entfernt
end

-- Bis 1.11: Teile ueber dem Masse-Limit wurden als Geister zurueckgehalten. Diese jetzt wieder platzieren
-- und die alten Daten von Masse- und Schiffslimit entfernen.
local function migrate_limits()
  for index, ghosts in pairs(storage.held_ghosts or {}) do
    local platform = nil
    for _, force in pairs(game.forces) do
      platform = platform or force.platforms[index]
    end
    if platform and platform.valid and platform.surface then
      for _, ghost in pairs(ghosts) do
        if ghost.tile then
          platform.surface.create_entity{name = "tile-ghost", inner_name = ghost.tile, position = ghost.position, force = platform.force}
        else
          platform.surface.create_entity{name = "entity-ghost", inner_name = ghost.entity, position = ghost.position,
            direction = ghost.direction, quality = ghost.quality, force = platform.force}
        end
      end
    end
  end
  storage.held_ghosts = nil
  storage.mass_warned = nil
  storage.upgrade_level = nil
  storage.final_levels = nil
end

-- Knopf "Orbitale Forschung" (vor 1.1.0) aus der GUI entfernen.
local function destroy_named(element, name)
  for _, child in pairs(element.children) do
    if child.name == name then child.destroy() else destroy_named(child, name) end
  end
end

script.on_init(function()
  init_storage()
  extractor.scan_existing()
  start_research.apply(game.forces.player)
  if remote.interfaces["freeplay"] then
    remote.call("freeplay", "set_disable_crashsite", true)
    local variant = settings.startup["ncs-rules-variant"].value
    local intro = (variant == "mining" and "ncs-message.intro-mining") or (variant == "hardcore" and "ncs-message.intro-hardcore")
      or "ncs-message.intro"
    remote.call("freeplay", "set_custom_intro_message", {intro})
  end
end)

script.on_configuration_changed(function()
  init_storage()
  migrate_limits()
  floors.migrate()
  extractor.scan_existing()
  -- Neue Freischaltungen bereits erforschter Forschungen anwenden (z. B. Fundstellen-Scanner mit "Boden-Extraktor")
  for _, force in pairs(game.forces) do
    force.reset_technology_effects()
  end
  for _, player in pairs(game.players) do
    destroy_named(player.gui.top, "ncs_pay_orbital_research")
    zoom.update(player)
  end
  suit.update_all()
  capacity.update_all()
  tungsten_drill.update_all_drills()
end)

script.on_load(function()
  if storage.pending_players and next(storage.pending_players) then
    script.on_event(defines.events.on_tick, on_tick)
  end
end)

script.on_event(defines.events.on_player_created, on_player_created)
script.on_event(defines.events.on_rocket_launch_ordered, on_rocket_launch_ordered)
script.on_event("ncs-board-rocket", function(event)
  rocket_ride.on_board(event, is_capsule)
end)

script.on_event(defines.events.on_lua_shortcut, info.on_lua_shortcut)
script.on_event(defines.events.on_player_controller_changed, function(event)
  suit.update_button(game.get_player(event.player_index))
  recall.update_button(game.get_player(event.player_index))
  zoom.update(game.get_player(event.player_index))
end)
script.on_event(defines.events.on_player_armor_inventory_changed, suit.on_player_armor_inventory_changed)
script.on_event(defines.events.on_pre_player_died, suit.on_pre_player_died)
script.on_event(defines.events.on_player_respawned, recall.on_player_respawned)
script.on_event(defines.events.on_gui_click, function(event)
  suit.on_gui_click(event)
  recall.on_gui_click(event)
  jump.on_gui_click(event)
  info.on_gui_click(event)
  extractor.on_gui_click(event)
end)
script.on_event(defines.events.on_gui_opened, function(event)
  jump.on_gui_opened(event)
  extractor.on_gui_opened(event)
  capsule_cargo.on_gui_opened(event, is_capsule)
end)
script.on_event(defines.events.on_gui_checked_state_changed, capsule_cargo.on_gui_checked_state_changed)
script.on_event(defines.events.on_entity_settings_pasted, function(event)
  capsule_cargo.on_entity_settings_pasted(event, is_capsule)
end)
script.on_event(defines.events.on_gui_closed, function(event)
  jump.on_gui_closed(event)
  extractor.on_gui_closed(event)
  capsule_cargo.on_gui_closed(event)
end)
script.on_event(defines.events.on_chunk_generated, extractor.on_chunk_generated)
script.on_event(defines.events.on_surface_created, extractor.on_surface_created)
script.on_event(defines.events.on_surface_deleted, surface_planet.on_surface_deleted)
script.on_event({defines.events.on_player_selected_area, defines.events.on_player_alt_selected_area}, function(event)
  extractor.on_player_selected_area(event)      -- Fundstellen-Scanner
  orbital_cannon.on_player_selected_area(event) -- Orbital-Fernsteuerung
end)
script.on_event(defines.events.on_object_destroyed, orbital_cannon.on_object_destroyed)

-- Bau- und Abbau-Ereignisse: Schiffs-Quellen (Lagerstaette anlegen/entfernen), Raketen-Traglast (Silo gegen
-- Stufen-Variante tauschen), Planeten-Regeln, Boden-Extraktor und Geister auf Schiffen (Hub
-- nimmt Items aus dem Spieler-Inventar).
-- Pro Ereignis gibt es nur einen Handler, deshalb gemeinsame Filter.
local function merged(lists)
  local result = {}
  for _, list in pairs(lists) do
    for _, filter in pairs(list) do table.insert(result, filter) end
  end
  return result
end
local BUILT_FILTER = merged({sources.FILTER, capacity.FILTER, planet_rules.FILTER, extractor.FILTER,
  hub_supply.FILTER, tungsten_drill.FILTER})
local PLATFORM_BUILT_FILTER = merged({sources.FILTER, tungsten_drill.FILTER})
local SOURCE_MARKER = {}
for _, filter in pairs(sources.FILTER) do SOURCE_MARKER[filter.name] = true end
-- Elektrischer Bohrer auf Wolframerz: tauschen; nach einer Schiffs-Quelle die Bohrer darueber pruefen.
-- Immer zuletzt, weil der Bohrer danach ersetzt sein kann.
local function after_built(event)
  local built = event.entity
  if not (built and built.valid) then return end
  if SOURCE_MARKER[built.name] then
    local p = built.position
    tungsten_drill.recheck_area(built.surface, {{p.x - 4, p.y - 4}, {p.x + 4, p.y + 4}})
  else
    tungsten_drill.on_built(event)
  end
end
local REMOVED_FILTER = merged({sources.FILTER, extractor.FILTER})
local function on_built(event)
  -- Zuerst die Planeten-Regel: Ein gesperrtes Gebaeude ist danach weg (entity ungueltig).
  planet_rules.on_built(event)
  if event.entity and not event.entity.valid then return end
  sources.on_built(event)
  local built = event.entity
  local capsule = built and built.valid and is_capsule(built.name)
  capacity.on_built(event)
  -- Kapsel merken; hat der Traglast-Tausch sie ersetzt, in der naechsten Sekunde neu zaehlen
  if capsule then
    if built.valid then capsule_cargo.add(built) else storage.capsules_rescan = 0 end
  end
  extractor.on_built(event)
  hub_supply.on_built(event)
  after_built(event)
end
local function on_removed(event)
  sources.on_removed(event)
  extractor.on_removed(event)
end
script.on_event(defines.events.on_space_platform_built_entity, function(event)
  sources.on_built(event)
  after_built(event)
end, PLATFORM_BUILT_FILTER)
script.on_event(defines.events.on_built_entity, on_built, BUILT_FILTER)
script.on_event(defines.events.on_robot_built_entity, on_built, BUILT_FILTER)
script.on_event(defines.events.script_raised_built, on_built, BUILT_FILTER)
script.on_event(defines.events.script_raised_revive, on_built, BUILT_FILTER)

script.on_event(defines.events.on_player_mined_entity, on_removed, REMOVED_FILTER)
script.on_event(defines.events.on_robot_mined_entity, on_removed, REMOVED_FILTER)
script.on_event(defines.events.on_space_platform_mined_entity, sources.on_removed, sources.FILTER)
script.on_event(defines.events.on_entity_died, on_removed, REMOVED_FILTER)
script.on_event(defines.events.script_raised_destroy, on_removed, REMOVED_FILTER)
script.on_event(defines.events.on_space_platform_changed_state, function(event)
  suit.check_platform(event.platform)
end)
local function on_research_changed(event)
  capacity.on_research_changed(event)
  boost.on_research_changed(event)
  for _, player in pairs(event.research.force.players) do
    suit.update_button(player)
    recall.update_button(player)
  end
  if storage.silent_research then return end -- Startforschung beim neuen Spiel
  if event.name == defines.events.on_research_finished then
    info.on_research_finished(event)
    ending.on_research_finished(event) -- "Nomade vollendet": Sieg
  else
    info.refresh(event.research.force)
  end
end
script.on_event(defines.events.on_research_finished, on_research_changed)
script.on_event(defines.events.on_research_reversed, on_research_changed)
-- Jeden Tick: Roboter-Granaten (eigener Handler, on_tick nutzt der Spielstart; kehrt sofort zurueck, wenn keine
-- Roboter unterwegs sind)
script.on_nth_tick(1, robot_shells.update)
-- Alle 5 Ticks: Kapsel-Explosionen und Triebwerk-Boost (seit 1.24.1 nicht mehr jeden Tick)
script.on_nth_tick(boost.TICKS, function(event)
  process_blasts()
  boost.on_tick(event)
end)
script.on_nth_tick(10, rocket_ride.update)
script.on_nth_tick(extractor.TICKS, extractor.on_nth_tick)
script.on_nth_tick(600, extractor.process_guarantees)
script.on_nth_tick(30, orbital_cannon.update) -- garantierte Fundstellen, sobald die Karte erzeugt ist
script.on_event(defines.events.on_trigger_created_entity, robot_shells.on_trigger_created_entity)
-- Errungenschaften
script.on_event(defines.events.on_player_changed_surface, achievements.on_player_changed_surface)
script.on_event(defines.events.on_script_trigger_effect, achievements.on_script_trigger_effect)
script.on_nth_tick(3600, achievements.check)
script.on_nth_tick(60, function(event)
  suit.check_all()
  recall.update_all()
  capacity.process_pending()
  capsule_cargo.update_all(CAPSULE_NAMES)
  -- Hub-Logistik geht alle Anforderer des Netzes durch: alle 3 s statt jede Sekunde (Optimierung 1.24.1)
  if event.tick % 180 == 0 then hub_logistics.update_all() end
  hub_supply.update_all()
  extractor.update_all()
  achievements.count_ground() -- Zeit auf Planeten fuer "Nomade"
  start_fluids.update()
  tungsten_drill.update_all() -- elektrische Bohrer auf Wolframerz nehmen Schaden
end)

-- Fuer Szenarien, andere Mods und Tests: Mutterschiff einer Force anlegen (falls noch keins existiert).
-- planet_name (optional): the planet a new ship starts above, default Nauvis.
remote.add_interface("nomad",
{
  create_mothership = function(force_name, planet_name)
    local force = game.forces[force_name or "player"]
    local platform = get_ship(force) or create_ship(force, planet_name)
    if platform then build_ship(platform) end
    return platform
  end,

  -- For mods that run several forces, each with its own ship (team mods, scenarios). None of this is needed in a
  -- normal game.
  --
  -- Nomad puts a new player on the ship of the force they have one tick after on_player_created. A mod that
  -- assigns the force later calls this once (on_init is fine, also before Nomad's own on_init) ...
  disable_auto_player_setup = function()
    storage.auto_player_setup_disabled = true
  end,
  -- ... and then this, when the player is on their force: the player goes to the force's ship. A force without a
  -- ship gets one, above the planet the player stands on (above Nauvis if they are not on a planet).
  setup_player = function(player_index)
    local player = game.get_player(player_index)
    if not (player and player.valid) then return end
    storage.pending_players = storage.pending_players or {}
    queue_player(player_index)
  end,
  -- The force starts over (its players left, the force is reused): forget its ship and what it had achieved. The
  -- ship itself is not touched; deleting it is up to the caller.
  reset_force = function(force_name)
    local force = game.forces[force_name]
    if not force then return end
    if storage.ships then storage.ships[force.index] = nil end
    achievements.reset_force(force)
    ending.reset_force(force)
  end,
  -- This surface stands for that planet: Nomad's per-planet rules (deposits, capsule load, achievements) treat
  -- it like the planet named. For a force's own copy of a planet. See scripts/surface-planet.lua.
  set_surface_planet = function(surface_index, planet_name)
    local surface = game.get_surface(surface_index)
    if not surface then return end
    if surface_planet.set(surface_index, planet_name) and storage.core_scanned then
      extractor.on_surface_planet_set(surface)
    end
  end,
  -- Lauf eines Boden-Extraktors starten (wie der Knopf im Fenster). Gibt nil oder den Grund zurueck.
  start_extractor = function(entity)
    return extractor.start(entity)
  end,
  -- Orbitalkanone auf Ziele feuern lassen (wie der Zielmarker). Gibt die Anzahl der angepeilten Ziele zurueck.
  orbital_target = function(force_name, surface_name, positions)
    return orbital_cannon.enqueue(game.forces[force_name], game.surfaces[surface_name], positions)
  end
})

commands.add_command("schiff", {"ncs-message.command-help"}, function(command)
  local player = command.player_index and game.get_player(command.player_index)
  if player then
    info.open(player)
  end
end)
