guard-haskell
=============

Guard::Haskell automatically runs your specs

# Guardfile example

Typical haskell project:

```ruby
guard :haskell do
  watch(%r{.*\.cabal$})
  watch(%r{test/Spec.hs$})
  watch(%r{test/.+Spec.l?hs$})
  watch(%r{src/.+.l?hs$})
  watch(%r{^.hspec-results$})
end
```

Some customizations:

```ruby
guard :haskell, sources: "lib", all_on_pass: true do
  watch(%r{.*\.cabal$})
  watch(%r{test/Spec.hs$})
  watch(%r{test/.+Spec.l?hs$})
  watch(%r{lib/.+.l?hs$})
  watch(%r{^.hspec-results$})
end
```

# Options

## `all_on_start`

Run all specs on start, (default: `false`)

## `all_on_pass`

Run all specs after previously failing spec passes, (default: `false`)

## `dot_ghci`

Path to `.ghci` script to load, can also be `:ignore` to ignore system-wide `.ghci` script (default: `nil`)

## `root_spec`

Root spec location, (default: `test/Spec.hs`)
