module SlackLine
  class SectionContext
    def initialize(parent_context, &block)
      @content = parent_context.section do |s|
        @in_progress_section = s
        instance_exec(&block)
      ensure
        @in_progress_section = nil
      end
    end

    attr_reader :content

    def text(content, plain: false)
      if plain
        @in_progress_section.plain_text(text: content)
      else
        @in_progress_section.mrkdwn(text: content)
      end
    end

    def link(text, url) = @in_progress_section.button(text: text, url: url, action_id: "link-button")
  end
end
