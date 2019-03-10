# frozen_string_literal: true

require 'set'
require './gw2_api'
require './text_format'

# Guild Wars 2 scope
module GW2
  # An event handler that supplies info about the guild with the given name, leveraging the given
  # GW2 API token.
  class GuildInfoHandler
    def initialize(guild_name, token)
      @guild_name = guild_name
      @token = token
    end

    def handle
      guild_ids = GW2::API::GuildSearch.request name: guild_name

      return ErrorResult.new "No guild found with name '#{guild_name}'" if guild_ids.empty?

      guild_id = guild_ids[0]
      guild = GW2::API::GuildDetails.request id: guild_id, token: token

      GuildInfoResult.new guild
    end

    private

    attr_reader :guild_name, :token
  end

  # A renderable result concerning guild information.
  class GuildInfoResult
    def initialize(guild)
      @name, @tag, @level, @motd, @aetherium, @favor =
        guild.values_at(:name, :tag, :level, :motd, :aetherium, :favor)
    end

    def render(discord_renderable)
      discord_renderable.channel.send_embed do |embed|
        embed.title = "#{name} [#{tag}] - Level #{level}"
        embed.description = motd
        embed.thumbnail = { url: emblem }
        embed.add_field(name: 'Aetherium', value: aetherium)
        embed.add_field(name: 'Guild Favor', value: favor)
        embed
      end
    end

    private

    def emblem
      "https://data.gw2.fr/guild-emblem/name/#{ERB::Util.url_encode(name)}.png"
    end

    attr_reader :name, :tag, :level, :motd, :aetherium, :favor
  end

  # A renderable result concerning a user input error or failure.
  class ErrorResult
    def initialize(message)
      @message = message
    end

    def render(discord_renderable)
      discord_renderable << @message
    end
  end

  # An event handler that emits a list of available upgrades for the guild with the given name to
  # the event's originating channel, leveraging the given GW2 API token.
  class GuildUpgradeListHandler
    def initialize(guild_name, token)
      @guild_name = guild_name
      @token = token
    end

    def handle
      guild_ids = GW2::API::GuildSearch.request name: guild_name

      return ErrorResult.new "No guild found with name '#{guild_name}'" if guild_ids.empty?

      guild_id = guild_ids[0]

      treasury = GW2::API::GuildTreasury.request id: guild_id, token: token

      upgrades_in_progress_ids = treasury.deep_select(:upgrade_id).uniq! * ','
      upgrades_in_progress =
        GW2::API::GuildUpgradeCatalogMany
          .request(ids: upgrades_in_progress_ids)
          .map { |u| GuildUpgrade.new u }

      GuildUpgradeListResult.new upgrades_in_progress
    end

    private

    attr_reader :guild_name, :token
  end

  class GuildUpgradeListResult
    def initialize(upgrades)
      @upgrades = upgrades
    end

    def render(discord_renderable)
      upgrades_by_type =
        upgrades
        .map { |u| [u.type, u.name] }
        .group_by { |u| u[0] }
        .sort
        .map do |kv|
          type, upgrades = kv
          "**#{type}**\n" + (upgrades.map { |u| u[1] }.sort.map { |u| "- #{u}" } * "\n")
        end
        .join("\n\n")

      discord_renderable << upgrades_by_type
    end

    private

    attr_reader :upgrades
  end

  class GuildUpgrade
    attr_reader :id, :name, :description, :icon, :type, :costs

    def initialize(upgrade_hash)
      @id, @name, @description, @icon, @type, costs =
        upgrade_hash.values_at(:id, :name, :description, :icon, :type, :costs)
      @costs = costs.map { |c| GuildUpgradeCost.new c }
    end
  end

  class GuildUpgradeCost
    def initialize(cost_hash)
      @type, @count, @name, @id = cost_hash.values_at(:type, :count, :name, :id)
    end

    private

    attr_reader :type, :count, :name, :id
  end

  # An event handler that emits progress info about the upgrade with the given name for the guild
  # with the given name to the event's originating channel, leveraging the given GW2 API token.
  # $gw2 guild upgrade 'The Shard Warband' 'Lumber'
  class GuildUpgradeInfoHandler
    def initialize(guild_name, upgrade_name, token)
      @guild_name = guild_name
      @upgrade_name = upgrade_name
      @token = token
    end

    def handle(event)
      guild_ids = GW2::API::GuildSearch.request name: guild_name
      if guild_ids.empty?
        event << "No guild found with name '#{guild_name}'"
        return
      end
      guild_id = guild_ids[0]

      guild = GW2::API::GuildDetails.request id: guild_id, token: token

      treasury = GW2::API::GuildTreasury.request id: guild_id, token: token

      upgrades_in_progress_ids = treasury.deep_select(:upgrade_id).uniq! * ','
      upgrades_in_progress = GW2::API::GuildUpgradeCatalogMany.request ids: upgrades_in_progress_ids

      matched_upgrades =
        upgrades_in_progress
        .select { |u| u[:name].downcase.include?(upgrade_name_downcased) }

      if matched_upgrades.empty?
        event <<
          "Couldn't find any upgrades similar to '#{upgrade_name}' in progress for '#{guild_name}'"
        return
      elsif matched_upgrades.count > 1
        upgrade_names = matched_upgrades.map { |u| u[:name] }.sort * ', '
        event << "Found more than one match for '#{upgrade_name}': #{upgrade_names}"
        return
      end
      upgrade = matched_upgrades[0]

      costs = upgrade[:costs]
      item_costs = costs.select { |c| c[:type] == 'Item' }
      non_item_costs = costs.reject { |c| c[:type] == 'Item' }

      item_cost_ids = item_costs.map { |c| c[:item_id] }.to_set
      items_owned =
        treasury
        .select { |t| item_cost_ids.include?(t[:item_id]) }
        .map { |t| t.values_at :item_id, :count }
        .to_h

      item_costs.map! do |c|
        owned = items_owned[c[:item_id]]
        needed = c[:count]
        complete = owned >= needed
        { name: c[:name], needed: needed, owned: owned, complete: complete }
      end
      item_costs.reject! { |c| c[:complete] }

      non_item_costs.map! do |c|
        name = c[:name]
        needed = c[:count]
        owned = nil
        owned = guild[:favor] if name == 'Guild Favor'
        owned = guild[:aetherium] if name == 'Aetherium'
        complete = !(owned.nil?) && owned >= needed
        { name: name, needed: needed, owned: owned, complete: complete }
      end
      non_item_costs.reject! { |c| c[:complete] || c[:owned].nil? }

      event.channel.send_embed do |embed|
        embed.title = upgrade[:name]
        embed.description = upgrade[:description]
        # embed.url = "https://wiki.guildwars2.com/wiki/#{upgrade[:name]}"
        embed.thumbnail = { url: upgrade[:icon] }
        (item_costs + non_item_costs).each do |c|
          embed.add_field(
            name: c[:name],
            value: TextFormat::GradientProgressBar.new(
              progress: c[:owned],
              max: c[:needed]
            ).render
          )
        end
        if item_costs.empty? && non_item_costs.empty?
          embed.add_field(name: 'Complete!', value: 'This upgrade is ready to build!')
        end
        embed
      end
    end

    private

    def upgrade_name_downcased
      @upgrade_name_downcased ||= upgrade_name.downcase
      @upgrade_name_downcased
    end

    attr_reader :guild_name, :upgrade_name, :token
  end

  # An event handler that displays guild treasury contributions during the last day for the guild
  # with the given name to the event's originating channel, using the given GW2 API token.
  class GuildContributionsHandler
    def initialize(guild_name, token)
      @guild_name = guild_name
      @token = token
    end

    def handle(event)
      guild_ids = GW2::API::GuildSearch.request name: guild_name
      if guild_ids.empty?
        event << "No guild found with name '#{guild_name}'"
        return
      end
      guild_id = guild_ids[0]

      log = GW2::API::GuildLog.request id: guild_id, token: token
      time_limit = DateTime.now.prev_day(1)

      contributions =
        log
        .select { |l| l[:type] == 'treasury' }
        .select { |l| DateTime.iso8601(l[:time]) >= time_limit }
        .each_with_object({}) do |l, acc|
          item_id = l[:item_id]
          item_hash = acc.fetch(item_id, count: 0)
          item_hash[:count] = item_hash[:count] + l[:count]
          acc[item_id] = item_hash
        end

      if contributions.empty?
        event << 'In the last day, there have been no guild contributions. :slight_frown:'
        return
      end

      item_ids = contributions.keys * ','
      GW2::API::ItemCatalogMany
        .request(ids: item_ids)
        .each do |item|
          item_id = item[:id]
          item_name = item[:name]
          contributions[item_id][:name] = item_name
        end

      event << (
        "In the last day, guild members have contributed:\n" +
        (contributions.values.map { |c| "#{c[:name]} - #{c[:count]}" }.to_a * "\n"))
    end

    private

    attr_reader :guild_name, :upgrade_name, :token
  end

  # An event handler that displays upgrades using the given ingredient for the guild with the given
  # name to the event's originating channel, using the given GW2 API token.
  class GuildIngredientUpgradesHandler
    def initialize(guild_name, item_name, token)
      @guild_name = guild_name
      @item_name = item_name
      @token = token
    end

    def handle(event)
      guild_ids = GW2::API::GuildSearch.request name: guild_name
      if guild_ids.empty?
        event << "No guild found with name '#{guild_name}'"
        return
      end
      guild_id = guild_ids[0]

      treasury = GW2::API::GuildTreasury.request id: guild_id, token: token

      treasury_item_ids = treasury.map { |i| i[:item_id] } * ','
      treasury_items = GW2::API::ItemCatalogMany.request ids: treasury_item_ids

      matched_items = treasury_items.select { |i| i[:name].downcase.include?(item_name_downcased) }
      if matched_items.empty?
        event << "Couldn't find any treasury items similar to '#{item_name}' for '#{guild_name}'"
        return
      elsif matched_items.count > 1
        item_names = matched_items.map { |i| i[:name] }.sort * ', '
        event << "Found more than one match for '#{item_name}': #{item_names}"
        return
      end
      item = matched_items[0]
      item_id = item[:id]

      treasury_item = treasury.select { |i| i[:item_id] == item_id }.first
      upgrade_ids = treasury_item[:needed_by].map { |u| u[:upgrade_id] } * ','
      upgrades_by_id =
        GW2::API::GuildUpgradeCatalogMany
        .request(ids: upgrade_ids)
        .each_with_object({}) { |u, m| m[u[:id]] = u }

      total_needed = treasury_item[:needed_by].inject(0) { |sum, u| sum + u[:count] }

      event.channel.send_embed do |embed|
        embed.title = item[:name]
        embed.description = TextFormat::GradientProgressBar.new(
          progress: treasury_item[:count],
          max: total_needed
        ).render
        embed.thumbnail = { url: item[:icon] }
        embed
      end

      has_enough, not_enough =
        treasury_item[:needed_by]
        .partition { |u| u[:count] <= treasury_item[:count] }
        .map { |u_list| format_upgrade_list(u_list, upgrades_by_id) }

      has_enough_section = nil
      has_enough_section = "**Enough to Build:**\n#{has_enough}" unless has_enough.empty?
      not_enough_section = nil
      not_enough_section = "**Insufficient to Build:**\n#{not_enough}" unless not_enough.empty?

      formatted_upgrades = [has_enough_section, not_enough_section].select { |u| u }.join("\n\n")
      event << formatted_upgrades
    end

    private

    def format_upgrade_list(upgrades, upgrades_by_id)
      upgrades
        .map { |u| [u[:count], upgrades_by_id[u[:upgrade_id]][:name]] }
        .sort
        .map { |u| "#{u[1]} :: #{u[0]}" }
        .join("\n")
    end

    def item_name_downcased
      @item_name_downcased ||= item_name.downcase
      @item_name_downcased
    end

    attr_reader :guild_name, :item_name, :token
  end

  # An event handler that displays upgrades ready to build for the guild with the given name to the
  # event's originating channel, using the given GW2 API token.
  # If Aetherium is the only resource remaining, the upgrade will be displayed with a pending
  # aetherium count.
  class GuildReadyUpgradesHandler
    def initialize(guild_name, token)
      @guild_name = guild_name
      @token = token
    end

    def handle(event)
      guild_ids = GW2::API::GuildSearch.request name: guild_name
      if guild_ids.empty?
        event << "No guild found with name '#{guild_name}'"
        return
      end
      guild_id = guild_ids[0]

      guild = GW2::API::GuildDetails.request id: guild_id, token: token

      all_upgrade_ids = Set.new
      incomplete_upgrade_ids = Set.new
      GW2::API::GuildTreasury.request(id: guild_id, token: token).each do |i|
        i[:needed_by].each do |u|
          all_upgrade_ids << u[:upgrade_id]
          incomplete_upgrade_ids << u[:upgrade_id] if u[:count] > i[:count]
        end
      end

      item_ready_upgrade_ids = all_upgrade_ids - incomplete_upgrade_ids
      if item_ready_upgrade_ids.empty?
        event << 'No upgrades ready to build. Get cracking, you slack-tailed maggots! :wrench:'
        return
      end

      upgrade_ids = item_ready_upgrade_ids.to_a * ','
      upgrades =
        GW2::API::GuildUpgradeCatalogMany
        .request(ids: upgrade_ids)
        .reject do |u|
          favor_cost = u[:costs].find { |c| c[:name] == 'Guild Favor' }
          favor_cost && favor_cost[:count] > guild[:favor]
        end

      upgrades.each do |u|
        aeth_cost = u[:costs].find { |c| c[:name] == 'Aetherium' } || { count: 0 }
        u[:missing_aether] = [0, aeth_cost[:count] - guild[:aetherium]].max
      end

      formatted_upgrades =
        upgrades
        .sort_by { |u| u.values_at(:missing_aether, :name) }
        .map do |u|
          aether_info = ''
          aether_info = " (pending #{u[:missing_aether]} Aetherium)" if u[:missing_aether].positive?
          "#{u[:name]}#{aether_info}"
        end
        .join("\n")
      event << formatted_upgrades
    end

    private

    attr_reader :guild_name, :token
  end
end
