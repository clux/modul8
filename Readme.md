# modul8 - modularize your web applications

 modul8 is a modularity enforcing code packager for JavaScript web applications.
 Like a normal code packager, it will dynamically pull in dependencies from multiple paths and compile and combine the dynamically ordered set of dependencies
 into a single browser compatible JavaScript file. This means your application can consist entirely of JavaScript/CoffeeScript CommonJS modules, and your code
 can be used verbatim on the server as long as it does not reference browser only dependencies like the DOM.

 Additionally, modul8 encourages some of the best practices of software development by allowing you to share code by between the client and server.
 It does so by allowing several _require domains_ on the client, represented by different paths on the server.
 Code from the main application domain can pull in dependencies from any of these domains, whereas each extra domain
 will reside on the server as standalone code referencable by both. What modules from all domains are pulled in will
 be shown in an npm like dependency tree.

 modul8 encapsulates each modules exports away in a hidden stash. This stash can only be required through `require()` and a couple of
 clever hook-in functions to allow for asynchronous load extensions, data domain extensions (inject objects/fns directly on a separate domain),
 and some pretty nifty debug functionality.

 For more information consult the extensive documentation.

## Features
  - client-side require without extra callbacks
  - compiles CommonJS compatible JavaScript or CoffeeScript
  - compilation of application code is dynamic and based only on the entry point and its dependency tree
  - non-CommonJS compatible files (:=libraries) can be optionally listed in the order they should be included (before the rest of the app)
  - CommonJS modules can work in both NodeJS and the browser if they do not reference external dependencies
  - low footprint - only ~70 lines pre-pended to the compiled file (no extra file to include - no assumed dependencies)
  - enforces modularity best practices (no circular dependencies allowed from the start, and helps analyse your require tree)
  - require tree is displayed in the style of `npm list`
  - only pulls in what is explicitly required - no need to ever manipulate your include list
  - application specific data can be pulled in during the compilation process, to be requireable in the browser.
  - Application does not rely on global variables (although it exports some for the console).
  - ideal for single page web applications - only 1 or 2 HTTP requests to get all your code + possibly templates

## Installation

via npm: `npm install modul8`

## Usage
Basic use only needs one data domain, and an entry point (`app.js`, assumed to lie on the domain `add()`ed first)
```js
modul8('app.js')
  .domains()
    .add('app', '/app/client/')
    .add('shared', '/app/shared/')
  .compile('dm.js')
```
##

## Notes on the data domain
This is the main entry point for plugins. Here are some appropriate things that it is useful for:

- 1a. exporting all your templates to data::templates.
- 1b. exporting template versions to data::versions to make sure cached templates are up to date (if not, you could $.get them as you needed)
- 2.  exporting model structure to data::models to avoid duplicating mongoose (say) logic
- 3.  exporting applications default options for drop downs to data::defaults

All you have to do to use this is either directly attach the data you have, or build a simple parser to make things browser friendly.



## Comments and Feedback
modul8 is still a relatively fresh project of mine. Feel free to give me traditional github feedback or help out.
Modul is Norwegian for module in case people do not understand 1337.
