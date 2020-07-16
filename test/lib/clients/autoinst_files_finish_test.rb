require_relative "../../test_helper"
require "autoinstall/clients/autoinst_files_finish"

Yast.import "Mode"

describe Y2Autoinstallation::Clients::AutoinstFilesFinish do
  describe "#write" do
    before do
      allow(Yast::Mode).to receive(:auto).and_return true
    end
    it "writes additional configuration files" do
      expect(Yast::AutoinstFile).to receive(:Write)
      subject.write
    end
  end
end
