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
      expect(guard.instance_variable_defined?(:@all_on_start)).to eq(true)
    end

    it "has :all_on_pass option" do
      expect(guard.instance_variable_defined?(:@all_on_pass)).to eq(true)
    end

    it "has :focus_on_fail option" do
      expect(guard.instance_variable_defined?(:@focus_on_fail)).to eq(true)
    end

    it "has :ghci_options option" do
      expect(guard.instance_variable_defined?(:@ghci_options)).to eq(true)
    end

    it "has :top_spec option" do
      expect(guard.instance_variable_defined?(:@top_spec)).to eq(true)
    end
  end

  describe "#start" do
    it "starts repl" do
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:init).with("test/Spec.hs")

      guard.start
    end

    it "does not run all examples on start by default" do
      expect(guard).not_to receive(:run_all)
      expect(guard).not_to receive(:success?)

      guard.start
    end

    it "runs all examples on start with :all_on_start option enabled" do
      custom_guard = ::Guard::Haskell.new(all_on_start: true)

      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:run)
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
    it "checks success after run" do
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:run).with("Foo")
      expect(guard).to receive(:success?)
      guard.instance_variable_set(:@last_run, :success)

      guard.start
      guard.run("Foo")
    end

    it "runs examples matching pattern if last run was a success" do
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:run).with("Foo")
      guard.instance_variable_set(:@last_run, :success)

      guard.start
      guard.run("Foo")
    end

    it "runs examples matching pattern if last run was a compile time failure" do
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:run).with("Foo")
      guard.instance_variable_set(:@last_run, :compile_failure)

      guard.start
      guard.run("Foo")
    end

    it "reruns failing examples if last run was a runtime failure and @focus_on_fail is set" do
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:rerun)
      expect_any_instance_of(::Guard::Haskell::Repl).not_to receive(:run).with("Foo")
      guard.instance_variable_set(:@last_run, :runtime_failure)
      guard.instance_variable_set(:@focus_on_fail, true)

      guard.start
      guard.run("Foo")
    end

    it "runs examples matching pattern if last run was a runtime failure but @focus_on_fail is unset" do
      expect_any_instance_of(::Guard::Haskell::Repl).not_to receive(:rerun)
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:run).with("Foo")
      guard.instance_variable_set(:@last_run, :runtime_failure)
      guard.instance_variable_set(:@focus_on_fail, false)

      guard.start
      guard.run("Foo")
    end
  end

  describe "#run_all" do
    it "checks success after run" do
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:run)
      expect(guard).to receive(:success?)
      guard.instance_variable_set(:@last_run, :success)

      guard.start
      guard.run_all
    end
  end

  describe "#success" do
    def notify(before, received, after)
      ::Guard::Haskell::Repl.any_instance.stub(:result) { received }
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:result)
      yield
      guard.instance_variable_set(:@last_run, before)

      guard.start
      guard.success?
      expect(guard.instance_variable_get(:@last_run)).to eq(after)
    end

    it "notifies on success after success" do
      notify(:success, :success, :success) do
        expect(::Guard::Notifier).to receive(:notify).with('Success')
      end
    end

    it "notifies on success after runtime failure" do
      notify(:runtime_failure, :success, :success) do
        expect(::Guard::Notifier).to receive(:notify).with('Success')
      end
    end

    it "notifies on success after compile time failure" do
      notify(:compile_failure, :success, :success) do
        expect(::Guard::Notifier).to receive(:notify).with('Success')
      end
    end

    it "notifies on runtime failure after success" do
      notify(:success, :runtime_failure, :runtime_failure) do
        expect(::Guard::Notifier).to receive(:notify).with('Failure', image: :failed)
      end
    end

    it "notifies on runtime failure after runtime failure" do
      notify(:runtime_failure, :runtime_failure, :runtime_failure) do
        expect(::Guard::Notifier).to receive(:notify).with('Failure', image: :failed)
      end
    end

    it "notifies on runtime failure after compile time failure" do
      notify(:compile_failure, :runtime_failure, :runtime_failure) do
        expect(::Guard::Notifier).to receive(:notify).with('Failure', image: :failed)
      end
    end

    it "notifies on compile time failure after success" do
      notify(:success, :compile_failure, :compile_failure) do
        expect(::Guard::Notifier).to receive(:notify).with('Failure', image: :failed)
      end
    end

    it "notifies on compile time failure after runtime failure" do
      notify(:runtime_failure, :compile_failure, :runtime_failure) do
        expect(::Guard::Notifier).to receive(:notify).with('Failure', image: :failed)
      end
    end

    it "notifies on compile time failure after compile time failure" do
      notify(:compile_failure, :compile_failure, :compile_failure) do
        expect(::Guard::Notifier).to receive(:notify).with('Failure', image: :failed)
      end
    end

    it "does not run all specs on success after failure by default" do
      ::Guard::Haskell::Repl.any_instance.stub(:success?) { true }
      guard.instance_variable_set(:@last_run, :failure)

      expect(guard).not_to receive(:run_all)

      guard.start
      guard.success?
    end

    it "runs all examples on success after runtime failure with :all_on_pass option" do
      ::Guard::Haskell::Repl.any_instance.stub(:result) { :success }
      custom_guard = ::Guard::Haskell.new(all_on_pass: true)
      custom_guard.instance_variable_set(:@last_run, :runtime_failure)

      expect(custom_guard).to receive(:run_all)

      custom_guard.start
      custom_guard.success?
    end

    it "runs all examples on success after compile time failure with :all_on_pass option" do
      ::Guard::Haskell::Repl.any_instance.stub(:result) { :success }
      custom_guard = ::Guard::Haskell.new(all_on_pass: true)
      custom_guard.instance_variable_set(:@last_run, :compile_failure)

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
    it "run examples for simple haskell files" do
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:run).with("Foo")
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:result)

      guard.start
      guard.run_on_modifications(["Foo.hs"])
    end

    it "run examples for simple literate haskell files" do
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:run).with("Foo")
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:result)

      guard.start
      guard.run_on_modifications(["Foo.lhs"])
    end

    it "run examples for *complex* haskell files" do
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:run).with("Bar.Baz")
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:result)

      guard.start
      guard.run_on_modifications(["foo/Bar/Baz.hs"])
    end

    it "run examples for simple haskell spec files" do
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:run).with("Foo")
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:result)

      guard.start
      guard.run_on_modifications(["FooSpec.hs"])
    end

    it "run examples for simple literate haskell spec files" do
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:run).with("Foo")
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:result)

      guard.start
      guard.run_on_modifications(["FooSpec.lhs"])
    end

    it "run examples for *complex* haskell spec files" do
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:run).with("Bar.Baz")
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:result)

      guard.start
      guard.run_on_modifications(["foo/Bar/BazSpec.hs"])
    end
  end
end
