Yast.import "Linuxrc"
Yast.import "Stage"

module Y2Autoinstallation
  # This class is responsible of detecting if the system was booted using EFI or not
  class EFIDetector
    EFI_VARS_DIRS = ["/sys/firmware/efi/efivars", "/sys/firmware/efi/vars/"].freeze

    # Returns whether the system was booted using UEFI or not
    #
    # During the First Stage of the installation it relies on linuxrc for detecting the boot
    # but in the rest of cases it checks if any of the EFI vars directories exist
    #
    # @return [Boolean] whether the system was booted using UEFI or not
    def self.boot_efi?
      if Yast::Stage.initial
        Yast::Linuxrc.InstallInf("EFI") == "1"
      else
        EFI_VARS_DIRS.any? { |d| Dir.exist?(d) }
      end
    end
  end
end
