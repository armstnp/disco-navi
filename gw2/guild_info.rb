# frozen_string_literal: true

require 'forwardable'
require './gw2_api'
require './recondition'

module GW2
  class GuildInfoHandler
    def initialize(event, guild_name, token)
      @event = event
      @guild_name = guild_name
      @token = token
    end

    def handle
      GuildQuery
        .new(guild_name, token)
        .handle
        .when_present { |guild| GuildEmitter.new guild }
        .when_absent { AbsentGuildEmitter.new guild_name }
        .render(event)
    end

    private

    attr_reader :event, :guild_name, :token
  end

  # An event handler that emits info about the guild with the given name to the event's originating
  # channel, leveraging the given GW2 API token.
  # TODO: Turn into strict query, move render out
  class GuildQuery
    def initialize(guild_name, token)
      @guild_name = guild_name
      @token = token
    end

    def handle
      guild_ids = GW2::API::GuildSearch.request name: guild_name
      return Recondition::Absent.new if guild_ids.empty?

      guild_id = guild_ids[0]
      guild = GW2::API::GuildFlexDetails.request id: guild_id, token: token
      Recondition::Present.new(GuildInfoResult.new(guild))
    end

    private

    attr_reader :guild_name, :token
  end

  # Information concerning a guild.
  class GuildInfoResult
    extend Forwardable

    attr_reader :id, :name, :tag

    def initialize(guild)
      @id, @name, @tag = guild.values_at(:id, :name, :tag)
      @private_info = build_private_info guild
    end

    def emblem
      "https://data.gw2.fr/guild-emblem/name/#{ERB::Util.url_encode(name)}.png"
    end

    def_delegators :@private_info, :when_private_details_visible

    private

    def build_private_info(guild)
      if guild.key? :level
        GuildVisiblePrivateInfo.new guild
      else
        GuildLockedPrivateInfo.new
      end
    end

    class GuildVisiblePrivateInfo
      attr_reader :level, :motd, :aetherium, :favor

      def initialize(guild)
        @level, @motd, @aetherium, @favor = guild.values_at(:level, :motd, :aetherium, :favor)
      end

      def when_private_details_visible
        yield self
      end
    end

    class GuildLockedPrivateInfo
      def when_private_details_visible; end
    end
  end

  class GuildEmitter
    def initialize(guild)
      @guild = guild
    end

    def render(discord_renderable)
      discord_renderable.channel.send_embed do |embed|
        embed.title = "#{guild.name} [#{guild.tag}]"
        embed.thumbnail = { url: guild.emblem }

        guild.when_private_details_visible do |private_info|
          embed.title = "#{guild.name} [#{guild.tag}] - Level #{private_info.level}"
          embed.description = private_info.motd
          embed.add_field(name: 'Aetherium', value: private_info.aetherium)
          embed.add_field(name: 'Guild Favor', value: private_info.favor)
          embed
        end
      end
    end

    private

    attr_reader :guild
  end

  class AbsentGuildEmitter
    def initialize(guild_name)
      @guild_name = guild_name
    end

    def render(discord_renderable)
      discord_renderable << "No guild found with name '#{guild_name}'"
    end

    private

    attr_reader :guild_name
  end
end
