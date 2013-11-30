guard-haskell
=============
[![Gem Version](https://badge.fury.io/rb/guard-haskell.png)](http://badge.fury.io/rb/guard-haskell)
[![Build Status](https://secure.travis-ci.org/supki/guard-haskell.png?branch=master)](http://travis-ci.org/supki/guard-haskell)
[![Dependencies Status](https://gemnasium.com/supki/guard-haskell.png)](https://gemnasium.com/supki/guard-haskell)


`Guard::Haskell` automatically runs your specs

# Install

```shell
% cabal install hspec
% gem install guard-haskell
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
  watch(%r{test/.+Spec\.l?hs$})
  watch(%r{src/.+\.l?hs$})
end
```

Customized haskell project:

```ruby
guard :haskell, all_on_pass: true, ghci_options: ["-DTEST"] do
  watch(%r{test/.+Spec\.l?hs$})
  watch(%r{lib/.+\.l?hs$})
  watch(%r{bin/.+\.l?hs$})
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

## Known problems

### App you test uses the GHC API

Unfortunately, testing such applications with `guard-haskell` is basically impossible
because `ghci` uses `GHC API` too.  Sooner or later you will see something like:

```
GHCi runtime linker: fatal error: I found a duplicate definition for symbol
   HUnitzm1zi2zi5zi2_TestziHUnitziBase_zdwzdcshowsPrec_slow
whilst processing object file
   /home/maksenov/.cabal/lib/HUnit-1.2.5.2/ghc-7.6.2/HSHUnit-1.2.5.2.o
This could be caused by:
   * Loading two different object files which export the same symbol
   * Specifying the same object file twice on the GHCi command line
   * An incorrect `package.conf' entry, causing some object to be
     loaded twice.
GHCi cannot safely continue in this situation.  Exiting now.  Sorry.
```

Fragile concurrent access is a known limitation of the `GHC API`, which hopefully will be eventually fixed.

  [0]: https://github.com/guard/guard#readme
  [1]: http://hspec.github.io/
  [2]: http://hspec.github.io/hspec-discover.html
