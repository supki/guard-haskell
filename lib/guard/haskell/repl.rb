require 'open3'

class ::Guard::Haskell::Repl
  attr_reader :stdin, :reader, :thread, :result

  def initialize
    @running = false
    @result  = :success
  end

  def start ghci_options
    cmd = ["ghci"]
    Dir["*"].each { |d| cmd << "-i#{d}" if File.directory?(d) }
    sandbox = ::Dir[".cabal-sandbox/*packages.conf.d"].first
    cmd << "-package-db=#{sandbox}" if sandbox
    cmd.concat(ghci_options)

    @stdin, stdout, @thread = ::Open3.popen2e(*cmd)
    @reader = ::Thread.new do
      loop do
        while (out = stdout.gets)
          print out
          if @running
            case out
            when /\d+ examples?, 0 failures/
              @result  = :success
              @running = false
            when /\d+ examples?, \d+ failures?/
              @result  = :runtime_failure
              @running = false
            when /Failed, modules loaded:/,
                 /\*{3} Exception:/,
                 /phase `C preprocessor' failed/
              @result  = :compile_failure
              @running = false
            end
          end
        end
      end
    end
  end

  def init spec
    _repl ":load #{spec}\n"
  end

  def exit
    ::Process::kill "TERM", thread.pid
    ::Thread.kill(reader)
  end

  def run pattern = nil
    if pattern.nil?
      _repl ":reload\n:main --color\n"
    else
      _repl ":reload\n:main --color --match #{pattern}\n"
    end
  end

  def rerun
    _repl ":reload\n:main --color --rerun\n"
  end

  def result
    while @running do sleep(0.01) end
    @result
  end

  def _repl command
    @running = true
    stdin.write command
  end
end
