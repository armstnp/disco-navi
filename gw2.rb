require 'cgi'
require 'httparty'
require 'discordrb/webhooks'

class HashEx
  def self.hash_str_keys_to_syms(x)
    return x unless x.is_a? Hash

    x.inject({}) do |memo, (k,v)|
      new_k = k.is_a?(String) ? k.to_sym : k

      new_v = v
      new_v = v.map { |x| hash_str_keys_to_syms(x) } if v.is_a? Array
      new_v = hash_str_keys_to_syms(v) if v.is_a? Hash

      memo[new_k] = new_v;
      memo
    end
  end
end

module GW2

  class Item
    def initialize(item_id)
      @item_id = item_id
    end

    def fetch
      response = HTTParty.get url
      if response.success?
        item_hash = response.parsed_response
        item_hash = HashEx::hash_str_keys_to_syms(item_hash)
        @item = item_hash
      else
        @item = nil
      end
    end

    def exists?
      !(item.nil?)
    end

    def name
      item[:name]
    end

    def icon
      item[:icon]
    end

    def chat_link
      item[:chat_link]
    end

    def rarity_color
      {'Junk' => 0xAAAAAA,
       'Basic' => 0x000000,
       'Fine' => 0x62A4DA,
       'Masterwork' => 0x1A9306,
       'Rare' => 0xFCD00B,
       'Exotic' => 0xFFA405,
       'Ascended' => 0xFB3E8D,
       'Legendary' => 0x4C139D}[rarity]
    end

    def has_description?
      !(item[:description].nil?)
    end

    def description
      item[:description] || (item[:details] && item[:details][:description])
    end

    def wiki_url
      clink = CGI::escape(chat_link)
      "https://wiki.guildwars2.com/index.php?title=Special%3ASearch&search=#{clink}&go=Go"
    end

    private

    attr_reader :item_id, :item

    def url
      "https://api.guildwars2.com/v2/items/#{item_id}"
    end

    def rarity
      item[:rarity]
    end
  end

  class ItemEmbed
    def initialize(item)
      @item = item
    end

    def print(event)
      event.channel.send_embed do |embed|
        embed.title = item.name
        embed.description = item.description if item.has_description?
        embed.url = item.wiki_url
        embed.color = item.rarity_color
        embed.thumbnail = { url: item.icon }
        embed.add_field(name: 'Chat Link', value: "`#{item.chat_link}`", inline: true)
        embed
      end
    end

    private

    attr_reader :item
  end
end
