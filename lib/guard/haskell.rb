require 'bundler/setup'
require 'guard/plugin'
require 'set'

class ::String
  def to_module_name
    self.split('/').drop_while{|x| /^[[:lower:]]/.match(x)}.join('.')
  end
end

module ::Guard
  class Haskell < ::Guard::Plugin

    require 'guard/haskell/repl'

    attr_accessor :opts, :repl
    attr_reader :targets, :last_run

    Options = ::Struct.new(
      :cabal_target,
      :repl_options,
      :all_on_start,
      :all_on_pass,
      :focus_on_fail,
    )

    DEFAULT_OPTIONS = {
      cabal_target:  "spec",
      repl_options:  [],
      all_on_start:  false,
      all_on_pass:   false,
      focus_on_fail: true,
    }

    def initialize(user_options = {})
      super
      self.opts = Options.new(*DEFAULT_OPTIONS.merge(user_options).values)
    end

    def start
      @last_run = :success # try to prove it wasn't :-)
      self.repl = Repl.new(opts.cabal_target, opts.repl_options)
      throw :cabal_repl_initialization_has_failed if self.repl.status == :loading_failure
      success?

      @targets = ::Set.new(::Dir.glob("**/*.{hs,lhs}"))

      if opts.all_on_start
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
      repl.reload_and_run_matching
      success?
    end

    def run(pattern)
      if opts.focus_on_fail and last_run == :runtime_failure
        repl.reload_and_rerun
      else
        repl.reload_and_run_matching(pattern)
      end
      success?
    end

    def success?
      case [last_run, repl.status]
      when [:runtime_failure, :success],
          [:compile_failure, :success]
        @last_run = :success
        Notifier.notify('Success')
        if opts.all_on_pass
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

    def run_on_additions(paths)
      unless paths.all? { |path| targets.include?(path) }
        @targets += paths
        reload
      end
    end

    def run_on_modifications(paths)
      case paths.first
      when /(.+)Spec\.l?hs$/, /(.+)\.l?hs$/ then run($1.to_module_name)
      when /\.cabal$/ then reload
      end
    end
  end
end
