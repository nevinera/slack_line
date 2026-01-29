module SlackLine
  class MessageContext
    def initialize(&block)
      @content = ::Slack::BlockKit.blocks do |b|
        @in_progress_blocks = b
        instance_eval(&block)
      ensure
        @in_progress_blocks = nil
      end
    end

    attr_reader :content

    def text(content, plain: false)
      @in_progress_blocks.section do |s|
        plain ? s.plain_text(text: content) : s.mrkdwn(text: content)
      end
    end

    def section(&block) = SectionContext.new(@in_progress_blocks, &block).content

    def context(content, plain: false)
      @in_progress_blocks.context do |c|
        plain ? c.plain_text(text: content) : c.mrkdwn(text: content)
      end
    end

    def divider = @in_progress_blocks.divider
  end
end
