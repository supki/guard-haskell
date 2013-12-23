require 'spec_helper'
require 'guard/notifier'

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
      it "handles typical passed run" do
        in_stream = ::StringIO.open(<<-FOO)
          Useful.Git
            fromGraph
              - creates `git init' script from empty graph
              - creates git script from two-node graph
              - creates git script from three-node graph
              - creates git script from three-node chain graph

          Finished in 0.0054 seconds
          4 examples, 0 failures
        FOO
        out_stream = File.open("/dev/null", "w")
        repl.instance_variable_set(:@running, true)

        repl.send(:listen, in_stream, out_stream)

        expect(repl.instance_variable_get(:@running)).to eq(false)
        expect(repl.instance_variable_get(:@result)).to eq(:success)
      end

      it "handles typical failed spec run" do
        in_stream = ::StringIO.open(<<-FOO)
          Useful.Git
            fromGraph
              - creates `git init' script from empty graph
              - creates git script from two-node graph FAILED [1]
              - creates git script from three-node graph
              - creates git script from three-node chain graph

          1) Useful.Git.fromGraph creates git script from two-node graph
          expected: Just [InitE,OrphanE "foo" "7",CommitE "bar" ["1"] "2"]
           but got: Just [InitE,OrphanE "foo" "1",CommitE "bar" ["1"] "2"]

          Randomized with seed 4611685481380198536

          Finished in 0.0089 seconds
          4 examples, 1 failure
          *** Exception: ExitFailure 1
        FOO
        out_stream = File.open("/dev/null", "w")
        repl.instance_variable_set(:@running, true)

        repl.send(:listen, in_stream, out_stream)

        expect(repl.instance_variable_get(:@running)).to eq(false)
        expect(repl.instance_variable_get(:@result)).to eq(:runtime_failure)
      end

      it "handles runtime linker error" do
        in_stream = ::StringIO.open(<<-FOO)
          GHCi runtime linker: fatal error: I found a duplicate definition for symbol
             HUnitzm1zi2zi5zi2_TestziHUnitziBase_zdwzdcshowsPrec_slow
          whilst processing object file
             /home/maksenov/.cabal/lib/HUnit-1.2.5.2/ghc-7.6.2/HSHUnit-1.2.5.2.o
          This could be caused by:
             * Loading two different object files which export the same symbol
             * Specifying the same object file twice on the GHCi command line
             * An incorrect `package.conf' entry, causing some object to be
               loaded twice.
          GHCi cannot safely continue in this situation.  Exiting now.  Sorry.
        FOO
        out_stream = File.open("/dev/null", "w")
        repl.instance_variable_set(:@running, true)

        repl.send(:listen, in_stream, out_stream)

        expect(repl.instance_variable_get(:@running)).to eq(false)
        expect(repl.instance_variable_get(:@result)).to eq(:compile_failure)
      end

      it "handles hspec exceptions" do
        in_stream = ::StringIO.open(<<-FOO)
          *Main> Ok, modules loaded: Main, Useful.Parser, Useful.Graph, Useful.Git.
          *Main>
          *** Exception: Prelude.undefined
        FOO
        out_stream = File.open("/dev/null", "w")
        repl.instance_variable_set(:@running, true)

        repl.send(:listen, in_stream, out_stream)

        expect(repl.instance_variable_get(:@running)).to eq(false)
        expect(repl.instance_variable_get(:@result)).to eq(:compile_failure)
      end

      it "handles CPP exceptions" do
        in_stream = ::StringIO.open(<<-FOO)
          *Main>
          test/Useful/GitSpec.hs:4:0:
               error: invalid preprocessing directive #ifd
               #ifd
               ^
          phase `C pre-processor' failed (exitcode = 1)
        FOO
        out_stream = File.open("/dev/null", "w")
        repl.instance_variable_set(:@running, true)

        repl.send(:listen, in_stream, out_stream)

        expect(repl.instance_variable_get(:@running)).to eq(false)
        expect(repl.instance_variable_get(:@result)).to eq(:compile_failure)
      end
    end
  end
end
