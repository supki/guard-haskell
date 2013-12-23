require 'open3'

class ::Guard::Haskell::Repl
  attr_reader :stdin, :listener, :thread, :result

  def initialize
    @running = false
    @result  = :success
  end

  def self.test(str)
    case str
    when /\d+ examples?, 0 failures/
      :success
    when /\d+ examples?, \d+ failures?/
      :runtime_failure
    when /Failed, modules loaded:/,
         /\*{3} Exception:/,
         /phase `C pre-processor' failed/,
         /GHCi runtime linker: fatal error:/
      :compile_failure
    end
  end

  def start ghci_options
    cmd = ["ghci"]
    Dir["*"].each { |d| cmd << "-i#{d}" if File.directory?(d) }
    sandbox = ::Dir[".cabal-sandbox/*packages.conf.d"].first
    cmd.concat(["-no-user-package-db", "-package-db=#{sandbox}"]) if sandbox
    cmd.concat(ghci_options)

    @stdin, stdout, @thread = ::Open3.popen2e(*cmd)
    @listener = ::Thread.new { listen(stdout, STDOUT) }
  end

  def init(spec)
    repl(":load #{spec}\n")
  end

  def exit
    ::Process::kill("TERM", thread.pid)
    ::Thread.kill(listener)
  end

  def run(pattern = nil)
    if pattern.nil?
      repl(":reload\n:main --color\n")
    else
      repl(":reload\n:main --color --match #{pattern}\n")
    end
  end

  def rerun
    repl(":reload\n:main --color --rerun\n")
  end

  def result
    while @running do sleep(0.01) end
    @result
  end

  private

    def repl(command)
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
