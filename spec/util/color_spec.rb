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

    it "ensures each float ranges between 0.0 and 1.0"

    it "shows lots of red for very red colors" do
      rgb = Mechahue::Color.from_xyb([0.6915, 0.3083, 100]).to_rgb
      expect(rgb[0]).to be_within(1e-3).of (1.0)
    end

    it "shows little red for very not-red colors" do
      rgb = Mechahue::Color.from_xyb([0.15, 0.45, 100]).to_rgb
      expect(rgb[0]).to be_within(1e-3).of (0.0)
    end

    it "shows lots of green for very green colors" do
      rgb = Mechahue::Color.from_xyb([0.1700, 0.7000, 100]).to_rgb
      expect(rgb[1]).to be_within(1e-3).of (1.0)
    end

    it "shows little green for very not-green colors" do
      rgb = Mechahue::Color.from_xyb([0.1532, 0.0475, 100]).to_rgb
      expect(rgb[1]).to be_within(1e-3).of (0.0)
    end

    it "shows lots of blue for very blue colors" do
      rgb = Mechahue::Color.from_xyb([0.1532, 0.0475, 100]).to_rgb
      expect(rgb[2]).to be_within(1e-3).of (1.0)
    end

    it "shows little blue for very not-blue colors" do
      rgb = Mechahue::Color.from_xyb([0.6915, 0.3083, 100]).to_rgb
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
      hsl = Mechahue::Color.from_xyb([0.1700, 0.7000, 100]).to_hsl
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

    it "shows a hue near 0 for deep red colors"
    it "shows a hue near 2π/3 for deep green colors"
    it "shows a hue near 4π/3 for deep blue colors"
    it "shows a saturation near 1.0 for very vivid colors"
    it "shows a saturation near 0.0 for very faded colors"
    it "shows low luminance for dim colors"
    it "shows high luminance for bright colors"
  end

  describe ".to_mirek" do
    it "returns an number between 153 and 500"
    it "correlates positively to x-values"
    it "returns a mirek value for non-mirek colors"
  end

  describe ".to_mb" do
    it "returns an array containing mirek value and brightness"
  end

  describe ".to_xyb" do
    it "returns an array of 3 numbers"
    it "matches the original xyb provided at instantiation"
  end

  describe ".to_light" do
    it "produces a hash suitable for passing to Light services in the Hue CLIP API V2"
    it "includes accurate xy data"
    it "includes accurate brightness data"
  end

  describe ".to_light_xy" do
    it "produces a hash suitable for passing as a color in the Hue CLIP API V2"
    it "includes accurate xy data"
  end

  describe ".to_hex" do
    it "produces a # followed by a six-character lowercase hex string"
    it "accurately reflects the rgb values of the color"
  end

  describe ".brightness" do
    it "returns a number"
    it "reflects the brightness value given at instantiation"
  end

  describe ".white?" do
    it "returns true if the original value was constructed from a mirek value"
    it "returns true if the original value was constructed from a color near a mirek value"
    it "returns false if the original value was not constructed from a color near a mirek value"
  end

  describe ".rotate_hue" do
    it "returns a new Color object"
    it "makes a color whose hue is in the interval [0.0, 2π]"
    it "makes a color whose hue is congruent with the original hue plus the given angle in radians"
    it "makes a color whose saturation is identical to the original color"
    it "makes a color whose luminance is identical to the original color"
    it "can make a series of fine steps around the color wheel and return approximately where it started"
  end

  describe ".navigate" do
    it "returns a new Color object"
    it "makes a color whose x,y-distance from the original matches the supplied distance"
    it "makes a color at the given angle from the original color"
  end

  describe ".add_hsl" do
    it "returns a new Color object"
    it "makes a color whose hue is in the interval [0.0, 2π]"
    it "makes a color whose hue is congruent with the original hue plus the given angle in radians"
    it "makes a color whose saturation is clipped to the interval [0.0, 1.0]"
    it "makes a color whose saturation is the sum of the current saturation and the supplied value"
    it "makes a color whose luminance is clipped to the interval [0.0, 1.0]"
    it "makes a color whose luminance is the sum of the current luminance and the supplied value"
  end

  describe ".add_mirek" do
    it "returns a new Color object"
    it "returns a color object whose mirek temperature is equal to the current color plus the requested difference"
  end

  describe ".color_text_fg" do
    it "returns a String"
    it "includes the requested string"
    it "has terminal control codes"
  end

  describe ".color_text_bg" do
    it "returns a String"
    it "includes the requested string"
    it "has terminal control codes"
  end

  it "can make lots of conversions between colors without severely distorting the color"
end
