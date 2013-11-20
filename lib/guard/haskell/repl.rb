require 'io/wait'
require 'open3'

class ::Guard::Haskell::Repl
  attr_reader :stdin, :reader, :thread, :success

  def start ghci_options
    cmd = ["ghci"]
    Dir["*"].each { |x| cmd << "-i#{x}" }
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
          case out
          when /\d+ examples?, 0 failures/
            @success = true
            @running = false
          when /\d+ examples?, \d+ failures?/, /Failed, modules loaded:/, /\*{3} Exception:/
            @success = false
            @running = false
          end
        else
          sleep(0.1)
        end
      end
    end
  end

  def init spec
    repl ":load #{spec}"
  end

  def exit
    ::Process::kill "TERM", thread.pid
    ::Thread.kill(reader)
  end

  def run pattern = nil
    if pattern.nil?
      repl ":main --color"
    else
      repl ":main --color --match #{pattern}"
    end
  end

  def rerun
    repl ":main --color --rerun"
  end

  def reload
    repl ":reload"
  end

  def success?
    while @running do sleep(0.01) end
    @success
  end

  def repl command
    @running = true
    stdin.write "#{command}\n"
  end
end
