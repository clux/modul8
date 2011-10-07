## Modularity

 It here is one thing you learn quickly in programming, it is this:
   - Spaghetti code is awful

 It is awful to read, but it is even worse to modify or maintain.

### What is Bad Code

 Without rehashing the entire internet: tightly coupled code is bad code. Because

   - The more tightly coupled your modules become, the more side-effects alterations will have and the harder it will be to reuse that module.
   - The more different behaviour per module, the harder it is to to maintain that module.
   - The more one type of behaviour is spread out into different modules, the harder it is to find the source of that behaviour.

### What is Good Code

#### What it is not: Bad Code
 If tightly coupled code is bad code, then good code is loosely coupled. A ⇒ B ∴ ¬B ⇒ ¬A.

 In other words, if you factor out your behaviour into small separate units of behaviour, you will have gained maintainability and
 readibility properties for free, and your code will inevitably have less unknown side-effects, leading to more secure code as well.
 It does, however, take certain disipline to constantly police your files for multiple types of behaviour.

 You may shrug and say, well, I'm only going to write this once anyway..

 ..indeed you will. You will write it once and quickly realize you were wrong.
 It would be even better if you wrote it zero times. Trust me.

 There's simply no way around it. The biggest mistake you can make as a learning programmer is to not factor out behaviour as early as possible.
 Always.

### Relation to JavaScript

 JavaScript has no module system.

 Shit.

 We have, on the other hand, got functions. Functions with closures.

    (function(){
      var private = 5;
      window.publicFn = function(){
        console.log(private);
      }
    })();

 This is the commonly employed method of encapsulating and exposing objects and functions that can reference private variable through a closure.
 This works; `var private` is inaccessible outside this anonymous function.

 Unfortunately, this just exposes publicFn to the global window object. This is not ideal, as anything, anywhere can just reference it, leaving
 us none the wiser. True modularity is clearly impossible when things are just lying around freely like this for everyone. It is fragile, and
 it is error prone as conflicts will actually just favour the last script to execute - as JavaScript simply runs top to bottom, attaching its
 exports to window as we go along. Clearly we need something better than this.

#### CommonJS

 There is a way to fix this, but first of all it assumes all modules need to support a stadardised format for exporting of modules.
 CommonJS is a such a standardization. It has very large traction at the moment, particularly driven by server side environments such as NodeJS.

 Its ideas are simple. Each module avoids the normal safety-wrapper, should assume it has a working `require()`, and instead of attaching its exports
 to a global object, it attaches them to an opaque `exports` object. Alternatively, it can replace the `module.exports` object to define all your exports at once.

 By making sure each module is written this way, CommonJS parsers can implement clever trickery on top of it to make this behaviour work.
 For more information on this goto the last section in this document: How a Module System Works

## How a Module System Works

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

    define(location, function(require, module, exports) {
      var private = 5;
      var b = require('b');
      exports.publicFn = function(){
        console.log(private);
      }
    });

 `stash` will be a pre-defined object on which all modules are exported. This can cleverly be defined in the closure where `makeRequire()` and `define()`
 is defined. This means that only these functions can access your modules. If the module system simply created a namespace for where your modules resided,
 say, `stash = window.ModuleSystem`, then this would be **bad**. You could still bypass the system and end up requiring stuff implicitly again.
 modul8 encapsulates `stash` inside a closure for `require()` and `define()`, so that only these functions + a few carefully constructed functions to
 debug export information and require strings.

 Now, a final problem we have glossed over is which order the modules must be included in. The module above requires the module `b`.
 What happens if this module has not yet been placed in the document? Syntax error. The least `require()`d modules must be included first.

 To solve this problem, you can either give a safe ordering yourself - which will become increasingly difficult as your application grows in size -
 or you can resolve `require()` calls recursively to create a dependency tree.

 modul8 in particular, does so via excellently simple `detective` module that constructs a full Abstract Syntax Tree before it safely scans for `require()` calls.
 Using this `detective` data, a tree like the following can be output from `analysis()`.

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
 You have ordered the modules correctly.

