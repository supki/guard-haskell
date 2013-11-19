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
end
```

Some customizations:

```ruby
guard :haskell, all_on_pass: true, dot_ghci: :ignore do
  watch(%r{.*\.cabal$})
  watch(%r{test/Spec.hs$})
  watch(%r{test/.+Spec.l?hs$})
  watch(%r{lib/.+.l?hs$})
end
```

# Options

## `all_on_start`

Run root spec on start (default: `false`).

## `all_on_pass`

Run root spec after previously failing spec passes (default: `false`).

## `dot_ghci`

Path to custom `.ghci` script to load, can also be `:ignore`
to ignore system-wide `.ghci` script (default: `nil`).

## `ghci_options`

Pass custom ghci options, for example, `-XCPP` directives like `-DTEST` (default: `[]`).

## `root_spec`

Root spec location (default: `test/Spec.hs`).
