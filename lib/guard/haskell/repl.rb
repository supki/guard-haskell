require 'open3'

class ::Guard::Haskell::Repl
  attr_reader :stdin, :listener, :thread, :result

  def initialize
    @running = false
    @result  = :success
  end

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
         /GHCi runtime linker: fatal error:/,
         /During interactive linking, GHCi couldn't find the following symbol:/
      :compile_failure
    end
  end

  def start(ghci_options, sandbox_glob)
    cmd = ["ghci"]

    Dir["*"].each { |d| cmd << "-i#{d}" if File.directory?(d) }
    lookup_sandbox(cmd, sandbox_glob)
    cmd.concat(ghci_options)

    @stdin, stdout, @thread = ::Open3.popen2e(*cmd)
    @listener = ::Thread.new { listen(stdout, STDOUT) }
  end

  def lookup_sandbox(cmd, sandbox_glob)
    sandboxes = Sandbox.new(sandbox_glob)
    sandboxes.with_best_sandbox(->(str) { str.scan(/\d+/).map(&:to_i) }) do |best_sandbox|
      puts "Cabal sandboxes found:"
      sandboxes.each { |sandbox| puts "  #{sandbox}" }
      puts "Cabal sandbox used:\n  #{best_sandbox}"
      cmd.concat(["-no-user-package-db", "-package-db=#{best_sandbox}"])
    end
  end

  def init(spec)
    run_command_and_wait_for_result(":load #{spec}\n")
  end

  def exit
    ::Process::kill("TERM", thread.pid)
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

  class Sandbox
    attr_reader :sandboxes

    include ::Enumerable

    def initialize(glob)
      @sandboxes = ::Dir[glob]
    end

    def each(&block)
      sandboxes.each(&block)
    end

    def with_best_sandbox(ordering)
      best = sandboxes.max_by(&ordering)
      yield best if best
      best
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
          when :success, :runtime_failure, :compile_failure
            @result  = res
            @running = false
          end
        end
      end
    end
end
