require 'cgi'

module ZURPG
  class StatusHandler
    CHECK = '✅'
    TRASH = '🗑'

    attr_reader :user_status
    private :user_status
    
    def initialize
      @user_status = {}
    end

    def handle_save(status, event)
      user_status[author_id(event)] = status
      event.message.create_reaction(CHECK)
    end

    def handle_fetch(event)
      author = author_id(event)
      status = user_status[author]
      author_name =
        if event.author.respond_to?(:display_name)
        then event.author.display_name
        else event.author.username
        end

      if status
        event << "**#{author_name}**: #{status}"
      else
        event << "**#{author_name}**: _No status recorded_"
      end
    end

    def handle_clear(event)
      user_status.delete(author_id(event))
      event.message.create_reaction(TRASH)
    end

    private

    def author_id(event)
      event.author.distinct
    end
  end
end