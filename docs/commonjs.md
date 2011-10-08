## How a Module System Works

This is going to contain more advanced background about what general module systems do, and what
distinguishes modul8.

### CommonJS parsing
#### Basics
A CommonJS parser must turn this:

    var private = 5;
    var b = require('b');
    exports.publicFn = function(){
      console.log(private);
    }

into

    var module = {}
    (function(require, module, exports){
      var private = 5;
      var b = require('b');
      exports.publicFn = function(){
        console.log(private);
      }
    })(makeRequire(location), module, stash[location])
    if (module.exports) {
      delete stash[location];
      stash[location] = module.exports;
    }

where `location` is a unique identifier passed down from the compiler to indicate where the module lives, so that `require()` can later retrieve it.
The `makeRequire()` factory must be able to construct specifically crafted `require()` functions for given locations.
`stash` will be a pre-defined object on which all modules are exported.  Wrapping up this behaviour inside a function, we can write something like this.

    define(location, function(require, module, exports) {
      var private = 5;
      var b = require('b');
      exports.publicFn = function(){
        console.log(private);
      }
    });

The `makeRequire()` and `define()` functions can cleverly be defined inside a closure with access to `stash`. This way only these functions can access your modules.


If the module system simply created a global namespace for where your modules resided, say, `stash = window.ModuleSystem`, then this would be **bad**.
You could still bypass the system and end up requiring stuff implicitly again.

modul8 encapsulates such a `stash` inside a closure for `require()` and `define()`, so that only these functions + a few carefully constructed functions to
debug export information and require strings.

#### Code Order
Now, a final problem we have glossed over is which order the modules must be included in. The module above requires the module `b`.
What happens if this module has not yet been placed in the document? Syntax error. The least `require()`d modules must be included first.

To solve this problem, you can either give a safe ordering yourself - which will become increasingly difficult as your application grows in size -
or you can resolve `require()` calls recursively to create a dependency tree.

modul8 in particular, does so via excellently simple `detective` module that constructs a full Abstract Syntax Tree before it safely scans for `require()` calls.
Using this `detective` data, a tree structure representing the dependencies can be created. modul8 allows printing of a prettified form of this tree.

    app::main
    ├───app::forms
    ├──┬app::controllers/user
    │  └──┬app::models/user
    │     └───app::forms
    ├──┬app::controllers/entries
    │  └───app::models/entry
    └──┬shared::validation
       └───shared::defs

It is clear that the modules on the edges of this tree must get required first, because they do not depend on anything. And similarly,
the previous level should be safe having included the outmost level. Note here that `app::forms` is needed both by
`app:moduls/user` and `app::main` so it must be included before both. Thus, we only care about a module's outmost level.

If we reduce the tree into an unique array of modules and their (maximum) level numbers, sort this by level numbers descending, then voila:
The modules have been ordered correctly.

#### modul8 Extensions

Whilst maintaining compatibility with the CommonJS spec, we have extended `require()` to ameliorate one common problem.

 - `require()` calls is a simple (clash prone) object property look-up on `stash[reqStr]`

We wanted to be able to share code between the server and the client by essentially having multiple _require paths_.
Since the relation between these paths are lost on the browser, we decided to namespace each each path, or _domain_ which we
refer to them as in modul8. This involves creating an object container directly on `stash`.
We can make a `require()` function that knows which domains to look on by passing in which domain it was found on as
an extra parameter to `define()`.

The result is that, with modul8, we can `require()` files relatively as if it was on a 100% CommonJS environment,
but we could also do cross-domain `require()` by using C++ style namespacing, e.g. calls like `require('shared::helper.js')`
to get access to code on a different domain.

Additionally modul8 also goes a long way trying to integrate globally exported libraries into its require system, and in fact,
removing the global shortcut(s) from your application code. Why we (can and sometimes) want to do this is explained in the [modularity doc](modularity.html), whilst
the feature is fully documented in the [API documentation](api.html).
