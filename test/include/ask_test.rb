#!/usr/bin/env rspec

require_relative "../test_helper"

require "yast"

# storage-ng
=begin
Yast.import "Profile"
Yast.import "Stage"
Yast.import "UI"
=end

describe "Yast::AutoinstallAskInclude" do
  # storage-ng
  before :all do
    skip("pending of storage-ng")
  end

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

  BASE_ASK = {
    "type" => "string", "question" => "hostname?", "default" => "my.site.de",
    "help" => "Some help", "dialog" => 0, "element" => 0,
    "stage" => "initial" }

  subject(:client) { DummyYast::AutoinstallAskClient.new }
  let(:profile) { { "general" => { "ask-list" => ask_list } } }
  let(:pressed_button) { :ok }

  describe "#askDialog" do
    let(:ask_list) { [ask] }

    before do
      allow(Yast::Profile).to receive(:current).and_return(profile)
      allow(Yast::Stage).to receive(:initial).and_return(true)
      allow(Yast::UI).to receive(:UserInput).and_return(pressed_button)
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
        let(:ask) { BASE_ASK }

        it "creates a TextEntry widget" do
          expect(Yast::UI).to receive(:OpenDialog)
          expect(client).to receive(:InputField).
            with(Id("0_0"), Opt(:hstretch, :notify, :notifyContextMenu), ask["question"], ask["default"]).
            and_call_original
          client.askDialog
        end
      end

      context "when the ask-list contains a question with timeout=0" do
        let(:ask) { BASE_ASK.merge("timeout" => 0) }

        it "waits for user input infinitely" do
          expect(Yast::UI).to receive(:OpenDialog)
          expect(Yast::UI).to receive(:UserInput)
          client.askDialog
        end
      end

      context "when the ask-list contains a question with timeout>0" do
        timeout_in_sec = 10
        let(:ask) { BASE_ASK.merge("timeout" => timeout_in_sec) }

        context "when user does not do anything" do
          it "waits for user input with timeout and then time-outs" do
            expect(Yast::UI).to receive(:OpenDialog)
            expect(Yast::UI).to receive(:TimeoutUserInput).exactly(timeout_in_sec).times.and_return :timeout
            client.askDialog
          end
        end

        context "when user stops the execution manually" do
          it "waits for user input with timeout and then stops and waits for user infinitely" do
            expect(Yast::UI).to receive(:OpenDialog)
            # user does some change in the third second
            expect(Yast::UI).to receive(:TimeoutUserInput).exactly(3).times.and_return(:timeout, :timeout, :user_action)
            # execution stops and wait for user to finish
            expect(Yast::UI).to receive(:UserInput)
            client.askDialog
          end
        end
      end

      context "when ask-list contains a question with type 'selection'" do
        let(:ask) { BASE_ASK.merge("selection" => items, "default" => "desktop") }
        let(:items) {
          %w(desktop server).map { |i| { "value" => i, "label" => i.capitalize } }
        }

        it "creates a ComboBox widget" do
          expect(Yast::UI).to receive(:OpenDialog)
          expected_options = [
            Item(Id("desktop"), "Desktop", true),
            Item(Id("server"), "Server", false)
          ]
          expect(client).to receive(:ComboBox).
            with(Id("0_0"), Opt(:notify), ask["question"], expected_options).
            and_call_original
          client.askDialog
        end
      end

      context "when ask-list contains a question with type 'password'" do
        let(:ask) { BASE_ASK.merge("password" => true) }

        it "creates two Password widgets" do
          expect(Yast::UI).to receive(:OpenDialog)
          expect(client).to receive(:Password).
            with(Id("0_0"), Opt(:notify, :notifyContextMenu), ask["question"], ask["default"]).
            and_call_original
          expect(client).to receive(:Password).
            with(Id("0_0_pass2"), Opt(:notify, :notifyContextMenu), "", ask["default"]).
            and_call_original
          client.askDialog
        end
      end

      context "when ask-list contains a question with type 'static_text'" do
        let(:ask) { BASE_ASK.merge("type" => "static_text") }

        it "creates a Label widget" do
          expect(Yast::UI).to receive(:OpenDialog)
          expect(client).to receive(:Label).
            with(Id("0_0"), ask["default"]).
            and_call_original
          client.askDialog
        end
      end

      context "when ask-list contains question with type 'symbol'" do
        let(:ask) {
          BASE_ASK.merge("type" => "symbol", "default" => :desktop, "selection" => items)
        }
        let(:items) {
          %w(desktop server).map { |i| { "value" => i.to_sym, "label" => i.capitalize } }
        }

        it "creates a ComboBox widget" do
          expect(Yast::UI).to receive(:OpenDialog)
          expected_options = [
            Item(Id(:desktop), "Desktop", true),
            Item(Id(:server), "Server", false)
          ]
          expect(client).to receive(:ComboBox).
            with(Id("0_0"), Opt(:notify, :immediate), ask["question"], expected_options).
            and_call_original
          client.askDialog
        end
      end

      context "when ask-list contains a question with type 'boolean'" do
        let(:ask) do
          BASE_ASK.merge("type" => "boolean", "question" => "Register system?", "default" => "true")
        end

        it "creates a CheckBox widget" do
          expect(Yast::UI).to receive(:OpenDialog)
          expect(client).to receive(:CheckBox).
            with(Id("0_0"), Opt(:notify), ask["question"], true).
            and_call_original
          client.askDialog
        end
      end

      context "when ask-list contains more than one question" do
        let(:string_ask) { BASE_ASK }
        let(:boolean_ask) do
          BASE_ASK.merge("type" => "boolean", "element" => 1, "default" => "true")
        end
        let(:ask_list) { [string_ask, boolean_ask] }

        it "creates one widget for each one of them" do
          expect(Yast::UI).to receive(:OpenDialog)
          expect(client).to receive(:InputField).
            with(Id("0_0"), Opt(:hstretch, :notify, :notifyContextMenu), string_ask["question"], string_ask["default"]).
            and_call_original
          expect(client).to receive(:CheckBox).
            with(Id("0_1"), Opt(:notify), boolean_ask["question"], true).
            and_call_original
          client.askDialog
        end
      end

      context "when ask-list contains more than one password question" do
        let(:first_pass_ask) { BASE_ASK.merge("password" => true)}
        let(:second_pass_ask) { BASE_ASK.merge("password" => true, "element" => 1)}
        let(:ask_list) { [first_pass_ask, second_pass_ask] }

        it "creates two password widgets for each question without repeating the Ids" do
          expect(Yast::UI).to receive(:OpenDialog)
          ["0_0", "0_0_pass2", "0_1", "0_1_pass2"].each do |wid|
            expect(client).to receive(:Password).
              with(Id(wid), anything, anything, anything).and_call_original
          end
          client.askDialog
        end
      end
    end

    describe "dialogs actions" do

      context "when ok button is pressed" do
        let(:pressed_button) { :ok }
        let(:response) { "some-user-response" }

        before do
          allow(Yast::UI).to receive(:QueryWidget).
            with(Id("0_0"), :Value).and_return(response)
        end

        context "when a path was specified" do
          let(:ask) { BASE_ASK.merge("path" => "users,0,gecos") }

          it "response is saved into the Profile at the specified path" do
            expect(Yast::Profile).to receive(:setElementByList).
              with(["users", 0, "gecos"], response, profile)
            client.askDialog
          end
        end

        context "when a pathlist was specified" do
          let(:ask) { BASE_ASK.merge("pathlist" => ["users,1000,login", "groups,1000,name"]) }

          it "saves response into Profile at the paths specified in the pathlist" do
            expect(Yast::Profile).to receive(:setElementByList).
              with(["users", 1000, "login"], response, profile)
            expect(Yast::Profile).to receive(:setElementByList).
              with(["groups", 1000, "name"], response, profile)
            client.askDialog
          end
        end

        context "when a file was specified" do
          let(:file_path) { "/tmp/response" }
          let(:ask) { BASE_ASK.merge("file" => file_path) }

          it "saves the user answer in the file" do
            expect(Yast::SCR).to receive(:Write).
              with(Yast::Path.new(".target.string"), file_path, response).
              and_return(true)
            client.askDialog
          end

          context "when response is a boolean" do
            let(:response) { true }
            let(:ask) { BASE_ASK.merge("type" => "boolean", "file" => file_path)}

            it "converts the answer to a string and saves it in the file" do
              expect(Yast::SCR).to receive(:Write).
                with(Yast::Path.new(".target.string"), file_path, "true").
                and_return(true)
              client.askDialog
            end
          end

          context "when asking for a 'password' and values don't match" do
            let(:ask) { BASE_ASK.merge("password" => true) }

            it "shows an error message and try run the dialog again" do
              expect(Yast::UI).to receive(:QueryWidget).
                with(Id("0_0_pass2"), :Value).and_return("some-other-thing", response)
              expect(Yast::Popup).to receive(:Error).with("The two passwords mismatch.")
              client.askDialog
            end
          end
        end

        context "when a script was specified" do
          let(:script) { { "source" => "echo", "filename" => "test.sh" } }
          let(:ask) { BASE_ASK.merge("script" => script) }
          let(:tmp_dir) { "/tmp" }
          let(:log_dir) { "/var/log/YaST2" }

          before do
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

          context "when 'environment' property is not set" do
            it "runs the script without passing the ask response" do
              expect(Yast::SCR).to receive(:Execute).
                with(Yast::Path.new(".target.bash"),
                     "/bin/sh -x /tmp/test.sh 2&> /tmp/ask_scripts_log/test.sh.log ")
              client.askDialog
            end
          end

          context "when 'environment' property is set" do
            let(:script) { { "source" => "echo", "filename" => "test.sh", "environment" => true } }

            it "runs the script passing the ask response" do
              expect(Yast::SCR).to receive(:Execute).
                with(Yast::Path.new(".target.bash"),
                     "VAL=\"some-user-response\" /bin/sh -x /tmp/test.sh 2&> /tmp/ask_scripts_log/test.sh.log ")
              client.askDialog
            end
          end

          it "shows some feedback while script is running" do
            message = "A user defined script is running. This may take a while."
            allow(Yast::SCR).to receive(:Execute)
            expect(Yast::Popup).to receive(:Feedback).
              with("", client._(message))
            client.askDialog
          end
        end

        context "when more dialogs left" do
          let(:ask_list) { [BASE_ASK, BASE_ASK.merge("dialog" => "1")] }

          it "next dialog is shown" do
            expect(Yast::UI).to receive(:UserInput).twice
            client.askDialog
          end
        end

        context "when no more dialogs left" do
          let(:ask_list) { [BASE_ASK] }

          it "finishes dialog processing and returns" do
            expect(Yast::UI).to receive(:UserInput).once
            client.askDialog
          end
        end

        context "when a value for 'next dialog' is set" do
          let(:ask_list) { [BASE_ASK, BASE_ASK.merge("dialog" => 1), BASE_ASK.merge("dialog" => 2)] }

          before do
            expect(Yast::SCR).to receive(:Read).
              with(Yast::Path.new(".target.size"), "/tmp/next_dialog").
              and_return(1)
            expect(Yast::SCR).to receive(:Read).
              with(Yast::Path.new(".target.string"), "/tmp/next_dialog").
              and_return("2")
          end

          it "jumps to that dialog" do
            expect(Yast::UI).to_not receive(:QueryWidget).
              with(Id("1_0"), :Value) # Skips dialog 1.
            expect(Yast::UI).to receive(:QueryWidget).
              with(Id("2_0"), :Value)
            expect(Yast::UI).to receive(:UserInput).twice.and_return(:ok)
            client.askDialog
          end
        end
      end
    end
  end
end
