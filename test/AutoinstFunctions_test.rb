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

end
