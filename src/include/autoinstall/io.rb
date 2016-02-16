# encoding: utf-8

# File:	include/autoinstall/io.ycp
# Package:	Autoinstallation Configuration System
# Summary:	I/O
# Authors:	Anas Nashif<nashif@suse.de>
#
# $Id$

require "transfer/file_from_url"

module Yast
  module AutoinstallIoInclude
    # include basename, dirname, get_file_from_url
    include Yast::Transfer::FileFromUrl

    def initialize_autoinstall_io(_include_target)
      Yast.import "AutoinstConfig"
    end

    # Get control files from different sources
    # @return [Boolean] true on success
    def Get(scheme, host, urlpath, localfile)
      get_file_from_url(scheme: scheme, host: host, urlpath: urlpath,
                        localfile: localfile,
                        urltok: AutoinstConfig.urltok,
                        destdir: AutoinstConfig.destdir)
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
