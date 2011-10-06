## Modularity

 It here is one thing you learn quickly in programming, it is this:
   - Spaghetti code is awful

 It is awful to read, but it is even worse to modify or maintain.

### What is Bad Code

 There are numerous papers and articles on this around, but I'll quickly 'define' spaghetti for completeness.

   - The more tightly coupled your modules become, the more side-effects alterations will have.
   - The more different behaviour per module, the harder it is to to maintain that module.
   - The more one type of behaviour is spread out into different modules unrelated, the harder it is to find the source of that behaviour.

### What is Good Code

#### What it is not: Bad Code
 By keeping your modules as loosely coupled as possible, you get all these properties of maintainability and readibility for free.
 You may shrug and say, well, I'm only going to write this once.

 ..indeed you will. It would be even better if you wrote it zero times.

 Ahem. Not only do you get these properties: more modular code is also more secure code.
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

 There is a way to fix this, but it assumes all modules need to support a stadardised format for exporting of modules.

#### CommonJS

 CommonJS is a such a standardization. It has very large traction at the moment, particularly driven by server side environments such as NodeJS.

 Its ideas are simple. Each module avoids the normal safety-wrapper and instead of attaching its exports
 to a global object, it attaches it to an opaque `exports` object. Alternatively, it can replace the `module.exports` object to define all your exports at once.
 Additionally, `require()` should work and know where you are to resolve relative requires.

 In other words, a CommonJS parser must turn this:

    var private = 5;
    exports.publicFn = function(){
      console.log(private);
    }

 into

    var module = {}
    var exportLocation = stash[location]
    (function(require, module, exports){
      var private = 5;
      exports.publicFn = function(){
        console.log(private);
      }
    })(makeRequire(location), module, exportLocation)
    if (module.exports) {
      delete stash[name];
      stash[name] = module.exports;
    }

 where `location` is a unique identifier passed down from the compiler to indicate where the module lives, so that `require()` can later retrieve it.
 The `makeRequire()` factory must be able to construct specifically crafted `require()` functions a location. Now if we can wrap all that behaviour
 up inside a function, we have got what essentially all module systems have, allowing the compiler to simply say something like

     define(location, """
      var private = 5;
      exports.publicFn = function(){
        console.log(private);
      }"""")

 If the appropriate `define()` function has been defined. If we do this for each module, then this will attach everything to `stash` and life will be good
 for what comes after it.

 Note that we said for what comes after it, for we have glossed over the problem with figuring out which order the modules must be included in. Consider if the module
 above `require()`d a submodule, but submodule has not yet been placed in the document. Syntax error. The least `require()`d modules must therefore get included
 first.

#### Module8
 It is somewhere around this point that Module8 diverges from typical CommonJS compiler implementation. In particular, the divergence is how to solve
 the following three problems.

 - 1. `require()` calls is up to this point essentially an object property look-up on `stash[reqStr]`
 - 2. The order of `require()`d modules must be resolved somehow.
 - 3. `stash` is still a global object, so our goals of disabling implicit requires are somewhat diminished.

 Modul8 solves these in the following ways.

  1. Is a readability and encapsulation issue. We ameliorate this by creating a sub-object of `stash` for each domain.
  This means the current domain (which will have to get passed into define and from that down to makeRequire) always gets scanned first,
  and `require()`s can specify a domain prefix in the style of a C++ namespace.

  2. Modul8 does a recursive scan of the all the modules `require()`d from the point of entry on the application domain. It is able to do so via the
  excellently simple node-detective that constructs a full Abstract Syntax Tree it scans for `require()` calls.

  3. Modul8 defines a new scope from the first definition of `var stash = {}` all around all the `define()` calls on the ordered set of modules.
  Since `require()` has access to this object from a closure, all our exports are completely hidden away.

  Additionally, for safety and testing, `require()` and `inspect()` is exported to a safe location on the global object so that console testers can inspect `stash` without it
  itself being global.


 That, in essence, is the `require()` system built up in Modul8.

### Debugging

 If you have wrongly spelt your `require()` references, you might not get a very useful error. To see where your object has actually been exported, you may find it useful to
 log the specified domain with the globally namespaced `M8.inspect(domain)` method - which can be referenced in the console without access to the closure of our `stash`.

 There is additionally a console friendly require version globally available at `M8.require()`.

### Best Practices

 One of the hardest areas to modularize web applications is the client application domain. If you are using jQuery, you should be particularly familiar with this.
 `$` selector calls spread around at random places, DOM insertion & manipulation code all over the place, the event style callback functions written for every URL.
 If this is familiar to you, then you should consider looking at a MVC/MVVM framework such as Spine/Backbone/Knockout (by no means is this an exhaustive list).

 However, for jQuery applications, some things transcends the framework you use to manage your events.
####Decoupling jQuery code
 It is alwyas important to think about the behaviour you are defining. If it is for

 - non-request based DOM interactivity - it is almost always better to write a plugin
 - request based DOM interactivity - you should use controllers/eventmanagers to handle your events and call above plugins.
 - calculations needed before DOM manipulation - you should make a standalone calulation module that should work on its own, and call it at appropriate stages above.

 This way if something breaks, you should be easily able to narrow down the problem to a UI error, a signaling error, or a calculation error. => Debugging becomes up to 3 times easier.

#### Ultimately
 Modul8 just tries to facilitate the building of maintainable code.
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

 Now, Modul8 only allows one domain to be DOM dependent (the application domain), so with correct usage - i.e. not stuffing every module in that domain -
 you will not have any big revelations there anyway. If however, you do decide to use this construct - perhaps because you did stuff everything in the application domain -
 you may reap some benefits by being more or less told what files can be moved to another domain. And if you can separate on the domain level, then you are already
 good on your way to resolving spaghetti hell. The rest is tackling correct MVC/MVVM models or other alternative ways of factoring out your spaghetti prone jQuery code.

 Good luck.
