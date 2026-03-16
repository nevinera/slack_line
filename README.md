# SlackLine

This is a ruby gem supporting easy construction, sending, editing, and
threading of messages and threads.

## Usage

Are you ready? Because this is going to be _so easy_.

```ruby
# Send a simple message directly
sent_message = SlackLine.message("Something happened!", to: "#general").post

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
sent_thread = SlackLine.thread("First text", "Second text", msg, to: "#general").post

# You can also build them inline via dsl
sent_thread = SlackLine.thread(to: "@dm_recipient") do
  message do
    context "yeah"
    text "That's right"
  end

  message(already_built_message)
  message "this makes a basic message directly"
end.post
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
* `per_message_delay` or `SLACK_LINE_PER_MESSAGE_DELAY` is a float,
  defaulting to 0.0. SlackLine will `sleep` for that duration after
  each message is posted, to allow you to avoid hitting rate-limits
  from posting many messages in a row.
* `per_thread_delay` or `SLACK_LINE_PER_THREAD_DELAY` is a float as
  well - SlackLine will `sleep` for this duration after each _thread_
  is posted, and after each non-thread message is posted.
* `cache_path` or `SLACK_LINE_CACHE_PATH` - a directory path for
  disk-caching the users and groups lists fetched from the Slack API.
  When set, SlackLine will use the [lightly](https://github.com/DannyBen/lightly)
  gem to cache results to disk, which avoids redundant API calls across
  separate runs. Requires `lightly` to be installed as an optional
  dependency - if it is not available, a `DiskCaching::NoLightly` error
  will be raised at runtime.
* `cache_duration` or `SLACK_LINE_CACHE_DURATION` - how long cached
  data remains valid (default `"15m"`). Accepts a plain integer number
  of seconds, or a number followed by a unit suffix: `s` (seconds),
  `m` (minutes), `h` (hours), or `d` (days). For example: `"30m"`,
  `"2h"`, `"1d"`, or `"900"`.

You can just set those via the environment variables, but you can also
set them on the singleton configuration object:

```ruby
SlackLine.configure do |config|
  config.slack_token = ENV["SLACK_TOKEN"]
  config.look_up_users = true
  config.bot_name = "CI Bot"
  config.default_channel = "#ci-flow"
  config.per_message_delay = 0.2
  config.per_thread_delay = 2.0
  config.cache_path = "/tmp/slack_line_cache"
  config.cache_duration = "1h"
end
```

### Multiple Configurations

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

# Now SlackLine.message (et al) will use SlackLine.client,
# configured as above.

BAR_SLACK = SlackLine::Client.new(default_channel: "#team-bar", bot_name: "BarBot")

# And now you can call those methods on `BAR_SLACK` to use a different
# default channel and name

BAR_SLACK.thread("Message 1", "Message 2").post
BAR_SLACK.message("Message 3", to: "#bar-team-3").post
```

## CLI Scripts

The gem ships with three executable scripts for sending and managing Slack messages
from the command line. All three accept `-t`/`--slack-token TOKEN` and
`-n`/`--bot-name NAME` to override the corresponding environment variables.
Configuration can also come from `SLACK_LINE_SLACK_TOKEN` and friends as described
above.

### `slack_line_message`

Sends, updates, or previews a single Slack message.

```sh
# Post a simple message
slack_line_message --post-to "#general" --save /tmp/msg.json "Something happened!"

# Preview without posting (prints JSON block kit content)
slack_line_message "Something happened!"

# Post a message using the block-kit DSL on stdin
echo 'text "Something happened!"' | slack_line_message --post-to "#general" --save /tmp/msg.json

# Append a reply to an existing thread (saved from a prior post)
slack_line_message --append /tmp/msg.json --save /tmp/msg.json "Follow-up!"

# Update a previously-sent message in place
slack_line_message --update /tmp/msg.json "Edited message text"

# Update a specific message within a saved thread (0-indexed)
slack_line_message --update /tmp/msg.json --message-number 2 "Corrected reply"
```

