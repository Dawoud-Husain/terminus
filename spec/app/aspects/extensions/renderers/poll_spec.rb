# frozen_string_literal: true

require "hanami_helper"

RSpec.describe Terminus::Aspects::Extensions::Renderers::Poll do
  subject(:renderer) { described_class.new fetcher: }

  let(:fetcher) { instance_double Terminus::Aspects::Extensions::MultiFetcher }

  describe "#call" do
    let :extension do
      Factory.structs[
        :extension,
        kind: "poll",
        uris: ["https://test.io/test.json"],
        template: <<~CONTENT
          <h1>{{extension.label}}</h1>
          {% for item in source.data %}
            <p>{{item.label}}: {{item.description}}</p>
          {% endfor %}
        CONTENT
      ]
    end

    let(:context) { {"extension" => {"label" => "Test Label"}} }

    let :data do
      {
        "data" => [
          {
            "label" => "Test",
            "description" => "A test."
          }
        ]
      }
    end

    it "renders template without errors for single response" do
      allow(fetcher).to receive(:call).and_return(
        Success(Terminus::Aspects::Extensions::Capsule[content: {"source" => data}])
      )

      expect(renderer.call(extension, context:)).to be_success(
        Terminus::Aspects::Extensions::Capsule[
          content: <<~CONTENT.strip
            <html><head></head><body><h1>Test Label</h1>

              <p>Test: A test.</p>

            </body></html>
          CONTENT
        ]
      )
    end

    context "with mixed responses" do
      before do
        allow(fetcher).to receive(:call).and_return(
          Failure(
            Terminus::Aspects::Extensions::Capsule[
              content: {"source_1" => data, "source_3" => data},
              errors: {"https://test.io" => "Danger!"}
            ]
          )
        )

        allow(extension).to receive(:template).and_return(<<~CONTENT)
          <h1>{{extension.label}}</h1>
          {% for item in source_1.data %}<p>{{item.label}}</p>{% endfor %}
          {% for item in source_2.data %}<p>{{item.label}}</p>{% endfor %}
          {% for item in source_3.data %}<p>{{item.label}}</p>{% endfor %}
        CONTENT
      end

      it "answers render template and captures errors" do
        html = <<~CONTENT.strip
          <html><head></head><body><h1>Test Label</h1>
          <p>Test</p>

          <p>Test</p>
          </body></html>
        CONTENT

        expect(renderer.call(extension, context:)).to be_failure(
          Terminus::Aspects::Extensions::Capsule[
            content: html,
            errors: {"https://test.io" => "Danger!"}
          ]
        )
      end
    end
  end
end
