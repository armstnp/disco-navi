module Recondition
  class Present
    def initialize(value)
      @value = value
    end

    def when_present
      PresentWithPresenceChecked.new(yield value)
    end

    def when_absent
      PresentWithAbsenceChecked.new value
    end

    class PresentWithPresenceChecked
      def initialize(value)
        @value = value
      end

      def when_absent
        value
      end

      private

      attr_reader :value
    end

    class PresentWithAbsenceChecked
      def initialize(value)
        @value = value
      end

      def when_present
        yield value
      end

      private

      attr_reader :value
    end

    private_constant :PresentWithPresenceChecked, :PresentWithAbsenceChecked

    private

    attr_reader :value
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
      def initialize(value)
        @value = value
      end

      def when_present
        value
      end

      private

      attr_reader :value
    end

    private_constant :AbsentWithPresenceChecked, :AbsentWithAbsenceChecked
  end
end
