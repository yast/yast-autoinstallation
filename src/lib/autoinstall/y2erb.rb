require "yast"
require "erb"

module Y2Autoinstallation
  class Y2ERB
    def self.render(path)
      env = TemplateEnvironment.new
      template = ERB.new(File.read(path))
      template.result(env.public_bindings) # intentional send as it is private method
    end

    class TemplateEnvironment
      include Yast::Logger

      def hardware
        @hardware ||= Yast::SCR.Read(Yast::Path.new(".probe"))
      end

      # @return [Array<Hash>] list of info about disks. Info contain:
      #   `:vendor` of disk
      #   `:device` kernel name of device
      #   `:udev_names` list of udev names for given disk
      #   `:model` model name from sysfs
      #   `:serial` serial number of disk
      #   `:size` disk size in bytes [Integer]
      def disks
        return @disks if @disks

        @disks = []
        hardware["disk"].each do |disk|
          dev_name = ::File.pathname(disk["dev_name"])
          result = {
            vendor: disk["vendor"],
            device: devn_name,
            udev_names: disk["dev_names"]
          }
          result[:model] = sys_block_value(dev_name, "device/model") || "Unknown"
          result[:serial] = sys_block_value(dev_name, "device/serial") || "Unknown"
          result[:size] = (sys_block_value(dev_name, "device/size") || "-1").to_i

          @disks << result
        end
      end

      # @return [Array<Hash>] list of info about network cards. Info contain:
      #   `:vendor` of card
      #   `:device` name of device
      #   `:mac` mac address of card
      #   `:active` if card io is active [Boolean]
      #   `:link_up` if card link is up [Boolean]
      def network_cards
        return @network_cards if @network_cards

        @network_cards = []
        hardware["netcard"].each do |card|
          resource = card["resource"]
          mac = resource["hwaddr"].first["addr"] rescue ""
          active = resource["io"].first["active"] rescue false
          link = resource["link"].first["state"] rescue false
          result = {
            vendor: card["vendor"],
            device: card["dev_name"],
            mac: mac,
            active: active,
            link: link
          }

          @network_cards << result
        end
      end

      # allow to use env bindings
      def public_bindings
        binding
      end

    private

      def  sys_block_value(device, path)
        sys_path = "/sys/block/#{device}/"
        ::File.read(sys_path + path).strip
      rescue => e
        log.warn "read of #{sys_path + path}  failed with #{e}"
        return nil
      end
    end
  end
end
