# Changelog

## Version 1.0

Initially published gem. Can send messages and threads, update messages, extend
threads, persist those things to disk and reload them. Convenience scripts that
can do each of those things directly (for simpler messages).

## Version 1.1

Fixed incorrect description/summary on gemspec.

## Version 1.2

Added disk-caching for the users and groups lists, through the `cache_path` and
`cache_duration` config options and matching CLI flags. Added the
`slack_line_stateful_thread` script, and `content` and `update` on `SentThread`.

## Version 1.3

`message` and `thread` now accept `to:`, as the README showed. Declared `reline`
as a runtime dependency, which fixes a warning or `LoadError` under Bundler on
Ruby 4.0. The invalid content error now lists the classes of the bad arguments.

## Version 1.4

**Breaking change:** calling `text` more than once in a `section` now raises an
`ArgumentError`. It used to silently keep only the last text, because a Slack
section block has one text field. Use one `section` per text.

Fixed README examples that didn't run, including `context` inside a `section`,
which Slack doesn't allow.

## Version 1.5

DSL blocks that take an argument now receive the builder, and `self` stays
the caller, so the block can use your own methods and instance variables:
`SlackLine.message { |m| m.text @title }`. Blocks with no arguments work as
before. When a bare block calls one of your own methods, SlackLine raises an
error that points at the block-argument form. It can't catch instance
variables, which are just nil inside a bare block.
