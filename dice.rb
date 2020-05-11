module Dice
  RANDOM = Random.new
  DIE_ROLL_REGEX = /\$(\d+)d(\S+)\s*(.*)/.freeze
  ROLL_CHAR_CAP = 800
  MAX_DICE = 100_000

  ZELDA_DIE_TYPE_RE = /^((10)|Z|z)$/.freeze
  ORITHAN_DIE_TYPE_RE = /^((6)|O|o)$/.freeze

  def self.new(roll_phrase)
    num_dice, die_type, comment = roll_phrase.match(DIE_ROLL_REGEX).captures

    num_dice = [Integer(num_dice), MAX_DICE].min

    comment = comment.strip

    die_variant =
      case die_type
      when ZELDA_DIE_TYPE_RE then ZeldaDie
      when ORITHAN_DIE_TYPE_RE then OrithanDie
      else NumericDie
      end

    die_variant.new(num_dice, die_type, comment)
  end

  class Die
    def initialize(num_dice, die_type, comment)
      @num_dice = num_dice
      @die_type = die_type
      @comment = comment
    end

    def beautify_int(i)
      i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    end

    def roll(roller)
      display_comment = ''
      display_comment = " (#{comment})" unless comment.empty?

      outcome = perform_roll

      "**#{roller}**: #{outcome[:rolls]}#{display_comment}\n#{outcome[:result]}"
    end

    protected

    attr_reader :num_dice, :die_type, :comment
  end

  class NumericDie < Die
    def initialize(num_dice, die_type, comment)
      super(num_dice, die_type, comment)
    end

    def perform_roll
      sides = Integer(die_type)
      rolls = (0...num_dice).collect { |_| RANDOM.rand(sides) + 1 }
      total = rolls.reduce(0, :+)

      roll_text = rolls.collect(&method(:beautify_int)).reduce { |accum, x| accum << ", #{x}" }
      roll_text = roll_text[0...ROLL_CHAR_CAP] << '...' if roll_text.size > ROLL_CHAR_CAP

      { rolls: roll_text, result: "**Total**: #{beautify_int(total)}" }
    end
  end

  class SuccessDie < Die
    def initialize(num_dice, die_type, comment)
      super(num_dice, die_type, comment)
    end

    def format_successes(roll_val)
      s = map_successes(roll_val)
      if s == 1 then "**#{roll_val}**"
      elsif s == 2 then "__**#{roll_val}**__"
      else roll_val.to_s
      end
    end

    def perform_roll
      sides = Integer(die_type)
      rolls = (0...num_dice).collect { |_| RANDOM.rand(sides) + 1 }

      is_over_cap = false
      roll_text =
        rolls
        .collect(&method(:format_successes))
        .reduce do |accum, x|
          if accum.length + x.length + 5 <= ROLL_CHAR_CAP
            accum << ", #{x}"
          else
            is_over_cap = true
            accum
          end
        end

      roll_text = roll_text << '...' if is_over_cap
      successes = rolls.collect(&method(:map_successes)).reduce(0, :+)

      { rolls: roll_text, result: "**Successes**: #{beautify_int(successes)}" }
    end
  end

  class ZeldaDie < SuccessDie
    def initialize(num_dice, _die_type, comment)
      super(num_dice, 10, comment)
    end

    def map_successes(x)
      case x
      when 5..9 then 1
      when 10 then 2
      else 0
      end
    end
  end

  class OrithanDie < SuccessDie
    def initialize(num_dice, _die_type, comment)
      super(num_dice, 6, comment)
    end

    def map_successes(x)
      case x
      when 4..5 then 1
      when 6 then 2
      else 0
      end
    end
  end
end
