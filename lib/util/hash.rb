class Hash
  def gentle_merge(other)
    merged = {}

    other.each do |key, value|
      merged[key] = if !self.has_key?(key) then
        value
      elsif self[key].class == Hash && value.class == Hash
        self[key].gentle_merge(value)
      else
        value
      end
    end

    self.each do |key, value|
      next if merged.has_key?(key)
      merged[key] = value
    end

    merged
  end
end
