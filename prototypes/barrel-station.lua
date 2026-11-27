-- Abfuellstation (nur Variante D "Hardcore", seit 1.0.5): Ohne Fabriken auf Planeten liessen sich sonst keine Faesser
-- fuellen, Fluessigkeiten (Rohoel, Schwefelsaeure, Wasser fuer den Extraktor auf Vulcanus) kaemen nicht weiter.
-- Montagemaschine, die nur Faesser fuellt und leert. Ab Start, auf Planeten immer erlaubt (ncs-Namen sperrt die
-- Variante nicht). Neuer Name statt "ncs-barrel-station": die gab es bis 1.24.0, migrations/1.24.1-barrel-station.json
-- macht daraus Assembler 2.
-- Laeuft in data-final-fixes: Die Fass-Rezepte erzeugt das Grundspiel erst in data-updates.

-- Seit 1.0.18 auch in E "Siedler" und F "Nomade" (Meldung: in F kein Oel abfuellbar, Assembler erst spaet).
local VARIANTS = {["hardcore"] = true, ["super-hardcore"] = true, ["super-duper-hardcore"] = true}
if not VARIANTS[settings.startup["ncs-rules-variant"].value] then return end

local NAME = "ncs-barrel-filler"
local CATEGORY = "ncs-barreling"

local station = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-2"])
station.name = NAME
station.minable = {mining_time = 0.2, result = NAME}
station.crafting_categories = {CATEGORY}
station.crafting_speed = 1
station.module_slots = 0
station.allowed_effects = {}
station.fast_replaceable_group = nil
station.next_upgrade = nil
station.surface_conditions = nil
station.icons = {
  {icon = "__base__/graphics/icons/assembling-machine-2.png", icon_size = 64},
  {icon = "__base__/graphics/icons/fluid/barreling/empty-barrel.png", icon_size = 64, scale = 0.25, shift = {8, 8}}
}
station.icon = nil

local item = table.deepcopy(data.raw.item["assembling-machine-2"])
item.name = NAME
item.place_result = NAME
item.icons = station.icons
item.icon = nil
item.order = "a[assembling-machine-0]-z[ncs-barrel-filler]"

data:extend(
{
  {type = "recipe-category", name = CATEGORY},
  station,
  item,
  {
    type = "recipe",
    name = NAME,
    enabled = true,
    energy_required = 1,
    ingredients =
    {
      {type = "item", name = "iron-plate", amount = 10},
      {type = "item", name = "iron-gear-wheel", amount = 5},
      {type = "item", name = "pipe", amount = 5},
      {type = "item", name = "electronic-circuit", amount = 3}
    },
    results = {{type = "item", name = NAME, amount = 1}}
  }
})

-- Alle Fass-Rezepte (auch die anderer Mods) gehen zusaetzlich in der Abfuellstation
for _, recipe in pairs(data.raw.recipe) do
  if recipe.subgroup == "fill-barrel" or recipe.subgroup == "empty-barrel" then
    recipe.categories = recipe.categories or {"crafting"}
    table.insert(recipe.categories, CATEGORY)
  end
end
