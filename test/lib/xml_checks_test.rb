#!/usr/bin/env rspec

require_relative "../test_helper"
require "autoinstall/xml_checks"

describe Y2Autoinstallation::XmlChecks do

  before do
    # mock the popup to avoid accidentally displaying a popup in tests
    allow(Yast2::Popup).to receive(:show)
  end

  describe ".valid_profile?" do
    before do
      expect_any_instance_of(Y2Autoinstallation::XmlValidator).to receive(:valid?)
        .and_return(valid)
    end

    context "valid profile" do
      let(:valid) { true }
    end

    context "invalid profile" do
      let(:valid) { false }

    end
  end
end
