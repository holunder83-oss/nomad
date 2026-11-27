data:extend(
{
  {
    -- Regeln fuer Planeten:
    --   A "mining" (Standard): auf Planeten nur Abbau, verarbeitet wird im All (prototypes/variant-a.lua)
    --   B "all": auf Planeten alles erlaubt
    --   C "space-age": Space-Age-Gebaeude nur im All, ausser Recycler und Agrarturm (prototypes/variant-b.lua)
    --   D "hardcore" (seit 1.0.5): wie A, aber ohne einfache Fabriken; jedes Gebaeude mit eigener Forschung nach
    --     Metallurgie-Science (prototypes/variant-d.lua), dazu die Abfuellstation (prototypes/barrel-station.lua)
    type = "string-setting",
    name = "ncs-rules-variant",
    setting_type = "startup",
    default_value = "mining",
    allowed_values = {"mining", "all", "space-age", "hardcore"},
    order = "0"
  },
  {
    -- Faktor fuer die Science-Kosten aller Nomad-Forschungen (ncs-*), Vanilla bleibt (data-final-fixes.lua)
    type = "double-setting",
    name = "ncs-research-cost",
    setting_type = "startup",
    default_value = 1,
    minimum_value = 0.1,
    maximum_value = 10,
    order = "1"
  },
  {
    -- Lautstaerke der Versorgungskapsel in Prozent (prototypes/supply-capsule.lua), seit 1.0.15
    type = "int-setting",
    name = "ncs-capsule-volume",
    setting_type = "startup",
    default_value = 100,
    minimum_value = 0,
    maximum_value = 100,
    order = "2"
  },
  {
    -- Wer auf einem Planeten stirbt, wacht im Hub des Mutterschiffs auf (scripts/recall.lua)
    type = "bool-setting",
    name = "ncs-respawn-on-ship",
    setting_type = "runtime-global",
    default_value = true,
    order = "a"
  }
})
