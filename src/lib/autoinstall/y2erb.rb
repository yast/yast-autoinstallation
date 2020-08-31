require "yast"
require "erb"

module Y2Autoinstallation
  class Y2ERB
    def self.render(path)
      env = TemplateEnvironment.new
      template = ERB.new(File.read(path))
      template.result(env.send(:binding)) # intentional send as it is private method
    end

    class TemplateEnvironment
      include Yast::Logger

      def hardware
        @hardware ||= Yast::SCR.Read(Yast::Path.new(".probe"))
      end

      def disks
        return @disks if @disks

        @disks = []
        hardware["disk"].each do |disk|
          result = {
            vendor: disk["vendor"],
            device: disk["dev_name"],
            udev_names: disk["dev_names"]
          }
          dev_name = ::File.pathname(result[:device])
          result[:model] = sys_block_value(dev_name, "device/model") || "Unknown"
          result[:serial] = sys_block_value(dev_name, "device/serial") || "Unknown"
          result[:size] = (sys_block_value(dev_name, "device/size") || "-1").to_i

          @disks << result
        end
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
