module SlackLine
  module Cli
    ExitException = Class.new(StandardError)
  end
end

glob = File.expand_path("../cli/*.rb", __FILE__)
Dir.glob(glob).sort.each { |f| require(f) }
