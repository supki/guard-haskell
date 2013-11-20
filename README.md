guard-haskell
=============
[![Build Status](https://secure.travis-ci.org/supki/guard-haskell.png?branch=master)](http://travis-ci.org/supki/guard-haskell)

`Guard::Haskell` automatically runs your specs

# Install

```shell
% cabal install hspec
% gem install guard
% git clone https://github.com/supki/guard-haskell
% cd guard-haskell
% gem build guard-haskell.gemspec
% gem install guard-haskell-0.1.0.0.gem
```

# Usage

## How does it work?

For explanation what `guard` is and how to use it, please refer to the [`guard manual`][0]

`guard-haskell` uses [`hspec`][1] to run specs and check their success, so it makes some assumptions about your code style:

  * `hspec` is your testing framework and

  * [`hspec-discover`][2] (or similar tool) organizes your specs,
  i.e. there is a "top" spec (usually `test/Spec.hs`) that pulls others in

When you type in `guard`, `guard-haskell` fires up an `ghci` instance which it talks to, reloading
and rerunning (parts of) "top" spec on files modifications.

## Guardfile examples

Typical haskell project:

```ruby
guard :haskell do
  watch(%r{.*\.cabal$})
  watch(%r{test/.+Spec.l?hs$})
  watch(%r{src/.+.l?hs$})
end
```

Customized haskell project:

```ruby
guard :haskell, all_on_pass: true, ghci_options: ["-DTEST"] do
  watch(%r{.*\.cabal$})
  watch(%r{test/.+Spec.l?hs$})
  watch(%r{lib/.+.l?hs$})
  watch(%r{bin/.+.l?hs$})
end
```

## Options

`Guard::Haskell` has a bunch of options:

### `all_on_start`

Run all specs on start (default: `false`).

### `all_on_pass`

Run all specs after previously failing spec _finally_ passes (default: `false`).

### `ghci_options`

Pass custom ghci options, for example, `-XCPP` directives like `-DTEST` (default: `[]`).

### `top_spec`

"Top" spec location (default: `test/Spec.hs`).

  [0]: https://github.com/guard/guard#readme
  [1]: http://hspec.github.io/
  [2]: http://hspec.github.io/hspec-discover.html
