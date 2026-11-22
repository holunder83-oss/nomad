-- Labore und Biolabore nur im All (Raumplattform: Druck 0, Schwerkraft 0).
-- Laeuft in data-final-fixes, damit Labore aus Planeten-Mods schon fertig sind.
--
-- Planetengebundene Sonderlabore (z. B. das Cerys-Labor, das eine nur auf Cerys vorhandene Strahlung braucht)
-- bleiben unveraendert: Druck und Schwerkraft zu ersetzen wuerde sie sonst nirgends mehr baubar machen.

local surface_util = require("prototypes.surface-util")

local space_only =
{
  {property = "pressure", max = 0},
  {property = "gravity", max = 0}
}

-- Mit T.H.U.D (1.0.10): Labore duerfen auch auf den Boden gelandeter Schiffe. Das laesst sich nicht als
-- Bedingung ausdruecken, deshalb bekommen die Labore keine Bedingung, und scripts/planet-rules.lua gibt sie auf
-- Planeten ausserhalb von gelandetem Boden zurueck (Liste in mod-data "ncs-lab-rules").
local thud = mods["Thud"] ~= nil
local thud_conditions = thud and data.raw["mod-data"]["thud-surface-conditions"]
local script_labs = {}

local exempt = {}
for name, lab in pairs(data.raw["lab"]) do
  -- Bedingungen ausser Druck/Schwerkraft bleiben (das Biolabor verlangt z. B. Druck 1000 = Nauvis,
  -- das wuerde sich mit "nur im All" ausschliessen und wird deshalb ersetzt).
  local conditions = {}
  -- Mit T.H.U.D sind die Bedingungen schon abgenommen und stehen in dessen mod-data
  local original = lab.surface_conditions or (thud_conditions and thud_conditions.data[name]) or {}
  for _, condition in pairs(original) do
    if condition.property ~= "pressure" and condition.property ~= "gravity" then
      table.insert(conditions, condition)
    end
  end

  if not surface_util.allowed_in_space(conditions) then
    table.insert(exempt, name)
  elseif thud then
    -- T.H.U.D hat die Bedingungen schon abgenommen und legt Labore still, deren alte Bedingungen nicht passen
    -- (das Biolabor verlangte Druck 1000, haette also im All stillgestanden). Nomad regelt Labore selbst.
    lab.surface_conditions = nil
    if thud_conditions then thud_conditions.data[name] = conditions[1] and table.deepcopy(conditions) or nil end
    script_labs[name] = true
  else
    for _, condition in pairs(space_only) do
      table.insert(conditions, table.deepcopy(condition))
    end
    lab.surface_conditions = conditions
  end
end

if thud then
  data:extend{{type = "mod-data", name = "ncs-lab-rules", data_type = "ncs-lab-rules", data = {labs = script_labs}}}
end

if #exempt > 0 then
  table.sort(exempt)
  log("[nomad] Planetengebundene Labore, nicht aufs All beschraenkt: " .. table.concat(exempt, ", "))
end
