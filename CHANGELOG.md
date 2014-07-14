2.0.0
=====

  * Switch to `cabal repl` as an inferior shell

  * Fix the bug where the cursor does not reappear on guard shutdown

1.6.0
=====

  * Handle Haskell pre-processor phase failures

  * Handle missing Haskell pre-processor failures

  * More extensible Guardfile template

1.5.0
=====

  * Add `sandbox_glob` option

  * Separate stages for [re]loading and rerunning specs

1.4.0
=====

  * Catch more obscure runtime linker errors

1.3.0
=====

  * Ignore user cabal package database if sandbox is found

  * Catch CPP failures (previously didn't work because of the typo)

  * Add `focus_on_fail` option

1.2.0
=====

  * Catch GHCI runtime linker failures

  * Separate runtime and compile time failures for `--rerun` to work better

  * Fix ignored spec results if spec was run directly from guard repl

1.1.0
=====

  * Support for `guard init haskell`
