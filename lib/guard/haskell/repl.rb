require 'open3'

class ::Guard::Haskell::Repl
  attr_reader :stdin, :listener, :inferior, :status

  def self.finished_with(str)
    case str
    when /\d+ examples?, 0 failures/,
         /Ok, modules loaded:/
      :success
    when /\d+ examples?, \d+ failures?/
      :runtime_failure
    when /Failed, modules loaded:/,
         /\*{3} Exception:/,
         /cannot find object file for module/,
         /phase `C pre-processor' failed/,
         /phase `Haskell pre-processor' failed/,
         /phase `Linker' failed/,
         /GHCi runtime linker: fatal error:/,
         /During interactive linking, GHCi couldn't find the following symbol:/,
         /ghc: could not execute:/
      :compile_failure
    when /^cabal:/
      :loading_failure
    end
  end

  def initialize(cabal_target, repl_options)
    @listening = false
    @status = :success
    start("cabal", "repl", cabal_target, *repl_options)
  end

  def start(*cmd)
    @listening = true
    @stdin, stdout, @inferior = ::Open3.popen2e(*cmd)
    @listener = ::Thread.new { listen(stdout, STDOUT) }
    wait_for_result
  end

  def exit
    stdin.write(":quit\n")
    ::Thread.kill(listener)
  end

  def reload_and_run_matching(pattern = nil)
    if run_command_and_wait_for_result(":reload\n")
      if pattern.nil?
        run_command_and_wait_for_result(":main --color\n")
      else
        run_command_and_wait_for_result(":main --color --match #{pattern}\n")
      end
    end
  end

  def reload_and_rerun
    if run_command_and_wait_for_result(":reload\n")
      run_command_and_wait_for_result(":main --color --rerun\n")
    end
  end

  private
    def run_command_and_wait_for_result(command)
      @listening = true
      stdin.write(command)
      wait_for_result == :success
    end

    def wait_for_result
      while @listening do sleep(0.01) end
      @status
    end

    def listen(in_stream, out_stream)
      while (line = in_stream.gets)
        out_stream.print(line)
        if @listening
          res = self.class.finished_with(line)
          case res
          when :success, :runtime_failure, :compile_failure, :loading_failure
            # A horrible hack to show the cursor again
            #
            # The problem is that '\e[?25h' code from hspec is waiting on
            # the next line, which we probably will never read :-(
            out_stream.print("\e[?25h")
            @status = res
            @listening = false
          end
        end
      end
    end
end
