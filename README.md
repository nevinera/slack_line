# SlackLine

This is a ruby gem supporting easy construction, sending, editing, and
threading of messages and threads.

## Configuration

The only required setup is an OAuth token - each of these options can
be set via ENV or `SlackLine.configure`:

* `slack_token` or `SLACK_LINE_SLACK_TOKEN` (required) - this
  allows the library to send messages and make API requests.
* `look_up_users` or `SLACK_LINE_LOOK_UP_USERS` (default false) - if
  your workspace refuses to turn `@somebody` mentions into links or
  notifications, you can set this and we'll parse them out, then use
  the slack API to map them to user/group IDs.
* `bot_name` or `SLACK_LINE_BOT_NAME` - what to call the bot that's
  posting (in slack). The default is to use its default name.
* `default_channel` or `SLACK_LINE_DEFAULT_CHANNEL` - a target name
  (either a channel with the leading pound-sign, or a user's handle
  with a leading at-sign). When not supplied, all `send` calls are
  required to specify a target instead.
* `allow_dsl` or `SLACK_LINE_ALLOW_DSL` - on by default, but if you
  really hate the dsl-style usage, you can disable it. If you set this
  to `false`, all of the block-accepting methods will yield their
  acceptors (they do anyway), and you'll need to call the dsl methods
  on those acceptors instead.
* `per_message_delay` or `SLACK_LINE_PER_MESSAGE_DELAY` is a float,
  defaulting to 0.0. SlackLine will `sleep` for that duration after
  each message is posted, to allow you to avoid hitting rate-limits
  from posting many messages in a row.
* `per_thread_delay` or `SLACK_LINE_PER_THREAD_DELAY` is a float as
  well - SlackLine will `sleep` for this duration after each _thread_
  is posted, and after each non-thread message is posted.

You can just set those via the environment variables, but you can also
set them on the singleton configuration object:

```ruby
SlackLine.configure do |config|
  config.slack_token = ENV["SLACK_TOKEN"]
  config.look_up_users = true
  config.bot_name = "CI Bot"
  config.default_channel = "#ci-flow"
  config.allow_dsl = false
  config.per_message_delay = 0.2
  config.per_thread_delay = 2.0
end
```

## Usage

Are you ready? Because this is going to be _so easy_.

```ruby
# Send a simple message directly
sent_message = SlackLine.post_message("Something happened!", to: "#general")

# Construct a more complex message, then send it
msg = SlackLine.message do
  section do
    context "Don't worry! If this message surprises you, context @foobar"
    text "A thing has happened"
    text "Yeah, it happened for sure"
    link "How bad?", problems_path(problem.id)
  end

  text "More details.."
end
sent_message = msg.post(to: "#general")

# Send a _thread_ of messages (strings generate simple messages)
sent_thread = SlackLine.post_thread("First text", "Second text", msg, to: "#general")

# You can also build them inline via dsl
sent_thread = SlackLine.post_thread(to: "@dm_recipient") do
  message do
    context "yeah"
    text "That's right"
  end

  message(already_built_message)
  message "this makes a basic message directly"
end
```

And then once you've sent a message or thread, you'll have a SentMessage
or SentThread object (which is basically an Array of SentMessages). You
can call `SentMessage#update` on any of those messages to edit them
after the fact - this is especially useful for keeping a message in a
public channel updated with the state of the process it's linking to.

`update` accepts a String, a Message, or a block _defining_ a message.
To update a SentThread, you'll need to choose  message:

```ruby
sent_message.update "Edit: never mind, false alarm"
sent_thread.first.update "Problem Resolved!"
sent_thread.detect { |m| m =~ /Not yet safe/ }&.update do
  text "it's safe now"
end
```

## Multiple Configurations

If you're working in a context where you need to support multiple
SlackLine configurations, don't worry! The singleton central config is
what the singleton central Client uses (that's what all of the top-level
SlackLine methods dispatch to), but you can construct additional clients
with their own configs easily:

```ruby
Slackline.configure do |config|
  config.slack_token = ENV["TOKEN"]
  config.default_channel = "#general"
  config.bot_name = "FooBot"
end

# Now SlackLine.post_message (et al) will use SlackLine.client,
# configured as above.

BAR_SLACK = SlackLine::Client.new(default_channel: "#team-bar", bot_name: "BarBot")

# And now you can call all of those methods on `BAR_SLACK` to use a
# different default channel and name

BAR_SLACK.post_thread("Message 1", "Message 2")
BAR_SLACK.post_message("Message 3", to: "#bar-team-3")
```
