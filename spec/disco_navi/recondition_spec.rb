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
