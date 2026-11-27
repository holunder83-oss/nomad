-- Kleines MG-Geschuetz (1.0.16, Wunsch des Users fuer Super-Hardcore): ab Start herstellbar und auf Planeten
-- baubar, damit man sich auf Nauvis gegen Beisser wehren kann, bevor das normale Geschuetz erforscht ist.
-- Kopie des Gatling-Geschuetzes, 1x1 statt 2x2 (Grafik x 0,6), schwaecher: halbe Lebenspunkte, kleinere Reichweite,
-- langsamer. Die Forschungen "Geschuetzgeschwindigkeit" wirken nicht (nur fuer gun-turret), Munitions-Schaden schon.
-- Nur in Variante E. Als ncs-Gebaeude sperrt prototypes/variant-a.lua es nicht.
-- (Auch in Variante F "Super-Duper-Hardcore".)
local variant = settings.startup["ncs-rules-variant"].value
if variant ~= "super-hardcore" and variant ~= "super-duper-hardcore" then return end

local NAME = "ncs-small-gun-turret"
local SCALE = 0.6

local function scale_vector(v, k)
  if v.x then return {x = v.x * k, y = v.y * k} end
  return {v[1] * k, v[2] * k}
end

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
    if type(value) == "table" and key ~= "shift" and not (type(key) == "string" and key:find("sound")) then
      scale_graphics(value, k, seen)
    end
  end
end

local turret = table.deepcopy(data.raw["ammo-turret"]["gun-turret"])
turret.name = NAME
turret.minable = {mining_time = 0.3, result = NAME}
turret.fast_replaceable_group = nil
turret.max_health = 200
turret.collision_box = {{-0.35, -0.35}, {0.35, 0.35}}
turret.selection_box = {{-0.5, -0.5}, {0.5, 0.5}}
turret.drawing_box_vertical_extension = 0.1
turret.rotation_speed = 0.01
-- Kabelpunkte gaeben die 2x2-Stellen an, deshalb ohne Schaltungsanschluss
turret.circuit_connector = nil
turret.circuit_wire_max_distance = 0
for _, key in pairs({"folded_animation", "preparing_animation", "prepared_animation", "attacking_animation",
  "folding_animation", "graphics_set", "water_reflection"}) do
  scale_graphics(turret[key], SCALE)
end
if turret.icon_draw_specification then turret.icon_draw_specification.scale = 0.4 end
for _, positioning in pairs(turret.icons_positioning or {}) do
  if positioning.shift then positioning.shift = scale_vector(positioning.shift, SCALE) end
end

local attack = turret.attack_parameters
attack.range = 14
attack.cooldown = 10
attack.damage_modifier = 0.8
attack.projectile_creation_distance = attack.projectile_creation_distance * SCALE
attack.projectile_center = scale_vector(attack.projectile_center, SCALE)
if attack.shell_particle then
  attack.shell_particle.center = scale_vector(attack.shell_particle.center, SCALE)
  attack.shell_particle.creation_distance = attack.shell_particle.creation_distance * SCALE
end
turret.call_for_help_radius = 20

local item = table.deepcopy(data.raw.item["gun-turret"])
item.name = NAME
item.order = "b[turret]-a[gun-turret]-0[small]"
item.place_result = NAME

data:extend(
{
  turret,
  item,
  {
    type = "recipe",
    name = NAME,
    enabled = true,
    energy_required = 4,
    ingredients =
    {
      {type = "item", name = "iron-gear-wheel", amount = 5},
      {type = "item", name = "copper-plate", amount = 5},
      {type = "item", name = "iron-plate", amount = 10}
    },
    results = {{type = "item", name = NAME, amount = 1}}
  }
})
