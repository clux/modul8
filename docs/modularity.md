# Modularity

This document contains some basic advice for how to achieve modularity,
then it goes into more advanced ideas as you scroll. At the bottom lie some information on arbiters.

## Welcome to Italy

It here is one thing you learn quickly in programming, it is this:

   - Spaghetti code is awful

It is awful to read, but it is even worse to modify or maintain.

## What is Bad Code

Without rehashing the entire internet: **tightly coupled code is bad code**. Because

   - The more tightly coupled your modules become, the more side-effects alterations will have and the harder it will be to reuse that module.
   - The more different behaviour per module, the harder it is to to maintain that module.
   - The more one type of behaviour is spread out into different modules, the harder it is to find the source of that behaviour.

## What is Good Code

#### What it is not: Bad Code
If tightly coupled code is bad code, then good code is loosely coupled. A ⇒ B ∴ ¬B ⇒ ¬A.

In other words, if you factor out your behaviour into small separate units of behaviour, you will have gained maintainability and
readibility properties for free, and your code will inevitably have less unknown side-effects, leading to more secure code as well.
It does, however, take certain disipline to constantly police your files for multiple types of behaviour.

You may shrug and say, well, I'm only going to write this once anyway..

..and you will be right. You will write it once and quickly realize you that it would have been even better if you hade written it zero times. Trust me.

There's simply no way around it. The biggest mistake you can make as a learning programmer is to not factor out behaviour as early as possible.
*</advice>*

## Relation to JavaScript

JavaScript has no module system.

_Shit_.

We have, on the other hand, got functions. Functions with closures.

    (function(){
      var private = 5;
      window.publicFn = function(){
        console.log(private);
      }
    })();

This is the commonly employed method of encapsulating and exposing objects and functions that can reference private variable through a closure.
This works; `private` is inaccessible outside this anonymous function.

Unfortunately, this just exposes publicFn to the global window object. This is not ideal, as anything, anywhere can just reference it, leaving
us not much wiser. True modularity is clearly impossible when things are just lying around freely like this for everyone. It is fragile, and
it is error prone as conflicting exports will actually just favour the last script to execute - as JavaScript simply runs top to bottom, attaching its
exports to window as we go along. Clearly we need something better than this.

### CommonJS

There is a way to fix this, but first of all it assumes all modules need to support a stadardised format for exporting of modules.
CommonJS is a such a standardization. It has very large traction at the moment, particularly driven by server side environments such as NodeJS.

Its ideas are simple. Each module avoids the above safety-wrapper, must assume it has a working `require()`,
and instead of attaching its exports to a global object, it attaches them to an opaque `exports` object.
Alternatively, it can replace the `module.exports` object to define all your exports at once.

By making sure each module is written this way, CommonJS parsers can implement clever trickery on top of it to make this behaviour work.
I.e. having each module's exports objects stored somewhere for `require()` and every module will export a singleton.
For more information on this goto the [CommonJS document](commonjs.html) describing how a module system works.


## Best Practices

One of the hardest areas to modularize web applications is the client application domain. If you are using jQuery,
you should be particularly familiar with this. `$` selector calls are spread around, DOM insertion & manipulation code
exists all over the place, identical behaviour modifying functions written for every URL.
If this is familiar to you, then you should consider looking at a MVC/MVVM framework such as Spine/Backbone/Knockout
(although this by no means is this an exhaustive list).

However, for jQuery applications, some things transcends the framework you use to manage your events.

### Decoupling jQuery code

It is always important to think about the behaviour you are defining. If it is for

 - non-request based DOM interactivity - it is almost always better to write a plugin
 - request based DOM interactivity - you should use controllers/eventmanagers to handle your events and call above plugins.
 - calculations needed before DOM manipulation - you should make a standalone calulation module that should work on its own,
 and call it at appropriate stages above.

This way if something breaks, you should be easily able to narrow down the problem to a UI error, a signaling error, or a calculation error.
=> Debugging becomes up to 3 times easier.

### General

modul8 just tries to facilitate the building of maintainable code. To actually do so, you need to always stay vigilant and remember to:

 - Not blend multiple types of behaviour together in one file.
 - Limit the areas from which you reference global variables.
 - Look for opportunities to move independent code onto different domains.
 - Look for opportunities to refactor code to make bits of it independent.
 - Enforce basic rules of JavaScript modularity: don't try to make circular dependencies work, analyse your require tree. If you are requiring the same library from every file, chances are you are doing something wrong.

Decouple your code this way and you will save yourself the trouble of later having to learn from your mistakes the hard way.

## Going Further

Global variable are evil, and should be kept to a minimum. We know this, and this is were a require system really shines, but you are generally
going to depend on a few global variables. Not all libraries are CommonJS compliant, and having jQuery plugins in showing up in your
dependency tree under every branch that requires jQuery might just make things more confusing than to load them classically.

Besides, you may want to load it in from a separate CDN anyway.

Even in such an environment, it is possible rid yourself of the global $ and jQuery symbols without breaking everything.

We will demonstrate such a solution. Begin by constructing a jQuery.js file on your application domain containing:

    module.exports = window.jQuery;
    delete window.jQuery;
    delete window.$

This means you can use `$ = require('jQuery')` so everything will be explicitly defined on the application domain,
you've deleted the global shortcuts so that you will know when you forgot to require, and jQuery (but none of its dependencies)
show up in the dependency tree. I.e. you will quickly identify what code is actually DOM dependent, and what isn't or shouldn't be.
Clearly this is advantageous.

Having found this pattern very useful, but also noticing how repeating this pattern on several libraries pollutes our application
code folder with meaningless files, a modul8 extension has been made in 0.3.0 to allow automatic creation of these arbiters in the
internal module system by using the `arbiters()` call.
This example could be automated by chaining on `arbiters().add('jQuery', ['jQuery', '$'])`. See the [API docs](api.html) for more details.

Note that modul8 only allows one domain to be DOM dependent (the application domain), so with correct usage -
i.e. not stuffing every module in that domain - you might not have any big revelations there anyway. You are likely
having to `require('jQuery')` in most places. But if you just find some areas that do not use it, and as a result move them to a
environment agnostic domain, then this has been a success.

If you can efficiently separate code on the domain level, try to keep above advice in mind
(always aim to factor out behavior into small loosely coupled modules),  then you are already
good on your way to resolving spaghetti hell. The rest is tackling the correct signaling model for your events.
And for that there are MVC/MVVM frameworms of varying sizes.

Good luck. Hopefully this is useful on some level.
