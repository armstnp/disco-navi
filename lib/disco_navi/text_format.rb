module TextFormat
  class ProgressBar
    def initialize(progress:, max:, title: nil, bar_width: 10)
      @progress = progress > max ? max : progress
      @max = max
      @title = title
      @bar_width = bar_width
    end

    def render
      filled_sections = fully_filled_sections + partially_full_sections
      empty_sections = '─' * (bar_width - filled_sections.length)
      "#{formatted_title}╟#{filled_sections}#{empty_sections}╢ :: #{progress}/#{max}"
    end

    private

    attr_reader :title, :progress, :max, :bar_width

    def formatted_title
      title ? "**#{title}** " : ''
    end

    def total_segments
      bar_width * 4
    end

    def segment_size
      Rational(max, total_segments)
    end

    def progress_segments
      (progress / segment_size).floor
    end

    def fully_filled_sections
      size = progress_segments / 4
      '█' * size
    end

    def partially_full_sections
      return '' if progress == max
      fill_selector = progress_segments % 4
      ['─', '░', '▒', '▓'][fill_selector]
    end
  end

  class GradientProgressBar
    def initialize(progress:, max:, title: nil, bar_width: 10)
      @progress = progress > max ? max : progress
      @max = max
      @title = title
      @bar_width = bar_width
    end

    def render
      "#{formatted_title}╟#{gradated_segments}╢ :: #{progress}/#{max}"
    end

    private

    attr_reader :title, :progress, :max, :bar_width

    def formatted_title
      title ? "**#{title}** " : ''
    end

    def total_segments
      bar_width * 4
    end

    def segment_size
      Rational(max, total_segments)
    end

    def progress_segments
      (progress / segment_size).floor
    end

    def gradated_segments
      elements = [0] * bar_width
      
      progress_segments.times do |_|
        bar_width.times do |i|
          next if elements[i] == 4

          if i == (bar_width - 1) || elements[i] == elements[i+1]
            elements[i] = elements[i] + 1
            break
          end
        end
      end

      elements.collect { |x| ['─', '░', '▒', '▓', '█'][x] }.join
    end
  end
  
  class CenteredProgressBar
    def initialize(progress:, max:, title: nil, bar_width: 10)
      raise 'Bar width must be even for centered bars' unless bar_width.even?
      @progress = progress > max ? max : progress
      @max = max
      @title = title
      @bar_width = bar_width
    end

    def render
      "#{formatted_title}╟#{gradated_segments}╢ :: #{progress}/#{max}"
    end

    private

    attr_reader :title, :progress, :max, :bar_width

    def formatted_title
      title ? "**#{title}** " : ''
    end

    def total_segments
      bar_width * 2 # half-width * 4 deep
    end

    def segment_size
      Rational(max, total_segments)
    end

    def progress_segments
      (progress / segment_size).floor
    end

    def gradated_segments
      half_width = bar_width / 2
      elements = [0] * half_width
      
      progress_segments.times do |_|
        half_width.times do |i|
          next if elements[i] == 4

          if i == (half_width - 1) || elements[i] == elements[i+1]
            elements[i] = elements[i] + 1
            break
          end
        end
      end

      rendered = elements.collect { |x| ['─', '░', '▒', '▓', '█'][x] }.join
      rendered.reverse + rendered
    end
  end
end