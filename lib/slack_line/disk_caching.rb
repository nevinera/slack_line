module SlackLine
  module DiskCaching
    NoLightly = Class.new(Error)

    def cached(config:, key:, &block)
      return yield if config.cache_path.nil?
      raise(NoLightly, "The 'lightly' gem is required for disk caching") unless defined?(Lightly)

      Lightly.new(dir: config.cache_path, life: config.cache_duration).get(key) { yield }
    end
  end
end
