require 'bundler/setup'
require 'guard/plugin'
require 'set'

class String
  def strip_lowercase_directories
    matches = self.match(/^\p{Lower}[^\/]+\/(.+)/)
    if matches
      matches[1].strip_lowercase_directories
    else
      self
    end
  end
end

module ::Guard
  class Haskell < ::Guard::Plugin

    require 'guard/haskell/repl'

    attr_reader :repl, :root_spec, :dot_ghci, :ghci_options, :targets

    def initialize options = {}
      super
      @last_run_was_successful = true # try to prove it wasn't :-)

      @root_spec    = options[:root_spec] || "test/Spec.hs"
      @dot_ghci     = options[:dot_ghci]
      @ghci_options = options[:ghci_options] || []
      @all_on_start = options[:all_on_start] || false
      @all_on_pass  = options[:all_on_pass] || false
    end

    def start
      @repl = Repl.new(dot_ghci, ghci_options)
      repl.init root_spec

      @targets = Set.new Dir.glob("**/*.{hs,lhs}")

      run_all if @all_on_start
    end

    def stop
      repl.exit
    end

    def reload
      stop
      start
    end

    def run_all
      repl.run
      result
    end

    def run pattern
      if @last_run_was_successful
        repl.run pattern
      else
        repl.rerun
      end
      result
    end

    def run_on_additions paths
      unless paths.all? { |path| targets.include? path }
        @targets += paths
        repl.init root_spec
      end
    end

    def result
      if repl.success?
        if not @last_run_was_successful
          @last_run_was_successful = true
          run_all if @all_on_pass
        end
        Notifier.notify('Success')
      else
        @last_run_was_successful = false
        Notifier.notify('Failure', image: :failed)
      end
    end

    def run_on_modifications paths
      case paths.first
      when /.cabal$/, %r{#{root_spec}$}
        repl.reload
        run_all
      when /(.+)Spec.l?hs$/, /(.+).l?hs$/
        repl.reload
        run $1.strip_lowercase_directories.gsub(/\//, ".")
      end
    end
  end
end
