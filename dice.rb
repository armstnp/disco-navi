module Dice
  RANDOM = Random.new
  DIE_ROLL_REGEX = /\$(\d+)d(\S+)\s*(.*)/
  ROLL_CHAR_CAP = 800
  MAX_DICE = 100000

  def self.new(roll_phrase)
    num_dice, die_type, comment = roll_phrase.match(DIE_ROLL_REGEX).captures

    num_dice = Integer(num_dice)
    num_dice = MAX_DICE if num_dice > MAX_DICE

    comment = comment.strip

    die_variant =
      if is_zelda_die_type?(die_type) then ZeldaDie
      elsif is_orithan_die_type?(die_type) then OrithanDie
      else NumericDie
      end

    die_variant.new(num_dice, die_type, comment)
  end

  def self.is_zelda_die_type?(die_type)
    die_type =~ /^((10)|Z|z)$/
  end

  def self.is_orithan_die_type?(die_type)
    die_type =~ /^((6)|O|o)$/
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
      die_noun = 'Dice'
      die_noun = 'Die' if num_dice == 1

      side_noun = die_type == '1' ? 'Side' : 'Sides'

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

      roll_text = rolls.collect { |x| beautify_int(x) }.reduce { |accum, x| accum << ", #{x}" }
      roll_text = roll_text[0...ROLL_CHAR_CAP] << "..." if roll_text.size > ROLL_CHAR_CAP

      {rolls: roll_text, result: "**Total**: #{beautify_int(total)}"}
    end
  end

  class SuccessDie < Die
    def initialize(num_dice, die_type, comment)
      super(num_dice, die_type, comment)
    end

    def format_successes(x)
      s = map_successes(x)
      if s == 1 then "**#{x}**"
      elsif s == 2 then "__**#{x}**__"
      else x.to_s
      end
    end

    def perform_roll
      sides = Integer(die_type)
      rolls = (0...num_dice).collect { |_| RANDOM.rand(sides) + 1 }

      is_over_cap = false
      roll_text =
        rolls
          .collect { |x| format_successes(x) }
	        .reduce do |accum, x|
	      if accum.length + x.length + 5 <= ROLL_CHAR_CAP
	        accum << ", #{x}"
	      else
	        is_over_cap = true
	        accum
	      end
	    end

      roll_text = roll_text << '...' if is_over_cap
      successes = rolls.collect { |x| map_successes(x) }.reduce(0, :+)

      {rolls: roll_text, result: "**Successes**: #{beautify_int(successes)}"}
    end
  end

  class ZeldaDie < SuccessDie
    def initialize(num_dice, die_type, comment)
      super(num_dice, 10, comment)
    end

    def map_successes(x)
      if (5..9).include?(x) then 1
      elsif 10 == x then 2
      else 0
      end
    end
  end

  class OrithanDie < SuccessDie
    def initialize(num_dice, die_type, comment)
      super(num_dice, 6, comment)
    end

    def map_successes(x)
      if (4..5).include?(x) then 1
      elsif 6 == x then 2
      else 0
      end
    end
  end
end
