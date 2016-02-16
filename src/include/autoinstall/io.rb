# encoding: utf-8

# File:	include/autoinstall/io.ycp
# Package:	Autoinstallation Configuration System
# Summary:	I/O
# Authors:	Anas Nashif<nashif@suse.de>
#
# $Id$
module Yast
  module AutoinstallIoInclude
    def initialize_autoinstall_io(include_target)
      textdomain "autoinst"
      Yast.import "URL"
      Yast.import "FTP"
      Yast.import "Installation"
      Yast.import "HTTP"
      Yast.import "StorageDevices"
      Yast.import "TFTP"
      Yast.import "AutoinstConfig"
      Yast.import "Storage"
      Yast.import "InstURL"

      @GET_error = ""
    end

    # Basename
    # @param string path
    # @return [String]  basename
    def basename(filePath)
      pathComponents = Builtins.splitstring(filePath, "/")
      ret = Ops.get_string(
        pathComponents,
        Ops.subtract(Builtins.size(pathComponents), 1),
        ""
      )
      ret
    end


    # Get directory name
    # @param string path
    # @return  [String] dirname
    def dirname(filePath)
      pathComponents = Builtins.splitstring(filePath, "/")
      last = Ops.get_string(
        pathComponents,
        Ops.subtract(Builtins.size(pathComponents), 1),
        ""
      )
      ret = Builtins.substring(
        filePath,
        0,
        Ops.subtract(Builtins.size(filePath), Builtins.size(last))
      )
      ret
    end





    # Get control files from different sources
    # @return [Boolean] true on success
    def Get(scheme, host, urlpath, localfile)
      get_file_from_url(scheme: scheme, host: host, urlpath: urlpath,
                        localfile: localfile,
                        urltok: AutoinstConfig.urltok,
                        destdir: AutoinstConfig.destdir)
    end

    # Copy a file from a URL to a local path
    # The URL allows autoyast-specific schemes:
    # https://www.suse.com/documentation/sles-12/singlehtml/book_autoyast/book_autoyast.html#Commandline.ay
    #
    # @param scheme    [String] cifs, nfs, device, usb, http, https, ...
    # @param host      [String]
    # @param urlpath   [String]
    # @param localfile [String] destination filename
    # @param urltok    [Hash{String => String}] same url as above, but better
    # @param destdir   [String] chroot (with crazy juggling)
    #
    # @return [Boolean] true on success
    def get_file_from_url(scheme:, host:, urlpath:, localfile:,
                          urltok:, destdir:)
      # adapt sane API to legacy implementation
      _Scheme    = scheme
      _Host      = host
      _Path      = urlpath
      _Localfile = localfile

      @GET_error = ""
      ok = false
      res = {}
      toks = deep_copy(urltok)
      Ops.set(toks, "scheme", _Scheme)
      Ops.set(toks, "host", _Host)
      Builtins.y2milestone(
        "Scheme:%1 Host:%2 Path:%3 Localfile:%4",
        _Scheme,
        _Host,
        _Path,
        _Localfile
      )
      if Builtins.regexpsub(_Path, "(.*)//(.*)", "\\1/\\2") != nil
        _Path = Builtins.regexpsub(_Path, "(.*)//(.*)", "\\1/\\2")
      end
      Ops.set(toks, "path", _Path)
      full_url = URL.Build(toks)

      tmp_dir = Convert.to_string(WFM.Read(path(".local.tmpdir"), []))
      mount_point = Ops.add(tmp_dir, "/tmp_mount")
      mp_in_local = mount_point
      chr = WFM.SCRGetName(WFM.SCRGetDefault)
      if Builtins.search(chr, "chroot=/mnt:") == 0
        mp_in_local = Ops.add(destdir, mount_point)
      end
      Builtins.y2milestone("Chr:%3 TmpDir:%1 Mp:%2", tmp_dir, mp_in_local, chr)
      WFM.Execute(path(".local.mkdir"), mp_in_local)

      if _Scheme == "http" || _Scheme == "https"
        HTTP.easySSL(true)
        if Ops.greater_than(
            SCR.Read(
              path(".target.size"),
              "/etc/ssl/clientcerts/client-cert.pem"
            ),
            0
          )
          HTTP.clientCertSSL("/etc/ssl/clientcerts/client-cert.pem")
        end
        if Ops.greater_than(
            SCR.Read(
              path(".target.size"),
              "/etc/ssl/clientcerts/client-key.pem"
            ),
            0
          )
          HTTP.clientKeySSL("/etc/ssl/clientcerts/client-key.pem")
        end
        res = HTTP.Get(full_url, _Localfile)
        if Ops.get_integer(res, "code", 0) == 200
          @GET_error = ""
          return true
        else
          Builtins.y2error("Can't find URL: %1", full_url)
          # autoyast tried to read a file but had no success.
          @GET_error = Builtins.sformat(
            _(
              "Cannot find URL '%1' via protocol HTTP(S). Server returned code %2."
            ),
            full_url,
            Ops.get_integer(res, "code", 0)
          )
          return false
        end
      end
      if _Scheme == "ftp"
        res = FTP.Get(full_url, _Localfile)
        if Ops.greater_or_equal(Ops.get_integer(res, "code", -1), 200) &&
            Ops.less_than(Ops.get_integer(res, "code", -1), 300) &&
            Ops.greater_than(SCR.Read(path(".target.size"), _Localfile), 0)
          @GET_error = ""
          return true
        else
          Builtins.y2error("Can't find URL: %1", full_url)
          # autoyast tried to read a file but had no success.
          @GET_error = Builtins.sformat(
            _("Cannot find URL '%1' via protocol FTP. Server returned code %2."),
            full_url,
            Ops.get_integer(res, "code", 0)
          )
          return false
        end
      elsif _Scheme == "file"
        file = Builtins.sformat("%1/%2", Installation.sourcedir, _Path) # FIXME: I have doubts this will ever work. Too early.
        if Ops.greater_than(SCR.Read(path(".target.size"), file), 0)
          cpcmd = Builtins.sformat("cp %1 %2", file, _Localfile)
          Builtins.y2milestone("Copy profile: %1", cpcmd)
          SCR.Execute(path(".target.bash"), cpcmd)
        else
          @GET_error = Ops.add(
            @GET_error,
            Builtins.sformat(
              _("Reading file on %1/%2 failed.\n"),
              Installation.sourcedir,
              _Path
            )
          )
          cpcmd = Builtins.sformat("cp %1 %2", _Path, _Localfile)
          Builtins.y2milestone("Copy profile: %1", cpcmd)
          SCR.Execute(path(".target.bash"), cpcmd)
        end

        if Ops.greater_than(SCR.Read(path(".target.size"), _Localfile), 0)
          @GET_error = ""
          ok = true
        else
          @GET_error = Ops.add(
            @GET_error,
            Builtins.sformat(_("Reading file on %1 failed.\n"), _Path)
          )
          Builtins.y2milestone(
            "Trying to find file on installation media: %1",
            Installation.boot
          )
          # The Cdrom entry in install.inf is obsolete. So we are using the
          # entry which is defined in InstUrl module. (bnc#908271)
          install_url = InstURL.installInf2Url("")
          # Builtins.regexpsub can also return nil (bnc#959723)
          cdrom_device = install_url ? (Builtins.regexpsub(install_url, "devices=(.*)$", "\\1") || "") : ""
          if Installation.boot == "cd" && !cdrom_device.empty?
            already_mounted = Ops.add(
              Ops.add("grep ", cdrom_device),
              " /proc/mounts ;"
            )
            am = Convert.to_map(
              SCR.Execute(path(".target.bash_output"), already_mounted)
            )

            if Ops.get_integer(am, "exit", -1) == 0 &&
                Ops.greater_than(
                  Builtins.size(Ops.get_string(am, "stdout", "")),
                  0
                )
              Builtins.y2warning(
                "%1 is already mounted, trying to bind mount...",
                cdrom_device
              )
              cmd = Ops.add(
                Ops.add(
                  Ops.add(
                    Ops.add("mount -v --bind `grep ", cdrom_device),
                    " /proc/mounts |cut -f 2 -d \\ ` "
                  ),
                  mount_point
                ),
                ";"
              )
              am1 = Convert.to_map(
                SCR.Execute(path(".target.bash_output"), cmd)
              )
              if Ops.get_integer(am1, "exit", -1) == 0
                ok = true
              else
                Builtins.y2warning(
                  "can't bind mount %1 failing...",
                  cdrom_device
                )
                ok = false
              end
            else
              try_again = 10
              while Ops.greater_than(try_again, 0)
                if !Convert.to_boolean(
                    WFM.Execute(
                      path(".local.mount"),
                      [cdrom_device, mount_point, Installation.mountlog]
                    )
                  )
                  # autoyast tried to mount the CD but had no success.
                  @GET_error = Ops.add(
                    @GET_error,
                    Builtins.sformat(_("Mounting %1 failed."), cdrom)
                  )
                  Builtins.y2warning("Mount failed")
                  ok = false
                  try_again = Ops.subtract(try_again, 1)
                  Builtins.sleep(3000)
                else
                  ok = true
                  try_again = 0
                end
              end
            end
            if ok
              cpcmd = Builtins.sformat(
                Ops.add(Ops.add("cp ", mount_point), "/%1 %2"),
                _Path,
                _Localfile
              )
              Builtins.y2milestone("Copy profile: %1", cpcmd)
              SCR.Execute(path(".target.bash"), cpcmd)
              WFM.Execute(path(".local.umount"), mount_point)
              if Ops.greater_than(SCR.Read(path(".target.size"), _Localfile), 0)
                @GET_error = ""
                return true
              end
            end
          end
          # autoyast tried to read a file but had no success.
          @GET_error = Ops.add(
            @GET_error,
            Builtins.sformat(
              _("Reading a file on CD failed. Path: %1/%2."),
              mount_point,
              _Path
            )
          )
          ok = false
        end
      elsif _Scheme == "nfs" # NFS
        if !Convert.to_boolean(
            SCR.Execute(
              path(".target.mount"),
              [Ops.add(Ops.add(_Host, ":"), dirname(_Path)), mount_point],
              "-o noatime,nolock"
            )
          ) &&
            !Convert.to_boolean(
              SCR.Execute(
                path(".target.mount"),
                [Ops.add(Ops.add(_Host, ":"), dirname(_Path)), mount_point],
                "-o noatime -t nfs4"
              )
            )
          Builtins.y2warning("Mount failed")
          # autoyast tried to mount a NFS directory which failed
          @GET_error = Builtins.sformat(
            _("Mounting %1 failed."),
            Ops.add(Ops.add(_Host, ":"), dirname(_Path))
          )
          return false
        end

        copyCmd = Ops.add(
          Ops.add(
            Ops.add(
              Ops.add(Ops.add("/bin/cp ", mp_in_local), "/"),
              basename(_Path)
            ),
            " "
          ),
          _Localfile
        )
        Builtins.y2milestone("Copy Command: %1", copyCmd)
        if WFM.Execute(path(".local.bash"), copyCmd) == 0
          @GET_error = ""
          ok = true
        else
          # autoyast tried to copy a file via NFS which failed
          @GET_error = Builtins.sformat(
            _("Remote file %1 cannot be retrieved"),
            Ops.add(Ops.add(mount_point, "/"), basename(_Path))
          )
          Builtins.y2error(
            "remote file %1 can't be retrieved",
            Ops.add(Ops.add(mount_point, "/"), basename(_Path))
          )
        end

        SCR.Execute(path(".target.umount"), mount_point)
      elsif _Scheme == "cifs" # CIFS
        if !Convert.to_boolean(
            SCR.Execute(
              path(".target.mount"),
              [Ops.add(Ops.add("//", _Host), dirname(_Path)), mount_point],
              "-t cifs -o guest,ro,noatime"
            )
          )
          Builtins.y2warning("Mount failed")
          # autoyast tried to mount a NFS directory which failed
          @GET_error = Builtins.sformat(
            _("Mounting %1 failed."),
            Ops.add(Ops.add("//", _Host), dirname(_Path))
          )
          return false
        end

        copyCmd = Ops.add(
          Ops.add(
            Ops.add(
              Ops.add(Ops.add("/bin/cp ", mp_in_local), "/"),
              basename(_Path)
            ),
            " "
          ),
          _Localfile
        )
        Builtins.y2milestone("Copy Command: %1", copyCmd)
        if WFM.Execute(path(".local.bash"), copyCmd) == 0
          @GET_error = ""
          ok = true
        else
          # autoyast tried to copy a file via NFS which failed
          @GET_error = Builtins.sformat(
            _("Remote file %1 cannot be retrieved"),
            Ops.add(Ops.add(mount_point, "/"), basename(_Path))
          )
          Builtins.y2error(
            "remote file %1 can't be retrieved",
            Ops.add(Ops.add(mount_point, "/"), basename(_Path))
          )
        end

        SCR.Execute(path(".target.umount"), mount_point)
      elsif _Scheme == "floppy"
        if StorageDevices.FloppyReady
          WFM.Execute(
            path(".local.mount"),
            [StorageDevices.FloppyDevice, mount_point]
          )

          if WFM.Execute(
              path(".local.bash"),
              Ops.add(
                Ops.add(
                  Ops.add(Ops.add(Ops.add("/bin/cp ", mount_point), "/"), _Path),
                  " "
                ),
                _Localfile
              )
            ) != 0
            Builtins.y2error(
              "file  %1 can't be retrieved",
              Ops.add(Ops.add(mount_point, "/"), _Path)
            )
          else
            @GET_error = ""
            ok = true
          end
          SCR.Execute(path(".target.umount"), mount_point)
        end
      elsif _Scheme == "device" || _Scheme == "usb" # Device or USB
        if _Path != ""
          deviceList = []
          if _Host == ""
            disks = _Scheme == "device" ?
              Convert.convert(
                SCR.Read(path(".probe.disk")),
                :from => "any",
                :to   => "list <map>"
              ) :
              Convert.convert(
                SCR.Read(path(".probe.usb")),
                :from => "any",
                :to   => "list <map>"
              )
            Builtins.foreach(disks) do |m|
              if _Scheme == "usb" && Ops.get_string(m, "bus", "USB") != "SCSI"
                next
              end
              if Builtins.haskey(m, "dev_name")
                i = 0
                dev = Ops.get_string(m, "dev_name", "")
                deviceList = Builtins.add(
                  deviceList,
                  Builtins.substring(dev, 5)
                )
                begin
                  i = Ops.add(i, 1)
                  dev = Ops.add(
                    Ops.get_string(m, "dev_name", ""),
                    Builtins.sformat("%1", i)
                  )
                  if SCR.Read(path(".target.lstat"), dev) != {}
                    deviceList = Builtins.add(
                      deviceList,
                      Builtins.substring(dev, 5)
                    )
                  end
                end while SCR.Read(path(".target.lstat"), dev) != {} ||
                  Ops.less_than(i, 5) # not uncommon for USB sticks to have no partition
              end
            end
            Builtins.y2milestone("devices to look on: %1", deviceList)
          else
            #   sometimes we have devices like /dev/cciss/c1d0p5
            #   those "nested" devices will be catched here
            #   as long as we find a directory where we expect a device,
            #   we cut down the Path and enhance the Host (device name)
            while SCR.Read(path(".target.dir"), Ops.add("/dev/", _Host)) != nil
              Builtins.y2milestone("nested device found")
              l = Builtins.splitstring(_Path, "/")
              _Host = Ops.add(Ops.add(_Host, "/"), Ops.get(l, 0, ""))
              l = Builtins.remove(l, 0)
              _Path = Builtins.mergestring(l, "/")
              Builtins.y2milestone("Host=%1 Path=%2", _Host, _Path)
            end
            # catching nested devices done
            deviceList = [_Host]
          end
          Builtins.foreach(deviceList) do |_Host2|
            Builtins.y2milestone("looking for profile on %1", _Host2)
            # this is workaround for bnc#849767
            # because of changes in autoyast startup this code is now
            # called much sooner (before Storage stuff is initialized)
            # call dummy method to trigger Storage initialization
            dummy = Storage.GetUsedFs()
            mp = Storage.DeviceMounted(Ops.add("/dev/", _Host2))
            already_mounted = !Builtins.isempty(mp)
            mount_point = mp if already_mounted
            Builtins.y2milestone(
              "already mounted=%1 mountpoint=%2 mp=%3",
              already_mounted,
              mount_point,
              mp
            )
            if !already_mounted &&
                !Convert.to_boolean(
                  SCR.Execute(
                    path(".target.mount"),
                    [Builtins.sformat("/dev/%1", _Host2), mount_point],
                    "-o noatime"
                  )
                )
              Builtins.y2milestone(
                "%1 is not mounted and mount failed",
                Builtins.sformat("/dev/%1", _Host2)
              )
              @GET_error = Builtins.sformat(
                _("%1 is not mounted and mount failed"),
                Builtins.sformat("/dev/%1", _Host2)
              )
              next
            end
            if WFM.Execute(
                path(".local.bash"),
                Ops.add(
                  Ops.add(
                    Ops.add(
                      Ops.add(Ops.add("/bin/cp ", mount_point), "/"),
                      _Path
                    ),
                    " "
                  ),
                  _Localfile
                )
              ) != 0
              # autoyast tried to copy a file but that file can't be found
              @GET_error = Builtins.sformat(
                _("File %1 cannot be found"),
                Ops.add(mount_point, _Path)
              )
              Builtins.y2milestone(
                "file %1 can't be found",
                Ops.add(mount_point, _Path)
              )
            else
              @GET_error = ""
              ok = true
              Builtins.y2milestone("found")
            end
            WFM.Execute(path(".local.umount"), mount_point) if !already_mounted
            raise Break if ok == true
          end
        end
      elsif _Scheme == "tftp" # Device
        if TFTP.Get(_Host, _Path, _Localfile)
          @GET_error = ""
          ok = true
        else
          @GET_error = Builtins.sformat(
            _("Cannot find URL '%1' via protocol TFTP."),
            Ops.add(Ops.add(_Host, ":"), _Path)
          )
          Builtins.y2error("file %1 can't be found", _Path)
        end
      else
        # the user wanted autoyast to fetch it's profile via an unknown protocol
        @GET_error = Builtins.sformat(_("Unknown protocol %1."), _Scheme)
        Builtins.y2error("Protocol not supported")
        ok = false
      end
      if !Builtins.isempty(@GET_error)
        Builtins.y2warning("GET_error:%1", @GET_error)
      end
      ok
    end


    # Get a file froma  given URL
    def GetURL(url, target)
      AutoinstConfig.urltok = URL.Parse(url)
      toks = deep_copy(AutoinstConfig.urltok)
      Get(
        Ops.get_string(toks, "scheme", ""),
        Ops.get_string(toks, "host", ""),
        Ops.get_string(toks, "path", ""),
        target
      )
    end
  end
end
