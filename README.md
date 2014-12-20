guard-haskell
=============
[![Gem Version](https://badge.fury.io/rb/guard-haskell.png)](http://badge.fury.io/rb/guard-haskell)
[![Build Status](https://secure.travis-ci.org/supki/guard-haskell.png?branch=master)](http://travis-ci.org/supki/guard-haskell)
[![Dependencies Status](https://gemnasium.com/supki/guard-haskell.png)](https://gemnasium.com/supki/guard-haskell)

`Guard::Haskell` automatically runs your specs

Installation
------------

```shell
% cabal install hspec
% gem install guard-haskell
```

Usage
-----

### How does it work?

For explanation what `guard` is and how to use it, please refer to the [`guard manual`][0]

`guard-haskell` uses [`hspec`][1] to run specs and check results, so it makes
some assumptions about your code organization and style:

  * `hspec` is your testing framework of choice; therefore,

  * [`hspec-discover`][2] organizes your specs

When you type `guard` in the terminal, `guard-haskell` fires up a `cabal repl` instance
to talk to, running (parts of) examples when files are modified.

Setup
-----

For `guard-haskell` to be ready to work we need a test suite (conventionally named "spec")
defined in the cabal file and a Guardfile (you can get one by running `guard init haskell`)

Marcin Gryszko has put together [a sample project][3] where `guard-haskell` is set up and can
be tinkered with.

### Guardfile examples

A typical haskell project:

```ruby
guard :haskell do
  watch(%r{test/.+Spec\.l?hs$})
  watch(%r{src/.+\.l?hs$})
  watch(%r{\.cabal$})
end
```

Another haskell project with a non-standard layout running `cabal repl`:

```ruby
cmd = "cabal repl spec --ghc-options='-ignore-dot-ghci -DTEST'"

guard :haskell, all_on_start: true, cmd: cmd do
  watch(%r{test/.+Spec\.l?hs$})
  watch(%r{lib/.+\.l?hs$})
  watch(%r{bin/.+\.l?hs$})
  watch(%r{\.cabal$})
end
```

Yet another haskell project running `ghci` as a REPL:

```ruby
cmd = "cabal exec ghci test/Spec.hs"

guard :haskell, all_on_start: true, all_on_pass: true, cmd: cmd do
  watch(%r{test/.+Spec\.l?hs$})
  watch(%r{src/.+\.l?hs$})
end
```

#### Gemfile

It's also advised to have a trivial `Gemfile` in the repository for
`bundler exec guard` to be able to pick the correct versions of the dependencies:

```ruby
source "https://rubygems.org"

gem "guard-haskell", "~>2.1"
```

Options
-------

`Guard::Haskell` has a bunch of options:

### `all_on_start`

Run all examples on start (default: `false`).

### `all_on_pass`

Run all examples when a failed spec passes again (default: `false`).

### `focus_on_fail`

Rerun only failed examples until they pass (default: `true`).

### `cmd`

The command to run in the background as a REPL (default: `cabal repl spec`)

Known problems
--------------

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
  [3]: https://github.com/mgryszko/hspec-kickstart
