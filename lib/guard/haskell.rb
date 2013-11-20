require 'bundler/setup'
require 'guard/plugin'
require 'set'

class ::String
  def strip_lowercase_directories
    matches = self.match(/^\p{Lower}[^\/]+\/(.+)/)
    if matches
      matches[1].strip_lowercase_directories
    else
      self
    end
  end

  def path_to_module_name
    self.gsub(/\//, ".")
  end
end

module ::Guard
  class Haskell < ::Guard::Plugin

    require 'guard/haskell/repl'

    attr_reader :repl, :top_spec, :dot_ghci, :ghci_options, :targets
    attr_reader :all_on_start, :all_on_pass

    def initialize options = {}
      super
      @last_run     = :success # try to prove it wasn't :-)
      @top_spec     = options[:top_spec] || "test/Spec.hs"
      @dot_ghci     = options[:dot_ghci]
      @ghci_options = options[:ghci_options] || []
      @all_on_start = options[:all_on_start] || false
      @all_on_pass  = options[:all_on_pass] || false
      @repl         = Repl.new
    end

    def start
      repl.start(dot_ghci, ghci_options)
      repl.init(top_spec)

      @targets = ::Set.new(::Dir.glob("**/*.{hs,lhs}"))

      if all_on_start
        run_all
        result
      end
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
    end

    def run pattern
      if @last_run == :success
        repl.run(pattern)
      else
        repl.rerun
      end
    end

    def result
      if repl.success?
        if @last_run == :failure
          @last_run = :success
          if all_on_pass
            run_all
            result
          end
        end
        Notifier.notify('Success')
      else
        @last_run = :failure
        Notifier.notify('Failure', image: :failed)
      end
    end

    def run_on_additions paths
      unless paths.all? { |path| targets.include? path }
        @targets += paths
        repl.init(top_spec)
      end
    end

    def run_on_modifications paths
      case paths.first
      when /(.+)Spec\.l?hs$/, /(.+)\.l?hs$/
        repl.reload
        run($1.strip_lowercase_directories.path_to_module_name)
        result
      end
    end
  end
end
