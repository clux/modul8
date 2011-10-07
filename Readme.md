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

 modul8 encapsulates all the exports objects in a closure where only `require()` and a couple of clever extra functions are defined.
 Because the export container can only be accessed through functions with access to that closure,
 this means you can't have invisible dependencies in your application (outside global libraries - which also can be easily integrated)
 The extra functions that can touch the exports are debug functions (for console read only access), and some hook-in functions to allow live
 extensions of domains (inject objects/fns directly onto certain domains).

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
  - Application does not rely on global variables (although it exports one for the console).
  - Allows easy integration of CommonJS incompatible libraries to the require system
  - ideal for single page web applications - only 1 or 2 HTTP requests to get all your code + possibly templates

## Installation

via npm: `npm install modul8`

## Usage
Basic use only needs one data domain, and an entry point (here `app.js` - assumed to lie on the domain `add()`ed first).

    modul8('app.js')
      .domains()
        .add('app', '/app/client/')
        .add('shared', '/app/shared/')
      .compile('./out.js')

 This adds two domains, and compiles all files from the two domains that have been explicitly `require()`d to `./out.js`.
 Every `require()` call is tracked and the resulting dependency tree is loggable. Cross domain `require()`s are namespaced
 C++ style, i.e. `require('shared::validation')` will look for a .js then .coffee file named validation on the shared domain.

 Non-application domains like _shared_ can potentially (if they are domain-isolated) be used on the server as well, To
 ensure this, any `require()` calls should be relative to preserve server side compatibility. As an example,
 a same-origin include of shared::defs should be done with a **./** prefix:  `require('./defs')`.


 A typical dependency tree output will look like this.

    app::app
    ├──┬app::controllers/user
    │  └───app::models/user
    ├──┬app::controllers/entries
    │  └───app::models/entry
    └──┬shared::validation
       └───shared::defs


## Injecting Data

 modul8 allows data to be attached to the private exports tree both from the server and live on the client.
 This allows for easy transportation of dynamically generated data from the server to the client by passing it through `modul8.data()`,
 and it allows integration with third party asynchronous script loaders by passing results to `require('M8::external')` on the client.

 The data API is particularly useful for web applications:

  - Want your templates compiled and passed down to the client in the JavaScript? Just write a parser plugin and hook it up.
  - Want mongoose logic on the client? Let modul8 pull the data down through such plugins.


## Learn more
 The API docs contain everything you could ever want to know about modul8 and more. Read it, try it out, and give feedback if you liked or hated it / parts of it.

 modul8 is a relatively fresh project of mine. It was crafted out of necessity, but it has grown into something larger. I hope it will be useful.
