Yast.import "Linuxrc"
Yast.import "Stage"

module Y2Autoinstallation
  # This module defines some methods that are used by different classes
  class EFIDetector
    # Use same approach than linuxrc for detecting the EFI boot in a running system but use
    # install.inf in case of initial Stage.
    EFI_VARS_DIRS = ["/sys/firmware/efi/efivars", "/sys/firmware/efi/vars/"].freeze

    # Whether the system was booted using UEFI or not
    #
    # @return [Boolean] whether the system was booted using UEFI or not according to linuxrc
    def boot_efi?
      if Yast::Stage.initial
        Yast::Linuxrc.InstallInf("EFI") == "1"
      else
        EFI_VARS_DIRS.any? { |d| Dir.exist?(d) }
      end
    end
  end
end
