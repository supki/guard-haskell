require 'rspec'
require 'guard/haskell'

RSpec.configure do |c|
  c.color = true
  c.order = :random
  c.expect_with :rspec do |r|
    r.syntax = :expect
  end
  c.warnings = true
end
