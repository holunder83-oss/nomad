-- Gebaeude und Freischalt-Forschungen fuer Lava-Becken und Bio-Boden (Boeden selbst: prototypes/floors.lua).
-- Einmal erforscht, danach beliebig viele Felder (begrenzt durch die teure Herstellung).
-- Zahlen sind vorlaeufig und werden beim Testen festgelegt.

local costs = require("prototypes.upgrade-costs")

-- Orbitaler Agrarturm: wie der Agrarturm, aber nur im All und nur auf Bio-Boden.
local tower = table.deepcopy(data.raw["agricultural-tower"]["agricultural-tower"])
tower.name = "ncs-orbital-agricultural-tower"
tower.minable = {mining_time = 0.2, result = "ncs-orbital-agricultural-tower"}
tower.placeable_by = nil
tower.fast_replaceable_group = nil
tower.next_upgrade = nil
tower.surface_conditions = {{property = "pressure", max = 0}, {property = "gravity", max = 0}}
tower.tile_buildability_rules =
{
  {
    area = table.deepcopy(tower.collision_box),
    required_tiles = {layers = {ncs_bio_zone = true}},
    colliding_tiles = {layers = {}}
  }
}

local tower_icons = {{icon = "__space-age__/graphics/icons/agricultural-tower.png", tint = {r = 0.75, g = 0.9, b = 1}}}
tower.icon = nil
tower.icons = tower_icons

local tower_item = table.deepcopy(data.raw.item["agricultural-tower"])
tower_item.name = "ncs-orbital-agricultural-tower"
tower_item.icon = nil
tower_item.icons = tower_icons
tower_item.place_result = "ncs-orbital-agricultural-tower"
tower_item.order = (tower_item.order or "") .. "-ncs"

data:extend(
{
  tower,
  tower_item,
  {
    type = "recipe",
    name = "ncs-orbital-agricultural-tower",
    enabled = false,
    energy_required = 10,
    ingredients =
    {
      {type = "item", name = "agricultural-tower", amount = 1},
      {type = "item", name = "low-density-structure", amount = 5}
    },
    results = {{type = "item", name = "ncs-orbital-agricultural-tower", amount = 1}}
  },
  {
    type = "technology",
    name = "ncs-lava-zone",
    icon = "__space-age__/graphics/technology/foundry.png",
    icon_size = 256,
    effects = {}, -- Abbau mit dem Extraktor, Effekt setzt prototypes/extractor.lua
    prerequisites = {"foundry", "metallurgic-science-pack"},
    unit = costs.unit("metallurgic-science-pack")
  },
  {
    type = "technology",
    name = "ncs-bio-zone",
    icon = "__space-age__/graphics/technology/yumako.png",
    icon_size = 256,
    effects =
    {
      {type = "unlock-recipe", recipe = "ncs-orbital-agricultural-tower"}
    },
    prerequisites = {"agriculture", "agricultural-science-pack"},
    unit = costs.unit("agricultural-science-pack")
  },
  {
    -- Zweiter Bio-Boden fuer Geleenuss, eigene Forschung. Seit 1.0.13 parallel zum Yumako-Boden
    -- (gleiche Voraussetzungen, Spieler waehlt die Reihenfolge); beide schalten den Agrarturm frei.
    type = "technology",
    name = "ncs-jellynut-zone",
    icon = "__space-age__/graphics/technology/jellynut.png",
    icon_size = 256,
    effects =
    {
      {type = "unlock-recipe", recipe = "ncs-orbital-agricultural-tower"}
    },
    prerequisites = {"agriculture", "agricultural-science-pack"},
    unit = costs.unit("agricultural-science-pack")
  }
})
