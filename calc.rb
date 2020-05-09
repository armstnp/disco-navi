# frozen_string_literal: true

require 'parslet'

module Calculator
  class ArithmeticParser < Parslet::Parser
    rule(:sum) do
      infix_expression(
        expr,
        [product_op, 2, :left],
        [sum_op, 1, :left]
      )
    end

    rule(:roll_op) { match('[dD]') }
    rule(:product_op) { str('*') | str('/') }
    rule(:sum_op) { str('+') | str('-') }

    rule(:expr) { die_roll | integer | paren_expr | negative >> sum.as(:val) }

    rule(:integer) { match('[0-9]').repeat(1).as(:int) }

    rule(:die_roll) { die_integer.as(:dice) >> match('[dD]') >> die_integer.as(:sides) }
    rule(:die_integer) { match('[0-9]').repeat(1).as(:die_int) }

    rule(:paren_expr) { str('(') >> sum >> str(')') }

    rule(:negative) { str('-').as(:negative) }

    root(:sum)
  end

  class ArithmeticTransform < Parslet::Transform
    @@r = Random.new

    rule(int: simple(:x)) { Accumulator.new(Integer(x)) }
    rule(die_int: simple(:x)) { Integer(x) }
    rule(negative: '-', val: simple(:x)) { x.update_val { |v| -v } }
    rule(o: '+', l: simple(:l), r: simple(:r)) { l.merge(r) { |x, y| x + y } }
    rule(o: '-', l: simple(:l), r: simple(:r)) { l.merge(r) { |x, y| x - y } }
    rule(o: '*', l: simple(:l), r: simple(:r)) { l.merge(r) { |x, y| x * y } }
    rule(o: '/', l: simple(:l), r: simple(:r)) { l.merge(r) { |x, y| Rational(x, y) } }
    rule(dice: simple(:dice), sides: simple(:sides)) do
      roll = (0...dice).collect { |_| @@r.rand(sides) + 1 }
      total = roll.reduce(0, :+)
      roll_hash = {
        dice: dice,
        sides: sides,
        roll: roll,
        total: total
      }
      Accumulator.new(total, [roll_hash])
    end
  end

  class Accumulator
    attr_reader :val, :rolls

    def initialize(val, rolls = [])
      @val = val
      @rolls = rolls
    end

    def update_val
      Accumulator.new(yield(val), rolls)
    end

    def update_rolls
      Accumulator.new(val, yield(rolls))
    end

    def merge(other)
      Accumulator.new(yield(val, other.val), rolls.concat(other.rolls))
    end

    def print_rolls(event)
      rolls.each do |roll_hash|
        dice, sides, roll, total = roll_hash.values_at(:dice, :sides, :roll, :total)
        roll_str = roll * '+'
        event << "#{dice}d#{sides} => #{roll_str} => #{total}\n"
      end
    end
  end

  class Handler
    @@parser = ArithmeticParser.new
    @@transform = ArithmeticTransform.new

    def initialize(expr)
      @expr = expr
    end

    def calculate(event)
      expr_tree = @@parser.parse(expr)
      result = @@transform.apply(expr_tree)

      if result.is_a? Accumulator
        emit_result(result, event)
      else
        emit_transform_failure(event)
      end
    rescue Parslet::ParseFailed
      emit_parse_failure(event)
    end

    private

    attr_reader :expr

    def emit_result(result, event)
      result.print_rolls(event)
      result_val = result.val
      result_val = result_val.numerator if result_val.is_a?(Rational) && result_val.denominator == 1
      event << "`#{expr}` => #{result_val}"
    end

    def emit_transform_failure(event)
      event << "`#{expr}` => Hmm, I'm bad at math.  You entered something I can read, but can't calculate..."
    end

    def emit_parse_failure(event)
      event << "`#{expr}` => Do you even math, bro?"
    end
  end
end
