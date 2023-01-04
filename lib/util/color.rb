module Mechahue
  class Color
    class << self
      def mirek_to_xy_table
        return @mirek_to_xy_table if @mirek_to_xy_table
        datafile = File.join(File.dirname(__FILE__), "../data/mirek_to_xy_table.json")
        raw_dict = JSON.parse(IO.read(datafile))
        @mirek_to_xy_table = {}
        raw_dict.each do |mirek_str, xy|
          @mirek_to_xy_table[mirek_str.to_i] = xy
        end

        # a hash mapping integer mirek => [x, y]
        @mirek_to_xy_table
      end

      def from_rgb(rgb)
        # rgb = 3-element array of red, green, blue intensities as reals in [0.0, 1.0]
        # from https://github.com/benknight/hue-python-rgb-converter/blob/master/rgbxy/__init__.py
        r, g, b = rgb

        # gamma correction
        r =   r > 0.04045   ?   ((r + 0.055) / 1.055)**2.4   :   (r / 12.92)
        g =   g > 0.04045   ?   ((g + 0.055) / 1.055)**2.4   :   (g / 12.92)
        b =   b > 0.04045   ?   ((b + 0.055) / 1.055)**2.4   :   (b / 12.92)

        # Wide RGB D65 conversion
        xx = 0.664511*r + 0.154324*g + 0.162028*b
        yy = 0.283881*r + 0.668433*g + 0.047685*b
        zz = 0.000088*r + 0.072310*g + 0.986039*b

        x = xx / (xx + yy + zz)
        y = yy / (xx + yy + zz)
        b = 100.0 * yy

        xyb = [x,y,b]
        from_xyb(xyb)
      end
      
      def from_hsl(hsl)
        # hsl = 3-element array of hue, saturation, luminance
        hue, sat, lum = hsl
        pi_over_3 = Math::PI/3.0
        c = (1 - (2*lum - 1).abs) * sat
        x = c * (1 - ( ((hue/pi_over_3) % 2) - 1).abs)
        m = lum - c/2

        hue_prime = (hue / pi_over_3).to_i % 6

        rp, gp, bp = case hue_prime
        when 0
          [ c, x, 0 ]
        when 1
          [ x, c, 0 ]
        when 2
          [ 0, c, x ]
        when 3
          [ 0, x, c ]
        when 4
          [ x, 0, c ]
        when 5
          [ c, 0, x ]
        end

        rgb = [ rp, gp, bp ].map { |v| v + m }
        self.from_rgb(rgb)
      end

      def from_mb(mb)
        # mb = [mirek, brightness]
        # mirek is integer color temperature (philips says to expect [153, 500] range)
        # brightness is light brightness [0, 100]
        table = self.mirek_to_xy_table
        xy = if table[mb[0]] then
          table[mb[0]]
        else
          upper = table.keys.min_by { |mirek| mirek >= mb[0] }
          lower = table.keys.max_by { |mirek| mirek <= mb[0] }
          delta = upper - lower
          alpha = (mb[0] - lower) / delta
          upper.zip(lower).map { |v| alpha*v[0] + (1.0-alpha)*v[1] }
        end

        xyb = [xy[0], xy[1], mb[1]]
        self.from_xyb(xyb)
      end

      def from_xyb(xyb)
        # 3-element array [x, y, b]
        # x, y: CIE XY coordinates, floats [0.0, 1.0]
        # b: brightness, integer [0, 100]
        self.new(xyb)
      end

      def from_hex(hexstr)
        # hexstr = html-style hex code, leading # optional
        hexstr = hexstr[1..-1] if hexstr.start_with?("#")
        rgb = [hexstr[0..1], hexstr[2..3], hexstr[4..5]].map { |pair| pair.to_i(16) / 255.0 }
        self.from_rgb(rgb)
      end

      def from_light(light)
        xyb = [light[:color][:xy][:x], light[:color][:xy][:y], light[:dimming][:brightness]]
        self.from_xyb(xyb)
      end

      def default_gamut
        { # Hue Gamut C
          red:   { x: 0.6915, y: 0.3083 },
          green: { x: 0.1700, y: 0.7000 },
          blue:  { x: 0.1532, y: 0.0475 },
        }
      end
    end

    attr_reader :xyb

    def initialize(xyb)
      @xyb = xyb
    end

    def to_rgb
      # from https://github.com/benknight/hue-python-rgb-converter/blob/master/rgbxy/__init__.py

      x, y, b = xyb
      z = 1.0 - x - y
      yy = b / 100.0
      xx = (yy / y) * x
      zz = (yy / y) * z

      # sRGB D65 conversion
      r =  1.656492 * xx - 0.354851 * yy - 0.255038 * zz
      g = -0.707196 * xx + 1.655397 * yy + 0.036152 * zz
      b =  0.051713 * xx - 0.121364 * yy + 1.011530 * zz
      r, g, b = rescale_rgb([r,g,b])

      # gamma correction
      r =   r <= 0.0031308   ?   12.92 * r   :   1.055 * r**(1/2.4) - 0.055
      g =   g <= 0.0031308   ?   12.92 * g   :   1.055 * g**(1/2.4) - 0.055
      b =   b <= 0.0031308   ?   12.92 * b   :   1.055 * b**(1/2.4) - 0.055
      rescale_rgb([r,g,b])
    end

    def rescale_rgb(rgb)
      rgb = rgb.map { |v| [0.0, v].max }
      max = rgb.max
      return rgb unless max > 1.0
      rgb.map { |v| v / max }
    end

    def to_hsl
      rgb = to_rgb
      cmax = rgb.max
      cmin = rgb.min
      delta = cmax - cmin
      pi_over_3 = Math::PI/3.0

      lum = (cmax + cmin) / 2
      sat = if delta == 0 then
        0.0
      else
        delta / (1.0 - (2*lum - 1).abs)
      end

      hue = if delta.abs < 1e-6 then
        0.0
      elsif cmax == rgb[0]
        pi_over_3 * ( (rgb[1] - rgb[2] ) / delta % 6 )
      elsif cmax == rgb[1]
        pi_over_3 * ( (rgb[2] - rgb[0] ) / delta + 2 )
      elsif cmax == rgb[2]
        pi_over_3 * ( (rgb[0] - rgb[1] ) / delta + 4 )
      end

      [ hue, sat, lum ]
    end

    def to_mirek
      # this won't interpolate to find nearest mirek value not in table
      tbl = self.class.mirek_to_xy_table
      tbl.keys.min_by { |ct| (tbl[ct][0] - xyb[0])**2 + (tbl[ct][1] - xyb[1])**2 }
    end

    def to_mb
      [ to_mirek, brightness ]
    end

    def to_xyb
      xyb
    end

    def to_light
      to_light_xy.merge(dimming: { brightness: xyb[2] })
    end

    def to_light_xy
      {
        color: {
          xy: {
            x: xyb[0],
            y: xyb[1],
          }
        },
      }
    end

    def to_hex
      "#" + to_rgb.map { |component| sprintf("%02x", (255 * component).round(0).to_i) }.join("")
    end

    def to_device_xy
      x, y = to_xy
      { xy: { x: x, y: y } }
    end

    def brightness
      xyb[2]
    end

    def white?
      # to_mirek needs to interpolate for this to return true for mirek values not on the table
      nearest_white = self.class.from_mb(self.to_mb)
      self.xy_distance(nearest_white) < 1e-3
    end

    def xy_distance(other)
      ((self.xyb[0] - other.xyb[0])**2 + (self.xyb[1] - other.xyb[1])**2)**0.5
    end

    def blend(other_color, params={})
      args = { method: white? ? :mirek : :rgb, alpha: 0.5 }.merge(params)
      case args[:method]
      when :mirek
        self.class.from_mb(self.mb.zip(other.mb).map { |pair| (1.0-alpha)*pair[0] + alpha*pair[1]})
      when :rgb
        self.class.from_rgb(self.rgb.zip(other.rgb).map { |pair| (1.0-alpha)*pair[0] + alpha*pair[1]})
      when :hsv
        self.class.from_hsv(self.hsv.zip(other.hsv).map { |pair| (1.0-alpha)*pair[0] + alpha*pair[1]})
      when :xyb
        self.class.from_xyb(self.hsv.zip(other.xyb).map { |pair| (1.0-alpha)*pair[0] + alpha*pair[1]})
      else
        raise "Unsupported blend method: #{args[:method]}"
      end
    end

    def rotate_hue(radians)
      add_hsl([radians, 0, 0])
    end

    def navigate(radians, distance)
      delta_x = Math.cos(radians) * distance
      delta_y = Math.sin(radians) * distance
      self.class.from_xyb([xyb[0] + delta_x, xyb[1] + delta_y, xyb[2]])
    end

    def add_hsl(hsl)
      new_hsl  = to_hsl.zip(hsl).map { |zz| zz.inject(&:+) }
      new_hsl[0] %= 2*Math::PI
      new_hsl[1] = [0.0, [1.0, new_hsl[1]].min].max
      new_hsl[2] = [0.0, [1.0, new_hsl[2]].min].max
      Color.from_hsl(new_hsl)
    end

    def add_mirek(delta)
      new_mirek = [153, [500, to_mirek + delta].min].max.round(0).to_i
      Color.from_mirek(new_mirek)
    end

    def color_text_fg(text)
      r, g, b = to_rgb.map { |channel| (255*channel).round }
      "\x1b[38;2;#{r};#{g};#{b}m" + text + "\x1b[0m"
    end

    def color_text_bg(text)
      r, g, b = to_rgb.map { |channel| (255*channel).round }
      "\x1b[48;2;#{r};#{g};#{b}m" + text + "\x1b[0m"
    end
  end
end
