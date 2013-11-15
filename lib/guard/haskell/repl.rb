module ::Guard::Haskell::Repl
  attr_reader :io

  def initialize includes, dot_ghci
    sandbox = ::Dir[".cabal-sandbox/*packages.conf.d"].first
    cmd = ["ghci"]
    includes.each { |x| cmd << "-i#{x}" }
    cmd << "-package-db=#{sandbox}" if sandbox
    case dot_ghci
    when :ignore then cmd << "-ignore-dot-ghci"
    when /.+/    then cmd << "-ghci-script #{dot_ghci}"
    end

    @io = ::IO.popen cmd, mode: "r+"
  end

  def exit
    ::Process::kill "TERM", io.pid
  end

  def run pattern
    if pattern.nil?
      repl ":main --color --out .hspec-results"
    else
      repl ":main --color --match #{pattern} --out .hspec-results"
    end
  end

  def init spec
    repl ":load #{spec}"
  end

  def rerun
    repl ":main --color --rerun --out .hspec-results"
  end

  def reload
    repl ":reload"
  end

  def repl command
    io.write "#{command}\n"
    result = ""
    begin
      loop do
        result << io.read_nonblock(4096)
      end
    rescue ::IO::WaitReadable
      result
    end
  end
end
