# frozen_string_literal: true

require 'rspec'
require 'disco_navi/recondition'

describe Recondition::Present do
  it 'contains a value' do
    Recondition::Present.new 'value'
  end

  context 'a present value that has been created' do
    let(:present) { Recondition::Present.new 'value' }

    it 'is assumed to have a value' do
      present.assume_present
    end

    it 'is assumed to have the value it was created with' do
      expect(present.assume_present).to eql 'value'
    end

    it 'cannot be assumed to be absent' do
      expect { present.assume_absent }.to raise_error Recondition::BadAssumption
    end

    it 'can be condensed starting with the present case' do
      condensed_value =
        present
        .when_present { |value| value + 'x' }
        .when_absent { 'no value' }

      expect(condensed_value).to eql 'valuex'
    end

    it 'can be condensed starting with the absent case' do
      condensed_value =
        present
        .when_absent { 'no value' }
        .when_present { |value| value + 'x' }

      expect(condensed_value).to eql 'valuex'
    end
  end
end

describe Recondition::Absent do
  it 'contains no value' do
    Recondition::Absent.new
  end

  context 'an absent value that has been created' do
    let(:absent) { Recondition::Absent.new }

    it 'is assumed to be absent' do
      absent.assume_absent
    end

    it 'cannot be assumed to be present' do
      expect { absent.assume_present }.to raise_error Recondition::BadAssumption
    end

    it 'can be condensed starting with the absent case' do
      condensed_value =
        absent
        .when_absent { 'no value' }
        .when_present { |value| value + 'x' }

      expect(condensed_value).to eql 'no value'
    end

    it 'can be condensed starting with the present case' do
      condensed_value =
        absent
        .when_present { |value| value + 'x' }
        .when_absent { 'no value' }

      expect(condensed_value).to eql 'no value'
    end
  end
end

describe Recondition::Left do
  it 'contains a left-slotted value' do
    Recondition::Left.new 'left'
  end

  context 'a left value that has been created' do
    let(:left) { Recondition::Left.new 'left' }

    it 'can be condensed starting with the left case' do
      condensed_value =
        left
        .when_left { |value| value + 'x' }
        .when_right { |value| value + 'y' }

      expect(condensed_value).to eql 'leftx'
    end

    it 'can be condensed starting with the right case' do
      condensed_value =
        left
        .when_right { |value| value + 'y' }
        .when_left { |value| value + 'x' }

      expect(condensed_value).to eql 'leftx'
    end
  end
end

describe Recondition::Right do
  it 'contains a right-slotted value' do
    Recondition::Right.new 'right'
  end

  context 'a right value that has been created' do
    let(:right) { Recondition::Right.new 'right' }

    it 'can be condensed starting with the left case' do
      condensed_value =
        right
        .when_left { |value| value + 'x' }
        .when_right { |value| value + 'y' }

      expect(condensed_value).to eql 'righty'
    end

    it 'can be condensed starting with the right case' do
      condensed_value =
        right
        .when_right { |value| value + 'y' }
        .when_left { |value| value + 'x' }

      expect(condensed_value).to eql 'righty'
    end
  end
end

describe Recondition::Success do
  it 'contains a success value' do
    Recondition::Success.new 'success'
  end

  context 'a success value that has been created' do
    let(:success) { Recondition::Success.new 'success' }

    it 'can be condensed starting with the success case' do
      condensed_value =
        success
        .when_success { |value| value + 'x' }
        .when_failure { |value| value + 'y' }

      expect(condensed_value).to eql 'successx'
    end

    it 'can be condensed starting with the failure case' do
      condensed_value =
        success
        .when_failure { |value| value + 'y' }
        .when_success { |value| value + 'x' }

      expect(condensed_value).to eql 'successx'
    end

    it 'preserves its existing successful value when re-attempting on failure' do
      condensed_value =
        success
        .otherwise_try { |failure_value| Recondition::Success.new(failure_value + 'x') }
        .when_success { |value| value + 'y' }
        .when_failure { |value| value + 'z' }

      expect(condensed_value).to eql 'successy'
    end
  end
end

describe Recondition::Failure do
  it 'contains a failure value' do
    Recondition::Failure.new 'failure'
  end

  context 'a failure value that has been created' do
    let(:failure) { Recondition::Failure.new 'failure' }

    it 'can be condensed starting with the success case' do
      condensed_value =
        failure
        .when_success { |value| value + 'x' }
        .when_failure { |value| value + 'y' }

      expect(condensed_value).to eql 'failurey'
    end

    it 'can be condensed starting with the failure case' do
      condensed_value =
        failure
        .when_failure { |value| value + 'y' }
        .when_success { |value| value + 'x' }

      expect(condensed_value).to eql 'failurey'
    end

    it 'tries its provided block with its value when re-attempting on failure' do
      condensed_value =
        failure
        .otherwise_try { |failure_value| Recondition::Success.new(failure_value + 'x') }
        .when_success { |value| value + 'y' }
        .when_failure { |value| value + 'z' }

      expect(condensed_value).to eql 'failurexy'
    end
  end
end
