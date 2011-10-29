# Extensible CommonJS in the browser
## Intro

Write a `main.js` as the application entry point

````javascript
var determine = require('./determine');
console.log(determine.isCool(['clux', 'lava']));
````

the required module `determine.coffee` (or .js if you prefer)

````coffeescript
cool = require('shared::cool') # <- cross-domain require
exports.isCool = (input) -> input.filter(cool)
````

and finally its required `cool.js` on the `shared` domain

````javascript
module.exports = function(name){
  return (name === 'clux');
};
````

To compile these files invoke `modul8()` and chain on options

````javascript
modul8('./client/main.js')
  .domains({'shared': './shared/'})
  .compile('./out.js');
````

This will construct a single, browser compatible `out.js` in your execution path and the generated dependency tree will look as follows:

    app::main
    └──┬app::determine
       └───shared::cool

The shared code is independent of the application and can be reused on the server.

Compilation can also be performed via the command line interface by typing

````bash
$ modul8 client/main.js -p shared:shared/ > out.js
````

from the path containing fhe shared/ and client/ folders.

To load the file from your site stick a script tag in your HTML:

````html
<script src="/out.js"></script>
````

## Quick Overview

modul8 is an extensible CommonJS code packager and analyzer for JavaScript and CoffeeScript web applications.
Applications are recursively analyzed for dependencies from an entry point and will pull in + compile just what is needed.

Code can be shared with the server by isolating modules/libraries in  shared _domains_. This means stand alone logic
can exist on the server and be referenced via a normal `require(dir+'module')`, but also be referenced via `require('shared::module')` on the client.

To give you full overview and control over what code is pulled in, modul8 automatically generates a depedency tree. This allows
fast analysis and identification of extraneous links, and becomes a very important tool for refactoring.
Note that the depedency tree is truly a tree because we enforce a strict no circular dependencies rule - allowing these are just bad for modularity.

modul8 supports live extensions of certain exports containers via third party script loaders, and server side data injection at compile time.

Lastly, modul8 aims to eliminate most global variables from your code. It does so using the following approaches

 - Encapsulate all exported data in the closure inhabited by `require()`
 - Incorporate globally available libraries into the module system via automatic arbiters

For more information consult the [api docs](http://clux.github.com/modul8/docs/api.html).

## Features

 - (extensible) client side require
 - simple code sharing between the server and the client
 - dynamic resolution and compilation of dependencies server-side
 - compiles CommonJS compatible JavaScript, CoffeeScript or hooked in AltJS
 - low footprint - ~1kB (minified/gzipped) output size inflation
 - enforces modularity best practices and logs an npm style dependency tree
 - injecd require data dynamically from the server or live from the client
 - no need to ever maintain include lists or order
 - minimizes global usage, encapsulates exports in closures, absorbs library globals
 - only rebuilds on repeat calls if necessary (files modified || options changed)
 - ideal for single page web applications, 1 or 2 HTTP request to get all code

## Installation

Install the library:

````bash
$ npm install modul8
````

Install the command line tool:

````bash
$ npm install -g modul8
````

Download the development version:

````bash
$ git clone git://github.com/clux/modul8
````

## Usage
Basic use only only the path to the entry point and an output.

````javascript
modul8('./client/app.js').compile('./out.js');
````

This compiles everything referenced explicitly through `app.js` to the single browser compatible `out.js`.


Every `require()` call is tracked and the resulting dependency tree is loggable. Cross domain `require()`s are namespaced
C++ style: `require('shared::validation')` will look for a `.js` then `.coffee` file named `validation` on the shared domain.
This extra domain must be configured using a chained `.domains()` call:

````javascript
modul8('./client/app.js')
  .domains({'shared': './shared/'})
  .compile('./out.js');
````

To ensure that the `shared` domain here can work on the server and the client, any `require()` calls
should be relative and not pull in anything outside that folder.
As an example, a same-origin include of shared::defs should be done with a **./** prefix:  `require('./defs')`.

The dependency analyzer will typically output something like this if configured

    app::app
    ├──┬app::controllers/user
    │  └───app::models/user
    ├──┬app::controllers/entries
    │  └───app::models/entry
    ├──┬shared::validation
    │  └───shared::defs
    └───M8::jQuery

`jQuery` can be seemlessly integrated (and will show up in the dependency tree as above) by using `.arbiters()`

## Injecting Data

Data can by injected at compile time from the server by specifying keys and pull functions.

````javascript
modul8('./client/app.js')
  .data({'models': myParser}) //myParser is a function returning a string
  .compile('./out.js');
````

The data API is particularly useful for web applications:

 - Want your templates compiled and passed down to the client in the JavaScript? Just write a parser plugin and hook it up.
 - Or, want a versioning system for your templates so that the newest can be stored in LocalStorage? Send the versions down.
 - Want simplified mongoose schemas on the client? Parse your models and send them down.

The data domain can also be safely extended live on the client using the extender function available in `require('M8::data')`.

Code loaded in via third party asynchronous script loaders can be attached to the `external` domain live via the
extender function available in `require('M8::external')`.

These functions can be used, and any code on these domains can be referenced without messing up the code analysis at compile time.
They can, however, show up in the dependency tree if desirable.

## Learn more
The [full documentation site](http://clux.github.com/modul8) should contain everything you could ever want to know about modul8 and probably more.
Read it, try it out, and give feedback if you like or hate it / parts of it, or if you want to contribute.

modul8 is a relatively fresh project of mine. It was crafted out of necessity, but it has grown into something larger.
I hope it will be useful.

## Running Tests

Install development dependencies:

````bash
$ npm install
````

Then run expresso

````bash
$ expresso
````

Actively tested with node:

  - 0.4.10

## License

MIT Licensed - See LICENSE file for details
