# frozen_string_literal: true

module ReinforcingSteelStandards
  REBAR_SPECS = {
    "RB6" => { diameter_mm: 6, unit_weight_kg_per_m: 0.222 },
    "RB9" => { diameter_mm: 9, unit_weight_kg_per_m: 0.499 },
    "DB10" => { diameter_mm: 10, unit_weight_kg_per_m: 0.617 },
    "DB12" => { diameter_mm: 12, unit_weight_kg_per_m: 0.888 },
    "DB16" => { diameter_mm: 16, unit_weight_kg_per_m: 1.58 },
    "DB20" => { diameter_mm: 20, unit_weight_kg_per_m: 2.47 },
    "DB25" => { diameter_mm: 25, unit_weight_kg_per_m: 3.85 },
    "DB28" => { diameter_mm: 28, unit_weight_kg_per_m: 4.83 },
    "DB32" => { diameter_mm: 32, unit_weight_kg_per_m: 6.31 }
  }.freeze

  module_function

  def inside_bend_diameter_mm(diameter_mm)
    return 6.0 * diameter_mm if diameter_mm <= 25.0
    return 8.0 * diameter_mm if diameter_mm <= 36.0

    10.0 * diameter_mm
  end

  def centerline_bend_radius_mm(diameter_mm)
    (inside_bend_diameter_mm(diameter_mm) / 2.0) + (diameter_mm / 2.0)
  end

  def hook_90_tail_mm(diameter_mm)
    12.0 * diameter_mm
  end

  def hook_180_tail_mm(diameter_mm)
    [4.0 * diameter_mm, 60.0].max
  end
end

