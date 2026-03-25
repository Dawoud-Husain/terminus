# frozen_string_literal: true

module Terminus
  module Aspects
    module Screens
      module Converters
        # Converts to color image.
        class Color
          include Deps[mini_magick: "mini_magick.core"]
          include Dry::Monads[:result]

          def call mold
            convert mold
          rescue MiniMagick::Error => error
            Failure error.message
          end

          private

          def convert mold
            output_path = mold.output_path
            colors = mold.color_codes.map { "xc:#{it}" }

            mini_magick.convert do |tool|
              tool << mold.input_path.to_s
              tool.rotate mold.rotation if mold.rotatable?
              tool.resize "#{mold.dimensions}!"
              tool.crop mold.crop if mold.cropable?
              tool.normalize
              tool.modulate "110,150"
              tool.colorspace "RGB"
              tool.merge! [
                "(",
                "-size",
                "1x1",
                *colors,
                "+append",
                "+write",
                "mpr:palette",
                "+delete",
                ")"
              ]
              tool.dither "FloydSteinberg"
              tool.remap "mpr:palette"
              tool.colorspace "sRGB"
              tool << "#{mold.file_type}:#{output_path}"
            end

            Success output_path
          end
        end
      end
    end
  end
end
