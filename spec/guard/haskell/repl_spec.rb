require 'fakefs/spec_helpers'
require 'spec_helper'
require 'guard/notifier'

dev_null = ::File.open("/dev/null", "w")
asset = ->(file) { "asset/#{file}" }

describe ::Guard::Haskell::Repl do
  let(:repl) do
    ::Guard::Haskell::Repl.new
  end

  context "running spec" do
    before(:each) do
      repl.stub(:run_command_and_wait_for_result) { |_| true }
    end

    describe '#reload_and_run_matching' do
      it "reloads the spec if no pattern is provided" do
        expect(repl).to receive(:run_command_and_wait_for_result).with(/:reload/)
        repl.reload_and_run_matching
      end

      it "reloads the spec if a pattern is provided" do
        expect(repl).to receive(:run_command_and_wait_for_result).with(/:reload/)
        repl.reload_and_run_matching
      end

      it "provides a pattern for spec to match" do
        expect(repl).to receive(:run_command_and_wait_for_result).with(/--match FooBar/)
        repl.reload_and_run_matching("FooBar")
      end

      it "provides no pattern for spec to match if an argument is nil" do
        expect(repl).not_to receive(:run_command_and_wait_for_result).with(/--match FooBar/)
        repl.reload_and_run_matching(nil)
      end
    end

    describe '#reload_and_rerun' do
      it "reloads the spec" do
        expect(repl).to receive(:run_command_and_wait_for_result).with(/:reload/)
        repl.reload_and_rerun
      end

      it "reruns the spec" do
        expect(repl).to receive(:run_command_and_wait_for_result).with(/--rerun/)
        repl.reload_and_rerun
      end
    end
  end

  describe '#finished_with' do
    it "handles zero examples/failures" do
      expect(::Guard::Haskell::Repl.finished_with("0 examples, 0 failures")).to eq(:success)
    end

    it "handles one example/zero failures" do
      expect(::Guard::Haskell::Repl.finished_with("1 example, 0 failures")).to eq(:success)
    end

    it "handles multiple examples/zero failures" do
      expect(::Guard::Haskell::Repl.finished_with("37 examples, 0 failures")).to eq(:success)
    end

    it "handles one example/failure" do
      expect(::Guard::Haskell::Repl.finished_with("1 example, 1 failure")).to eq(:runtime_failure)
    end

    it "handles multiple examples/multiple failures" do
      expect(::Guard::Haskell::Repl.finished_with("26 examples, 2 failures")).to eq(:runtime_failure)
    end

    it "handles failure to load the module" do
      expect(::Guard::Haskell::Repl.finished_with("Failed, modules loaded:")).to eq(:compile_failure)
    end

    it "handles uncaught exceptions" do
      expect(::Guard::Haskell::Repl.finished_with("*** Exception: Prelude.undefined")).to eq(:compile_failure)
    end

    it "handles CPP errors" do
      expect(::Guard::Haskell::Repl.finished_with("phase `C pre-processor' failed")).to eq(:compile_failure)
    end

    it "handles Haskell pre-processor errors" do
      expect(::Guard::Haskell::Repl.finished_with("phase `Haskell pre-processor' failed")).to eq(:compile_failure)
    end

    it "handles runtime linker errors" do
      expect(::Guard::Haskell::Repl.finished_with("GHCi runtime linker: fatal error:")).to eq(:compile_failure)
    end
  end

  describe '#listen' do
    context 'real world' do
      it "handles typical pass run" do
        in_stream  = ::File.open(asset["passed/spec-pass.ok"])
        repl.instance_variable_set(:@listening, true)

        repl.send(:listen, in_stream, dev_null)

        expect(repl.instance_variable_get(:@listening)).to eq(false)
        expect(repl.instance_variable_get(:@status)).to eq(:success)
      end

      it "handles typical failure run" do
        in_stream  = ::File.open(asset["failed/spec-failure.err"])
        repl.instance_variable_set(:@listening, true)

        repl.send(:listen, in_stream, dev_null)

        expect(repl.instance_variable_get(:@listening)).to eq(false)
        expect(repl.instance_variable_get(:@status)).to eq(:runtime_failure)
      end

      it 'handles "duplicate definition" runtime linker error' do
        in_stream  = ::File.open(asset["failed/runtime-linker-duplicate-definition-for-symbol.err"])
        repl.instance_variable_set(:@listening, true)

        repl.send(:listen, in_stream, dev_null)

        expect(repl.instance_variable_get(:@listening)).to eq(false)
        expect(repl.instance_variable_get(:@status)).to eq(:compile_failure)
      end

      # Unfortunately I can't remember why it happened :-(
      it 'handles "couldn\'t find symbol" runtime linker error' do
        in_stream  = ::File.open(asset["failed/runtime-linker-couldn't-find-symbol.err"])
        repl.instance_variable_set(:@listening, true)

        repl.send(:listen, in_stream, dev_null)

        expect(repl.instance_variable_get(:@listening)).to eq(false)
        expect(repl.instance_variable_get(:@status)).to eq(:compile_failure)
      end

      # This one's even trickier to reproduce than the previous one
      it 'handles "cannot find object file" runtime linker error' do
        in_stream  = ::File.open(asset["failed/runtime-linker-cannot-find-object-file.err"])
        repl.instance_variable_set(:@listening, true)

        repl.send(:listen, in_stream, dev_null)

        expect(repl.instance_variable_get(:@listening)).to eq(false)
        expect(repl.instance_variable_get(:@status)).to eq(:compile_failure)
      end

      it "handles hspec exceptions" do
        in_stream  = ::File.open(asset["failed/exception.err"])
        repl.instance_variable_set(:@listening, true)

        repl.send(:listen, in_stream, dev_null)

        expect(repl.instance_variable_get(:@listening)).to eq(false)
        expect(repl.instance_variable_get(:@status)).to eq(:compile_failure)
      end

      it "handles CPP exceptions" do
        in_stream  = ::File.open(asset["failed/phase-c-pre-processor-failed.err"])
        repl.instance_variable_set(:@listening, true)

        repl.send(:listen, in_stream, dev_null)

        expect(repl.instance_variable_get(:@listening)).to eq(false)
        expect(repl.instance_variable_get(:@status)).to eq(:compile_failure)
      end

      it "handles preprocessor phase failures" do
        in_stream  = ::File.open(asset["failed/phase-haskell-pre-processor-failed.err"])
        repl.instance_variable_set(:@listening, true)

        repl.send(:listen, in_stream, dev_null)

        expect(repl.instance_variable_get(:@listening)).to eq(false)
        expect(repl.instance_variable_get(:@status)).to eq(:compile_failure)
      end

      it "handles missing preprocessor error" do
        in_stream  = ::File.open(asset["failed/invalid-preprocessor.err"])
        repl.instance_variable_set(:@listening, true)

        repl.send(:listen, in_stream, dev_null)

        expect(repl.instance_variable_get(:@listening)).to eq(false)
        expect(repl.instance_variable_get(:@status)).to eq(:compile_failure)
      end

      it "handles linker phase failures" do
        in_stream  = ::File.open(asset["failed/phase-linker-failed.err"])
        repl.instance_variable_set(:@listening, true)

        repl.send(:listen, in_stream, dev_null)

        expect(repl.instance_variable_get(:@listening)).to eq(false)
        expect(repl.instance_variable_get(:@status)).to eq(:compile_failure)
      end
    end
  end
end
