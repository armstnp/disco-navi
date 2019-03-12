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

  # An error indicating an assumption was incorrectly made about the state of a Reconditioned object
  class BadAssumption < StandardError
    def initialize(msg)
      super msg
    end
  end

  # --=== Role: Maybe ==-
  # A value that may or may not be present.
  #
  # Condense its contents to a single type by chaining two messages in any order:
  # - when_present { |value| ... }
  # - when_absent { ... }
  #
  # The result will be the value returned by the appropriate block, depending on whether the value
  #  was present or not.
  # For best results, ensure both possible returned objects fill some common role.
  #
  # Other uses of the role include:
  # - assume_present: returns the value if present, or raises an error if absent
  # - assume_absent: throws if present

  # A value that is present. Fills the Maybe role.
  class Present
    include Valued

    def when_present
      PresentWithPresenceChecked.new(yield value)
    end

    def when_absent
      PresentWithAbsenceChecked.new value
    end

    def assume_present
      value
    end

    def assume_absent
      raise BadAssumption, 'Present value was assumed to be absent.'
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

  # The absence of a value. Fills the Maybe role.
  class Absent
    def when_present
      AbsentWithPresenceChecked.new
    end

    def when_absent
      AbsentWithAbsenceChecked.new(yield)
    end

    def assume_present
      raise BadAssumption, 'Absent value was assumed to be present.'
    end

    def assume_absent; end

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

  # --=== Role: Either ===--
  # A value that fills one of two expected slots, 'left' and 'right'; useful for short-term results
  # where the caller can better determine which common role it wants the value to fill than the
  # object constructing the Either object.
  #
  # Condense its contents to a single type by chaining two messages in any order:
  # - when_left { |value| ... }
  # - when_right { |value| ... }
  #
  # The result will be the value returned by the appropriate block, depending on whether the value
  #  was in the left or right slot.
  # For best results, ensure both possible returned objects fill some common role.

  # A value that is in the left slot. Fills the Either role.
  class Left
    include Valued

    def when_left
      LeftWithLeftChecked.new(yield value)
    end

    def when_right
      LeftWithRightChecked.new(value)
    end

    # A left-slotted object that has been condensed, and is awaiting the right check
    class LeftWithLeftChecked
      include Valued

      def when_right
        value
      end
    end

    # A left-slotted object that is awaiting condensation with a left check
    class LeftWithRightChecked
      include Valued

      def when_left
        yield value
      end
    end

    private_constant :LeftWithLeftChecked, :LeftWithRightChecked
  end

  # A value that is in the right slot. Fills the Either role.
  class Right
    include Valued

    def when_left
      RightWithLeftChecked.new(value)
    end

    def when_right
      RightWithRightChecked.new(yield value)
    end

    # A right-slotted object that is awaiting condensation with a right check
    class RightWithLeftChecked
      include Valued

      def when_right
        yield value
      end
    end

    # A right-slotted object that has been condensed, and is awaiting the left check
    class RightWithRightChecked
      include Valued

      def when_left
        value
      end
    end

    private_constant :RightWithLeftChecked, :RightWithRightChecked
  end

  # --=== Role: Result ===--
  # A value that fills one of two expected slots, 'success' and 'failure'; useful for short-term
  # results where the caller can better determine which common role it wants the value to fill than
  # the object constructing the Result object, and has stronger labels than 'Either' for its slots.
  #
  # Condense its contents to a single type by chaining two messages in any order:
  # - when_success { |value| ... }
  # - when_failure { |value| ... }
  #
  # The result will be the value returned by the appropriate block, depending on whether the value
  #  was in the success or failure slot.
  # For best results, ensure both possible returned objects fill some common role.

  # A value that is a successful result of some operation. Fills the Result role.
  class Success
    include Valued

    def when_success
      SuccessWithSuccessChecked.new(yield value)
    end

    def when_failure
      SuccessWithFailureChecked.new(value)
    end

    # A success object that has been condensed, and is awaiting the failure check
    class SuccessWithSuccessChecked
      include Valued

      def when_failure
        value
      end
    end

    # A success object that is awaiting condensation with a success check
    class SuccessWithFailureChecked
      include Valued

      def when_success
        yield value
      end
    end

    private_constant :SuccessWithSuccessChecked, :SuccessWithFailureChecked
  end

  # A value that is the failed result of some operation. Fills the Result role.
  class Failure
    include Valued

    def when_success
      FailureWithSuccessChecked.new(value)
    end

    def when_failure
      FailureWithFailureChecked.new(yield value)
    end

    # A failure object that is awaiting condensation with a failure check
    class FailureWithSuccessChecked
      include Valued

      def when_failure
        yield value
      end
    end

    # A failure object that has been condensed, and is awaiting the success check
    class FailureWithFailureChecked
      include Valued

      def when_success
        value
      end
    end

    private_constant :FailureWithSuccessChecked, :FailureWithFailureChecked
  end
end
