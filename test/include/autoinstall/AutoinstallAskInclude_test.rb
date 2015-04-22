#!/usr/bin/env rspec

root_path = File.expand_path('../..', __FILE__)
ENV["Y2DIR"] = File.join(root_path, 'src')

require "yast"
require_relative "../../../src/include/autoinstall/ask.rb"
require_relative "../../../src/modules/Profile"

describe "Yast::AutoinstallAskInclude" do
  module DummyYast
    class AutoinstallAskClient < Yast::Client
      def main
        Yast.include self, "autoinstall/ask.rb"
      end

      def initialize
        main
      end
    end
  end

  let(:client) { DummyYast::AutoinstallAskClient.new }
  let(:base_ask) do
    { "type" => "string", "question" => "hostname?", "default" => "my.site.de",
      "help" => "Some help", "dialog" => 0, "element" => 0,
      "stage" => "initial" }
  end
  let(:profile) { { "general" => { "ask-list" => ask_list } } }
  let(:result) { :ok }

  describe "#askDialog" do
    let(:ask_list) { [ask] }

    before(:each) do
      allow(Yast::Profile).to receive(:current).and_return(profile)
      allow(Yast::Stage).to receive(:initial).and_return(true)
      allow(Yast::UI).to receive(:UserInput).and_return(result)
    end

    context "when ask-list is empty" do
      let(:ask_list) { [] }

      it "no dialog is shown" do
        expect(Yast::UI).to_not receive(:OpenDialog)
        client.askDialog
      end
    end

    describe "dialogs creation" do
      context "when the ask-list contains a question with type 'string'" do
        let(:ask) { base_ask }

        it "creates a TextEntry widget" do
          expect(Yast::UI).to receive(:OpenDialog).and_call_original
          expect(client).to receive(:TextEntry).
            with(client.Id("0_0"), client.Opt(:notify), ask["question"], ask["default"]).
            and_call_original
          client.askDialog
        end
      end

      context "when ask-list contains a question with type 'selection'" do
        let(:ask) { base_ask.merge("selection" => items, "default" => "desktop") }
        let(:items) {
          %w(desktop server).map { |i| { "value" => i, "label" => i.capitalize } }
        }

        it "creates a ComboBox widget" do
          expect(Yast::UI).to receive(:OpenDialog).and_call_original
          expected_options = [
            client.Item(client.Id("desktop"), "Desktop", true),
            client.Item(client.Id("server"), "Server", false)
          ]
          expect(client).to receive(:ComboBox).
            with(client.Id("0_0"), client.Opt(:notify), ask["question"], expected_options).
            and_call_original
          client.askDialog
        end
      end

      context "when ask-list contains a question with type 'password'" do
        let(:ask) { base_ask.merge("password" => true) }

        it "creates two Password widgets" do
          expect(Yast::UI).to receive(:OpenDialog).and_call_original
          expect(client).to receive(:Password).
            with(client.Id("0_0"), client.Opt(:notify), ask["question"], ask["default"]).
            and_call_original
          expect(client).to receive(:Password).
            with(client.Id(:pass2), client.Opt(:notify), "", ask["default"]).
            and_call_original
          client.askDialog
        end
      end

      context "when ask-list contains a question with type 'static_text'" do
        let(:ask) { base_ask.merge("type" => "static_text") }

        it "creates a Label widget" do
          expect(Yast::UI).to receive(:OpenDialog).and_call_original
          expect(client).to receive(:Label).
            with(client.Id("0_0"), ask["default"]).
            and_call_original
          client.askDialog
        end
      end

      context "when ask-list contains question with type 'symbol'" do
        let(:ask) {
          base_ask.merge("type" => "symbol", "default" => :desktop, "selection" => items)
        }
        let(:items) {
          %w(desktop server).map { |i| { "value" => i.to_sym, "label" => i.capitalize } }
        }

        it "creates a ComboBox widget" do
          expect(Yast::UI).to receive(:OpenDialog).and_call_original
          expected_options = [
            client.Item(client.Id(:desktop), "Desktop", true),
            client.Item(client.Id(:server), "Server", false)
          ]
          expect(client).to receive(:ComboBox).
            with(client.Id("0_0"), client.Opt(:notify), ask["question"], expected_options).
            and_call_original
          client.askDialog
        end
      end

      context "when ask-list contains a question with type 'boolean'" do
        let(:ask) do
          base_ask.merge("type" => "boolean", "question" => "Register system?", "default" => "true")
        end

        it "creates a CheckBox widget" do
          expect(Yast::UI).to receive(:OpenDialog).and_call_original
          expect(client).to receive(:CheckBox).
            with(client.Id("0_0"), client.Opt(:notify), ask["question"], true).
            and_call_original
          client.askDialog
        end
      end
    end

    describe "dialogs actions" do

      context "when ok button is pressed" do
        let(:result) { :ok }
        let(:value) { "some-value" }

        before(:each) do
          allow(Yast::UI).to receive(:QueryWidget).
            with(client.Id("0_0"), :Value).and_return(value)
        end

        context "and a path was specified" do
          let(:ask) { base_ask.merge("path" => "users,0,gecos") }

          it "values are saved into the Profile at the specified path" do
            expect(Yast::Profile).to receive(:setElementByList).
              with(["users", 0, "gecos"], value, profile).
              and_call_original
            client.askDialog
          end
        end

        context "and a pathlist was specified" do
          let(:ask) { base_ask.merge("pathlist" => ["users,1000,login", "groups,1000,name"]) }

          it "saves value into Profile at the paths specified in the pathlist" do
            expect(Yast::Profile).to receive(:setElementByList).
              with(["users", 1000, "login"], value, profile).and_call_original
            expect(Yast::Profile).to receive(:setElementByList).
              with(["groups", 1000, "name"], value, profile).and_call_original
            client.askDialog
          end
        end

        context "and a file was specified" do
          let(:file_path) { "/tmp/value" }
          let(:ask) { base_ask.merge("file" => file_path) }

          it "saves value in the file" do
            expect(Yast::SCR).to receive(:Write).
              with(Yast::Path.new(".target.string"), file_path, value).
              and_return(true)
            client.askDialog
          end

          context "and value is a boolean" do
            let(:value) { true }
            let(:ask) { base_ask.merge("type" => "boolean", "file" => file_path)}

            it "save the value in the file" do
              expect(Yast::SCR).to receive(:Write).
                with(Yast::Path.new(".target.string"), file_path, "true").
                and_return(true)
              client.askDialog
            end
          end
        end

        context "and a script was specified" do
          let(:script) { { "source" => "echo", "filename" => "test.sh" } }
          let(:ask) { base_ask.merge("script" => script) }
          let(:tmp_dir) { "/tmp" }
          let(:log_dir) { "/var/log/YaST2" }

          before(:each) do
            allow(Yast::AutoinstConfig).to receive(:tmpDir).and_return(tmp_dir)
            allow(Yast::AutoinstConfig).to receive(:logs_dir).
              and_return(log_dir)
            script_path = "#{tmp_dir}/#{script["filename"]}"
            allow(Yast::SCR).to receive(:Write).
              with(Yast::Path.new(".target.string"), script_path, script["source"]).
              and_return(true)
            allow(Yast::SCR).to receive(:Execute).
              with(Yast::Path.new(".target.mkdir"), File.join(tmp_dir, "ask_scripts_log"))
          end

          context "when environment is not set" do
            it "runs the script without passing the ask value" do
              expect(Yast::SCR).to receive(:Execute).
                with(Yast::Path.new(".target.bash"),
                     "/bin/sh -x /tmp/test.sh 2&> /tmp/ask_scripts_log/test.sh.log ")
              client.askDialog
            end
          end

          context "when environment is set" do
            let(:script) { { "source" => "echo", "filename" => "test.sh", "environment" => true } }

            it "runs the script passing the ask value" do
              expect(Yast::SCR).to receive(:Execute).
                with(Yast::Path.new(".target.bash"),
                     "VAL=\"some-value\" /bin/sh -x /tmp/test.sh 2&> /tmp/ask_scripts_log/test.sh.log ")
              client.askDialog
            end
          end
        end

        context "and more dialogs left" do
          let(:ask_list) { [base_ask, base_ask.merge("dialog" => "1")] }

          it "next dialog is shown" do
            expect(Yast::UI).to receive(:UserInput).twice
            client.askDialog
          end
        end

        context "and no more dialogs left" do
          let(:ask_list) { [base_ask] }

          it "terminates" do
            expect(Yast::UI).to receive(:UserInput).once
            client.askDialog
          end
        end

        context "when /tmp/next_dialog contains a dialog id" do
          let(:ask_list) { [base_ask, base_ask.merge("dialog" => 1), base_ask.merge("dialog" => 2)] }

          before(:each) do
            expect(Yast::SCR).to receive(:Read).
              with(Yast::Path.new(".target.size"), "/tmp/next_dialog").
              and_return(1)
            expect(Yast::SCR).to receive(:Read).
              with(Yast::Path.new(".target.string"), "/tmp/next_dialog").
              and_return("2")
          end

          it "jumps to that dialog" do
            expect(Yast::UI).to_not receive(:QueryWidget).
              with(client.Id("1_0"), :Value) # Skips dialog 1.
            expect(Yast::UI).to receive(:QueryWidget).
              with(client.Id("2_0"), :Value).and_return(value)
            expect(Yast::UI).to receive(:UserInput).twice.and_return(:ok)
            client.askDialog
          end
        end
      end
    end
  end
end
