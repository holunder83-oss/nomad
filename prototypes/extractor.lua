-- Boden-Extraktor: steht auf einer Fundstelle auf einem Planeten und holt daraus Spezialboeden oder Schiffs-Quellen,
-- die im Extraktor liegen bleiben, bis man sie abholt (Laufzeit: scripts/extractor.lua).
-- Daten in scripts/extractor-config.lua. Fundstellen sind Lagerstaetten einer eigenen Kategorie, die kein Bohrer
-- abbaut; sie sind auf der Karte zu sehen. Gebaeude: 3x3 auf Basis des Assemblers 3 (ein Fluessigkeits-Eingang, ein
-- Ausgang), Grafik "Deep Extractor Mk3" aus CMA Graphics.
-- Zahlen sind vorlaeufig und werden beim Testen festgelegt.

local config = require("scripts.extractor-config")
local cma = require("prototypes.cma")

local GRAPHICS, ICON = cma.crafting_graphics("deep-extractor", "mk3", 3, true)
local ICONS = {{icon = ICON, icon_size = 64}}

local function tinted(sprite, tint)
  local copy = table.deepcopy(sprite)
  local function apply(layer)
    if type(layer) ~= "table" then return end
    if layer.filename or layer.filenames then
      if not layer.draw_as_shadow and not layer.draw_as_light and not layer.draw_as_glow then layer.tint = tint end
    end
    for key, inner in pairs(layer) do
      if type(inner) == "table" and key ~= "tint" and key ~= "shift" and key ~= "size" then apply(inner) end
    end
  end
  apply(copy)
  return copy
end

local extractor = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-3"])
extractor.name = config.EXTRACTOR
extractor.icon = nil
extractor.icons = ICONS
extractor.minable = {mining_time = 1, result = config.EXTRACTOR}
extractor.placeable_by = nil
extractor.fast_replaceable_group = nil
extractor.next_upgrade = nil
extractor.max_health = 3000
extractor.crafting_categories = {"ncs-extraction"}
extractor.crafting_speed = 1
extractor.fixed_recipe = nil
-- Keine Module, keine Beacons
extractor.module_slots = 0
extractor.allowed_effects = {}
extractor.effect_receiver = {uses_module_effects = false, uses_beacon_effects = false, uses_surface_effects = false}
extractor.icons_positioning = nil
extractor.graphics_set = GRAPHICS
extractor.graphics_set_flipped = nil
extractor.water_reflection = nil
-- Vulcanus: viel Wasser und Dampf pro Sekunde, deshalb grosse Anschluesse
for _, box in pairs(extractor.fluid_boxes or {}) do
  box.volume = 1000
end
-- Nur auf Planeten
extractor.surface_conditions = {{property = "gravity", min = 0.1}}

