require 'sketchup.rb'
require 'extensions.rb'

module GoRebar
  module StirrupSystem135
    
    # ฐานข้อมูลเหล็กเส้น (น้ำหนัก kg/m และสี)
    REBAR_SPECS = {
      "RB6"  => { dia: 6.mm,  w: 0.222, color: "Silver" },
      "RB9"  => { dia: 9.mm,  w: 0.499, color: "Gray" },
      "DB10" => { dia: 10.mm, w: 0.617, color: "LimeGreen" },
      "DB12" => { dia: 12.mm, w: 0.888, color: "Green" },
      "DB16" => { dia: 16.mm, w: 1.580, color: "Red" },
      "DB20" => { dia: 20.mm, w: 2.470, color: "Yellow" },
      "DB25" => { dia: 25.mm, w: 3.850, color: "Blue" },
      "DB28" => { dia: 28.mm, w: 4.830, color: "Cyan" },
      "DB32" => { dia: 32.mm, w: 6.310, color: "Orange" }
    }

    def self.show_dialog
      # ตัวเลือกสำหรับ Dialog
      rebar_list = REBAR_SPECS.keys.join("|")
      orientation_list = "Column (Vertical)|Beam (Horizontal)"
      
      prompts = [
        "Orientation:",       # 0
        "Rebar Type:",        # 1
        "Width (m):",         # 2
        "Depth (m):",         # 3
        "Cover (m):",         # 4
        "Member Length (m):", # 5
        "Spacing @ (m):"      # 6
      ]
      
      # Default: Beam Mode, DB12, 0.20x0.40
      defaults = ["Beam (Horizontal)", "DB12", 0.20, 0.40, 0.03, 3.00, 0.15]
      list = [orientation_list, rebar_list, "", "", "", "", ""]
      
      inputs = UI.inputbox(prompts, defaults, list, "Generate Stirrup 135°")
      return unless inputs
      
      # แปลงค่า input
      is_column = inputs[0] == "Column (Vertical)"
      type = inputs[1]
      spec = REBAR_SPECS[type]
      unless spec
        show_error("Unknown rebar type: #{type}")
        return
      end
      
      opts = {
        is_column: is_column,
        type: type,
        dia: spec[:dia],
        weight_per_m: spec[:w],
        color_name: spec[:color],
        width: inputs[2].to_f.m,
        depth: inputs[3].to_f.m,
        cover: inputs[4].to_f.m,
        member_len: inputs[5].to_f.m,
        spacing: inputs[6].to_f.m
      }

      generate_system(opts)
    end

    def self.generate_system(opts)
      model = Sketchup.active_model
      report_args = nil
      operation_started = false

      begin
        validate_options!(opts)
        positions = build_stirrup_positions(opts[:member_len], opts[:spacing])

        model.start_operation("Create Stirrup 135 System", true)
        operation_started = true

        layer_name = "STR-Rebar-Stirrup"
        layer = model.layers[layer_name] || model.layers.add(layer_name)

        # สร้าง Main Group
        direction_text = opts[:is_column] ? "Vertical" : "Horizontal"
        main_group = model.active_entities.add_group
        main_group.name = "Set: #{opts[:type]} (#{direction_text}) @ #{opts[:spacing].to_m}m"
        main_group.layer = layer

        # สร้าง Component Definition (วาดบนระนาบ XY)
        cover_mm = opts[:cover].to_mm.round
        comp_def_name = "Stirrup_135_#{opts[:type]}_#{opts[:width].to_mm.to_i}x#{opts[:depth].to_mm.to_i}_C#{cover_mm}_H6DB75"
        comp_def = model.definitions[comp_def_name]

        unless comp_def
          comp_def = model.definitions.add(comp_def_name)
          # ส่งค่าไปวาดเส้น Geometry ภายใน Component
          length_per_piece = draw_stirrup_geometry(comp_def.entities, opts)
          comp_def.set_attribute("GoRebar", "unit_length", length_per_piece)
        end

        unit_length = comp_def.get_attribute("GoRebar", "unit_length", 0.0)

        # --- การวาง Component (Array) ---
        positions.each do |dist|
          if opts[:is_column]
            # === เสา (Column) ===
            # วางเรียงขึ้นตามแกน Z (ปกติ)
            tr = Geom::Transformation.translation(Geom::Vector3d.new(0, 0, dist))

          else
            # === คาน (Beam) ===
            # วางเรียงไปตามแกน X (สีแดง)
            # หมุน Component ให้ตั้งขึ้น:
            # - แกน X (Width) -> ไปจับแกน Y โลก
            # - แกน Y (Depth) -> ไปจับแกน Z โลก (ตั้งขึ้น)
            # - แกน Z (Normal) -> ไปจับแกน X โลก (ทิศทางคาน)

            pt_origin = Geom::Point3d.new(dist, 0, 0)

            # ใช้ Transformation.axes เพื่อกำหนดทิศทางใหม่ (Origin, X_Axis, Y_Axis, Z_Axis ใหม่)
            tr = Geom::Transformation.axes(pt_origin, Y_AXIS, Z_AXIS, X_AXIS)
          end

          instance = main_group.entities.add_instance(comp_def, tr)
          instance.layer = layer
        end

        model.commit_operation
        operation_started = false

        # แสดงรายงาน
        count = positions.length
        total_len = unit_length * count
        total_weight = total_len.to_m * opts[:weight_per_m]
        report_args = [opts, count, unit_length, total_len, total_weight]
      rescue => e
        model.abort_operation if operation_started
        log_error(e)
        show_error("Cannot create stirrup system:\n#{e.message}")
        return
      end

      show_report(*report_args) if report_args
    end

    # ฟังก์ชันวาดเส้น (Geometry) - วาดบนระนาบ XY เสมอ
    def self.draw_stirrup_geometry(entities, opts)
      width = opts[:width]
      depth = opts[:depth]
      dia = opts[:dia]
      cover = opts[:cover]
      
      radius = dia / 2.0
      offset_val = cover + radius
      
      # ขนาดแกนกลาง
      w_center = width - 2 * offset_val
      h_center = depth - 2 * offset_val
      
      bend_r = 2.0 * dia
      z_clash_offset = dia 
      
      # สูตรปลายขา (135 องศา)
      min_hook = 6 * dia
      hook_len = [min_hook, 75.mm].max 

      # จุดศูนย์กลางโค้ง 4 มุม (Local XY)
      c_tl = Geom::Point3d.new(0, 0, 0)
      c_tr = Geom::Point3d.new(w_center - 2*bend_r, 0, 0)
      # สังเกต: แกน Y ลงล่าง (Negative) เพื่อให้สอดคล้องกับการมอง Top View
      c_br = Geom::Point3d.new(w_center - 2*bend_r, -(h_center - 2*bend_r), 0)
      c_bl = Geom::Point3d.new(0, -(h_center - 2*bend_r), 0)

      all_points = []
      
      # 1. START HOOK (มุดเข้าใน SE)
      start_arc_pt = get_circle_point(c_tl, bend_r, 225.degrees)
      vec_tail_start = Geom::Vector3d.new(1, -1, 0).normalize
      start_tip = start_arc_pt.offset(vec_tail_start, hook_len)
      
      all_points << start_tip
      all_points.concat(get_arc_points(c_tl, bend_r, 225, 90)) # CW
      
      # 2. MAIN LOOP (วนตามเข็ม)
      all_points.concat(get_arc_points(c_tr, bend_r, 90, 0))   # Top
      all_points.concat(get_arc_points(c_br, bend_r, 0, 270))  # Right
      all_points.concat(get_arc_points(c_bl, bend_r, 270, 180))# Bottom
      
      # 3. END HOOK (มุดเข้าใน SE + ยกหลบ)
      end_hook_points = []
      end_hook_points.concat(get_arc_points(c_tl, bend_r, 180, 45)) # Left -> 45
      
      end_arc_pt = get_circle_point(c_tl, bend_r, 45.degrees)
      vec_tail_end = Geom::Vector3d.new(1, -1, 0).normalize
      end_tip = end_arc_pt.offset(vec_tail_end, hook_len)
      
      end_hook_points << end_tip
      
      # ยกขาจบขึ้น (Z Offset)
      tr_lift = Geom::Transformation.translation(Geom::Vector3d.new(0, 0, z_clash_offset))
      end_hook_points.each { |pt| pt.transform!(tr_lift) }
      
      all_points.concat(end_hook_points)

      # จัดตำแหน่งให้ระยะ cover อ้างอิงจากผิวนอกเหล็กจริง
      cover_axis_offset = offset_val + bend_r
      tr_pos = Geom::Transformation.translation(Geom::Vector3d.new(cover_axis_offset, -cover_axis_offset, 0))
      all_points.each { |pt| pt.transform!(tr_pos) }
      
      # สร้างเส้นและ Follow Me
      path = entities.add_curve(all_points)
      raise "Unable to create stirrup path." if path.nil? || path.empty?
      
      # คำนวณความยาว
      total_length = 0.0
      path.each { |edge| total_length += edge.length }

      # สร้างหน้าตัด
      start_pt = all_points[0]
      next_pt = all_points[1]
      vec = next_pt - start_pt
      raise "Invalid stirrup path: first segment is too short." if vec.length < 0.001
      vec.normalize!
      
      # !!! จุดสำคัญ: ใช้ 8 เหลี่ยม (segments) เพื่อความลื่น !!!
      circle = entities.add_circle(start_pt, vec, radius, 8)
      face = entities.add_face(circle)
      raise "Unable to create rebar cross-section face." unless face
      
      face.reverse! if face.normal.dot(vec) > 0
      face.followme(path.select{|e| e.is_a?(Sketchup::Edge)})
      
      # ใส่สี
      mat_name = "Rebar_#{opts[:type]}"
      mat = Sketchup.active_model.materials[mat_name]
      unless mat
        mat = Sketchup.active_model.materials.add(mat_name)
        mat.color = opts[:color_name]
      end
      entities.each { |e| e.material = mat if e.is_a?(Sketchup::Face) }

      return total_length
    end
    
    # HTML Report
    def self.show_report(opts, count, unit_len, total_len, weight)
      orientation_str = opts[:is_column] ? "Column (Vertical)" : "Beam (Horizontal)"
      
      dlg = UI::HtmlDialog.new(
        {
          :dialog_title => "Stirrup 135 Estimation Report",
          :preferences_key => "com.gorebar.report135",
          :width => 400, :height => 550,
          :min_width => 300, :min_height => 300
        })
      
      html = <<-EOT
        <!DOCTYPE html>
        <html>
        <head>
          <style>
            body { font-family: 'Segoe UI', sans-serif; padding: 20px; background-color: #f9f9f9; }
            h2 { color: #b71c1c; border-bottom: 3px solid #b71c1c; padding-bottom: 10px; margin-top: 0; }
            .card { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 4px 12px rgba(0,0,0,0.15); }
            table { width: 100%; border-collapse: collapse; margin-top: 15px; }
            td { padding: 10px; border-bottom: 1px solid #eee; font-size: 14px; }
            .label { font-weight: 600; color: #555; }
            .val { text-align: right; color: #000; font-family: monospace; font-size: 15px; }
            .total-box { background-color: #ffebee; border-radius: 6px; padding: 15px; margin-top: 20px; }
            .total-row td { border-bottom: none; font-size: 16px; font-weight: bold; color: #b71c1c; }
            .footer { margin-top: 20px; text-align: center; color: #aaa; font-size: 12px; }
          </style>
        </head>
        <body>
          <div class="card">
            <h2>Stirrup 135&deg; Report</h2>
            <table>
              <tr><td class="label">Orientation</td><td class="val">#{orientation_str}</td></tr>
              <tr><td class="label">Rebar Type</td><td class="val"><strong>#{opts[:type]}</strong></td></tr>
              <tr><td class="label">Section (WxD)</td><td class="val">#{(opts[:width].to_m).round(2)} x #{(opts[:depth].to_m).round(2)} m</td></tr>
              <tr><td class="label">Hook Type</td><td class="val">135&deg; (6db, min 75mm)</td></tr>
              <tr><td class="label">Spacing</td><td class="val">@ #{opts[:spacing].to_m} m</td></tr>
              <tr><td class="label">Member Length</td><td class="val">#{opts[:member_len].to_m} m</td></tr>
              <tr><td class="label">Quantity</td><td class="val"><strong>#{count}</strong> pcs</td></tr>
              <tr><td class="label">Length/Pcs</td><td class="val">#{unit_len.to_m.round(3)} m</td></tr>
            </table>
            
            <div class="total-box">
              <table>
                <tr class="total-row">
                  <td>Total Length</td>
                  <td class="val">#{total_len.to_m.round(2)} m</td>
                </tr>
                <tr class="total-row">
                  <td>Total Weight</td>
                  <td class="val">#{weight.round(2)} kg</td>
                </tr>
              </table>
            </div>
          </div>
          <div class="footer">GoRebar Calculation System</div>
        </body>
        </html>
      EOT
      
      dlg.set_html(html)
      dlg.show
    end

    def self.validate_options!(opts)
      raise ArgumentError, "Unknown rebar type: #{opts[:type]}" unless REBAR_SPECS[opts[:type]]
      raise ArgumentError, "Spacing must be greater than 0." unless opts[:spacing] && opts[:spacing] > 0
      raise ArgumentError, "Member length must be greater than 0." unless opts[:member_len] && opts[:member_len] > 0
      raise ArgumentError, "Rebar diameter must be greater than 0." unless opts[:dia] && opts[:dia] > 0
      raise ArgumentError, "Cover must be 0 or greater." unless opts[:cover] && opts[:cover] >= 0
      raise ArgumentError, "Width must be greater than 0." unless opts[:width] && opts[:width] > 0
      raise ArgumentError, "Depth must be greater than 0." unless opts[:depth] && opts[:depth] > 0

      radius = opts[:dia] / 2.0
      bend_r = 2.0 * opts[:dia]
      min_section = 2 * (opts[:cover] + radius + bend_r)

      if opts[:width] <= min_section
        raise ArgumentError, "Width is too small. Minimum is greater than #{min_section.to_mm.round(1)} mm."
      end

      if opts[:depth] <= min_section
        raise ArgumentError, "Depth is too small. Minimum is greater than #{min_section.to_mm.round(1)} mm."
      end
    end

    def self.build_stirrup_positions(member_len, spacing)
      tolerance = 0.001
      positions = [0.0]
      dist = spacing

      while dist < member_len - tolerance
        positions << dist
        dist += spacing
      end

      positions << member_len if (member_len - positions[-1]).abs > tolerance
      positions
    end

    def self.show_error(message)
      UI.messagebox(message)
    rescue
      puts message
    end

    def self.log_error(error)
      if error.respond_to?(:full_message)
        puts error.full_message
      else
        puts "#{error.class}: #{error.message}"
        puts error.backtrace.join("\n") if error.backtrace
      end
    end

    # Helper Functions
    def self.get_arc_points(center, radius, start_deg, end_deg, segments=8)
      points = []
      s = start_deg % 360
      e = end_deg % 360
      diff = e - s
      sweep = diff
      sweep -= 360 if sweep > 0 
      step = sweep / segments.to_f
      (0..segments).each do |i|
        deg = s + (step * i)
        rad = deg.degrees
        x = center.x + radius * Math.cos(rad)
        y = center.y + radius * Math.sin(rad)
        points << Geom::Point3d.new(x, y, 0)
      end
      points
    end
    
    def self.get_circle_point(center, radius, angle_rad)
      x = center.x + radius * Math.cos(angle_rad)
      y = center.y + radius * Math.sin(angle_rad)
      Geom::Point3d.new(x, y, 0)
    end
  end
end

GoRebar::StirrupSystem135.show_dialog
