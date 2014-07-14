require 'open3'

class ::Guard::Haskell::Repl
  attr_reader :stdin, :listener, :thread, :result

  def self.test(str)
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

  def initialize(test_suite, repl_options)
    @running = false
    @result  = :success
    start("cabal", "repl", test_suite, *repl_options)
  end

  def start(*cmd)
    @running = true
    @stdin, stdout, @thread = ::Open3.popen2e(*cmd)
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
      talk_to_repl(command)
      wait_for_result == :success
    end

    def wait_for_result
      while @running do sleep(0.01) end
      @result
    end

    def talk_to_repl(command)
      @running = true
      stdin.write(command)
    end

    def listen(in_stream, out_stream)
      while (str = in_stream.gets)
        out_stream.print(str)
        if @running
          res = self.class.test(str)
          case res
          when :success, :runtime_failure, :compile_failure, :loading_failure
            # A horrible hack to show the cursor again
            #
            # The problem is that '\e[?25h' code from hspec is waiting on
            # the next line, which we probably will never read :-(
            out_stream.print("\e[?25h")
            @result  = res
            @running = false
          end
        end
      end
    end
end
