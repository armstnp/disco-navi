#!/usr/bin/env ruby

::RBNACL_LIBSODIUM_GEM_LIB_PATH = "D:/Dev/Projects/ivory-dice-rb/libsodium.dll"

require 'dotenv/load'
require 'discordrb'
require 'discordrb/webhooks'
require 'discordrb/webhooks/embeds'
require './gw2'
require './guild_upgrades'
require './calc'
require './zelda_status'

#
# If you don't yet have a token and application ID to put in here, you will need to create a bot account here:
#   https://discordapp.com/developers/applications/me
# If you're wondering about what redirect URIs and RPC origins, you can ignore those for now. If that doesn't satisfy
# you, look here: https://github.com/meew0/discordrb/wiki/Redirect-URIs-and-RPC-origins
# After creating the bot, simply copy the token (*not* the OAuth2 secret) and the client ID and put it into the
# respective places.
bot = Discordrb::Bot.new token: ENV['DISCORD_BOT_TOKEN'], client_id: (ENV['DISCORD_BOT_CLIENT_ID'].to_i)

puts "This bot's invite URL is #{bot.invite_url}."
puts 'Click on it to invite it to your server.'

$r = Random.new
$max_dice = 100000
$die_roll_regex = /\$(\d+)d(\S+)\s*(.*)/
$roll_char_cap = 800
$pesters = Dir["D:/Dev/Projects/ivory-dice-rb/soundboard/*"]
$gw2_api_token = ENV['GW2_API_TOKEN']
$aws_access_key_id = ENV['AWS_ACCESS_KEY_ID']
$aws_secret_access_key = ENV['AWS_SECRET_ACCESS_KEY']
$zurpg_status = ZURPG::StatusHandler.new

def beautify_int(i)
  i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
end

def roll_numeric(dice, sides)
  sides = Integer(sides)
  rolls = (0...dice).collect { |_| $r.rand(sides) + 1 }
  total = rolls.reduce(0, :+)

  roll_text = rolls.collect { |x| beautify_int(x) }.reduce { |accum, x| accum << ", #{x}" }
  roll_text = roll_text[0...$roll_char_cap] << "..." if roll_text.size > $roll_char_cap

  {rolls: roll_text, result: "**Total**: #{beautify_int(total)}"}
end

def successes(x)
  if (5..9).include?(x) then 1
  elsif 10 == x then 2
  else 0
  end
end

def format_success(x)
  s = successes(x)
  if s == 1 then "**#{x}**"
  elsif s == 2 then "__**#{x}**__"
  else x.to_s
  end
end

def roll_zelda(dice)
  rolls = (0...dice).collect { |_| $r.rand(10) + 1 }

  is_over_cap = false
  roll_text =
    rolls.collect { |x| format_success(x) }
         .reduce do |accum, x|
           if accum.length + x.length + 5 <= $roll_char_cap
             accum << ", #{x}"
           else
             is_over_cap = true
             accum
           end
         end
  
  roll_text = roll_text << '...' if is_over_cap

  successes = rolls.collect { |x| successes(x) }.reduce(0, :+)

  {rolls: roll_text, result: "**Successes**: #{beautify_int(successes)}"}
end

def is_zelda_die_type?(die_type)
  die_type =~ /^((10)|Z|z)$/
end

# Respond to '$Xd___', AKA a die roll request
bot.message(contains: $die_roll_regex) do |event|
  num_dice, die_type, comment = event.content.match($die_roll_regex).captures

  num_dice = Integer(num_dice)
  num_dice = $max_dice if num_dice > $max_dice
  die_noun = 'Dice'
  die_noun = 'Die' if num_dice == 1

  side_noun = die_type == "1" ? 'Side' : 'Sides'

  comment = comment.strip

  outcome = roll_numeric(num_dice, die_type) unless is_zelda_die_type?(die_type)
  outcome = roll_zelda(num_dice) if is_zelda_die_type?(die_type)

  author_name =
    if event.author.respond_to?(:display_name)
    then event.author.display_name
    else event.author.username end
  
  event << "**#{author_name}**: #{outcome[:rolls]}\n#{outcome[:result]}"
end



bot.message(start_with: /\$join\s+/) do |event|
  channel_name = event.content.match(/\$join\s+(.+)/).captures[0]
  voice_channels = bot.find_channel(channel_name, event.server&.name, type: 2) # 2: voice channel

  if voice_channels.empty? then
    event << "No voice channel found: '#{channel_name}'"
  elsif voice_channels.size > 1 then
    channel_names =
      voice_channels
      .collect { |c| "#{c.server&.name}\##{c.name}" }
      .reduce { |accum, x| accum << ", #{x}" }
    event << "Ambiguous voice channel name; found options: #{channel_names}"
  else
    bot.voice_connect(voice_channels[0])
  end
end

bot.message(content: "$leave") do |event|
  event.voice&.destroy
  event << "Okay, okay, I'll leave now..." unless event.voice
end

bot.message(content: "$whereyouat") do |event|
  event << event.voice&.channel&.name
end

bot.message(start_with: "$pester") do |event|
  captures = event.content.match(/\$pester\s*(\d*)\s*(speak)?/).captures
  repetitions = 1
  repetitions = captures[0].to_i if captures[0] && !(captures[0].empty?)
  speak = true if captures[1]
  repetitions.times do
    event.voice.play_file($pesters.sample) if event.voice
    event.channel.send_message(["Hello!", "Hey!", "Listen!", "Look!", "Watch out!"].sample, true) if speak
  end
end

