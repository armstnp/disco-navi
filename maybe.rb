# frozen_string_literal: true

# Recondition - Conditionless objects designed to encourage condensing potential values to the same
# role.
module Recondition
  # Core mixin that marks the object as containing a private value.
  module Valued
    def initialize(value)
      @value = value
    end

    private

    attr_reader :value
  end

  # An object in which a value is present; follows the Maybe role
  class Present
    include Valued

    def when_present
      PresentWithPresenceChecked.new(yield value)
    end

    def when_absent
      PresentWithAbsenceChecked.new value
    end

    # A Present object that has been condensed, and is awaiting the absence check
    class PresentWithPresenceChecked
      include Valued

      def when_absent
        value
      end
    end

    # A Present object that is awaiting condensation with a presence check
    class PresentWithAbsenceChecked
      include Valued

      def when_present
        yield value
      end
    end

    private_constant :PresentWithPresenceChecked, :PresentWithAbsenceChecked
  end

  # An object in which value is absent; follows the Maybe role
  class Absent
    def when_present
      AbsentWithPresenceChecked.new
    end

    def when_absent
      AbsentWithAbsenceChecked.new(yield)
    end

    # An Absent object that is awaiting condensation with an absence check
    class AbsentWithPresenceChecked
      def when_absent
        yield
      end
    end

    # An Absent object that has been condensed, and is awaiting the presence check
    class AbsentWithAbsenceChecked
      include Valued

      def when_present
        value
      end
    end

    private_constant :AbsentWithPresenceChecked, :AbsentWithAbsenceChecked
  end
end
