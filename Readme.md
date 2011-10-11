# modul8 - modularize your web applications

modul8 is a modularity enforcing code packager and analyzer for JavaScript web applications.
Like a normal code packager, it will dynamically pull in dependencies from multiple paths and compile and combine the dynamically ordered set of dependencies
into a single browser compatible JavaScript file.

Additionally, modul8 encourages best practises such as loose coupling and code sharing between the server and the client.
Sharing is done by allowing several _require domains_ on the client, represented by different paths on the server.
Code from the app domain can pull in dependencies from any domains, whereas each other domain
consists of standalone code referencable by both. What modules that are somehow pulled in from the app domain is loggable as
an npm like dependency **tree** (this structure is enforced) - so that no surprise bloating affects your JavaScript file.

modul8 encapsulates all the exports objects in a closure where only `require()` and a couple of extra functions are defined.
Because the export container can only be accessed through functions with access to that closure,
you cannot have invisible dependencies in your application - even globals like `jQuery` and `$` can be deleted and integrated easily into the require system.

The extra functions that can touch the exports container are debug functions (for console read only access), and some hook-in functions to allow live
extentions to parts of the exports container.
These functions can be used from the server to attach dynamic data to the `data` domain,
or live from the client to attach results of third-party script loaders to the `external` domain.

For more information consult the [extensive documentation](http://clux.github.com/modul8).

## Features

 - client side require
 - automatically share code between the server and the client
 - dynamic resolution and compilation of dependencies server-side
 - compiles CommonJS compatible JavaScript or CoffeeScript
 - low footprint - only ~100 lines prepended to output source
 - enforces modularity best practices
 - dependency tree loggable in `npm list` style
 - no need to ever maintain include lists or order
 - inject requireable data from the server directly
 - inject requireable data live from the client
 - minimizes global usage, encapsulates exports in closures
 - ideal for single page web applications, 1/2 HTTP request to get all code

## Installation

via npm: `npm install modul8`

or for the development version `git clone git://github.com/clux/modul8`

## Usage
Basic use only needs one data domain, and an entry point (here `app.js` - assumed to lie on the domain `add()`ed first).

    var modul8 = require('modul8');
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

modul8 allows data to be _safely_ attached to the private exports container both from the server and live on the client.
This allows for easy transportation of dynamically generated data from the server to the client by passing it through `modul8.data()`.
Client side manipulation allows integration with third party asynchronous script loaders by passing results
to `require('M8::external')`.

The data API is particularly useful for web applications:

 - Want your templates compiled and passed down to the client in the JavaScript? Just write a parser plugin and hook it up.
 - Or, want a versioning system for your templates so that the newest can be stored in LocalStorage? Send the versions down.
 - Want mongoose logic on the client? Let modul8 pull the data down through such plugins.


## Learn more
The [docs](http://clux.github.com/modul8) should contain everything you could ever want to know about modul8 and probably more.
Read it, try it out, and give feedback if you like or hate it / parts of it, or if you want to contribute.

modul8 is a relatively fresh project of mine. It was crafted out of necessity, but it has grown into something larger.
I hope it will be useful.

## Running Tests

Install development dependencies:

    npm install

Then:

    expresso verify

Actively tested with node:

  - 0.4.10