Options:

* `-p`/`--post-to TARGET` - channel or user to post to
* `-a`/`--append PATH` - append a reply to the thread saved at PATH
* `-U`/`--update PATH` - update the message (or thread) saved at PATH
* `-m`/`--message-number N` - which message in a thread to update (0-indexed;
  required with `--update` on a thread)
* `-s`/`--save PATH` - write the sent/updated result to PATH as JSON
* `-u`/`--look-up-users` - resolve `@mentions` via the Slack API
* `--cache-path PATH` / `--cache-duration DURATION` - disk-cache user/group lookups
* `--no-backoff` - disable per-message sleep delays

When no content arguments are given and no DSL is piped, the script reads DSL
interactively from stdin.

### `slack_line_thread`

Sends or previews a thread (multiple messages posted together).

```sh
# Post a thread from positional string arguments
slack_line_thread --post-to "#general" --save /tmp/thread.json "First" "Second" "Third"

# Preview the thread without posting
slack_line_thread "First" "Second"

# Post a thread from block-kit DSL on stdin
cat thread.dsl | slack_line_thread --post-to "#general" --save /tmp/thread.json
```

A DSL block looks like:

```ruby
message "Simple first message"
message do
  text "Fancier second message"
  context "with some context"
end
```

Options mirror `slack_line_message`, minus the update/append flags:

* `-p`/`--post-to TARGET` - channel or user to post to
* `-s`/`--save PATH` - write the sent result to PATH as JSON
* `-u`/`--look-up-users`, `--cache-path`, `--cache-duration`, `--no-backoff` -
  same as above

### `slack_line_stateful_thread`

Designed for long-running processes that need to post a single status message
and then keep it updated as state changes - for example, a deployment pipeline
that posts `[running] Deploy started`, updates it to `[done] Deploy finished`,
and appends replies along the way. The sent message is persisted to a file;
subsequent invocations load and re-persist that file to know which Slack message
to update.

Messages are formatted as `[STATE] body`. The `--state` and `--message` flags each
update their respective part independently; omitting one leaves it unchanged on update.

```sh
# Initial post - creates /tmp/deploy.json and posts "[running] Deploy started"
slack_line_stateful_thread --path /tmp/deploy.json --post-to "#deploys" \
  --state running --message "Deploy started"

# Update the state only - becomes "[done] Deploy started"
slack_line_stateful_thread --path /tmp/deploy.json --state done

# Update the body only - becomes "[done] Deploy finished"
slack_line_stateful_thread --path /tmp/deploy.json --message "Deploy finished"

# Update both state and body - becomes "[failed] Something went wrong"
slack_line_stateful_thread --path /tmp/deploy.json --state failed --message "Something went wrong"

# Append a thread reply without changing the main message
slack_line_stateful_thread --path /tmp/deploy.json --thread --message "Step 1 complete"
```

Options:

* `--path PATH` - (required) file path used to persist the sent message between invocations
* `-p`/`--post-to TARGET` - channel or user; required on the first call, forbidden
  thereafter
* `-s`/`--state STATE` - the state label shown in brackets; required on first call
* `-m`/`--message MESSAGE` - the message body; required on first call and when using
  `--thread`
* `--thread` - append a reply instead of updating the main message (mutually exclusive
  with `--state`)

## Slack App Permissions

In order to post/update messages, the app behind your `SLACK_LINE_TOKEN` can use
these permissions:

* `chat:write` - send messages at all.
* `chat:write.public` - send messages to public channels your app _isn't a member
  of_ (so you don't need to invite them to the relevant channels to make them work).
* `im:write` - start direct messages with individuals.
* `users:read` and `usergroups:read` - look up users/groups for (a) messaging them
  directly or (b) supporting the `look_up_users` config option (for those more
  restrictive workspaces)
