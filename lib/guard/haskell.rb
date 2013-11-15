require 'bundler/setup'
require 'guard/plugin'
require 'set'

module ::Guard
  class Haskell < ::Guard::Plugin

    require 'guard/haskell/repl'

    attr_reader :repl, :sources, :tests, :dot_ghci, :targets

    def initialize options = {}
      super
      @last_run_was_successful = true # try to prove it wasn't :-)

      @sources      = options[:sources] || "src"
      @tests        = options[:tests] || "test"
      @dot_ghci     = options[:dot_ghci]
      @all_on_start = options[:all_on_start] || false
      @all_on_pass  = options[:all_on_pass] || false
    end

    def start
      @repl = Repl.new [sources, tests], dot_ghci
      repl.init "#{tests}/Spec.hs"

      @targets = Set.new Dir.glob("{#{sources},#{tests}}/**/*.{hs,lhs}")

      run_all if @all_on_start
    end

    def stop
      repl.exit
    end

    def reload
      stop
      start
    end

    def run_all pattern = nil
      if @last_run_was_successful
        repl.run pattern
      else
        repl.rerun
      end
    end

    def run_on_additions paths
      unless paths.all? { |path| targets.include? path }
        @targets += paths
        repl.init "#{tests}/Spec.hs"
      end
    end

    def run_on_modifications paths
      pattern = paths.first
      case pattern
      when /.cabal$/, %r{#{tests}/Spec.hs}
        repl.reload
        run_all
      when ".hspec-results"
        out = File.read pattern

        puts out

        if out =~ /\d+ examples?, 0 failures/
          if not @last_run_was_successful
            @last_run_was_successful = true
            run_all if @all_on_pass
          end
          Notifier.notify('Success')
        else
          @last_run_was_successful = false
          Notifier.notify('Failure', image: :failed)
        end
      when /#{tests}\/(.+)Spec.l?hs$/
        repl.reload
        run_all $1.gsub(/\//, ".")
      when /#{sources}\/(.+).l?hs$/
        repl.reload
        run_all $1.gsub(/\//, ".")
      end
    end
  end
end