#### modul8 Extensions

 Whilst maintaining compatibility with the CommonJS spec, we have extended require to ameliorate one common problem.

 - `require()` calls is a clash prone object property look-up on `stash[reqStr]`

 We wanted to be able to share code between the server and the client by essentially having multiple _require paths_.
 Since the relation between these paths are lost on the browser, we decided to namespace each each path, or _domain_ which we
 refer to them as in modul8. This involves creating an object container directly on `stash`.
 We can make a `require()` function that knows which domains to look on by passing in which domain it was found on as
 an extra parameter to `define()`.

 The result is that, with modul8, we can `require()` files relatively as if it was on a 100% CommonJS environment,
 but we could also do cross-domain `require()` by using C++ style namespacing, e.g. calls like `require('shared::helper.js')`
 to get access to code on a different domain.


### Best Practices

 One of the hardest areas to modularize web applications is the client application domain. If you are using jQuery, you should be particularly familiar with this.
 `$` selector calls spread around, DOM insertion & manipulation code all over the place, the same event style callback functions written for every URL.
 If this is familiar to you, then you should consider looking at a MVC/MVVM framework such as Spine/Backbone/Knockout (this by no means is this an exhaustive list).

 However, for jQuery applications, some things transcends the framework you use to manage your events.
####Decoupling jQuery code
 It is always important to think about the behaviour you are defining. If it is for

 - non-request based DOM interactivity - it is almost always better to write a plugin
 - request based DOM interactivity - you should use controllers/eventmanagers to handle your events and call above plugins.
 - calculations needed before DOM manipulation - you should make a standalone calulation module that should work on its own, and call it at appropriate stages above.

 This way if something breaks, you should be easily able to narrow down the problem to a UI error, a signaling error, or a calculation error. => Debugging becomes up to 3 times easier.

#### Ultimately
 modul8 just tries to facilitate the building of maintainable code.
 To actually build maintainable code, you need to always stay vigilant and remember to:

 - Not blend multiple types of behaviour together in one file.
 - Limit the areas from which you reference global variables.
 - Look for opportunities to move independent code onto different domains.
 - Look for opportunities to refactor code to make bits of it independent.
 - Enforce basic rules of JavaScript modularity: don't try to make circular dependencies work, analyse your require tree. If you are requiring the same library from every file, chances are you are doing something wrong.

 Decouple your code this way and you will save yourself the trouble of later having to learn from your mistakes the hard way.


### Going Further

 Global variable are evil, and should be kept to a minimum. We know this, and this is were a require system really shines, but you are ultimately
 going to depend on a few global variables. Not all libraries are CommonJS compliant, and having jQuery plugins in your require tree (and all its requirements)
 might make things more confusing than by continuing to load jQuery and its plugins in the classical way. Besides, you may want to load it in from a separate CDN anyway.

 Even in such an environment, it is possible rid yourself of the global $ and jQuery symbols without breaking everything.

 We will demonstrate such a solution. Begin by constructing a jQuery.js file on your application domain containing:

    module.exports = window.jQuery;
    delete window.jQuery;
    delete window.$

  This means you can use `$ = require('jQuery')` so everything will be explicitly defined, plus you've deleted the global shortcuts so that you will know when you forgot to require.

 Clearly this as some advantages. By having all requires of jQuery explicitly defined you know exactly what parts of your code depend on. It will not affect
 libraries as these are loaded in before the big `define()` and `stash` attaching scope, but you probably won't care for these anyway. jQuery will show up in your require tree,
 so you will quickly identify what code is actually DOM dependent, and what isn't or shouldn't be.

 Now, modul8 only allows one domain to be DOM dependent (the application domain), so with correct usage - i.e. not stuffing every module in that domain -
 you will not have any big revelations there anyway. If however, you do decide to use this construct - perhaps because you did stuff everything in the application domain -
 you may reap some benefits by being more or less told what files can be moved to another domain. And if you can separate on the domain level, then you are already
 good on your way to resolving spaghetti hell. The rest is tackling correct MVC/MVVM models or other alternative ways of factoring out your spaghetti prone jQuery code.

 Good luck.
