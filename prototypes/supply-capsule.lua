-- Versorgungskapsel: kleines, fruehes Raketensilo auf Planeten.
-- Schiesst kleine Ladungen zum Schiff im Orbit, langsam und teuer.
-- Nimmt seit 1.24.1 auch Spieler mit (vorher verhinderte control.lua das). Das Raketensilo ist das Upgrade.
-- Zahlen sind vorlaeufig und werden beim Testen festgelegt.

local icons = {{icon = "__base__/graphics/icons/rocket-silo.png", tint = {r = 0.6, g = 0.85, b = 1}}}

---------------------------------------------------------------------------
-- Kleiner als das Raketensilo (seit 1.20.0): Grafik und Positionen von Silo und Rakete auf SCALE verkleinert.

local SCALE = 4 / 9 -- 9x9 -> 4x4 Felder
local SPEED = 4     -- Tueren und Lichter: viermal so schnell ("einfach was ins All ballern")
local ROCKET_SPEED = 8 -- Aufstieg und Triebwerksstart der Rakete
local ROCKET_ACCELERATION = 10 -- Beschleunigung beim Wegfliegen

local function scale_vector(v, k)
  if type(v) ~= "table" then return v end
  if v.x then return {x = v.x * k, y = v.y * k} end
  return {(v[1] or 0) * k, (v[2] or 0) * k}
end

-- Alle Sprites/Animationen in einer Tabelle verkleinern (scale und shift), rekursiv.
local function scale_graphics(t, k, seen)
  if type(t) ~= "table" then return end
  seen = seen or {}
  if seen[t] then return end
  seen[t] = true
  if t.filename or t.filenames or t.stripes then
    t.scale = (t.scale or 1) * k
    if t.shift then t.shift = scale_vector(t.shift, k) end
  end
  for key, value in pairs(t) do
    if type(value) == "table" and key ~= "shift" then scale_graphics(value, k, seen) end
  end
end

local function scale_box(box, k)
  return {scale_vector(box[1], k), scale_vector(box[2], k)}
end

local function scale_keys(t, keys, k)
  for _, key in pairs(keys) do
    local value = t[key]
    if type(value) == "number" then t[key] = value * k
    elseif type(value) == "table" then t[key] = scale_vector(value, k) end
  end
end

-- Rakete: kleiner und schneller
local rocket = table.deepcopy(data.raw["rocket-silo-rocket"]["rocket-silo-rocket"])
rocket.name = "ncs-supply-capsule-rocket"
scale_graphics(rocket, SCALE)
rocket.collision_box = scale_box(rocket.collision_box, SCALE)
scale_keys(rocket, {"rocket_initial_offset", "rocket_rise_offset", "cargo_attachment_offset",
  "rocket_render_layer_switch_distance", "full_render_layer_switch_distance", "effects_fade_in_start_distance",
  "effects_fade_in_end_distance", "rocket_visible_distance_from_center", "rocket_above_wires_slice_offset_from_center",
  "rocket_air_object_slice_offset_from_center"}, SCALE)
rocket.rising_speed = rocket.rising_speed * ROCKET_SPEED
rocket.engine_starting_speed = rocket.engine_starting_speed * ROCKET_SPEED
rocket.flying_speed = rocket.flying_speed * ROCKET_ACCELERATION
rocket.flying_acceleration = rocket.flying_acceleration * ROCKET_ACCELERATION

local capsule = table.deepcopy(data.raw["rocket-silo"]["rocket-silo"])
capsule.name = "ncs-supply-capsule"
capsule.rocket_entity = "ncs-supply-capsule-rocket"
scale_graphics(capsule, SCALE)
capsule.collision_box = {{-1.8, -1.8}, {1.8, 1.8}}
capsule.selection_box = {{-2, -2}, {2, 2}}
capsule.hole_clipping_box = scale_box(capsule.hole_clipping_box, SCALE)
scale_keys(capsule, {"door_back_open_offset", "door_front_open_offset", "silo_fade_out_start_distance",
  "silo_fade_out_end_distance"}, SCALE)
if capsule.icon_draw_specification and capsule.icon_draw_specification.shift then
  capsule.icon_draw_specification.shift = scale_vector(capsule.icon_draw_specification.shift, SCALE)
end
for _, hatch in pairs((capsule.cargo_station_parameters or {}).hatch_definitions or {}) do
  for key, value in pairs(hatch) do
    if type(value) == "number" and key ~= "receiving_cargo_units" then hatch[key] = value * SCALE
    elseif key == "offset" or key == "pod_shadow_offset" then hatch[key] = scale_vector(value, SCALE) end
  end
