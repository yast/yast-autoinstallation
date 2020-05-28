# Copyright (c) [2020] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require_relative "../../../test_helper"
require "autoinstall/widgets/storage/encryption_attrs"
require "y2storage"
require "cwm/rspec"

describe Y2Autoinstallation::Widgets::Storage::EncryptionAttrs do
  subject(:widget) { described_class.new(section) }

  let(:section) do
    Y2Storage::AutoinstProfile::PartitionSection.new
  end

  include_examples "CWM::CustomWidget"

  let(:crypt_method_widget) do
    instance_double(Y2Autoinstallation::Widgets::Storage::CryptMethod, value: :luks1)
  end
  let(:crypt_key_widget) do
    instance_double(Y2Autoinstallation::Widgets::Storage::CryptKey, value: "xxxxx")
  end

  before do
    allow(Y2Autoinstallation::Widgets::Storage::CryptMethod).to receive(:new)
      .and_return(crypt_method_widget)
    allow(Y2Autoinstallation::Widgets::Storage::CryptKey).to receive(:new)
      .and_return(crypt_key_widget)
  end

  describe "#init" do
    it "sets initial values" do
      expect(crypt_method_widget).to receive(:value=)
      expect(crypt_key_widget).to receive(:value=)
      widget.init
    end
  end

  describe "#values" do
    it "includes crypt_method" do
      expect(widget.values).to include("crypt_method" => :luks1)
    end

    it "includes crypt_key" do
      expect(widget.values).to include("crypt_key" => "xxxxx")
    end
  end
end
