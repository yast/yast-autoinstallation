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

require_relative "../../test_helper"
require "autoinstall/clients/clone_system"
require "tmpdir"

Yast.import "AutoinstClone"

describe Y2Autoinstallation::Clients::CloneSystem do
  subject(:client) { described_class.new }

  before do
    Yast::Stage.Set("normal")
  end

  describe "#main" do
    let(:args) { [] }
    let(:normal?) { true }
    let(:package_installed?) { true }
    let(:tmp_dir) { Dir.mktmpdir("YaST-") }
    let(:profile_exists?) { false }

    before do
      allow(Yast::WFM).to receive(:Args).and_return(args)
      allow(Yast::Mode).to receive(:normal).and_return(normal?)
      allow(Yast::PackageSystem).to receive(:Installed).with("autoyast2")
        .and_return(package_installed?)
      allow(Yast::Installation).to receive(:restart_file)
        .and_return(File.join(tmp_dir, "restart_yast"))
      allow(Yast::AutoinstClone).to receive(:Process)
      allow(Yast::XML).to receive(:YCPToXMLFile)
      allow(Yast::FileUtils).to receive(:Exists).and_call_original
      allow(Yast::FileUtils).to receive(:Exists).with(/autoinst.xml/).and_return(profile_exists?)
    end

    around(:each) do |example|
      example.run
    ensure
      FileUtils.remove_entry(tmp_dir) if Dir.exist?(tmp_dir)
    end

    context "when running in normal mode" do
      context "when 'autoyast2' package is not installed" do
        let(:package_installed?) { false }

        it "installs the 'autoyast2' package and creates the 'restart file'" do
          expect(Yast::PackageSystem).to receive(:InstallAll).with(["autoyast2"]).and_return(true)
          client.main
          expect(File).to exist(Yast::Installation.restart_file)
        end
      end

      context "when 'autoyast2' is installed and the 'restart' file exists" do
        before do
          FileUtils.touch(Yast::Installation.restart_file)
        end

        it "removes the 'restart' file" do
          client.main
          expect(File).to_not exist(Yast::Installation.restart_file)
        end
      end
    end

    describe "'modules' command" do
      let(:args) { ["modules"] }
      let(:profile) { instance_double(Hash) }

      before do
        allow(Yast::Profile).to receive(:current).and_return(profile)
      end

      context "when the target file already exists" do
        let(:profile_exists?) { true }

        before do
          allow(Yast::Popup).to receive(:ContinueCancel).and_return(continue?)
        end

        context "and the user asks to continue" do
          let(:continue?) { true }

          it "saves the profile to the given file" do
            expect(Yast::XML).to receive(:YCPToXMLFile)
              .with(:profile, profile, "/root/autoinst.xml")
            client.main
          end
        end

        context "and the user asks to abort" do
          let(:continue?) { false }

          it "aborts the process" do
            expect(Yast::AutoinstClone).to_not receive(:Process)
            expect(Yast::XML).to_not receive(:YCPToXMLFile)
            client.main
          end
        end
      end

      it "clones and writes the profile to '/root/autoinst.xml'" do
        expect(Yast::AutoinstClone).to receive(:Process)
        expect(Yast::XML).to receive(:YCPToXMLFile).with(:profile, profile, "/root/autoinst.xml")
        client.main
      end

      context "when some module names are specified" do
        let(:args) { ["modules", "clone=partitioning,ssh_import"] }

        it "adds them to the list of modules to clone" do
          expect(Yast::AutoinstClone).to receive(:additional=).with(["partitioning", "ssh_import"])
          client.main
        end
      end
    end
  end
end