local prototypes_list =
{
  {type = "recipe-category", name = "ncs-extraction"},
  {type = "resource-category", name = "ncs-core"},
  extractor,
  {
    type = "item",
    name = config.EXTRACTOR,
    icons = ICONS,
    subgroup = "space-interactors",
    order = "0[ncs-supply-capsule]-c[extractor]",
    place_result = config.EXTRACTOR,
    stack_size = 10,
    weight = 200000
  },
  {
    type = "recipe",
    name = config.EXTRACTOR,
    enabled = false,
    energy_required = 30,
    ingredients =
    {
      {type = "item", name = "steel-plate", amount = 100},
      {type = "item", name = "refined-concrete", amount = 50},
      {type = "item", name = "electric-engine-unit", amount = 20},
      {type = "item", name = "processing-unit", amount = 20}
    },
    results = {{type = "item", name = config.EXTRACTOR, amount = 1}}
  },
  -- Fundstellen-Scanner: Werkzeug wie der Abbauplaner. Klick damit zeigt die naechsten Fundstellen
  -- (Pfeil an der Figur, Liste im Chat), siehe extractor.scan in scripts/extractor.lua.
  {
    type = "selection-tool",
    name = config.SCANNER,
    icons = {{icon = "__base__/graphics/icons/radar.png", icon_size = 64, tint = {r = 0.75, g = 1, b = 0.8}}},
    subgroup = "space-interactors", -- neben dem Extraktor
    order = "0[ncs-supply-capsule]-c[extractor]-b[scanner]",
    stack_size = 1,
    select = {border_color = {r = 0.4, g = 1, b = 0.6}, cursor_box_type = "entity", mode = {"nothing"}},
    alt_select = {border_color = {r = 0.4, g = 1, b = 0.6}, cursor_box_type = "entity", mode = {"nothing"}}
  },
  {
    type = "recipe",
    name = config.SCANNER,
    enabled = false,
    energy_required = 5,
    ingredients =
    {
      {type = "item", name = "radar", amount = 1},
      {type = "item", name = "advanced-circuit", amount = 10}
    },
    results = {{type = "item", name = config.SCANNER, amount = 1}}
  },
  {
    type = "technology",
    name = config.TECHNOLOGY,
    icon = "__space-age__/graphics/technology/big-mining-drill.png",
    icon_size = 256,
    effects =
    {
      {type = "unlock-recipe", recipe = config.EXTRACTOR},
      {type = "unlock-recipe", recipe = config.SCANNER}
    },
    prerequisites = {"production-science-pack", "space-science-pack"},
    unit =
    {
      count = 1000,
      ingredients =
      {
        {"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1},
        {"production-science-pack", 1}, {"space-science-pack", 1}
      },
      time = 30
    },
    order = "z[ncs]-e[extractor]"
  }
}

-- Aquilo, Waerme: unsichtbarer Waermespeicher unter dem Extraktor (legt scripts/extractor.lua nur auf Aquilo an).
-- Waermerohre schliessen an jedem Randfeld des 3x3 an; das Skript entzieht ihm waehrend des Laufs Waerme.
-- heating_radius: ein warmer Speicher haelt auch den Extraktor selbst eisfrei.
local heat_connections = {}
for _, side in pairs({
  {dir = defines.direction.north, cells = {{-1, -1}, {0, -1}, {1, -1}}},
  {dir = defines.direction.east, cells = {{1, -1}, {1, 0}, {1, 1}}},
  {dir = defines.direction.south, cells = {{1, 1}, {0, 1}, {-1, 1}}},
  {dir = defines.direction.west, cells = {{-1, 1}, {-1, 0}, {-1, -1}}}
}) do
  for _, cell in pairs(side.cells) do
    table.insert(heat_connections, {position = cell, direction = side.dir})
  end
end
table.insert(prototypes_list,
{
  type = "heat-interface",
  name = config.EXTRACTOR .. "-heat",
  localised_name = {"entity-name." .. config.EXTRACTOR},
  icons = ICONS,
  flags = {"placeable-off-grid", "not-on-map", "not-blueprintable", "not-deconstructable", "not-upgradable",
    "no-copy-paste", "hide-alt-info", "not-in-kill-statistics"},
  hidden = true,
  hidden_in_factoriopedia = true,
  selectable_in_game = false,
  collision_mask = {layers = {}},
  collision_box = {{-1.4, -1.4}, {1.4, 1.4}},
  max_health = 1000000,
  gui_mode = "none",
  heating_radius = 1,
  heat_buffer =
  {
    max_temperature = 1000,
    specific_heat = "10MJ",
    max_transfer = "10GW",
    min_working_temperature = config.COLD.MIN_TEMPERATURE,
    connections = heat_connections
  },
  picture = {filename = "__core__/graphics/empty.png", size = 1}
})

-- Fulgora, Schrott-Lawine: instabiler Schrott. Verdirbt nach config.AVALANCHE.SPOIL_SECONDS und explodiert dabei
-- (jedes Stueck klein), auch in Kisten und auf Baendern. In jeder Montagemaschine wird er zu normalem
-- Schrott stabilisiert (geht in Variante A auf Planeten, Assembler 1+2 sind dort erlaubt).
local scrap_item = data.raw.item["scrap"]
local unstable_icons = {{icon = "__space-age__/graphics/icons/scrap.png", icon_size = 64, tint = {r = 1, g = 0.45, b = 0.35}}}
table.insert(prototypes_list,
{
  type = "item",
  name = config.AVALANCHE.item,
  icons = unstable_icons,
  subgroup = "fulgora-processes",
  order = "a[scrap]-a[scrap]-ncs",
  inventory_move_sound = scrap_item.inventory_move_sound,
  pick_sound = scrap_item.pick_sound,
  drop_sound = scrap_item.drop_sound,
  stack_size = 50,
  weight = scrap_item.weight,
  spoil_ticks = config.AVALANCHE.SPOIL_SECONDS * 60,
  spoil_to_trigger_result =
  {
    -- Jedes Stueck einzeln (am Boden und auf Baendern liegen Items ohnehin einzeln): kleine Explosion mit 4 Schaden,
    -- ein voller Stapel also 200. Eine Stahlkiste (350) haelt knapp 2 Stapel aus.
    items_per_trigger = 1,
    trigger =
    {
      type = "direct",
      action_delivery =
      {
        type = "instant",
        source_effects =
        {
          {type = "create-entity", entity_name = "explosion"},
          -- Errungenschaft "Lawinenreiter": merkt sich die Explosion (scripts/achievements.lua)
          {type = "script", effect_id = "ncs-unstable-scrap-exploded"},
          {
            type = "nested-result",
            action =
            {
              type = "area",
              radius = 2,
              action_delivery =
              {
                type = "instant",
                target_effects = {{type = "damage", damage = {amount = 4, type = "explosion"}}}
              }
            }
          }
        }
      }
    }
  }
})
table.insert(prototypes_list,
{
  type = "recipe",
  name = "ncs-stabilize-scrap",
  icons = unstable_icons,
  categories = {"crafting"},
  subgroup = "fulgora-processes",
  order = "a[scrap]-b[stabilize]-ncs",
  enabled = false,
  hide_from_player_crafting = true,
  auto_recycle = false,
  allow_productivity = false,
  energy_required = 2,
  ingredients = {{type = "item", name = config.AVALANCHE.item, amount = 10}},
  results = {{type = "item", name = "scrap", amount = 10}}
})

-- Seit 1.0.11 (Wunsch des Users): instabiler Schrott geht auch direkt in den Recycler, gleiche Ergebnisse wie
-- normaler Schrott (Kopie von "scrap-recycling").
local scrap_recycling = data.raw.recipe["scrap-recycling"]
if scrap_recycling then
  local recipe = table.deepcopy(scrap_recycling)
  recipe.name = "ncs-unstable-scrap-recycling"
  recipe.localised_name = {"recipe-name.ncs-unstable-scrap-recycling"}
  recipe.icons = unstable_icons
  recipe.icon = nil
  recipe.order = "a[scrap]-c[recycling]-ncs"
  recipe.enabled = false
  recipe.auto_recycle = false
  recipe.ingredients = {{type = "item", name = config.AVALANCHE.item, amount = 1}}
  table.insert(prototypes_list, recipe)
end

local stone = data.raw.resource["stone"]
for _, core in pairs(config.cores) do
  local product = data.raw.item[core.product]
  local product_icons = product.icons or {{icon = product.icon, icon_size = product.icon_size}}

  -- Fundstelle: Lagerstaette, die nur der Extraktor "abbaut" (Menge = verbleibende Laeufe)
  local resource = table.deepcopy(stone)
  resource.name = core.entity
  resource.localised_name = {"entity-name.ncs-core", {"item-name." .. core.product}}
  resource.localised_description = {"entity-description.ncs-core"}
  resource.icon = nil
  resource.icons = product_icons
  resource.category = "ncs-core"
  resource.autoplace = nil
  resource.minable = {mining_time = 1, result = core.product}
  resource.stages = tinted(stone.stages, core.tint)
  -- Auf buntem Boden (Gleba) sah man die Steine kaum: pulsierendes Leuchten in der Farbe der Fundstelle
  -- (Leuchten des Uranerzes, eingefaerbt, staerker und schneller).
  local glow = table.deepcopy(data.raw.resource["uranium-ore"].stages_effect)
  if glow then
    resource.stages_effect = tinted(glow, core.tint)
    resource.effect_animation_period = 2
    resource.effect_animation_period_deviation = 0.5
    resource.effect_darkness_multiplier = 2
    resource.min_effect_alpha = 0.5
    resource.max_effect_alpha = 1
  end
  resource.map_color = core.tint
  resource.mining_visualisation_tint = core.tint
  resource.factoriopedia_simulation = nil
  resource.tree_removal_probability = nil
  resource.tree_removal_max_distance = nil
  table.insert(prototypes_list, resource)

  local results = {{type = "item", name = core.product, amount = core.count}}
  local ingredients = table.deepcopy(core.ingredients)
  if core.challenge == "avalanche" then
    -- Eigener Ausgabe-Platz fuer den Schrott, den das Skript waehrend des Laufs hineinlegt
    table.insert(results, {type = "item", name = config.AVALANCHE.item, amount = 1})
  elseif core.challenge == "heat" then
    -- Wasser rein, Dampf raus: aktiviert die Anschluesse; die eigentlichen Mengen bewegt das Skript.
    -- 500 statt 1: Seit 2.1 richtet sich die Groesse des Eingangs nach der Rezeptmenge (bei 1 fasst er nur 4).
    table.insert(ingredients, {type = "fluid", name = "water", amount = 500})
    table.insert(results, {type = "fluid", name = "steam", amount = 1, temperature = config.HEAT.STEAM_TEMPERATURE})
  end

  table.insert(prototypes_list,
  {
    type = "recipe",
    name = core.recipe,
    main_product = core.product,
    localised_name = {"recipe-name.ncs-extract", {"item-name." .. core.product}},
    icons = product_icons,
    categories = {"ncs-extraction"},
    subgroup = "space-interactors",
    order = "0[ncs-supply-capsule]-d[extract]-" .. core.name,
    enabled = true,
    hide_from_player_crafting = true,
    auto_recycle = false,
    allow_productivity = false,
    allow_quality = false,
    energy_required = config.RUN_SECONDS,
    ingredients = ingredients,
    results = results
  })
end

data:extend(prototypes_list)

-- Die Freischalt-Forschungen der Boeden und Quellen schalten kein Rezept mehr frei (die gibt es nicht mehr),
-- sondern den Abbau mit dem Extraktor. Sie setzen deshalb den Extraktor voraus.
for _, core in pairs(config.cores) do
  local technology = data.raw.technology[core.technology]
  if technology then
    local product = data.raw.item[core.product]
    local resource_icons = product.icons or {{icon = product.icon, icon_size = product.icon_size}}
    local effects = {}
    for _, effect in pairs(technology.effects or {}) do
      if not (effect.type == "unlock-recipe" and effect.recipe == core.product) then table.insert(effects, effect) end
    end
    table.insert(effects, 1, {type = "nothing", icons = resource_icons, effect_description = {"ncs-tech.extract", {"item-name." .. core.product}}})
    if core.challenge == "avalanche" then
      table.insert(effects, 2, {type = "unlock-recipe", recipe = "ncs-stabilize-scrap"})
      if data.raw.recipe["ncs-unstable-scrap-recycling"] then
        table.insert(effects, 3, {type = "unlock-recipe", recipe = "ncs-unstable-scrap-recycling"})
      end
    end
    technology.effects = effects
    technology.prerequisites = technology.prerequisites or {}
    table.insert(technology.prerequisites, config.TECHNOLOGY)
  end
end
