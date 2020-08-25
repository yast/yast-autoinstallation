require "yast"
require "erb"

module Y2Autoinstallation
  class Y2ERB
    def self.render(path)
      env = TemplateEnvironment.new
      template = ERB.new(File.read(path))
      template.result(env.public_binding)
    end

    class TemplateEnvironment
      def hardware
        @hardware ||= Yast::SCR.Read(Yast::Path.new(".probe"))
      end

      # expose method bindings
      def public_binding
        binding
      end
    end
  end
end
