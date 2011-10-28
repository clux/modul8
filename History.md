FUTURE / 2011-??-??
==================
  TODO:
  * Provide more levels of logging on the client

0.7.0 / 2011-10-28
==================
  * Command Line Interface - documented under CLI
  * recompiling now happens if settings were changed as well (bug)
  * move underscore copied snippets out of src - require underscore instead
  * domloader API simplified to work with CLI, also now defaults to anonymous fn rather than jQuery domloader
  * `.compile()` will not recompile the file if no changes have been made to previously included files
  * modified test suite included to ensure above works
  * arbiter test suite included
  * `.analysis.hide(domain)` was not working correctly
  * server side resolver was ignoring resource names on other domains when clashing with arbiters

0.6.1 / 2011-10-18
==================
  * `.arbiters()` allows an object to be inserted at once
  * Biggish documentation improvements

0.6.0 / 2011-10-17
==================
  * `require('folder')` will look for a `folder` file then an `index` file under `folder/`
  * `require('folder/') will look for an `index` file under `folder/`
  * `require()` collision priority updated
  *  collision test suite included
  * `.compile()` will throw error if multiple files with same unique identifier (extensionless dom::filename) are attempted included - but helpfully after `.analysis()`
  * `.register('.ext', extCompiler)` will allow bundling of other altJs languages

0.5.0 / 2011-10-14
==================
  * `.data()` and `.domains()` now both can take objects directly instead of adding
  * `.libraries()` can be specified without all the 3 sub-calls, just specify all htree parameters direcly on this instead
  * `.analysis().ignore(domain)` can be used to supress certain domains from printed depedency tree (perhaps good to hide `external` or `M8`)

0.4.0 / 2011-10-13
==================
  * Better documentation + examples bundled
  * Fixed a collision bug causing same folder structure to be ignored by the bundler in one branch
  * Fixed a bug in the circular checker not correctly matching + no longer hanging on cirtain curculars
  * Loggability of requires on the client works as in the documentation
  * `M8.domains()` now returns a list of strings instead of console.logging it
  * 'M8.data()' and 'M8.external()' does not return
  * Configured a basic test environment using zombiejs
  * Safed up API against subclass calls against on superclass.

0.3.0 / 2011-10-08
==================

  * Full documentation
  * `arbiters()` added

==================
  modul8 was never advertised before this point
==================

0.2.2 / 2011-10-04
==================

  * Fix a define and a require bug

0.2.0 / 2011-10-03
==================

  * Initial commit on the new name
  * Style bundling factored out to a separate module

0.1.0 / 2011-09-20
==================

  * Initial commit on brownie
