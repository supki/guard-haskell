require 'io/wait'
require 'open3'

class ::Guard::Haskell::Repl
  attr_reader :stdin, :reader, :thread, :success

  def start ghci_options
    cmd = ["ghci"]
    Dir["*"].each { |d| cmd << "-i#{d}" if File.directory?(d) }
    sandbox = ::Dir[".cabal-sandbox/*packages.conf.d"].first
    cmd << "-package-db=#{sandbox}" if sandbox
    cmd.concat(ghci_options)

    @stdin, stdout, @thread = ::Open3.popen2e(*cmd)
    @reader = ::Thread.new do
      loop do
        n = stdout.nread
        if n > 0
          out = stdout.read(n)
          print out
          if @running
            case out
            when /\d+ examples?, 0 failures/
              @success = true
              @running = false
            when /\d+ examples?, \d+ failures?/,
                 /Failed, modules loaded:/,
                 /\*{3} Exception:/,
                 /phase `C preprocessor' failed/
              @success = false
              @running = false
            end
          end
        else
          sleep(0.1)
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

  def success?
    while @running do sleep(0.01) end
    @success
  end

  def _repl command
    @running = true
    stdin.write command
  end
end