end
capsule.times_to_blink = 1
capsule.light_blinking_speed = capsule.light_blinking_speed * SPEED
capsule.door_opening_speed = capsule.door_opening_speed * SPEED
capsule.launch_wait_time = 20 -- Ticks zwischen Startbefehl und Zuendung (Standard 120)
capsule.icon = nil
capsule.icons = icons
capsule.minable = {mining_time = 1, result = "ncs-supply-capsule"}
capsule.placeable_by = nil
-- Kein Upgrade-Planer zum Raketensilo mehr: Factorio verlangt dafuer die gleiche Groesse (Kapsel ist kleiner).
capsule.next_upgrade = nil
capsule.fast_replaceable_group = "ncs-supply-capsule"
capsule.crafting_categories = {"ncs-supply-capsule"}
-- Kein festes Rezept: Je Planet eine eigene Ladung aus dessen Rohstoffen (siehe unten). Welche gilt, setzt
-- scripts/capsule-cargo.lua per set_recipe. Das Silo zaehlt nur fertige Herstellvorgaenge, das Produkt ist egal.
capsule.fixed_recipe = nil
capsule.rocket_parts_required = 5 -- 5 Ladungen a 2 s: etwa 10 s pro Start
capsule.lift_weight = 250000 -- 250 kg, ein Viertel einer normalen Rakete
capsule.module_slots = 0
-- Vom Silo geerbt: Strg-Klick/Schnelleinfuellen ginge nur in Modul-Plaetze. Die Kapsel hat keine, deshalb aus,
-- damit man Kohle und Eisenerz von Hand einfuellen kann.
capsule.fast_transfer_modules_into_module_slots_only = false
capsule.allowed_effects = nil
capsule.icons_positioning = nil
capsule.max_health = 1500
-- Seit 1.0.12 (Wunsch des Users): Auf Aquilo gibt es kein festes Erz, die Ladung braucht Ammoniak-Loesung und
-- Lithium-Sole, auf Vulcanus Lava statt Kohle. Zwei Fluessigkeits-Eingaenge (links und rechts), nur sichtbar und aktiv bei einem Rezept mit Fluessigkeit.
local function fluid_input(direction, position)
  return
  {
    production_type = "input",
    pipe_picture = assembler3pipepictures and assembler3pipepictures() or nil,
    pipe_covers = pipecoverspictures and pipecoverspictures() or nil,
    volume = 1000,
    secondary_draw_orders = {north = -1},
    pipe_connections = {{flow_direction = "input", direction = direction, position = position}}
  }
end
capsule.fluid_boxes =
{
  fluid_input(defines.direction.west, {-1.5, 0.5}),
  fluid_input(defines.direction.east, {1.5, 0.5})
}
capsule.fluid_boxes_off_when_no_fluid_recipe = true
capsule.energy_usage = "150kW"
capsule.active_energy_usage = "600kW"

data:extend(
{
  {
    type = "recipe-category",
    name = "ncs-supply-capsule"
  },
  rocket,
  capsule,
  {
    type = "item",
    name = "ncs-supply-capsule",
    icons = icons,
    subgroup = "space-interactors",
    order = "0[ncs-supply-capsule]",
    place_result = "ncs-supply-capsule",
    stack_size = 1
  },
  {
    type = "recipe",
    name = "ncs-supply-capsule",
    enabled = true,
    energy_required = 3,
    ingredients =
    {
      {type = "item", name = "iron-plate", amount = 100},
      {type = "item", name = "iron-gear-wheel", amount = 40},
      {type = "item", name = "electronic-circuit", amount = 40},
      {type = "item", name = "stone-brick", amount = 50}
    },
    results = {{type = "item", name = "ncs-supply-capsule", amount = 1}}
  }
})

---------------------------------------------------------------------------
-- Ladungen: Eine Ladung = ein "Raketenteil" der Kapsel, rocket_parts_required Ladungen ergeben einen Start.
-- Seit 1.21.0 je Planet eine eigene Ladung aus dessen Rohstoffen (Treibstoff + Huelle), damit die Kapsel ueberall
-- startet. Planeten ohne eigene Ladung (Aquilo, Mod-Planeten) nehmen die generische: nur Strom, aber langsam.
-- Zuordnung Planet -> Ladung: scripts/capsule-cargo.lua.

local function load_recipe(name, energy, ingredients)
  return
  {
    type = "recipe",
    name = name,
    localised_name = {"recipe-name.ncs-supply-capsule-load"},
    icons = icons,
    enabled = true,
    hidden_in_factoriopedia = true,
    hide_from_player_crafting = true,
    auto_recycle = false,
    energy_required = energy,
    categories = {"ncs-supply-capsule"},
    ingredients = ingredients,
    results = {{type = "item", name = "rocket-part", amount = 1}},
    allow_productivity = false
  }
end

data:extend(
{
  -- Nauvis (alter Rezeptname, damit alte Spielstaende ihre Kapsel behalten)
  load_recipe("ncs-supply-capsule-load", 2,
  {
    {type = "item", name = "coal", amount = 40},
    {type = "item", name = "iron-ore", amount = 4}
  }),
  -- Vulcanus seit 1.0.12 (Wunsch des Users) Lava statt Kohle, ueber einen der Rohr-Anschluesse
  load_recipe("ncs-supply-capsule-load-vulcanus", 2,
  {
    {type = "fluid", name = "lava", amount = 100},
    {type = "item", name = "calcite", amount = 4}
  }),
  load_recipe("ncs-supply-capsule-load-gleba", 2,
  {
    {type = "item", name = "yumako", amount = 20},
    {type = "item", name = "jellynut", amount = 20},
    {type = "item", name = "stone", amount = 10} -- seit 1.0.5 (Wunsch des Users): etwas Bergbau auf Gleba
  }),
  load_recipe("ncs-supply-capsule-load-fulgora", 2,
  {
    {type = "item", name = "scrap", amount = 40}
  }),
  -- Aquilo (seit 1.0.12): nur Fluessigkeiten, ueber die beiden Rohr-Anschluesse
  load_recipe("ncs-supply-capsule-load-aquilo", 2,
  {
    {type = "fluid", name = "ammoniacal-solution", amount = 50},
    {type = "fluid", name = "lithium-brine", amount = 50}
  }),
  load_recipe("ncs-supply-capsule-load-generic", 10, {})
})
