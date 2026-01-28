require "rspec"
require "rspec/its"
require "rspec/collection_matchers"
require "pry"

if ENV["SIMPLECOV"]
  require "simplecov"

  class ProblemsFormatter
    def format(result)
      warn result.groups.map { |name, files| format_group(name, files) }
    end

    private

    def format_group(name, files)
      problem_files = files.select { |f| f.covered_percent < 100.0 }
      if problem_files.any?
        header = "#{name}: coverage missing\n"
        rows = problem_files.map { |f| "    #{f.filename} (#{f.covered_percent.round(2)}%)\n" }
        ([header] + rows).join
      else
        "#{name}: fully covered\n"
      end
    end
  end

  SimpleCov.start do
    formatter(ProblemsFormatter) unless ENV["SIMPLECOV_HTML"]
    minimum_coverage line: 100
    add_group "lib", "lib/"
    add_filter "spec/"
  end
end

gem_root = File.expand_path("../..", __FILE__)

require File.join(gem_root, "lib/slack_line")

support_glob = File.join(gem_root, "spec", "support", "**", "*.rb")
Dir[support_glob].sort.each { |f| require f }

RSpec.configure do |config|
  config.raise_errors_for_deprecations!
  config.mock_with :rspec
  config.order = "random"
  config.tty = true
end
