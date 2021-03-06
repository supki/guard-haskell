require 'spec_helper'
require 'guard/notifier'

describe "monkey patching" do
  describe ::String do
    describe "#to_module_name" do
      it "converts the empty string to the empty module name" do
        expect("".to_module_name).to eq("")
      end

      it "is identity for very simple module paths" do
        expect("Foo".to_module_name).to eq("Foo")
      end

      it "drops lowercase directory prefixes and substitutes / with ." do
        expect("foo/bar/Qux/Quux".to_module_name).to eq("Qux.Quux")
      end

      it "does not deal with extensions in the path" do
        expect("foo/bar/Qux/Quux.hs".to_module_name).to eq("Qux.Quux.hs")
      end
    end
  end
end

class ::Guard::Haskell::Repl
  def initialize(*args)
  end

  def status
    :success
  end
end

::Guard.init({})

describe ::Guard::Haskell do
  let(:guard) {
    ::Guard::Haskell.new
  }

  before :each do
    ::Guard.stub(:add_group)
    ::Guard::Haskell::Repl.any_instance.stub(:init)
  end

  describe ".initialize" do
    ::Guard::Haskell::DEFAULT_OPTIONS.each do |key, value|
      it "has :#{key} option" do
        expect(::Guard::Haskell.new.opts.send(key)).to eq(value)
      end
    end
  end

  describe "#start" do
    it "starts cabal repl by default" do
      expect_any_instance_of(::Guard::Haskell::Repl)
        .to receive(:initialize).with("cabal repl spec")

      guard.start
    end

    it "checks the repl has been loaded successfully" do
      expect(guard).to receive(:success?)

      guard.start
    end

    it "does not run all examples on start by default" do
      expect(guard).not_to receive(:run_all)

      guard.start
    end

    it "runs all examples on start with :all_on_start option enabled" do
      custom_guard = ::Guard::Haskell.new(all_on_start: true)

      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:reload_and_run_matching).with(no_args)
      expect(custom_guard).to receive(:success?).twice

      custom_guard.start
    end

    it "starts the REPL specified by the :cmd option" do
      cmd = "cabal exec -- ghci test/Spec.hs -ignore-dot-ghci"

      expect_any_instance_of(::Guard::Haskell::Repl)
        .to receive(:initialize).with(cmd)

      custom_guard = ::Guard::Haskell.new(cmd: cmd)
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
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:reload_and_run_matching).with("Foo")
      guard.instance_variable_set(:@last_run, :success)
      guard.start

      expect(guard).to receive(:success?)
      guard.run("Foo")
    end

    it "runs examples matching pattern if last run was a success" do
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:reload_and_run_matching).with("Foo")
      guard.instance_variable_set(:@last_run, :success)

      guard.start
      guard.run("Foo")
    end

    it "runs examples matching pattern if last run was a compile time failure" do
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:reload_and_run_matching).with("Foo")
      guard.instance_variable_set(:@last_run, :compile_failure)

      guard.start
      guard.run("Foo")
    end

    it "reruns failing examples if last run was a runtime failure and @focus_on_fail is set" do
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:reload_and_rerun)
      expect_any_instance_of(::Guard::Haskell::Repl).not_to receive(:reload_and_run_matching).with("Foo")

      guard.opts.focus_on_fail = true
      guard.start
      guard.instance_variable_set(:@last_run, :runtime_failure)
      guard.run("Foo")
    end

    it "runs examples matching pattern if last run was a runtime failure but @focus_on_fail is unset" do
      expect_any_instance_of(::Guard::Haskell::Repl).not_to receive(:reload_and_rerun)
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:reload_and_run_matching).with("Foo")
      guard.instance_variable_set(:@last_run, :runtime_failure)
      guard.opts.focus_on_fail = false

      guard.start
      guard.run("Foo")
    end
  end

  describe "#run_all" do
    it "checks success after run" do
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:reload_and_run_matching)
      guard.start

      expect(guard).to receive(:success?)
      guard.run_all
    end
  end

  describe "#success" do
    def notify(before, received, after)
      guard.start
      ::Guard::Haskell::Repl.any_instance.stub(:status) { received }
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:status)
      yield

      guard.instance_variable_set(:@last_run, before)
      guard.success?
      expect(guard.instance_variable_get(:@last_run)).to eq(after)
    end

    it "notifies on success after success" do
      notify(:success, :success, :success) do
        expect(::Guard::Notifier).to receive(:notify).with('Success', image: :success)
      end
    end

    it "notifies on success after runtime failure" do
      notify(:runtime_failure, :success, :success) do
        expect(::Guard::Notifier).to receive(:notify).with('Success', image: :success)
      end
    end

    it "notifies on success after compile time failure" do
      notify(:compile_failure, :success, :success) do
        expect(::Guard::Notifier).to receive(:notify).with('Success', image: :success)
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
      expect(guard).not_to receive(:run_all)

      guard.start
      guard.instance_variable_set(:@last_run, :failure)
      guard.success?
    end

    it "runs all examples on success after runtime failure with :all_on_pass option" do
      ::Guard::Haskell::Repl.any_instance.stub(:status) { :success }
      custom_guard = ::Guard::Haskell.new(all_on_pass: true)
      expect(custom_guard).to receive(:run_all)

      custom_guard.start
      custom_guard.instance_variable_set(:@last_run, :runtime_failure)
      custom_guard.success?
    end

    it "runs all examples on success after compile time failure with :all_on_pass option" do
      ::Guard::Haskell::Repl.any_instance.stub(:status) { :success }
      custom_guard = ::Guard::Haskell.new(all_on_pass: true)
      expect(custom_guard).to receive(:run_all)

      custom_guard.start
      custom_guard.instance_variable_set(:@last_run, :compile_failure)
      custom_guard.success?
    end
  end

  describe "#run_on_modifications" do
    before :each do
      ::Guard::Haskell::Repl.any_instance.stub(:status) { :success }
    end

    it "run examples for simple haskell files" do
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:reload_and_run_matching).with("Foo")
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:status)

      guard.start
      guard.run_on_modifications(["Foo.hs"])
    end

    it "run examples for simple literate haskell files" do
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:reload_and_run_matching).with("Foo")
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:status)

      guard.start
      guard.run_on_modifications(["Foo.lhs"])
    end

    it "run examples for *complex* haskell files" do
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:reload_and_run_matching).with("Bar.Baz")
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:status)

      guard.start
      guard.run_on_modifications(["foo/Bar/Baz.hs"])
    end

    it "run examples for simple haskell spec files" do
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:reload_and_run_matching).with("Foo")
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:status)

      guard.start
      guard.run_on_modifications(["FooSpec.hs"])
    end

    it "run examples for simple literate haskell spec files" do
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:reload_and_run_matching).with("Foo")
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:status)

      guard.start
      guard.run_on_modifications(["FooSpec.lhs"])
    end

    it "run examples for *complex* haskell spec files" do
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:reload_and_run_matching).with("Bar.Baz")
      expect_any_instance_of(::Guard::Haskell::Repl).to receive(:status)

      guard.start
      guard.run_on_modifications(["foo/Bar/BazSpec.hs"])
    end
  end

  describe "#run_on_additions" do
    it "reinitializes the repl on new files" do
      expect_any_instance_of(::Guard::Haskell).to receive(:reload).once

      guard.start
      guard.instance_variable_set(:@targets, [])
      guard.run_on_additions(["foo", "bar"])
    end

    it "does not reinitialize the repl if new files were seen before" do
      expect_any_instance_of(::Guard::Haskell).not_to receive(:reload).once

      guard.start
      guard.instance_variable_set(:@targets, ["foo", "bar"])
      guard.run_on_additions(["foo", "bar"])
    end
  end
end