bot.message(start_with: /\$calc\s+/) do |event|
  expr = event.content.match(/\$calc\s+(.*)/).captures[0]
  calculator = Calculator::Handler.new(expr)
  calculator.calculate(event)
end

bot.message(start_with: '$gw2 item') do |event|
  item_id = event.content.match(/\$gw2 item\s+(\d+)/).captures[0]
  item = GW2::Item.new(item_id)
  item.fetch
  item_embed = GW2::ItemEmbed.new(item)
  item_embed.print(event)
end

bot.message(start_with: '$gw2 guild info') do |event|
  guild_name = event.content.match(/\$gw2 guild info\s+'(.+?)'/).captures[0]
  GW2::GuildInfoHandler.new(guild_name, $gw2_api_token).handle(event).render(event)
end

bot.message(start_with: '$gw2 guild list upgrades') do |event|
  guild_name = event.content.match(/\$gw2 guild list upgrades\s+'(.+?)'/).captures[0]
  GW2::GuildUpgradeListHandler.new(guild_name, $gw2_api_token).handle(event)
end

bot.message(start_with: '$gw2 guild list ready upgrades') do |event|
  guild_name = event.content.match(/\$gw2 guild list ready upgrades\s+'(.+?)'/).captures[0]
  GW2::GuildReadyUpgradesHandler.new(guild_name, $gw2_api_token).handle(event)
end

bot.message(start_with: '$gw2 guild upgrade') do |event|
  guild_name, upgrade_name = event.content.match(/\$gw2 guild upgrade\s+'(.+?)'\s+'(.+?)'/).captures
  GW2::GuildUpgradeInfoHandler.new(guild_name, upgrade_name, $gw2_api_token).handle(event)
end

bot.message(start_with: '$gw2 guild contrib') do |event|
  guild_name = event.content.match(/\$gw2 guild contrib\s+'(.+?)'/).captures[0]
  GW2::GuildContributionsHandler.new(guild_name, $gw2_api_token).handle(event)
end

bot.message(start_with: '$gw2 guild item upgrades') do |event|
  guild_name, item_name = event.content.match(/\$gw2 guild item upgrades\s+'(.+?)'\s+'(.+?)'/).captures
  GW2::GuildIngredientUpgradesHandler.new(guild_name, item_name, $gw2_api_token).handle(event)
end

bot.message(start_with: '$zstatus') do |event|
  status_in = event.content.match(/\$zstatus\s*(.*)/).captures[0]
  if status_in.nil?
    return
  elsif status_in.empty?
    $zurpg_status.handle_fetch(event)
  elsif status_in.strip == 'clear'
    $zurpg_status.handle_clear(event)
  else
    $zurpg_status.handle_save(status_in, event)
  end
end

bot.message(content: '$help') do |event|
  event.channel.send_embed() do |embed|
    embed.title = 'Utility'
    embed.color = 0xAA3939
    embed.add_field(name: '${x}d{y} or ${x}D{y}', value: 'Roll x dice with y sides, e.g. $5d20')
    embed.add_field(
      name: '${x}dz or ${x}dZ or ${x}d10',
      value: 'Roll x special ZURPG dice: 1-4 = 0, 5-9 = 1, 10 = 2')
    embed.add_field(
      name: '$zstatus {status}',
      value: 'Sets your status')
    embed.add_field(
      name: '$zstatus',
      value: 'Displays your status')
    embed.add_field(
      name: '$zstatus clear',
      value: 'Clears your status')
    embed.add_field(
      name: '$calc {expression}',
      value: 'Do integer / rational mathematics.  No spaces allowed. +,-,*,/,(), and die rolls permitted, e.g. 10d10-5+2/(2d2+6)')
  end
  event.channel.send_embed() do |embed|
    embed.title = 'Voice'
    embed.color = 0x226666
    embed.add_field(
      name: '$join {voice-channel}',
      value: 'Make Navi join a voice chat channel by name, e.g. $join General')
    embed.add_field(
      name: '$pester [n] [speak]',
      value: 'Make Navi nag people in voice n times (1 by default), and in TTS if you tell her to speak; e.g. $pester 10 speak')
    embed.add_field(name: '$leave', value: "Make Navi leave any voice channel she's in")
  end
  event.channel.send_embed() do |embed|
    embed.title = 'Guild Wars 2'
    embed.color = 0x7B9F35
    embed.add_field(
      name: "$gw2 guild info '{guild-name}'",
      value: "Show info about the given guild, e.g. $gw2 guild info 'The Shard Warband'")
    embed.add_field(
      name: "$gw2 guild list upgrades '{guild-name}'",
      value: "Show upgrades in progress for the given guild, e.g. $gw2 guild list upgrades 'The Shard Warband'")
    embed.add_field(
      name: "$gw2 guild list ready upgrades '{guild-name}'",
      value: "Show upgrades ready to build for the given guild, e.g. $gw2 guild list ready upgrades 'The Shard Warband'")
    embed.add_field(
      name: "$gw2 guild upgrade '{guild-name}' '{upgrade-name}'",
      value: "Show remaining progress for the given upgrade, e.g. $gw2 guild upgrade 'The Shard Warband' 'Tavern'")
    embed.add_field(
      name: "$gw2 guild contrib '{guild-name}'",
      value: "Shows guild treasury contributions over the past day, e.g. $gw2 guild contrib 'The Shard Warband'")
    embed.add_field(
      name: "$gw2 guild item upgrades '{guild-name}' '{item-name}'",
      value: "Shows upgrades that use the given item, and quantities required, e.g. $gw2 guild item upgrades 'The Shard Warband' 'Linseed'")
  end
end

bot.run
