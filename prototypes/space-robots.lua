-- Roboter im All: Space Age sperrt den Roboport (braucht Druck >= 10) und die Logistik-Kisten
-- (brauchen Schwerkraft >= 0.1) fuer Raumplattformen. Die Roboter selbst haben keine Sperre.
-- Hier werden nur diese Platzierungsregeln entfernt; auf Planeten aendert sich nichts,
-- weil alle Planeten Druck und Schwerkraft haben.
-- Persoenliche Bauroboter brauchen keine Aenderung: Sie funktionieren, sobald die Spielfigur
-- im Raumanzug draussen ist (Ausruestung wird beim Aus-/Einsteigen mit uebertragen).

local function remove_conditions(prototype, property)
  if not (prototype and prototype.surface_conditions) then return end
  local conditions = {}
  for _, condition in pairs(prototype.surface_conditions) do
    if condition.property ~= property then
      table.insert(conditions, condition)
    end
  end
  prototype.surface_conditions = #conditions > 0 and conditions or nil
end

remove_conditions(data.raw["roboport"]["roboport"], "pressure")

for _, name in pairs({"passive-provider-chest", "active-provider-chest", "storage-chest", "buffer-chest", "requester-chest"}) do
  remove_conditions(data.raw["logistic-container"][name], "gravity")
end

-- Seit 1.24.1 (Wunsch des Users): auch normale Kisten (Schwerkraft >= 0.1) und Stein-/Stahlofen (Druck >= 10)
-- duerfen aufs Schiff. Die Oefen laufen dort mit Brennstoff wie auf Planeten.
for _, name in pairs({"wooden-chest", "iron-chest", "steel-chest"}) do
  remove_conditions(data.raw["container"][name], "gravity")
end
for _, name in pairs({"stone-furnace", "steel-furnace"}) do
  remove_conditions(data.raw["furnace"][name], "pressure")
end

-- Seit 1.0.12 (Wunsch des Users): Zuege im All. Space Age verlangt fuer Schienen, Signale, Bahnhoefe, Lokomotiven
-- und Wagen Schwerkraft >= 0.1. Gilt fuer alle Prototypen dieser Typen, auch aus anderen Mods.
for _, type in pairs({"straight-rail", "curved-rail-a", "curved-rail-b", "half-diagonal-rail", "legacy-straight-rail",
    "legacy-curved-rail", "elevated-straight-rail", "elevated-curved-rail-a", "elevated-curved-rail-b",
    "elevated-half-diagonal-rail", "rail-ramp", "rail-support", "rail-signal", "rail-chain-signal", "train-stop",
    "locomotive", "cargo-wagon", "fluid-wagon", "artillery-wagon", "infinity-cargo-wagon"}) do
  for _, prototype in pairs(data.raw[type] or {}) do
    remove_conditions(prototype, "gravity")
  end
end

-- Hub im Logistik-Netz (scripts/hub-logistics.lua): Der Hub selbst gehoert zu keinem Netz. Deshalb legt das Skript
-- an jeden Hub zwei unsichtbare Kisten. In die Lager-Kiste liefern die Roboter Ueberschuss (das Skript leert sie
-- in den Hub), die Anbieter-Kiste fuellt das Skript mit Items aus dem Hub, die im Netz angefordert werden.
local EMPTY = {filename = "__core__/graphics/empty.png", size = 1}
for name, template in pairs({["ncs-hub-storage"] = "storage-chest", ["ncs-hub-provider"] = "passive-provider-chest"}) do
  local chest = table.deepcopy(data.raw["logistic-container"][template])
  chest.name = name
  chest.localised_name = {"entity-name.space-platform-hub"}
  chest.icons = nil
  chest.icon = data.raw["space-platform-hub"]["space-platform-hub"].icon
  chest.flags = {"placeable-off-grid", "not-on-map", "not-blueprintable", "not-deconstructable", "not-upgradable",
    "no-copy-paste", "hide-alt-info", "not-in-kill-statistics"}
  chest.hidden = true
  chest.hidden_in_factoriopedia = true
  chest.minable = nil
  chest.selectable_in_game = false
  chest.collision_mask = {layers = {}}
  chest.collision_box = {{-0.35, -0.35}, {0.35, 0.35}}
  chest.selection_box = {{-0.5, -0.5}, {0.5, 0.5}}
  chest.picture = EMPTY
  chest.animation = nil
  chest.circuit_connector = nil
  chest.circuit_wire_max_distance = 0
  chest.inventory_size = 48
  chest.max_health = 1000000
  chest.corpse = nil
  chest.dying_explosion = nil
  chest.surface_conditions = nil
  chest.placeable_by = nil
  chest.fast_replaceable_group = nil
  chest.next_upgrade = nil
  data:extend({chest})
end
