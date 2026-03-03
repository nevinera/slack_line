RSpec.describe SlackLine::DiskCaching do
  let(:test_class) do
    Class.new do
      include SlackLine::DiskCaching
    end
  end

  let(:instance) { test_class.new }

  def config(cache_path:, cache_duration: 900)
    instance_double(SlackLine::Configuration, cache_path:, cache_duration:)
  end

  describe "#cached" do
    context "when config.cache_path is nil" do
      it "yields the block directly" do
        result = instance.cached(config: config(cache_path: nil), key: "test") { "value" }
        expect(result).to eq("value")
      end
    end

    context "when config.cache_path is provided" do
      context "and Lightly is not defined" do
        it "raises DiskCaching::NoLightly" do
          expect { instance.cached(config: config(cache_path: "/tmp/cache"), key: "test") { "value" } }
            .to raise_error(SlackLine::DiskCaching::NoLightly)
        end
      end

      context "and Lightly is defined" do
        let(:fake_lightly_cache) { instance_double("FakeLightly") }

        before do
          stub_const("Lightly", Class.new do
            def initialize(dir:, life:)
              @dir = dir
              @life = life
            end
          end)
          allow(Lightly).to receive(:new).and_return(fake_lightly_cache)
          allow(fake_lightly_cache).to receive(:get).with("the-key") { |&b| b.call }
        end

        it "instantiates Lightly with the cache_path and cache_duration from config" do
          instance.cached(config: config(cache_path: "/tmp/cache", cache_duration: 300), key: "the-key") { "value" }
          expect(Lightly).to have_received(:new).with(dir: "/tmp/cache", life: 300)
        end

        it "returns the result of the block" do
          result = instance.cached(config: config(cache_path: "/tmp/cache"), key: "the-key") { "value" }
          expect(result).to eq("value")
        end
      end
    end
  end
end
