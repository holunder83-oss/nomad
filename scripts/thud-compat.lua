-- Zusammenspiel mit T.H.U.D (optional, seit 1.0.10, Wunsch des Users). T.H.U.D laesst Schiffe auf Planeten landen
-- und wieder abheben. Nomad ergaenzt:
--   - Auf dem Boden eines gelandeten Schiffs gilt alles wie auf dem Schiff (Labore und gesperrte Fabriken):
--     scripts/planet-rules.lua, prototypes/lab-rules.lua.
--   - T.H.U.D erlaubt Plattform-Fundament auf jedem festen Planetenboden. Nomad laesst es nur dort liegen, wo
--     T.H.U.D es an gelandeten Boden anschliesst (dann ist es "thud-landed-foundation"); einzelnes Fundament
--     kommt zurueck, wie im Grundspiel. T.H.U.D laedt vor Nomad, sein Handler ist also schon gelaufen.
--   - Das Mutterschiff wiederfinden: T.H.U.D loescht beim Landen die Plattform und legt beim Abheben eine neue mit
--     gleichem Namen an (control.lua, get_ship).

local thud = {}

local FOUNDATION = "space-platform-foundation"

function thud.active()
  return script.active_mods["Thud"] ~= nil
end

local function refund(event, surface, stack, position)
  local player = event.player_index and game.get_player(event.player_index)
  if player and player.valid then
    stack.count = stack.count - player.insert(stack)
    player.create_local_flying_text{text = {"ncs-thud.foundation"}, position = position, create_at_cursor = true}
    player.play_sound{path = "utility/cannot_build"}
  elseif event.robot and event.robot.valid then
    local cargo = event.robot.get_inventory(defines.inventory.robot_cargo)
    if cargo then stack.count = stack.count - cargo.insert(stack) end
  end
  if stack.count > 0 then
    surface.spill_item_stack{position = position, stack = stack, enable_looted = true, force = event.robot and event.robot.force}
  end
end

-- on_player_built_tile / on_robot_built_tile
function thud.on_built_tile(event)
  if not thud.active() then return end
  local item = event.item
  if not (item and item.name == FOUNDATION) then return end
  local surface = game.get_surface(event.surface_index)
  if not (surface and surface.valid) or surface.platform then return end

  local revert = {}
  for _, change in pairs(event.tiles) do
    local position = change.position
    if surface.get_tile(position.x, position.y).name == FOUNDATION then
      revert[#revert + 1] = {name = change.old_tile.name, position = position}
    end
  end
  if not revert[1] then return end

  surface.set_tiles(revert, true, false, true, false)
  for _, tile in pairs(revert) do surface.set_hidden_tile(tile.position, nil) end
  local quality = event.quality and event.quality.name or "normal"
  refund(event, surface, {name = FOUNDATION, count = #revert, quality = quality}, revert[1].position)
end

return thud
