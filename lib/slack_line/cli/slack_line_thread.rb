require "optparse"
require "reline"

module SlackLine
  module Cli
    class SlackLineThread
      def initialize(argv:, stdout: $stdout, stderr: $stderr)
        @argv = argv
        @stdout = stdout
        @stderr = stderr
      end

      def run
        if options[:post_to]
          run_post
        else
          run_preview
        end
      end

      def options
        return @options if defined?(@options)
        opts = {post_to: nil, save: nil, slack_token: nil, look_up_users: nil, bot_name: nil, backoff: nil}
        remaining = option_parser(opts).parse(@argv.dup)
        if remaining.empty?
          opts[:dsl] = read_stdin
        else
          opts[:content] = remaining
        end
        @options = opts
      end

      def configuration
        return @configuration if defined?(@configuration)
        cfg_opts = options.slice(:slack_token, :look_up_users, :bot_name, :backoff).compact
        @configuration = Configuration.new(nil, **cfg_opts)
      end

      private

      attr_reader :stdout, :stderr

      def option_parser(opts)
        OptionParser.new do |parser|
          parser.on("-t", "--slack-token TOKEN") { |t| opts[:slack_token] = t }
          parser.on("-u", "--look-up-users") { opts[:look_up_users] = true }
          parser.on("-n", "--bot-name NAME") { |n| opts[:bot_name] = n }
          parser.on("-p", "--post-to TARGET") { |t| opts[:post_to] = t }
          parser.on("-s", "--save PATH") { |p| opts[:save] = p }
          parser.on("--no-backoff") { opts[:backoff] = false }
        end
      end

      def read_stdin
        stderr.puts "No content provided, reading (as dsl) from stdin. Control+D to finish:\n\n"
        lines = []
        while (line = Reline.readline("THD> ", true))
          lines << line
        end
        lines.join("\n")
      end

      def client = @client ||= Client.new(configuration)

      def save(result) = File.write(options[:save], JSON.pretty_generate(result.as_json))

      def thread
        @thread ||=
          if options[:content]
            Thread.new(*options[:content], client:)
          else
            dsl = options[:dsl]
            Thread.new(client:) { eval(dsl) } # standard:disable Security/Eval
          end
      end

      def run_post
        sent = thread.post(to: options[:post_to])
        stderr.puts "Posted thread to #{options[:post_to]}"
        save(sent) if options[:save]
      end

      def preview_message(message)
        stdout.puts "\n\n--------------------- Message ---------------------\n"
        stdout.puts "Preview at: #{message.builder_url}\n\n"
        stdout.puts JSON.pretty_generate(message.content.as_json)
      end

      def run_preview
        stderr.puts "Preview messages at:"
        thread.builder_urls.each { |url| stderr.puts "  #{url}" }
        thread.each { |message| preview_message(message) }
      end
    end
  end
end
