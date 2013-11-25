require 'spec_helper'
require 'guard/notifier'

describe "monkey patching" do
  describe ::String do
    describe "#strip_lowercase_directories" do
      it "works on empty string" do
        expect("".strip_lowercase_directories).to eq("")
      end

      it "works on string without lowercase directory prefixes" do
        expect("Foo".strip_lowercase_directories).to eq("Foo")
      end

      it "works on string with lowercase directory prefix" do
        expect("foo/Bar".strip_lowercase_directories).to eq("Bar")
      end

      it "works on string with multiple lowercase directory prefixes" do
        expect("foo/bar/Baz".strip_lowercase_directories).to eq("Baz")
      end
    end

    describe "#path_to_module_name" do
      it "works on string without path separators" do
        expect("Foo".path_to_module_name).to eq("Foo")
      end

      it "works on string with path separators" do
        expect("Foo/Bar/Baz".path_to_module_name).to eq("Foo.Bar.Baz")
      end
    end
  end
end

describe ::Guard::Haskell do
  let(:guard) do
    ::Guard::Haskell.new
  end

  before :each do
    ::Guard.stub(:add_group)
    ::Guard::Haskell::Repl.any_instance.stub(:start)
    ::Guard::Haskell::Repl.any_instance.stub(:init)
  end

  describe ".initialize" do
    it "has :all_on_start option" do
      expect(guard.instance_variable_defined?(:@all_on_start)).to be_true
    end

    it "has :all_on_pass option" do
      expect(guard.instance_variable_defined?(:@all_on_pass)).to be_true
    end

    it "has :ghci_options option" do
      expect(guard.instance_variable_defined?(:@ghci_options)).to be_true
    end

    it "has :top_spec option" do
      expect(guard.instance_variable_defined?(:@top_spec)).to be_true
    end
  end

  describe "#start" do
    it "starts repl" do
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:init).with("test/Spec.hs")

      guard.start
    end

    it "does not run all specs on start by default" do
      expect(guard).not_to receive(:run_all)
      expect(guard).not_to receive(:success?)

      guard.start
    end

    it "runs all specs on start with :all_on_start option enabled" do
      custom_guard = ::Guard::Haskell.new(all_on_start: true)

      expect(custom_guard).to receive(:run_all)
      expect(custom_guard).to receive(:success?)

      custom_guard.start
    end

    it "starts repl with custom spec specified with :top_spec option" do
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:init).with("test/CustomSpec.hs")

      custom_guard = ::Guard::Haskell.new(top_spec: "test/CustomSpec.hs")
      custom_guard.start
    end
  end

  describe "#stop" do
    it "stops repl" do
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:exit)

      guard.start
      guard.stop
    end
  end

  describe "#reload" do
    it "restarts repl" do
      expect(guard).to receive(:stop)
      expect(guard).to receive(:start)
      guard.reload
    end
  end

  describe "#run" do
    it "runs specs matching pattern if last run was a success" do
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:run).with("Foo")
      guard.instance_variable_set(:@last_run, :success)

      guard.start
      guard.run("Foo")
    end

    it "reruns previous specs if last run was a failure" do
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:rerun)
      guard.instance_variable_set(:@last_run, :failure)

      guard.start
      guard.run("Foo")
    end
  end

  describe "#success" do
    it "notifies on success" do
      ::Guard::Haskell::Repl.any_instance.stub(:success?) { true }
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:success?)
      expect(::Guard::Notifier).to receive(:notify).with('Success')
      guard.instance_variable_set(:@last_run, :failure)

      guard.start
      guard.success?
      expect(guard.instance_variable_get(:@last_run)).to eq(:success)
    end

    it "notifies on failure" do
      ::Guard::Haskell::Repl.any_instance.stub(:success?) { false }
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:success?)
      expect(::Guard::Notifier).to receive(:notify).with('Failure', image: :failed)
      guard.instance_variable_set(:@last_run, :success)

      guard.start
      guard.success?
      expect(guard.instance_variable_get(:@last_run)).to eq(:failure)
    end

    it "does not run all specs on success after failure by default" do
      ::Guard::Haskell::Repl.any_instance.stub(:success?) { true }
      guard.instance_variable_set(:@last_run, :failure)

      expect(guard).not_to receive(:run_all)

      guard.start
      guard.success?
    end

    it "runs all specs on success after failure with :all_on_pass option" do
      ::Guard::Haskell::Repl.any_instance.stub(:success?) { true }
      custom_guard = ::Guard::Haskell.new(all_on_pass: true)
      custom_guard.instance_variable_set(:@last_run, :failure)

      expect(custom_guard).to receive(:run_all)

      custom_guard.start
      custom_guard.success?
    end
  end

  describe "#run_on_additions" do
    it "reinitializes the repl on new files" do
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:init).twice

      guard.start
      guard.instance_variable_set(:@targets, [])
      guard.run_on_additions ["foo", "bar"]
    end

    it "does not reinitialize the repl if new files were seen before" do
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:init).once

      guard.start
      guard.instance_variable_set(:@targets, ["foo", "bar"])
      guard.run_on_additions ["foo", "bar"]
    end
  end

  describe "#run_on_modifications" do
    it "run specs for simple haskell files" do
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:run).with("Foo")
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:success?)

      guard.start
      guard.run_on_modifications(["Foo.hs"])
    end

    it "run specs for simple literate haskell files" do
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:run).with("Foo")
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:success?)

      guard.start
      guard.run_on_modifications(["Foo.lhs"])
    end

    it "run specs for *complex* haskell files" do
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:run).with("Bar.Baz")
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:success?)

      guard.start
      guard.run_on_modifications(["foo/Bar/Baz.hs"])
    end

    it "run specs for simple haskell spec files" do
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:run).with("Foo")
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:success?)

      guard.start
      guard.run_on_modifications(["FooSpec.hs"])
    end

    it "run specs for simple literate haskell spec files" do
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:run).with("Foo")
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:success?)

      guard.start
      guard.run_on_modifications(["FooSpec.lhs"])
    end

    it "run specs for *complex* haskell spec files" do
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:run).with("Bar.Baz")
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:success?)

      guard.start
      guard.run_on_modifications(["foo/Bar/BazSpec.hs"])
    end
  end
end
