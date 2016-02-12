#!/usr/bin/env rspec

require_relative "../test_helper"

Yast.import "AutoinstConfig"

describe "Yast::AutoinstallIoInclude" do
  class AutoinstallIoTest < Yast::Module
    def initialize
      Yast.include self, "autoinstall/io.rb"
    end
  end

  subject { AutoinstallIoTest.new }

  describe "#Get" do
    let(:tmpdir) { "/tmp_dir" }
    let(:mount_point) { "#{tmpdir}/tmp_mount" }
    let(:destdir) { "/destdir" }

    def expect_copy_generic(from_chroot, from, to, result)
      expect(Yast::WFM).to receive(:Execute)
        .with(path(".local.bash"), "/bin/cp #{from_chroot}#{from} #{to}")
        .and_return(result ? 0 : 1)
    end

    def expect_copy(from, to, result)
      expect_copy_generic(destdir, from, to, result)
    end

    # this is a bug similar to bsc#829265
    def expect_copy_misrooted(from, to, result)
      expect_copy_generic("", from, to, result)
    end

    # this is OK, not a bug
    def expect_copy_premounted(from, to, result)
      expect_copy_generic("", from, to, result)
    end

    def expect_mount_generic(local_or_target, device, mp, result, optstring)
      args = [path(".#{local_or_target}.mount"), [device, mp]]
      args << optstring unless optstring.nil?
      receiver = (local_or_target == "local") ? Yast::WFM : Yast::SCR
      expect(receiver).to receive(:Execute)
        .with(*args)
        .and_return(result)
    end

    def expect_mount(device, mp, result, optstring = nil)
      expect_mount_generic("target", device, mp, result, optstring)
    end

    # Some code paths use a different method which seems to be wrong
    # The local/target mess was last modified in
    # https://github.com/yast/yast-autoinstallation/commit/69f1966dd1456301a69102c6d3bacfe7c9f9dc49
    # for https://bugzilla.suse.com/show_bug.cgi?id=829265
    def expect_mount_local(device, mp, result, optstring = nil)
      expect_mount_generic("local", device, mp, result, optstring)
    end

    def expect_umount(mp, _result)
      expect(Yast::SCR).to receive(:Execute)
        .with(path(".target.umount"), mp)
    end

    def expect_umount_local(mp, _result)
      # Bug: local is wrong. nfs and cifs correctly use .target.umount
      expect(Yast::WFM).to receive(:Execute)
        .with(path(".local.umount"), mp)
    end

    before do
      expect(Yast::AutoinstConfig).to receive(:urltok)
        .and_return({})
      expect(Yast::WFM).to receive(:Read)
        .and_return(tmpdir)
      expect(Yast::WFM).to receive(:SCRGetDefault)
        .and_return(333)
      expect(Yast::WFM).to receive(:SCRGetName).with(333)
        .and_return("chroot=/mnt:scr")
      expect(Yast::AutoinstConfig).to receive(:destdir)
        .and_return(destdir)
      expect(Yast::WFM).to receive(:Execute)
        .with(path(".local.mkdir"), "#{destdir}#{mount_point}")
    end

    it "returns false for unknown scheme" do
      expect(subject.Get("money_transfer_protocol",
                         "bank", "account", "pocket")).to eq(false)
    end

    context "when scheme is 'device' or 'usb'" do
      let(:scheme) { "device" }

      def expect_mount_check(device, prior_mp)
        allow(Yast::Storage).to receive(:GetUsedFs)
        expect(Yast::Storage).to receive(:DeviceMounted)
          .with(device).and_return(prior_mp)
      end

      def expect_is_directory?(device, result)
        expect(Yast::SCR).to receive(:Read)
          .with(path(".target.dir"), device)
          .and_return(result ? [] : nil)
      end

      it "returns false for an empty path" do
        expect(subject.Get(scheme, "sda", "", "/localfile")).to eq(false)
      end

      context "when host specifies a device" do
        let(:host) { "sdc4" }
        let(:localfile) { "/localfile" }

        before do
          expect(Yast::SCR).to receive(:Read)
            .with(path(".target.dir"), "/dev/sdc4")
            .and_return(nil)
        end

        it "checks + copies, successfully" do
          expect_mount_check("/dev/sdc4", "/already_mounted")
          expect_copy_premounted("/already_mounted/mypath", localfile, true)

          expect(subject.Get(scheme, host, "mypath", localfile))
            .to eq(true)
        end

        it "checks + copies, failing" do
          expect_mount_check("/dev/sdc4", "/already_mounted")
          expect_copy_premounted("/already_mounted/mypath", localfile, false)

          expect(subject.Get(scheme, host, "mypath", localfile))
            .to eq(false)
        end

        it "checks + mounts + copies + umounts, successfully" do
          expect_mount_check("/dev/sdc4", "")
          expect_mount("/dev/sdc4", mount_point, true, "-o noatime")
          expect_copy_misrooted("#{mount_point}/mypath", localfile, true)
          expect_umount_local(mount_point, true)

          expect(subject.Get(scheme, host, "mypath", localfile))
            .to eq(true)
        end

        it "checks + fails to mount" do
          expect_mount_check("/dev/sdc4", "")
          expect_mount("/dev/sdc4", mount_point, false, "-o noatime")

          expect(subject.Get(scheme, host, "mypath", localfile))
            .to eq(false)
        end

        it "checks + mounts + copies(fails) + umounts" do
          expect_mount_check("/dev/sdc4", "")
          expect_mount("/dev/sdc4", mount_point, true, "-o noatime")
          expect_copy_misrooted("#{mount_point}/mypath", localfile, false)
          expect_umount_local(mount_point, true)

          expect(subject.Get(scheme, host, "mypath", localfile))
            .to eq(false)
        end
      end

      context "when host+path specify a device" do
        let(:host) { "disk" }
        let(:urlpath) { "by-id/f00f/mypath" }
        let(:localfile) { "/localfile" }

        it "finds device + checks mount + copies, successfully" do
          expect_is_directory?("/dev/disk", true)
          expect_is_directory?("/dev/disk/by-id", true)
          expect_is_directory?("/dev/disk/by-id/f00f", false)

          expect_mount_check("/dev/disk/by-id/f00f", "/already_mounted")
          expect_copy_premounted("/already_mounted/mypath", localfile, true)

          expect(subject.Get(scheme, host, urlpath, localfile))
            .to eq(true)
        end
      end

      context "when host is empty" do
        let(:host) { "" }
        let(:urlpath) { "mypath" }
        let(:localfile) { "/localfile" }

        shared_examples "disk_prober" do
          it "probes sda, sdb, and does lotsa stuff" do
            lstat_mocks = {
              "/dev/sda1" => true,
              "/dev/sda2" => false,
              "/dev/sda3" => false,
              "/dev/sda4" => true,
              "/dev/sda5" => true,
              "/dev/sda6" => false,

              "/dev/sdb1" => true,
              "/dev/sdb2" => false,
              "/dev/sdb3" => false,
              "/dev/sdb4" => false,
              "/dev/sdb5" => false
            }

            lstat_mocks.each do |device, exists|
              expect(Yast::SCR).to receive(:Read)
                .with(path(".target.lstat"), device).twice
                .and_return(exists ? { "size" => 1 } : {})
            end

            # only up to sda5 because that is when we find the file
            mount_points = {
              "/dev/sda"  => "",
              "/dev/sda1" => "/mnt_sda1",
              "/dev/sda4" => "",
              "/dev/sda5" => "",
            }

            mount_points.each do |device, mp|
              expect_mount_check(device, mp)
            end

            # only up to sda5 because that is when we find the file
            mount_succeeded = {
              "/dev/sda"  => false,
              "/dev/sda4" => true,
              "/dev/sda5" => true,
            }

            mount_succeeded.each do |device, result|
              expect_mount(device, mount_point, result, "-o noatime")
            end

            # sda1 fails, sda4 fails, sda5 succeeds
            expect_copy_premounted("/mnt_sda1/mypath", localfile, false)
            expect_copy_misrooted("#{mount_point}/mypath", localfile, false)
            expect_copy_misrooted("#{mount_point}/mypath", localfile, true)

            mount_succeeded.each do |device, result|
              # if the MOUNT succeeded previously, now UMOUNT
              expect_umount_local(mount_point, true) if result
            end

            # DO IT, this is the call that needs all the above mocking
            expect(subject.Get(scheme, host, "mypath", localfile))
              .to eq(true)
          end
        end

        context "when scheme is 'device'" do
          let(:scheme) { "device" }

          before do
            probed_disks = [
              {},
              { "dev_name" => "/dev/sda" },
              { "dev_name" => "/dev/sdb" }
            ]

            expect(Yast::SCR).to receive(:Read)
              .with(path(".probe.disk"))
              .and_return(probed_disks)
          end

          it_should_behave_like "disk_prober"
        end

        context "when scheme is 'usb'" do
          let(:scheme) { "usb" }

          before do
            probed_disks = [
              {},
              { "dev_name" => "/dev/minnie" },
              { "dev_name" => "/dev/mickey", "bus" => "USB"  },
              { "dev_name" => "/dev/sda",    "bus" => "SCSI" },
              { "dev_name" => "/dev/sdb",    "bus" => "SCSI" }
            ]

            expect(Yast::SCR).to receive(:Read)
              .with(path(".probe.usb"))
              .and_return(probed_disks)
          end

          it_should_behave_like "disk_prober"
        end
      end
    end

    # not yet covered
    context "when scheme is 'http' or 'https'" do
    end
    context "when scheme is 'ftp'" do
    end
    context "when scheme is 'file'" do
    end

    context "when scheme is 'nfs'" do
      let(:scheme) { "nfs" }
      let(:host) { "example.com" }
      let(:urlpath) { "/foo/bar" }
      let(:localfile) { "/localfile" }

      it "fails if mount fails twice" do
        expect_mount("#{host}:/foo/", mount_point, false, "-o noatime,nolock")
        expect_mount("#{host}:/foo/", mount_point, false, "-o noatime -t nfs4")

        expect(subject.Get(scheme, host, urlpath, localfile))
          .to eq(false)
      end

      it "mounts(1), copies successfully, umounts" do
        expect_mount("#{host}:/foo/", mount_point, true, "-o noatime,nolock")
        expect_copy(mount_point + "/bar", localfile, true)
        expect_umount(mount_point, true)

        expect(subject.Get(scheme, host, urlpath, localfile))
          .to eq(true)
      end

      it "mounts(2), copies successfully, umounts" do
        expect_mount("#{host}:/foo/", mount_point, false, "-o noatime,nolock")
        expect_mount("#{host}:/foo/", mount_point, true, "-o noatime -t nfs4")
        expect_copy(mount_point + "/bar", localfile, true)
        expect_umount(mount_point, true)

        expect(subject.Get(scheme, host, urlpath, localfile))
          .to eq(true)
      end

      it "mounts(1), copies unsuccessfully, umounts" do
        expect_mount("#{host}:/foo/", mount_point, true, "-o noatime,nolock")
        expect_copy(mount_point + "/bar", localfile, false)
        expect_umount(mount_point, true)

        expect(subject.Get(scheme, host, urlpath, localfile))
          .to eq(false)
      end

      it "mounts(2), copies unsuccessfully, umounts" do
        expect_mount("#{host}:/foo/", mount_point, false, "-o noatime,nolock")
        expect_mount("#{host}:/foo/", mount_point, true, "-o noatime -t nfs4")
        expect_copy(mount_point + "/bar", localfile, false)
        expect_umount(mount_point, true)

        expect(subject.Get(scheme, host, urlpath, localfile))
          .to eq(false)
      end
    end

    context "when scheme is 'cifs'" do
      let(:scheme) { "cifs" }
      let(:host) { "example.com" }
      let(:urlpath) { "/foo/bar" }
      let(:localfile) { "/localfile" }

      it "fails if mount fails" do
        expect_mount("//#{host}/foo/", mount_point, false, "-t cifs -o guest,ro,noatime")

        expect(subject.Get(scheme, host, urlpath, localfile))
          .to eq(false)
      end

      it "mounts, copies successfully, umounts" do
        expect_mount("//#{host}/foo/", mount_point, true, "-t cifs -o guest,ro,noatime")
        expect_copy(mount_point + "/bar", localfile, true)
        expect_umount(mount_point, true)

        expect(subject.Get(scheme, host, urlpath, localfile))
          .to eq(true)
      end

      it "mounts, copies unsuccessfully, umounts" do
        expect_mount("//#{host}/foo/", mount_point, true, "-t cifs -o guest,ro,noatime")
        expect_copy(mount_point + "/bar", localfile, false)
        expect_umount(mount_point, true)

        expect(subject.Get(scheme, host, urlpath, localfile))
          .to eq(false)
      end
    end

    context "when scheme is 'tftp'" do
      let(:scheme) { "tftp" }
      let(:host) { "example.com" }
      let(:urlpath) { "/foo" }
      let(:localfile) { "/localfile" }

      it "delegates to TFTP.GET, with success" do
        expect(Yast::TFTP).to receive(:Get)
          .with(host, urlpath, localfile)
          .and_return(true)

        expect(subject.Get(scheme, host, urlpath, localfile))
          .to eq(true)
      end

      it "delegates to TFTP.GET, with failure" do
        expect(Yast::TFTP).to receive(:Get)
          .with(host, urlpath, localfile)
          .and_return(false)

        expect(subject.Get(scheme, host, urlpath, localfile))
          .to eq(false)
      end
    end

    context "when scheme is 'floppy'" do
      let(:scheme) { "floppy" }
      let(:host) { "unused" }
      let(:urlpath) { "/foo" }
      let(:localfile) { "/localfile" }

      it "fails if floppy is not ready" do
        expect(Yast::StorageDevices).to receive(:FloppyReady)
          .and_return(false)
        expect(subject.Get(scheme, host, urlpath, localfile))
          .to eq(false)
      end

      context "when floppy is ready" do
        let(:device) { "/dev/fd7" }
        before do
          expect(Yast::StorageDevices).to receive(:FloppyReady)
            .and_return(true)
          expect(Yast::StorageDevices).to receive(:FloppyDevice)
            .and_return(device)
        end

        it "mounts, copies successfully, umounts" do
          expect_mount_local(device, mount_point, true)
          expect_copy_misrooted("#{mount_point}/#{urlpath}", localfile, true)
          expect_umount(mount_point, true)

          expect(subject.Get(scheme, host, urlpath, localfile))
            .to eq(true)
        end

        it "mounts, copies unsuccessfully, umounts" do
          expect_mount_local(device, mount_point, true)
          expect_copy_misrooted("#{mount_point}/#{urlpath}", localfile, false)
          expect_umount(mount_point, true)

          expect(subject.Get(scheme, host, urlpath, localfile))
            .to eq(false)
        end
      end
    end

  end
end
