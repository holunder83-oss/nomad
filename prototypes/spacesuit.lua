-- Raumanzug: Forschung, nach der man auf dem Schiff aus dem Hub aussteigen und herumlaufen kann
-- (nur im Orbit, siehe scripts/spacesuit.lua). Zahlen sind vorlaeufig und werden beim Testen festgelegt.
-- Die Anzug-Figur selbst (schwebt ueber Gebaeude) wird in data-final-fixes erzeugt (prototypes/spacesuit-character.lua).

data:extend(
{
  {
    type = "technology",
    name = "ncs-spacesuit",
    icon = "__base__/graphics/technology/heavy-armor.png",
    icon_size = 256,
    effects = {{type = "nothing", effect_description = {"ncs-tech.spacesuit"}}},
    prerequisites = {"logistic-science-pack"},
    unit =
    {
      count = 100,
      ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}},
      time = 15
    },
    order = "a[ncs]-b[spacesuit]"
  },
  -- Seit 1.0.11 (Wunsch des Users): nach Gleba mit Kohlefaser auch im Flug draussen bleiben.
  {
    type = "technology",
    name = "ncs-spacesuit-flight",
    icons =
    {
      {icon = "__base__/graphics/technology/heavy-armor.png", icon_size = 256},
      {icon = "__space-age__/graphics/icons/carbon-fiber.png", icon_size = 64, scale = 0.25, shift = {8, 8}}
    },
    effects = {{type = "nothing", effect_description = {"ncs-tech.spacesuit-flight"}}},
    prerequisites = {"ncs-spacesuit", "agricultural-science-pack", "carbon-fiber"},
    unit =
    {
      count = 2000,
      ingredients =
      {
        {"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1},
        {"space-science-pack", 1}, {"agricultural-science-pack", 1}
      },
      time = 30
    },
    order = "a[ncs]-b[spacesuit]-b[flight]"
  }
})
