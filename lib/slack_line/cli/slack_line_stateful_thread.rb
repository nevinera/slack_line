require "optparse"

module SlackLine
  module Cli
    class SlackLineStatefulThread
      def initialize(argv:, stdout: $stdout, stderr: $stderr)
        @argv = argv
        @stdout = stdout
        @stderr = stderr
      end

      def run
        validate_options!
        if path_exists?
          run_subsequent
        else
          run_initial
        end
      rescue DiskCaching::NoLightly, Configuration::InvalidValue => e
        raise ExitException, e.message
      end

      def options
        return @options if defined?(@options)
        opts = {path: nil, post_to: nil, state: nil, message: nil, thread: nil, slack_token: nil, bot_name: nil}
        option_parser(opts).parse(@argv.dup)
        @options = opts
      end

      def configuration
        return @configuration if defined?(@configuration)
        cfg_opts = options.slice(:slack_token, :bot_name).compact
        @configuration = Configuration.new(nil, **cfg_opts)
      end

      private

      attr_reader :stdout, :stderr

      def option_parser(opts) # rubocop:disable Metrics/AbcSize
        OptionParser.new do |parser|
          parser.on("-t", "--slack-token TOKEN") { |t| opts[:slack_token] = t }
          parser.on("-n", "--bot-name NAME") { |n| opts[:bot_name] = n }
          parser.on("--path PATH") { |p| opts[:path] = p }
          parser.on("-p", "--post-to TARGET") { |t| opts[:post_to] = t }
          parser.on("-s", "--state STATE") { |s| opts[:state] = s }
          parser.on("-m", "--message MESSAGE") { |m| opts[:message] = m }
          parser.on("--thread") { opts[:thread] = true }
        end
      end

      def validate_options!
        raise ExitException, "--path is required" unless options[:path]
        path_exists? ? validate_subsequent_options! : validate_initial_options!
      end

      def validate_initial_options!
        raise ExitException, "--post-to is required for initial post" unless options[:post_to]
        raise ExitException, "--state is required for initial post" unless options[:state]
        raise ExitException, "--message is required for initial post" unless options[:message]
      end

      def validate_subsequent_options!
        raise ExitException, "--post-to cannot be used after initial post" if options[:post_to]
        options[:thread] ? validate_thread_options! : validate_update_options!
      end

      def validate_thread_options!
        raise ExitException, "--thread cannot be used with --state" if options[:state]
        raise ExitException, "--thread requires --message" unless options[:message]
      end

      def validate_update_options!
        raise ExitException, "One of --state or --message is required" unless options[:state] || options[:message]
      end

      def path_exists? = options[:path] && File.exist?(options[:path])

      def client = @client ||= Client.new(configuration)

      def load_sent
        @load_sent ||= SlackLine.from_json(JSON.parse(File.read(options[:path])), client:)
      end

      def save_sent(result) = File.write(options[:path], JSON.pretty_generate(result.as_json))

      def run_initial
        text = "[#{options[:state]}] #{options[:message]}"
        sent = Message.new(text, client:).post(to: options[:post_to])
        save_sent(sent)
        stderr.puts "Posted stateful thread to #{options[:post_to]}"
      end

      def run_subsequent
        options[:thread] ? run_thread_message : run_update_message
      end

      def parse_state_message(text)
        match = text&.match(/\A\[([^\]]*)\] (.+)\z/m)
        raise ExitException, "Cannot parse state and body from stored message content" unless match
        [match[1], match[2]]
      end

      def current_state_and_body(sent)
        parse_state_message(sent.content.dig(0, "text", "text"))
      end

      def run_update_message
        sent = load_sent
        current_state, current_body = current_state_and_body(sent)
        new_text = "[#{options[:state] || current_state}] #{options[:message] || current_body}"
        updated = sent.update(Message.new(new_text, client:))
        save_sent(updated)
        stderr.puts "Updated message in #{updated.channel}"
      end

      def run_thread_message
        sent = load_sent
        sent_thread = sent.append(options[:message])
        save_sent(sent_thread)
        stderr.puts "Threaded message in #{sent_thread.channel}"
      end
    end
  end
end
