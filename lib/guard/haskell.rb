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

    attr_reader :repl, :top_spec, :ghci_options, :targets, :last_run
    attr_reader :all_on_start, :all_on_pass, :focus_on_fail

    DEFAULT_OPTIONS = {
      top_spec:      "test/Spec.hs",
      ghci_options:  [],
      all_on_start:  false,
      all_on_pass:   false,
      focus_on_fail: true,
    }

    def initialize(user_options = {})
      super

      @last_run      = :success # try to prove it wasn't :-)

      options        = DEFAULT_OPTIONS.merge(user_options)
      @top_spec      = options[:top_spec]
      @ghci_options  = options[:ghci_options]
      @all_on_start  = options[:all_on_start]
      @all_on_pass   = options[:all_on_pass]
      @focus_on_fail = options[:focus_on_fail]

      @repl          = Repl.new
    end

    def start
      repl.start(ghci_options)
      repl.init(top_spec)

      @targets = ::Set.new(::Dir.glob("**/*.{hs,lhs}"))

      if all_on_start
        run_all
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
      success?
    end

    def run pattern
      if focus_on_fail and last_run == :runtime_failure
        repl.rerun
      else
        repl.run(pattern)
      end
      success?
    end

    def success?
      case [last_run, repl.result]
      when [:runtime_failure, :success],
          [:compile_failure, :success]
        @last_run = :success
        Notifier.notify('Success')
        if all_on_pass
          run_all
        end
      when [:success, :success]
        Notifier.notify('Success')
      when [:runtime_failure, :compile_failure],
        [:runtime_failure, :runtime_failure],
        [:compile_failure, :compile_failure]
        Notifier.notify('Failure', image: :failed)
      when [:compile_failure, :runtime_failure],
        [:success, :runtime_failure]
        @last_run = :runtime_failure
        Notifier.notify('Failure', image: :failed)
      when [:success, :compile_failure]
        @last_run = :compile_failure
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
        run($1.strip_lowercase_directories.path_to_module_name)
      end
    end
  end
end
