require 'fakefs/spec_helpers'
require 'spec_helper'
require 'guard/notifier'

dev_null = ::File.open("/dev/null", "w")
run_file = ->(file) { "spec/run-files/#{file}" }

describe ::Guard::Haskell::Repl do
  let(:repl) do
    ::Guard::Haskell::Repl.new
  end

  describe '#init' do
    it "calls :load on ghci instance" do
      expect(repl).to receive(:repl).with(/:load/)
      repl.init("Spec.hs")
    end

    it "loads provided spec" do
      expect(repl).to receive(:repl).with(/FooBarSpec.hs/)
      repl.init("FooBarSpec.hs")
    end
  end

  describe '#run' do
    it "reloads the spec if no pattern is provided" do
      expect(repl).to receive(:repl).with(/:reload/)
      repl.run
    end

    it "reloads the spec if a pattern is provided" do
      expect(repl).to receive(:repl).with(/:reload/)
      repl.run("FooBar")
    end

    it "provides a pattern for spec to match" do
      expect(repl).to receive(:repl).with(/--match FooBar/)
      repl.run("FooBar")
    end
  end

  describe '#rerun' do
    it "reloads the spec" do
      expect(repl).to receive(:repl).with(/:reload/)
      repl.rerun
    end

    it "reruns the spec" do
      expect(repl).to receive(:repl).with(/--rerun/)
      repl.rerun
    end
  end

  describe '#test' do
    it "handles zero examples/failures" do
      expect(::Guard::Haskell::Repl.test("0 examples, 0 failures")).to eq(:success)
    end

    it "handles one example/zero failures" do
      expect(::Guard::Haskell::Repl.test("1 example, 0 failures")).to eq(:success)
    end

    it "handles multiple examples/zero failures" do
      expect(::Guard::Haskell::Repl.test("37 examples, 0 failures")).to eq(:success)
    end

    it "handles one example/failure" do
      expect(::Guard::Haskell::Repl.test("1 example, 1 failure")).to eq(:runtime_failure)
    end

    it "handles multiple examples/multiple failures" do
      expect(::Guard::Haskell::Repl.test("26 examples, 2 failures")).to eq(:runtime_failure)
    end

    it "handles failure to load the module" do
      expect(::Guard::Haskell::Repl.test("Failed, modules loaded:")).to eq(:compile_failure)
    end

    it "handles uncaught exceptions" do
      expect(::Guard::Haskell::Repl.test("*** Exception: Prelude.undefined")).to eq(:compile_failure)
    end

    it "handles CPP errors" do
      expect(::Guard::Haskell::Repl.test("phase `C pre-processor' failed")).to eq(:compile_failure)
    end

    it "handles runtime linker errors" do
      expect(::Guard::Haskell::Repl.test("GHCi runtime linker: fatal error:")).to eq(:compile_failure)
    end
  end

  describe '#listen' do
    context 'real world' do
      it "handles typical pass run" do
        in_stream  = ::File.open(run_file["spec-pass.success"])
        repl.instance_variable_set(:@running, true)

        repl.send(:listen, in_stream, dev_null)

        expect(repl.instance_variable_get(:@running)).to eq(false)
        expect(repl.instance_variable_get(:@result)).to eq(:success)
      end

      it "handles typical failure run" do
        in_stream  = ::File.open(run_file["spec-failure.error"])
        repl.instance_variable_set(:@running, true)

        repl.send(:listen, in_stream, dev_null)

        expect(repl.instance_variable_get(:@running)).to eq(false)
        expect(repl.instance_variable_get(:@result)).to eq(:runtime_failure)
      end

      it 'handles "duplicate definition" runtime linker error' do
        in_stream  = ::File.open(run_file["runtime-linker-duplicate-definition-for-symbol.error"])
        repl.instance_variable_set(:@running, true)

        repl.send(:listen, in_stream, dev_null)

        expect(repl.instance_variable_get(:@running)).to eq(false)
        expect(repl.instance_variable_get(:@result)).to eq(:compile_failure)
      end

      # Unfortunately I can't remember why it happened :-(
      it 'handles "couldn\'t find symbol" runtime linker error' do
        in_stream  = ::File.open(run_file["runtime-linker-couldn't-find-symbol.error"])
        repl.instance_variable_set(:@running, true)

        repl.send(:listen, in_stream, dev_null)

        expect(repl.instance_variable_get(:@running)).to eq(false)
        expect(repl.instance_variable_get(:@result)).to eq(:compile_failure)
      end

      it "handles hspec exceptions" do
        in_stream  = ::File.open(run_file["hspec-exception.error"])
        repl.instance_variable_set(:@running, true)

        repl.send(:listen, in_stream, dev_null)

        expect(repl.instance_variable_get(:@running)).to eq(false)
        expect(repl.instance_variable_get(:@result)).to eq(:compile_failure)
      end

      it "handles CPP exceptions" do
        in_stream  = ::File.open(run_file["cpp-exception.error"])
        repl.instance_variable_set(:@running, true)

        repl.send(:listen, in_stream, dev_null)

        expect(repl.instance_variable_get(:@running)).to eq(false)
        expect(repl.instance_variable_get(:@result)).to eq(:compile_failure)
      end
    end
  end

  describe "#lookup_sandbox" do
    include FakeFS::SpecHelpers

    before(:each) { ::IO.any_instance.stub(:puts) }

    it "does not find anything if there are no sandboxes" do
      expect_any_instance_of(::IO).not_to receive(:puts)
      expect(repl.lookup_sandbox([])).to be_nil
    end

    it "finds as sandbox" do
      ::FileUtils.mkdir_p([".cabal-sandbox/foo-bar-ghc-7.6.3-packages.conf.d"])
      expect_any_instance_of(::IO).to receive(:puts).with("Cabal sandboxes found:")
      expect(repl.lookup_sandbox([])).to eq("/.cabal-sandbox/foo-bar-ghc-7.6.3-packages.conf.d")
    end

    it "compares sandboxes cleverly" do
      ::FileUtils.mkdir_p(
          [ ".cabal-sandbox/foo-bar-ghc-1.0-packages.conf.d",
            ".cabal-sandbox/foo-bar-ghc-1.1-packages.conf.d",
            ".cabal-sandbox/foo-bar-ghc-1.2-packages.conf.d",
            ".cabal-sandbox/foo-bar-ghc-1.10-packages.conf.d",
          ])
      expect(repl.lookup_sandbox([])).to eq("/.cabal-sandbox/foo-bar-ghc-1.10-packages.conf.d")
    end
  end
