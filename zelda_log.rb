# frozen_string_literal: true

module ZURPG
  class ActiveLogGenerator
    MAX_BACKSEEK_HRS = 24
    MAX_BACKSEEK_SECS = MAX_BACKSEEK_HRS * 60 * 60
    MAX_BACKSEEK_MESSAGES = 100_000

    def initialize(end_log_message)
      @end_log_message = end_log_message
    end

    def call
      status_message = channel.send_message 'Seeking backwards: 0 messages'

      start_message = backseek from_message: end_log_message, recording_to_status: status_message
      unless start_message
        error = <<~MSG
          Couldn't find the starting point to your log.
          Searched to a maximum of #{MAX_BACKSEEK_HRS} hours, #{MAX_BACKSEEK_MESSAGES} messages.
        MSG
        channel.send_temporary_message error, 30
        return
      end

      file = LogSpitter.new(start_message, end_log_message, status_message).call
      channel.send_file File.open(file, 'r')
    end

    private

    def backseek(from_message:, recording_to_status:, curr_offset: 0)
      channel.start_typing if (curr_offset % 500).zero?
      recording_to_status.edit "Seeking backwards: #{curr_offset} messages"

      messages = channel.history(100, from_message.id) # Retrieves in reverse order

      start_message = messages.find { |m| start_of_log? m }
      return start_message if start_message

      last_message = messages.last
      return unless in_backseek_range? last_message

      # TODO: Properly trampoline
      backseek(
        from_message: last_message,
        recording_to_status: recording_to_status,
        curr_offset: curr_offset + 100
      )
    end

    attr_reader :end_log_message

    def channel
      end_log_message.channel
    end

    def author_id
      @author_id ||= end_log_message.author.id
    end

    def end_timestamp
      @end_timestamp ||= end_log_message.timestamp
    end

    def earliest_start_timestamp
      @earliest_start_timestamp ||= end_timestamp - MAX_BACKSEEK_SECS
    end

    def start_of_log?(message)
      start_log_command?(message) && matches_author?(message)
    end

    def start_log_command?(message)
      message.content.strip.start_with? '$startlog'
    end

    def matches_author?(message)
      message.author.id == author_id
    end

    def in_backseek_range?(message)
      message.timestamp > earliest_start_timestamp
    end
  end

  class LogSpitter
    def initialize(start_message, end_message, status_message)
      @start_message = start_message
      @end_message = end_message
      @status_message = status_message
    end

    def call
      File.open(filename, 'w') do |f|
        curr_message = [start_message, 0]
        curr_message = spit_to f, *curr_message while curr_message
      end
      filename
    end

    private

    def spit_to(file, from_message, tally)
      channel.start_typing if (tally % 500).zero?
      status_message.edit "Writing to log: #{tally} messages"

      messages = channel.history(100, nil, from_message.id).reverse
      messages
        .take_while { |m| !end_message?(m) }
        .map { |m| format_message m }
        .each { |m| file.puts m }

      [messages.last, tally + 100] unless messages.any? { |m| end_message? m }
    end

    def format_message(message)
      content = message.content
      author = message.author&.nick || message.author.username
      if emote? content
        "*\t#{author} #{content[1..-2]}"
      else
        "<#{author}>\t#{content}"
      end
    end

    def emote?(content)
      content.start_with?('_') && content.end_with?('_')
    end

    attr_reader :start_message, :end_message, :status_message

    def channel
      @channel ||= start_message.channel
    end

    def end_message?(message)
      message.id == end_message_id
    end

    def end_message_id
      @end_message_id ||= end_message.id
    end

    def filename
      return @filename if @filename

      sname = channel.server.name
      cname = channel.name
      ts = start_message.timestamp.strftime '%Y%m%d%H%M%S'
      requestor = end_message.author
      rname = requestor&.nick || requestor.username
      @filename = "/tmp/#{sname} - #{cname} - #{ts} - #{rname}.txt"
    end
  end
end
