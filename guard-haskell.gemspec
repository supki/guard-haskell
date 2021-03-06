# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'guard/haskell/version'

Gem::Specification.new do |s|
  s.name = 'guard-haskell'
  s.version = Guard::HaskellVersion::VERSION
  s.author = 'Matvey Aksenov'
  s.email = 'matvey.aksenov@gmail.com'
  s.summary = 'Guard gem for Haskell'
  s.description = 'Guard::Haskell automatically runs your specs'
  s.homepage = 'https://github.com/supki/guard-haskell#readme'
  s.license = 'BSD2'

  s.files = `git ls-files`.split($/)
  s.test_files = s.files.grep(%r{^spec/})
  s.require_path = 'lib'

  s.add_dependency 'guard', '~> 2.12'

  s.add_development_dependency 'bundler', '>= 1.3.5'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'fakefs', '~> 0.6'
end
