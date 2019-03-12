module Recondition
  module Valued
    def initialize(value)
      @value = value
    end

    private

    attr_reader :value
  end

  class Present
    include Valued

    def when_present
      PresentWithPresenceChecked.new(yield value)
    end

    def when_absent
      PresentWithAbsenceChecked.new value
    end

    class PresentWithPresenceChecked
      include Valued

      def when_absent
        value
      end
    end

    class PresentWithAbsenceChecked
      include Valued

      def when_present
        yield value
      end
    end

    private_constant :PresentWithPresenceChecked, :PresentWithAbsenceChecked
  end

  class Absent
    def when_present
      AbsentWithPresenceChecked.new
    end

    def when_absent
      AbsentWithAbsenceChecked.new(yield)
    end

    class AbsentWithPresenceChecked
      def when_absent
        yield
      end
    end

    class AbsentWithAbsenceChecked
      include Valued

      def when_present
        value
      end
    end

    private_constant :AbsentWithPresenceChecked, :AbsentWithAbsenceChecked
  end
end
