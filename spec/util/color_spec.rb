XY_RED    = [0.6915, 0.3083]
XY_GREEN  = [0.1700, 0.7000]
XY_BLUE   = [0.1532, 0.0475]
XY_WHITE  = [0.3127, 0.3290]

XYB_RED   = XY_RED   + [100]
XYB_GREEN = XY_GREEN + [100]
XYB_BLUE  = XY_BLUE  + [100]
XYB_WHITE = XY_WHITE + [100]

describe Mechahue::Color do
  describe "::mirek_to_xy_table" do
    it "is a hash" do
      expect(Mechahue::Color.mirek_to_xy_table).to be_a(Hash)
    end

    it "is keyed by integers for every value in [153, 500]" do
      table = Mechahue::Color.mirek_to_xy_table
      (153..500).to_a.each do |n|
        expect(table.has_key?(n)).to be_truthy
      end
    end

    it "contains an array of x, y coordinates for each temperature" do
      Mechahue::Color.mirek_to_xy_table.each do |key, value|
        expect(key).to be_a(Numeric)
        expect(value).to be_a(Array)
        expect(value.length).to be >= 2
        expect(value[0]).to be_a(Numeric)
        expect(value[1]).to be_a(Numeric)
      end
    end
  end

  describe "::from_rgb" do
    it "returns a Color" do
      expect(Mechahue::Color.from_rgb([0.5, 0.5, 0.5])).to be_a(Mechahue::Color)
    end

    it "creates colors of low brightness for very low RGB values" do
      color = Mechahue::Color.from_rgb([0.0, 0.0, 0.0])
      expect(color.brightness).to eq 0.0
    end

    it "creates colors of medium brightness for medium RGB values" do
      color = Mechahue::Color.from_rgb([0.75, 0.75, 0.75])
      expect(color.brightness.round).to be_within(5).of(50)
    end

    it "creates colors of high brightness for very high RGB values" do
      color = Mechahue::Color.from_rgb([1.0, 1.0, 1.0])
      expect(color.brightness.round).to eq 100
    end
  end

  describe "::from_hsl" do
    it "returns a Color" do
      expect(Mechahue::Color.from_hsl([0.0, 1.0, 1.0])).to be_a(Mechahue::Color)
    end

    it "creates colors of low brightness for low luminance values" do
      color = Mechahue::Color.from_hsl([0.0, 1.0, 0.0])
      expect(color.brightness).to eq(0)
    end

    it "creates colors of high brightness for high luminance values" do
      color = Mechahue::Color.from_hsl([0.0, 1.0, 1.0])
      expect(color.brightness.round).to eq(100)
    end
  end

  describe "::from_mb" do
    it "returns a Color" do
      expect(Mechahue::Color.from_mb([170, 100.0])).to be_a(Mechahue::Color)
    end

    it "matches the xy coordinates from the mirek_to_xy_table" do
      samples = [153, 172, 291, 358, 494, 500]
      samples.each do |sample|
        expect(Mechahue::Color.from_mb([sample, 100.0]).xyb[0..1]).to eq Mechahue::Color.mirek_to_xy_table[sample][0..1]
      end
    end

    it "matches the supplied brightness" do
      expect(Mechahue::Color.from_mb([170, 12.34]).brightness).to eq 12.34
    end
  end

  describe "::from_xyb" do
    it "returns a Color" do
      expect(Mechahue::Color.from_xyb([0.3129, 0.3289, 100.0])).to be_a(Mechahue::Color)
    end

    it "matches the supplied xyb values" do
      xyb = [0.3129, 0.3289, 23.0]
      color = Mechahue::Color.from_xyb(xyb)
      expect(color.xyb).to eq(xyb)
    end
  end

  describe "::from_hex" do
    it "accepts color strings prefixed with a #" do
      expect(Mechahue::Color.from_xyb("ffffff")).to be_a(Mechahue::Color)
    end

    it "accepts color strings that are not prefixed with a #" do
      color1 = Mechahue::Color.from_hex("#ffffff")
      color2 = Mechahue::Color.from_hex("ffffff")
      expect(color1.xyb).to eq color2.xyb
    end

    it "matches the supplied rgb values" do
      values = [ 0.0, 32.0/255.0, 127.0/255.0, 173.0/255.0, 1.0]
      rgb_sets = []
      values.each do |red|
        values.each do |green|
          values.each do |blue|
            rgb_sets << [red, green, blue]
          end
        end
      end

      rgb_sets.each do |rgb|
        hex = rgb.map { |c| sprintf("%02x", (255*c).round.to_i) }.join
        color = Mechahue::Color.from_hex(hex)
        color.to_rgb.each_with_index do |value, index| 
          expect(value).to be_within(1e-6).of rgb[index]
        end
      end
    end
  end

  describe "::from_light" do
    context "when given a Resource::Light object" do
      it "returns a color" do
        info = {dimming:{brightness:53}, color: {xy: {x: 0.3, y: 0.4}}}
        light = Mechahue::Resource::Light.new(nil, info)
        expect(Mechahue::Color.from_light(light)).to be_a(Mechahue::Color)
      end

      it "matches the indicated xy coordinates and brightness" do
        info = {dimming:{brightness:53}, color: {xy: {x: 0.3, y: 0.4}}}
        light = Mechahue::Resource::Light.new(nil, info)
        color = Mechahue::Color.from_light(light)
        expect(color.xyb).to eq [0.3, 0.4, 53]
      end
    end

    context "when given a Hue CLIP API V2 information hash" do
      it "returns a Color" do
        info = {dimming:{brightness:53}, color: {xy: {x: 0.3, y: 0.4}}}
        expect(Mechahue::Color.from_light(info)).to be_a(Mechahue::Color)
      end

      it "matches the indicated xy coordinates and brightness" do
        info = {dimming:{brightness:53}, color: {xy: {x: 0.3, y: 0.4}}}
        expect(Mechahue::Color.from_light(info).xyb).to eq [0.3, 0.4, 53]
      end
    end
  end

  describe ".initialize" do
    it "initializes the instance with xyb coordinates" do
      xyb = [0.1, 0.2, 3]
      expect(Mechahue::Color.new(xyb).xyb).to eq xyb
    end
  end

  describe ".to_rgb" do
    it "returns an array of 3 floats" do
      rgb = Mechahue::Color.from_xyb([0.3, 0.4, 53]).to_rgb
      expect(rgb.length).to eq 3
      expect(rgb[0]).to be_a(Float)
      expect(rgb[1]).to be_a(Float)
      expect(rgb[2]).to be_a(Float)
    end

    it "ensures each float ranges between 0.0 and 1.0" do
      colors = [XYB_RED, XYB_GREEN, XYB_BLUE, XYB_WHITE].map { |xyb| Mechahue::Color.from_xyb(xyb) }
      colors.each do |color|
        color.to_rgb.each { |ch| expect(ch).to be >= 0.0 }
        color.to_rgb.each { |ch| expect(ch).to be <= 1.0 }
      end
    end

    it "shows lots of red for very red colors" do
      rgb = Mechahue::Color.from_xyb(XYB_RED).to_rgb
      expect(rgb[0]).to be_within(1e-3).of (1.0)
    end

    it "shows little red for very not-red colors" do
      rgb = Mechahue::Color.from_xyb([0.15, 0.45, 100]).to_rgb
      expect(rgb[0]).to be_within(1e-3).of (0.0)
    end

    it "shows lots of green for very green colors" do
      rgb = Mechahue::Color.from_xyb(XYB_GREEN).to_rgb
      expect(rgb[1]).to be_within(1e-3).of (1.0)
    end

    it "shows little green for very not-green colors" do
      rgb = Mechahue::Color.from_xyb(XYB_BLUE).to_rgb
      expect(rgb[1]).to be_within(1e-3).of (0.0)
    end

    it "shows lots of blue for very blue colors" do
      rgb = Mechahue::Color.from_xyb(XYB_BLUE).to_rgb
      expect(rgb[2]).to be_within(1e-3).of (1.0)
    end

    it "shows little blue for very not-blue colors" do
      rgb = Mechahue::Color.from_xyb(XYB_RED).to_rgb
      expect(rgb[2]).to be_within(1e-3).of (0.0)
    end

    it "shows lots of all 3 channels for very bright colors" do
      rgb = Mechahue::Color.from_xyb([0.32, 0.32, 100]).to_rgb
      expect(rgb[0]).to be_within(0.05).of (1.0)
      expect(rgb[1]).to be_within(0.05).of (1.0)
      expect(rgb[2]).to be_within(0.05).of (1.0)
    end
  end

  describe ".to_hsl" do
    it "returns an array of 3 floats" do
      hsl = Mechahue::Color.from_xyb(XYB_GREEN).to_hsl
      expect(hsl).to be_a(Array)
      expect(hsl.length).to eq 3
      expect(hsl[0]).to be_a(Float)
      expect(hsl[1]).to be_a(Float)
      expect(hsl[2]).to be_a(Float)
    end

    it "ensures the hue ranges between 0.0 and 2π" do
      axis = [0.32, 0.32]
      radius = 0.2
      step = 0.01
      angle = 0.00

      while angle <= 4*Math::PI do
        x = axis[0] + radius * Math.cos(angle)
        y = axis[1] + radius * Math.sin(angle)

        hsl = Mechahue::Color.from_xyb([x, y, 100]).to_hsl
        expect(hsl[0]).to be >= 0.0
        expect(hsl[0]).to be <  2*Math::PI

        angle += step
      end
    end

    it "ensures the saturation ranges between 0.0 and 1.0" do
      axis = [0.32, 0.32]
      angle_step = 0.01
      angle = 0.00
      radius = 0.00
      radius_step = 0.2 / 12*Math::PI * angle_step

      while angle <= 12*Math::PI do
        x = axis[0] + radius * Math.cos(angle)
        y = axis[1] + radius * Math.sin(angle)

        hsl = Mechahue::Color.from_xyb([x, y, 100]).to_hsl
        expect(hsl[1]).to be >= 0.0
        expect(hsl[1]).to be <= 1.0

        angle += angle_step
        radius += radius_step
      end
    end

    it "ensures that the luminance ranges between 0.0 and 1.0" do
      brightness = 0
      while brightness <= 100 do
        hsl = Mechahue::Color.from_xyb([0.32, 0.32, brightness]).to_hsl
        expect(hsl[2]).to be >= 0.0
        expect(hsl[2]).to be <  1.0

        brightness += 1
      end
    end

    it "shows a hue near 0 for deep red colors" do
      color = Mechahue::Color.from_rgb([1.0, 0.0, 0.0])
      expect(color.to_hsl[0]).to be_within(4.8481368111e-06).of 0.0 # 4.848e-6 =~ 1 arcsecond
    end

    it "shows a hue near 2π/3 for deep green colors" do
      color = Mechahue::Color.from_rgb([0.0, 1.0, 0.0])
      expect(color.to_hsl[0]).to be_within(4.8481368111e-06).of 2*Math::PI/3 # 4.848e-6 =~ 1 arcsecond
    end

    it "shows a hue near 4π/3 for deep blue colors" do
      color = Mechahue::Color.from_rgb([0.0, 0.0, 1.0])
      expect(color.to_hsl[0]).to be_within(4.8481368111e-06).of 4*Math::PI/3 # 4.848e-6 =~ 1 arcsecond
    end

    it "shows a saturation near 1.0 for very vivid colors" do
      color = Mechahue::Color.from_rgb([1.0, 0.0, 0.0])
      expect(color.to_hsl[1]).to be_within(1e-6).of 1.0
    end

    it "shows a saturation near 0.0 for very faded colors" do
      color = Mechahue::Color.from_rgb([0.5, 0.5, 0.5])
      expect(color.to_hsl[1]).to be_within(1e-6).of 0.0
    end

    it "shows low luminance for dim colors" do
      color = Mechahue::Color.from_rgb([0.01, 0.0, 0.0])
      expect(color.to_hsl[2]).to be_within(1e-2).of 0.0
    end

    it "shows high luminance for bright colors" do
      color = Mechahue::Color.from_rgb([1.0, 1.0, 1.0])
      expect(color.to_hsl[2]).to be_within(1e-4).of 1.0
    end
  end

  describe ".to_mirek" do
    it "returns an number between 153 and 500" do
      axis = [0.32, 0.32]
      radius = 0.2
      step = 0.01
      angle = 0.00

      while angle <= 4*Math::PI do
        x = axis[0] + radius * Math.cos(angle)
        y = axis[1] + radius * Math.sin(angle)

        mirek = Mechahue::Color.from_xyb([x, y, 100]).to_mirek
        expect(mirek).to be >= 153
        expect(mirek).to be <= 500

        angle += step
      end
    end

    it "correlates positively to x-values" do
      x0, y0 = [0.29, 0.29]
      step = 0.001
      x = x0
      last_mirek = 0

      while x < 0.6
        mirek = Mechahue::Color.from_xyb([x, y0, 100]).to_mirek
        expect(mirek).to be > last_mirek
        x += step
      end
    end

    it "returns a mirek value for non-mirek colors" do
      mirek = Mechahue::Color.from_xyb(XYB_RED).to_mirek
      expect(mirek).to be_a(Numeric)
      expect(mirek).to be >= 0.0
      expect(mirek).to be <= 500.0
    end

    it "matches the original mirek value when constructed from a mirek value" do
      (153 .. 500).to_a.each do |mirek|
        reverse_mirek = Mechahue::Color.from_mb([mirek, 100]).to_mirek
        expect(reverse_mirek).to be_within(1e-3).of mirek
      end
    end
  end

  describe ".to_mb" do
    it "returns an array containing mirek value and brightness" do
      mb = [350, 64]
      color = Mechahue::Color.from_mb([350, 64])
      expect(color.to_mb).to eq mb
    end
  end

  describe ".to_xyb" do
    it "returns an array of 3 numbers" do
      color = Mechahue::Color.from_rgb([1.0, 0.2, 0.6])
      xyb = color.to_xyb
      expect(xyb.length).to eq 3
      expect(xyb[0]).to be_a(Float)
      expect(xyb[1]).to be_a(Float)
      expect(xyb[2]).to be_a(Float)
    end

    it "matches the original xyb provided at instantiation" do
      xyb = [0.54, 0.32, 78]
      color = Mechahue::Color.from_xyb(xyb)
      expect(color.xyb).to eq xyb
    end
  end

  describe ".to_light" do
    it "produces a hash suitable for passing to Light services in the Hue CLIP API V2" do
      info = Mechahue::Color.from_xyb(XYB_RED).to_light
      expect(info).to be_a(Hash)
      expect(info[:color]).to be_a(Hash)
      expect(info[:color][:xy]).to be_a(Hash)
      expect(info[:color][:xy][:x]).to be_a Numeric
      expect(info[:color][:xy][:y]).to be_a Numeric
      expect(info[:dimming]).to be_a(Hash)
      expect(info[:dimming][:brightness]).to be_a Numeric
    end

    it "includes accurate xy and brightness data" do
      info = Mechahue::Color.from_xyb(XYB_RED).to_light
      expect(info[:color][:xy][:x]).to eq XYB_RED[0]
      expect(info[:color][:xy][:y]).to eq XYB_RED[1]
      expect(info[:dimming][:brightness]).to eq XYB_RED[2]
    end
  end

  describe ".to_light_xy" do
    it "produces a hash suitable for passing as a color in the Hue CLIP API V2" do
      info = Mechahue::Color.from_xyb(XYB_RED).to_light
      expect(info).to be_a(Hash)
      expect(info[:color]).to be_a(Hash)
      expect(info[:color][:xy]).to be_a(Hash)
      expect(info[:color][:xy][:x]).to be_a Numeric
      expect(info[:color][:xy][:y]).to be_a Numeric
    end

    it "includes accurate xy data" do
      info = Mechahue::Color.from_xyb(XYB_RED).to_light
      expect(info[:color][:xy][:x]).to eq XYB_RED[0]
      expect(info[:color][:xy][:y]).to eq XYB_RED[1]
    end
  end

  describe ".to_hex" do
    it "produces a # followed by a six-character lowercase hex string" do
      hex = Mechahue::Color.from_xyb(XYB_RED).to_hex
      expect(hex.length).to eq 7
      expect(hex[0]).to eq "#"
      expect(hex[1..-1]).to match(/[0-9a-f]{6}/)
    end

    it "accurately reflects the rgb values of the color" do
      step_size = 1.0/32.0
      reds = (0..32).to_a.map { |x| x * step_size }
      blues = (0..32).to_a.map { |x| x * step_size }
      greens = (0..32).to_a.map { |x| x * step_size }

      reds.each do |red|
        greens.each do |green|
          blues.each do |blue|
            rgb = [red, green, blue]
            color = Mechahue::Color.from_rgb(rgb)
            actual_rgb = color.to_rgb # account for some rounding error in the rgb->xyb conversion; excessive error here is beyond the scope of this test
            expected_hex = "#" + actual_rgb.map { |x| sprintf("%02x", (255*x).round(0).to_i) }.join
            expect(color.to_hex).to eq expected_hex
          end
        end
      end
    end

    it "returns the original hex color code when the color was instantiated with from_hex" do
      rng = Random.new(80085)
      2000.times do
        original_hex = "#" + rng.bytes(3).unpack("CCC").map { |x| sprintf("%02x", x) }.join
        color = Mechahue::Color.from_hex(original_hex)
        expect(color.to_hex).to eq original_hex
      end
    end
  end

  describe ".brightness" do
    it "returns a number" do
      color = Mechahue::Color.from_xyb([0.32, 0.32, 61])
      expect(color.brightness).to be_a(Numeric)
    end

    it "reflects the brightness value given at instantiation" do
      color = Mechahue::Color.from_xyb([0.32, 0.32, 61])
      expect(color.brightness).to eq 61
    end
  end

  describe ".white?" do
    it "returns true if the original value was constructed from a mirek value" do
      Mechahue::Color.mirek_to_xy_table.keys.each_with_index do |mirek, n|
        color = Mechahue::Color.from_mb([mirek, n % 100])
        expect(color.white?).to eq true
      end
    end

    it "returns true if the original value was constructed from a color very near a mirek value" do
      Mechahue::Color.mirek_to_xy_table.keys.each_with_index do |mirek, n|
        x, y = Mechahue::Color.mirek_to_xy_table[mirek]
        x += 0.0005
        y -= 0.0005

        color = Mechahue::Color.from_xyb([x, y, 100])
        expect(color.white?).to eq true
      end
    end

    it "returns false if the original value was not constructed from a color near a mirek value" do
      Mechahue::Color.mirek_to_xy_table.keys.each_with_index do |mirek, n|
        x, y = Mechahue::Color.mirek_to_xy_table[mirek]
        x += 0.01
        y -= 0.01

        color = Mechahue::Color.from_xyb([x, y, 100])
        expect(color.white?).to eq false
      end
    end
  end

  describe ".rotate_hue" do
    it "returns a new Color object" do
      color = Mechahue::Color.from_xyb(XYB_RED)
      expect(color.rotate_hue(0.1)).to be_a(Mechahue::Color)
    end

    it "makes a color whose hue is in the interval [0.0, 2π]" do
      color = Mechahue::Color.from_xyb(XYB_RED)
      angle = 0.0
      step = 0.2

      while angle <= 4*Math::PI do
        hue = color.rotate_hue(angle).to_hsl[0]
        expect(hue).to be >= 0
        expect(hue).to be <  2*Math::PI

        angle += step
      end
    end

    it "makes a color whose hue is congruent with the original hue plus the given angle in radians" do
      color = Mechahue::Color.from_xyb(XYB_GREEN)
      original_hue = color.to_hsl[0]
      angles = [ 0.0, Math::PI/3, 2*Math::PI/3, 3*Math::PI/3, 4*Math::PI/3, 5*Math::PI/3, 6*Math::PI/3, 7*Math::PI/3 ]
      
      angles.each do |angle|
        expected_hue = (original_hue + angle) % (2*Math::PI)
        hue = color.rotate_hue(angle).to_hsl[0]
        expect(hue).to be_within(4.8481368111e-06).of(expected_hue) # 4.8481368111e-06 =~ 1 arcsecond
      end
    end

    it "makes a color whose saturation is identical to the original color" do
      color = Mechahue::Color.from_hex("#7e194f")
      original_sat = color.to_hsl[1]
      angles = [ 0.0, Math::PI/3, 2*Math::PI/3, 3*Math::PI/3, 4*Math::PI/3, 5*Math::PI/3, 6*Math::PI/3, 7*Math::PI/3 ]
      
      angles.each do |angle|
        sat = color.rotate_hue(angle).to_hsl[1]
        expect(sat).to be_within(1e-8).of(original_sat)
      end
    end

    it "makes a color whose luminance is identical to the original color" do
      color = Mechahue::Color.from_hex("#7e194f")
      original_lum = color.to_hsl[1]
      angles = [ 0.0, Math::PI/3, 2*Math::PI/3, 3*Math::PI/3, 4*Math::PI/3, 5*Math::PI/3, 6*Math::PI/3, 7*Math::PI/3 ]
      
      angles.each do |angle|
        lum = color.rotate_hue(angle).to_hsl[1]
        expect(lum).to be_within(1e-8).of(original_lum)
      end
    end

    it "can make a series of fine steps around the color wheel and return approximately where it started" do
      last_color = original_color = Mechahue::Color.from_hex("#1f8d47")
      total_steps = 256
      step = 2*Math::PI / total_steps

      total_steps.times do |n|
        last_color = last_color.rotate_hue(step)
      end

      expect(last_color.to_xyb[0]).to be_within(1e-6).of(original_color.to_xyb[0])
      expect(last_color.to_xyb[1]).to be_within(1e-6).of(original_color.to_xyb[1])
      expect(last_color.to_xyb[2]).to be_within(1e-6).of(original_color.to_xyb[2])
    end
  end

  describe ".navigate" do
    it "returns a new Color object" do
      expect(Mechahue::Color.from_xyb(XYB_WHITE).navigate(1.0, 0.1)).to be_a(Mechahue::Color)
    end

    it "makes a color whose x,y-distance from the original matches the supplied distance" do
      angles = 256.times.map { |n| 2*Math::PI/256.0 * n }
      angles.each_with_index do |angle, n|
        distance = 0.1 / 256 * n
        original_color = Mechahue::Color.from_xyb(XYB_WHITE)

        new_color = original_color.navigate(angle, distance)
        distance = ((new_color.to_xyb[0] - original_color.to_xyb[0])**2 + (new_color.to_xyb[1] - original_color.to_xyb[1])**2)**0.5
        expect(distance).to be_within(1e-6).of(distance)
      end
    end

    it "makes a color at the given angle from the original color" do
      angles = 256.times.map { |n| 2*Math::PI/256.0 * n }
      angles.each_with_index do |angle, n|
        original_color = Mechahue::Color.from_xyb(XYB_WHITE)
        new_color = original_color.navigate(angle, 0.1 / 256 * n)
        delta_x, delta_y = [new_color.to_xyb[0] - original_color.to_xyb[0], new_color.to_xyb[1] - original_color.to_xyb[1]]

        angle = Math::atan2(delta_y, delta_x)
        expect(angle).to be_within(1e-6).of(angle)
      end
    end
  end

  describe ".add_hsl" do
    it "returns a new Color object" do
      original_color = Mechahue::Color.from_hsl([2*Math::PI/3, 0.5, 0.5])
      new_color = original_color.add_hsl([0.1, 0.1, 0.1])
      expect(new_color).to be_a(Mechahue::Color)
    end

    it "makes a color whose hue is in the interval [0.0, 2π]" do
      original_color = Mechahue::Color.from_hsl([2*Math::PI/3, 0.5, 0.5])
      new_color = original_color.add_hsl([5*Math::PI/3, 0, 0])
      expect(new_color.to_hsl[0]).to be_within(1e-6).of(Math::PI/3)
    end

    it "makes a color whose saturation is clipped to the interval [0.0, 1.0]" do
      original_color = Mechahue::Color.from_hsl([2*Math::PI/3, 0.5, 0.5])
      new_color = original_color.add_hsl([0, 2.0, 0])
      expect(new_color.to_hsl[1]).to be_within(1e-6).of(1.0)
      expect(new_color.to_hsl[1]).to be <= 1.0
    end

    it "makes a color whose saturation is the sum of the current saturation and the supplied value" do
      original_color = Mechahue::Color.from_hsl([2*Math::PI/3, 0.5, 0.5])
      new_color = original_color.add_hsl([0, 0.2, 0])
      expect(new_color.to_hsl[1]).to be_within(1e-6).of(0.7)
    end

    it "makes a color whose luminance is clipped to the interval [0.0, 1.0]" do
      original_color = Mechahue::Color.from_hsl([2*Math::PI/3, 0.5, 0.5])
      new_color = original_color.add_hsl([0, 0, 2.0])
      expect(new_color.to_hsl[2]).to be_within(1e-6).of(1.0)
      expect(new_color.to_hsl[2]).to be <= 1.0
    end

    it "makes a color whose luminance is the sum of the current luminance and the supplied value" do
      original_color = Mechahue::Color.from_hsl([2*Math::PI/3, 0.5, 0.5])
      new_color = original_color.add_hsl([0, 0, 0.2])
      expect(new_color.to_hsl[2]).to be_within(1e-6).of(0.7)
    end
  end

  describe ".add_mirek" do
    it "returns a new Color object" do
      original_color = Mechahue::Color.from_mb([300, 100])
      new_color = original_color.add_mirek(10)
      expect(new_color).to be_a(Mechahue::Color)
    end

    it "returns a color object whose mirek temperature is equal to the current color plus the requested difference" do
      original_color = Mechahue::Color.from_mb([300, 100])
      new_color = original_color.add_mirek(10)
      expect(new_color.to_mirek).to eq(310)
    end

    it "returns a color object for which that_color.white? is true" do
      original_color = Mechahue::Color.from_mb([300, 100])
      new_color = original_color.add_mirek(10)
      expect(new_color.white?).to eq true
    end
  end

  describe ".color_text_fg" do
    it "returns a String" do
      color = Mechahue::Color.from_xyb(XYB_RED)
      text = color.color_text_fg("foo")
      expect(text).to be_a(String)
    end

    it "includes the requested string" do
      color = Mechahue::Color.from_xyb(XYB_RED)
      text = color.color_text_fg("if it wasn't for that horse")
      expect(text).to include("if it wasn't for that horse")
    end

    it "has terminal control codes to apply present color to foreground" do
      color = Mechahue::Color.from_xyb(XYB_RED)
      r,g,b = color.to_rgb.map { |x| (255*x).round(0).to_i }
      text = color.color_text_fg("if it wasn't for that horse")
      expect(text.start_with?("\x1b[38;2;#{r};#{g};#{b}m")).to eq true
    end

    it "has terminal control codes to end colored section" do
      color = Mechahue::Color.from_xyb(XYB_RED)
      r,g,b = color.to_rgb.map { |x| (255*x).round(0).to_i }
      text = color.color_text_fg("if it wasn't for that horse")
      expect(text.end_with?("\x1b[0m")).to eq true
    end
  end

  describe ".color_text_bg" do
    it "returns a String" do
      color = Mechahue::Color.from_xyb(XYB_RED)
      text = color.color_text_bg("foo")
      expect(text).to be_a(String)
    end

    it "includes the requested string" do
      color = Mechahue::Color.from_xyb(XYB_RED)
      text = color.color_text_bg("if it wasn't for that horse")
      expect(text).to include("if it wasn't for that horse")
    end

    it "has terminal control codes to apply present color to background" do
      color = Mechahue::Color.from_xyb(XYB_RED)
      r,g,b = color.to_rgb.map { |x| (255*x).round(0).to_i }
      text = color.color_text_bg("if it wasn't for that horse")
      expect(text.start_with?("\x1b[48;2;#{r};#{g};#{b}m")).to eq true
    end

    it "has terminal control codes to end colored section" do
      color = Mechahue::Color.from_xyb(XYB_RED)
      r,g,b = color.to_rgb.map { |x| (255*x).round(0).to_i }
      text = color.color_text_bg("if it wasn't for that horse")
      expect(text.end_with?("\x1b[0m")).to eq true
    end
  end

  it "can make lots of conversions between colors without severely distorting the color" do
    original_color = Mechahue::Color.from_hex("#9f5ca3")
    modified = Mechahue::Color.from_hsl(original_color.to_hsl)
    modified = modified.navigate(Math::PI/4, 0.12)
    modified = modified.add_hsl([0, 0, 0.2])
    modified = modified.add_hsl([0, 0, -0.2])
    modified = modified.navigate(Math::PI, 2**0.5 * 0.12)
    6.times { modified = modified.rotate_hue(Math::PI/3) }
    modified = modified.navigate(7*Math::PI/4, 0.12)
    expect(modified.to_hex).to eq "#9f5ca3"
  end
end
