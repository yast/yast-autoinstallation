require_relative "../../test_helper"
require "autoinstall/clients/autoinst_files_finish"

describe Y2Autoinstallation::Clients::AutoinstFilesFinish do
  describe "#write" do
    it "writes additional configuration files" do
      expect(Yast::AutoinstFile).to receive(:Write)
      subject.write
    end
  end
end
