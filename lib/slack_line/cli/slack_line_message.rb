require "optparse"
require "reline"

module SlackLine
  module Cli
    class SlackLineMessage
      def initialize(argv:, stdout: $stdout, stderr: $stderr)
        @argv = argv
        @stdout = stdout
        @stderr = stderr
      end

      def run
        if options[:append]
          run_append
        elsif options[:update]
          run_update
        elsif options[:post_to]
          run_post
        else
          run_preview
        end
      end

      def options
        return @options if defined?(@options)
        opts = {post_to: nil, append: nil, update: nil, message_number: nil, save: nil, slack_token: nil, look_up_users: nil, bot_name: nil, backoff: nil}
        remaining = option_parser(opts).parse(@argv.dup)
        if remaining.empty?
          opts[:dsl] = read_stdin
        else
          opts[:content] = remaining
        end
        validate_options!(opts)
        @options = opts
      end

      def configuration
        return @configuration if defined?(@configuration)
        cfg_opts = options.slice(:slack_token, :look_up_users, :bot_name, :backoff).compact
        @configuration = Configuration.new(nil, **cfg_opts)
      end

      private

      attr_reader :stdout, :stderr

      def option_parser(opts) # rubocop:disable Metrics/AbcSize
        OptionParser.new do |parser|
          parser.on("-t", "--slack-token TOKEN") { |t| opts[:slack_token] = t }
          parser.on("-u", "--look-up-users") { opts[:look_up_users] = true }
          parser.on("-n", "--bot-name NAME") { |n| opts[:bot_name] = n }
          parser.on("-p", "--post-to TARGET") { |t| opts[:post_to] = t }
          parser.on("-a", "--append PATH") { |p| opts[:append] = p }
          parser.on("-U", "--update PATH") { |p| opts[:update] = p }
          parser.on("-m", "--message-number N", Integer) { |n| opts[:message_number] = n }
          parser.on("-s", "--save PATH") { |p| opts[:save] = p }
          parser.on("--no-backoff") { opts[:backoff] = false }
        end
      end

      def validate_options!(opts)
        if [opts[:post_to], opts[:append], opts[:update]].compact.size > 1
          raise(ExitException, "Only one of --post-to, --append, or --update can be used at a time")
        end
        raise ExitException, "--message-number requires --update" if opts[:message_number] && !opts[:update]
        raise ExitException, "--message-number cannot be less than 0" if opts[:message_number] && opts[:message_number] < 0
      end

      def read_stdin
        stderr.puts "No content provided, reading (as dsl) from stdin. Control+D to finish:\n\n"
        lines = []
        while (line = Reline.readline("MSG> ", true))
          lines << line
        end
        lines.join("\n")
      end

      def client = @client ||= Client.new(configuration)

      def load_json(path, client:) = SlackLine.from_json(JSON.parse(File.read(path)), client:)

      def save(result) = File.write(options[:save], JSON.pretty_generate(result.as_json))

      def message
        @message ||=
          if options[:content]
            Message.new(*options[:content], client:)
          else
            dsl = options[:dsl]
            Message.new(client:) { eval(dsl) } # standard:disable Security/Eval
          end
      end

      def append_target = @append_target ||= load_json(options[:append], client:)

      def run_append
        sent_thread = append_target.append(message)
        stderr.puts "Appended to thread in #{sent_thread.channel}"
        save(sent_thread) if options[:save]
      end

      def update_target = @update_target ||= load_json(options[:update], client:)

      def validate_update_flags!
        message_number = options[:message_number]
        if update_target.is_a?(SentMessage)
          raise(ExitException, "--message-number cannot be used when updating a single message") if message_number
        elsif message_number.nil?
          raise(ExitException, "--message-number is required when updating a thread")
        elsif message_number >= update_target.size
          raise(ExitException, "--message-number #{message_number} is out of range (thread has #{update_target.size} messages)")
        end
      end

      def message_to_update
        return @message_to_update if defined?(@message_to_update)

        validate_update_flags!
        if update_target.is_a?(SentMessage)
          @message_to_update = update_target
        else
          msg_num = options[:message_number]
          @message_to_update = update_target.sent_messages[msg_num]
        end
      end

      def run_update
        updated_msg = message_to_update.update(message)
        result = update_target.is_a?(SentThread) ? rebuilt_thread(updated_msg) : updated_msg
        type = update_target.is_a?(SentThread) ? "thread" : "message"
        stderr.puts "Updated #{type} in #{result.channel}"
        save(result) if options[:save]
      end

      def rebuilt_thread(updated_msg)
        idx = options[:message_number]
        msgs = update_target.sent_messages
        SentThread.new(*msgs[0...idx], updated_msg, *msgs[(idx + 1)..])
      end

      def run_post
        sent = message.post(to: options[:post_to])
        stderr.puts "Posted message to #{options[:post_to]}"
        save(sent) if options[:save]
      end

      def run_preview
        stderr.puts "Preview message at #{message.builder_url}\n\n"
        stdout.puts JSON.pretty_generate(message.content.as_json)
      end
    end
  end
end
