# Extensible CommonJS in the browser

Browser side `require()` - automatically compiled and analyzed.

Write a `main.js` as the entry point
````javascript
var determine = require('./determine');
console.log(determine.isCool(['clux', 'pibbz']));
````
then a the required module `determine.coffee` (or .js if you prefer)
````coffeescript
cool = require('shared::cool')
exports.isCool = (input) -> input.filter(cool)
````
and finally its required `cool` module on the `shared` domain
````javascript
module.exports = function(name){
  return (name === 'clux');
};
````

To compile these files invoke `modul8` as follows
````javascript
modul8('main.js')
  .domains()
    .add('app', path+'/client/')
    .add('shared', path+'/shared/')
  .compile('./out.js')
````

This will construct an `out.js` in your execution path and the generated dependency tree will look as follows:

    app::main
    └──┬app::determine
       └───shared::cool


## Quick Overview

modul8 is an extensible CommonJS code packager and analyzer for JavaScript and CoffeeScript web applications.
Applications are recursively analyzed for dependencies from an entry point and will pull in + compile just what is needed.

Code can be shared with the server by isolating modules/libraries in  shared _domains_. This means stand alone logic
can exist on the server and be referenced via a normal `require(path+'module')`, but also be referenced via `require('shared::module')` on the client.

To give you full overview and control over what code is pulled in, modul8 automatically generates a depedency tree. This allows
fast analysis and identification of extraneous links, and it is for me, one of the most important tools for refactoring.
Note that the depedency tree is truly a tree because we enforce a strict no circular dependencies rule.

modul8 supports live extensions of certain exports containers via third party script loaders, and server side data injection at compile time.
No need for hacks.

Lastly, modul8 aims to eliminate most global variables from your code. It does so by the following approaches

 - Encapsulate all exported data in the closure inhabited by `require()`
 - Incorporate globally available libraries into the module system via automatic arbiters using `delete`

For more information consult the [documentation](http://clux.github.com/modul8/api.html).

## Feature List

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
 - exports containers encapsulates in closures
 - incorporates globals into the require system intelligently
 - ideal for single page web applications, 1/2 HTTP request to get all code

## Installation

via npm: `$ npm install modul8`

or for the development version `$ git clone git://github.com/clux/modul8`

## Usage
Basic use only needs one data domain, and an entry point. The entry point is assumed to lie on the first domain (i.e. /app/client/app.js must exist)
````javascript
var modul8 = require('modul8');
modul8('app.js')
  .domains()
    .add('app', path+'/client/')
    .add('shared', path+'/shared/')
  .compile('./out.js')
````
This compiles everything referenced explicitly thorugh `app.js` to the single browser compatible `out.js`.

Every `require()` call is tracked and the resulting dependency tree is loggable. Cross domain `require()`s are namespaced
C++ style: `require('shared::validation')` will look for a `.js` then `.coffee` file named `validation` on the shared domain.

To ensure that the `shared` domain here can work on the server and the client, any `require()` calls
should be relative and not pull in anything outside that folder.
As an example, a same-origin include of shared::defs should be done with a **./** prefix:  `require('./defs')`.

A typical dependency tree output will look like this.

    app::app
    ├──┬app::controllers/user
    │  └───app::models/user
    ├──┬app::controllers/entries
    │  └───app::models/entry
    └──┬shared::validation
    │  └───shared::defs
    └───M8::jQuery


## Injecting Data

Data can by incjected at compile time from the server by specifying keys and pull functions.
````javascript
modul8('app.js')
  .data()
    .add('models', myParser) //myParser is a function returning a string
````javascript

The data API is particularly useful for web applications:

 - Want your templates compiled and passed down to the client in the JavaScript? Just write a parser plugin and hook it up.
 - Or, want a versioning system for your templates so that the newest can be stored in LocalStorage? Send the versions down.
 - Want mongoose logic on the client? Let modul8 pull the data down through such plugins.

The data domain can also be safely extended live on the client using the extender function available in `require('M8::data')`.

Code loaded in via third party asynchronous script loaders can be attached to the `external` domain live via the
extender function available in `require('M8::external')`.

These functions can be used, and any code on these domains can be referenced without messing up the code analysis at compile time.
They can, however, show up in the dependency tree if desirable.

## Learn more
The [docs](http://clux.github.com/modul8) should contain everything you could ever want to know about modul8 and probably more.
Read it, try it out, and give feedback if you like or hate it / parts of it, or if you want to contribute.

modul8 is a relatively fresh project of mine. It was crafted out of necessity, but it has grown into something larger.
I hope it will be useful.

## Running Tests

Install development dependencies:

    $ npm install

Then run expresso

    $ expresso

Actively tested with node:

  - 0.4.10
