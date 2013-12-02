require 'spec_helper'
require 'guard/notifier'

describe ::Guard::Haskell::Repl do
  let(:repl) do
    ::Guard::Haskell::Repl.new
  end

  describe '#init' do
    it "calls :load on ghci instance" do
      expect(repl).to receive(:_repl).with(/:load/)
      repl.init("Spec.hs")
    end

    it "loads provided spec" do
      expect(repl).to receive(:_repl).with(/FooBarSpec.hs/)
      repl.init("FooBarSpec.hs")
    end
  end

  describe '#run' do
    it "reloads the spec if no pattern is provided" do
      expect(repl).to receive(:_repl).with(/:reload/)
      repl.run
    end

    it "reloads the spec if a pattern is provided" do
      expect(repl).to receive(:_repl).with(/:reload/)
      repl.run("FooBar")
    end

    it "provides a pattern for spec to match" do
      expect(repl).to receive(:_repl).with(/--match FooBar/)
      repl.run("FooBar")
    end
  end

  describe '#rerun' do
    it "reloads the spec" do
      expect(repl).to receive(:_repl).with(/:reload/)
      repl.rerun
    end

    it "reruns the spec" do
      expect(repl).to receive(:_repl).with(/--rerun/)
      repl.rerun
    end
  end
end
