# Modularity

This document contains some basic advice for how to achieve modularity,
then it goes into more advanced ideas as you scroll.
At the bottom lie some information on arbiters.

## Welcome to Italy

It here is one thing you learn quickly in programming, it is this:

- Spaghetti code is awful

It is awful to read, but it is even worse to modify or maintain.

## What is Bad Code

Without rehashing the entire internet:
**tightly coupled code is bad code**. Because

- The more tightly coupled your modules become,
the more side-effects alterations will have
and the harder it will be to reuse that module (violating DRY)
- The more different behaviour per module,
the harder it is to to maintain that module.
- The more one type of behaviour is spread out into different modules,
the harder it is to find the source of that behaviour.

## What is Good Code

#### What it is not: Bad Code
If tightly coupled code is bad code, then good code is loosely coupled.
A ⇒ B ∴ ¬B ⇒ ¬A.

In other words, if you factor out your behaviour into small separate units
of behaviour, you will have gained maintainability and readibility
properties for free, and your code will inevitably have less unknown
side-effects, leading to more secure code as well. It does, however,
take certain disipline to constantly police your files for multiple types
of behaviour.

You may shrug and say, well, I'm only going to write this once anyway..

..and you will be right. You will write it once and likely wish you wrote
it zero times.

In my opinion, the biggest mistake you can make as a learning programmer
is to not bothering to factor out behaviour as early as possible.
*</advice>*


## Best Practices

modul8 provides the means to separate your code into different files
effectively, but how do you as a developer split up your behaviour?

One of the hardest areas to modularize web applications is the client
application domain. If you are using jQuery, you should be particularly
familiar with this. `$` selector calls all around,
DOM insertion & manipulation code in random places,
identical behaviour existing for each URL. If this is a problem for you,
read on.

### Decouping MVC code
If you have tried the one size fits all approach to modularity and
try to cram your project into a MVC/MVVM structure, you may have had
success, or you might have hated it. At any rate, here is some general
ideas to consider if you are currently using or planning to use an MVC framework.

**Independent entry controller**

- A base point should be some sort of _controller_ which requires all outside controllers
- This centralized point should control major events on your site (like going to a new page), delegating to the other main controllers
- Nothing should require the main app controller (otherwise you get circulars, keep it simple)

**Controllers**

- All other contollers should control events specific to the data type they control
- Each controller should have a corresponding model - which the app might not need to know about

**Models**

- This contents of a model may not depend on jQuery (wheras the actual abstract Model class might)
- The model should contain logic to get information about this data type (i.e. maybe from one database table via ajax - which should be built in to the base class)

**Extras**

- Templates should have their own model and controller. The model can store them in LocalStorage or fetch them from server, but they can come bundled with modul8's output as well
- Validation logic should exist in the model and should be based on validation rules used on the server - so some data should be passed down to ensure this logic is in sync at all times
- Extra HTML helper logic should have its own module (possibly even DOM independent)

### DOM Decoupling
This section is very relevant if you are just using jQuery, or if you are
trying to roll your own application structure rather than using MVC.

The general jQuery advice is that you think about the behaviour you are
defining. Here are 4 general rules to go on for certain behaviour:

- non-request based DOM interactivity
⇒ write a plugin
- request based DOM interactivity
⇒ use controllers/eventmanagers to handle events, and call above plugin(s)
- calculations needed before DOM manipulation
⇒ make a standalone module (in a domain / npm) and call it at above stages.
- DOM interactivity changing styles
⇒ add a className to relevant container, and keep the style in the CSS

This way if something breaks, you should be able to narrow down the problem to
a UI error (code or style), a signaling error, or a calculation error.
⇒ Debugging becomes up to 4 times easier.

### General Modularity

modul8 just tries to facilitate the building of maintainable code.
To actually do so, you need to always stay vigilant and remember to:

- Not blend multiple types of behaviour together in one file.
- Limit the areas from which you reference global variables.
- Look for opportunities to move independent code onto different domains.
- Look for opportunities to refactor code to make bits of it independent.
- Enforce basic rules of JavaScript modularity: don't try to make
circular dependencies work, analyse your require tree. If you are requiring
the same libraries from every file, chances are you are doing something wrong.

Decouple your code this way and you will save yourself the trouble of later
having to learn from your mistakes the hard way.

## Going Further

### Domains or Node Modules?
Say you have factored out a piece of behaviour from your client side app.
Where do you put it? Do you put it

- in a folder under the client root
- in a separate domain
- make a node module out if it

This are increasingly flexible depending on what you want to do.
If you want to only use it on the client, you should keep it in the client root
so that it is immediately obvious to anyone reading your code where it works.

If you want to use it on the server, you have to use one of the other approaches.
A shared domain is great if you have completely server and client agnostic code.
This is what extra domains were designed for. One of the key reasons domains were
pushed by modul8 is that having a 'shared' folder next to your 'client' and
'server' folders screams to the reader that this code should work anywhere
and must be treated with respect. This is good.

Sometimes however, you need extra npm functionality on either end.
This is possible to achieve, but only if it is itself a node module.
A node module can be required on the client if it
sufficiently server agnostic. The downside to placing your code in here is that
it gives no indication to the people reading your code that it will work on
the client. On the other hand, it might be easier to reuse across projects when
things are checked into npm. Use with caution, but it's worth taking advantage of.

### Killing Globals

Global variable are evil, and should be kept to a minimum.
We know this, and this is were a require system really shines,
but you are generally going to depend on a few global variables.
Not all libraries are CommonJS compliant, and having jQuery plugins showing up
in your dependency tree under every branch that requires jQuery might
just make things more confusing than to load them classically.

Besides, you may want to load it in from a separate CDN anyway.

Even in such an environment, it is possible rid yourself of the global
`$` and `jQuery` symbols without breaking everything.

We will demonstrate such a solution. Begin by constructing a `jQuery.js`
file on your application domain containing:

    module.exports = window.jQuery;
    delete window.jQuery;
    delete window.$

With this you can put `var $ = require('jQuery')` so everything will be explicitly
defined on the application domain. You've also deleted the global shortcuts so that
you will know when you forgot to require.
Finally, jQuery (but none of its dependencies) show up in the dependency tree -
so you will quickly identify what code is actually DOM dependent
, and what isn't or shouldn't be. Clearly this is advantageous.

Having found this pattern very useful, but also noticing how repeating this pattern
on several libraries pollutes our application code folder with meaningless files,
a modul8 extension was created early on to allow automatic creation of these
arbiters in the internal module system by using the `arbiters()` call.

This example could be automated by
chaining on `arbiters().add('jQuery', ['jQuery', '$'])`.
See the [API docs](api.html) for more details.

### DOM Dependence
Note that modul8 only allows one domain to be DOM dependent
(the application domain), and from the start you are likely going to have
`require('jQuery')` or similar in many places there.

However, if you just find some areas that do not use it, and as a result move
logic to an environment agnostic domain, then it this is a great success.
Your jQuery dependent code is diminished, so the more tightly coupled code
of your application is smaller.

If you can efficiently separate code on the domain level, try to keep above
advice in mind; always aim to factor out behavior into small loosely coupled
modules. If you can do this then you are already well on your way to resolving
spaghetti hell. The rest is mostly  getting the correct signaling model for your
events to your controllers/controller style entities.

Good luck.
Hopefully this has been useful on some level : )
