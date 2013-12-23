1.3.0
=====

  * Ignore user cabal package database if sandbox is found
  * Catch CPP failures (previously did n't work because of the typo)
  * Add `focus_on_fail` option

1.2.0
=====

  * Catch GHCI runtime linker failures
  * Separate runtime and compile time failures for `--rerun` to work better
  * Fix ignored spec results if spec was run directly from guard repl

1.1.0
=====

  * Support for `guard init haskell`