end

describe ::Guard::Haskell::Repl::Sandbox do
  ::Sandbox = ::Guard::Haskell::Repl::Sandbox
  include FakeFS::SpecHelpers

  let(:id) { ->(x) { x } }
  let(:reversed) { ->(str) { str.reverse } }

  before(:each) { ::IO.any_instance.stub(:puts) }

  it "has an empty list of sandboxes if no sandboxes are found" do
    expect(::Sandbox.new("*").sandboxes).to eq([])
  end

  it "has a singleton list of sandboxes if one sandbox is found" do
    ::FileUtils.touch(["foo", "bar", "baz"])
    expect(::Sandbox.new("foo").sandboxes).to eq(["/foo"])
  end

  it "has a list of sandboxes if more than one sandbox is found" do
    ::FileUtils.touch(["foo", "bar", "baz"])
    expect(::Sandbox.new("ba*").sandboxes).to eq(["/bar", "/baz"])
  end

  it "has a nil for the best sandbox of an empty list of sandboxes" do
    expect_any_instance_of(::IO).not_to receive(:puts)
    expect(::Sandbox.new("*").with_best_sandbox(id) { |s| puts s }).to be_nil
  end

  it "chooses a \"maximum\" for the best sandbox" do
    ::FileUtils.touch(["foo", "bar", "baz"])
    expect_any_instance_of(::IO).to receive(:puts).with("/foo")
    expect(::Sandbox.new("*").with_best_sandbox(id) { |s| puts s }).to eq("/foo")
  end

  it "chooses a \"maximum\" of the complex ordering for the best sandbox" do
    ::FileUtils.touch(["foo", "bar", "baz", "zap"])
    expect_any_instance_of(::IO).to receive(:puts).with("/baz")
    expect(::Sandbox.new("*").with_best_sandbox(reversed) { |s| puts s }).to eq("/baz")
  end
end
