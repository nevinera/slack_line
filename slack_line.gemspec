require_relative "lib/slack_line/version"

Gem::Specification.new do |spec|
  spec.name = "slack_line"
  spec.version = SlackLine::VERSION
  spec.authors = ["Eric Mueller"]
  spec.email = ["nevinera@gmail.com"]

  spec.summary = "Build CLIs that are configured via args, file, and/or environment"
  spec.description = <<~DESC
    We've written code that merges/cascades default configuration, config-files,
    environment variables, and cli-passed arguments _too many times_. This gem
    intends to distill that into a configuration hash describing those controls
    and relationships, so that users can supply values in multiple ways.
  DESC
  spec.homepage = "https://github.com/nevinera/slack_line"
  spec.license = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 3.2.0")

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.require_paths = ["lib"]
  spec.bindir = "bin"
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`
      .split("\x0")
      .reject { |f| f.start_with?("spec") }
  end
  spec.executables = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z bin/`
      .split("\x0")
      .map { |path| path.sub(/^bin\//, "") }
  end

  spec.add_development_dependency "rspec", "~> 3.13"
  spec.add_development_dependency "rspec-its", "~> 1.3"
  spec.add_development_dependency "rspec-collection_matchers", "~> 1.2.1"
  spec.add_development_dependency "simplecov", "~> 0.22.0"
  spec.add_development_dependency "quiet_quality"
  spec.add_development_dependency "pry", "~> 0.14"
  spec.add_development_dependency "standard", ">= 1.35.1"
  spec.add_development_dependency "rubocop", ">= 1.62"
  spec.add_development_dependency "mdl", "~> 0.12"
end
