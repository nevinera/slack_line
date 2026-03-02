module SlackLine
  class MessageConverter
    def initialize(blocks, client:)
      @blocks = blocks
      @client = client
    end

    def convert = resolve_mentions(@blocks)

    private

    attr_reader :client

    def resolve_mentions(json)
      case json
      when Array then resolve_mentions_in_array(json)
      when Hash then resolve_mentions_in_hash(json)
      else json
      end
    end

    def resolve_mentions_in_array(array)
      array.map { |item| resolve_mentions(item) }
    end

    def resolve_mentions_in_hash(hash)
      text_key = hash.key?(:text) ? :text : "text"
      type_key = hash.key?(:type) ? :type : "type"
      if hash[type_key] == "mrkdwn" && hash[text_key].is_a?(String)
        hash.merge(text_key => substitute_mentions(hash[text_key]))
      else
        hash.transform_values { |v| resolve_mentions(v) }
      end
    end

    def substitute_mentions(text)
      text.gsub(/@([\w-]+)/) do |match|
        token = $1
        if (user = client.users.find(display_name: token))
          "<@#{user.id}>"
        elsif (group = client.groups.find(handle: token))
          "<!subteam^#{group.id}>"
        else
          match
        end
      end
    end
  end
end
