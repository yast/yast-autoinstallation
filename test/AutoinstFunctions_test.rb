#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import "AutoinstFunctions"
Yast.import "Stage"
Yast.import "Mode"
Yast.import "AutoinstConfig"

describe Yast::AutoinstFunctions do

  subject { Yast::AutoinstFunctions }

  let(:stage) { "initial" }
  let(:mode) { "autoinst" }
  let(:second_stage) { true }

  before do
    Yast::Mode.SetMode(mode)
    Yast::Stage.Set(stage)
    allow(Yast::AutoinstConfig).to receive(:second_stage).and_return(second_stage)
    Yast::Profile.Import({})
  end

  describe "#second_stage_required?" do
    context "when not in initial stage" do
      let(:stage) { "continue" }

      it "returns false" do
        expect(subject.second_stage_required?).to eq(false)
      end
    end

    context "when not in autoinst or autoupgrade mode" do
      let(:mode) { "normal" }

      it "returns false" do
        expect(subject.second_stage_required?).to eq(false)
      end
    end

    context "when second stage is disabled" do
      let(:second_stage) { false }

      it "returns false" do
        expect(subject.second_stage_required?).to eq(false)
      end
    end

    context "when in autoinst mode and second stage is enabled" do
      it "relies on ProductControl.RunRequired" do
        expect(Yast::ProductControl).to receive(:RunRequired)
          .with("continue", mode).and_return(true)
        expect(subject.second_stage_required?).to eq(true)
      end
    end

    context "when in autoupgrade mode and second stage is enabled" do
      let(:mode) { "autoupgrade" }

      it "relies on ProductControl.RunRequired" do
        expect(Yast::ProductControl).to receive(:RunRequired)
          .with("continue", mode).and_return(true)
        expect(subject.second_stage_required?).to eq(true)
      end
    end
  end

  describe "#check_second_stage_environment" do
    context "second stage is not needed" do
      it "returns an empty error string" do
        allow(subject).to receive(:second_stage_required?).and_return(false)
        expect(subject.check_second_stage_environment).to be_empty
      end
    end

    context "second stage is needed" do
      before do
        allow(subject).to receive(:second_stage_required?).and_return(true)
      end

      context "required package are installed" do
        it "returns an empty error string" do
          allow(Yast::Pkg).to receive(:IsSelected).and_return(true)
          expect(subject.check_second_stage_environment).to be_empty
        end
      end

      context "required package are not installed" do
        before do
          allow(Yast::Pkg).to receive(:IsSelected).and_return(false)
        end

        context "registration has not been defined in AY configuration file" do
          it "reports error to set registration" do
            allow(Yast::Profile).to receive(:current).and_return({})
            expect(subject.check_second_stage_environment).to include("configuring the registration")
          end
        end

        context "registration has failed" do
          it "reports error to check registration settings" do
            allow(Yast::Profile).to receive(:current).and_return(
              {"suse_register" => {"do_registration" => true}})
            expect(subject.check_second_stage_environment).to include("registration has failed")
          end
        end
      end
    end
  end

  describe "#selected_product" do
    def base_product(name, short_name)
      Y2Packager::Product.new(name: name, short_name: short_name)
    end

    let(:selected_name) { "SLES15" }

    before(:each) do
      allow(Y2Packager::Product)
        .to receive(:available_base_products)
        .and_return(
          [
            base_product("SLES", selected_name),
            base_product("SLED", "SLED15")
          ]
        )

        # reset cache between tests
        subject.instance_variable_set(:@selected_product, nil)
    end

    it "returns proper base product when explicitly selected in the profile and such base product exists on media" do
      allow(Yast::Profile)
        .to receive(:current)
        .and_return("software" => { "products" => [selected_name] })

      expect(subject.selected_product.short_name).to eql selected_name
    end

    it "returns nil when product is explicitly selected in the profile and such base product doesn't exist on media" do
      allow(Yast::Profile)
        .to receive(:current)
        .and_return("software" => { "products" => { "product" => "Fedora" } })

      expect(subject.selected_product).to be nil
    end

    it "returns base product identified by patterns in the profile if such base product exists on media" do
      allow(Yast::Profile)
        .to receive(:current)
        .and_return("software" => { "patterns" => ["sles-base-32bit"] })

      expect(subject.selected_product.short_name).to eql selected_name
    end

    it "returns base product identified by packages in the profile if such base product exists on media" do
      allow(Yast::Profile)
        .to receive(:current)
        .and_return("software" => { "packages" => ["sles-release"] })

      expect(subject.selected_product.short_name).to eql selected_name
    end

    it "returns base product if there is just one on media and product cannot be identified from profile" do
      allow(Y2Packager::Product)
        .to receive(:available_base_products)
        .and_return(
          [
            base_product("SLED", "SLED15")
          ]
        )
      allow(Yast::Profile)
        .to receive(:current)
        .and_return("software" => {})

      expect(subject.selected_product.short_name).to eql "SLED15"
    end
  end
end
