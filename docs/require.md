# require()

Modul8's `require()` works hand in hand with a private `define()` call that gets pre-pended to the compiled source.
On compilation each module is wrapped in a define call (ensuring encapsulation of private variables between modules) that give each of these modules
the necessary context for the `require()` calls it may make. All context is stored via closures and will be hidden from you.

## Ways to require

There are four different ways to use require:

 - **Globally**:        `require('subfolder/module.js')`. This will scan all the domains (except data) for a matching structure, starting the search at your current location.
 A gloabl require does not care about your current location.

 - **Relatively**:      `require('./module.js')`. This will scan only the current domain and the current folder
 You can keep chaining on '../' to go up directories, but this has to happen in the beginning of the require string:
 `require('./../subfolder/../basemodule.js')` **is not legal** while `require('./../basemodule.js')` **is**.

  - **Domain Specific**  `require('shared::val.js')`. Scans the specified domain (only) as if it were a global require from within that domain.
 You cannot do relative requires combined with domain prefixes as this is either non-sensical (cross domain case: folder structure between domains lost on the browser),
 or unnecessary (same origin case: you should simply be using relative requires).

 - **Data Domain**:     `require('data::datakey')`. The data domain is special. It is there to allow requiring of data that was `add()`-chained on the `data()` method.
 It does not arise from physical files, and will not show up in the dependency tree. It is simply data you have attached deliberately.

 - **Through Arbiters** `require('jQuery')` - given that `arbiters().add('jQuery',['$','jQuery'])` was passed in on the server.
 This will have deleted the global shortcuts included. Since these are probably commonly dependend upon they can be used without specifying their default domain: `M8::`.
 Note that this domain name is not related to the namespace setting. If a jQuery.js file is found on the current domain, however, it will gain priority over the
 arbiters domain. If this cooexistence is necessary, any arbiters must be `require()`d domainspecifically: `$ = require('M8::jQuery')`.

### File extensions

 File extensions are never necessary, but you can (and sometimes should) include them for specificity (except for on the data domain).

 To see why you perhaps should, consider the simplified algorithm `require()` uses to resolve the files you required on the server:

    name = require input, domain = current domait (stored in closure)
    while(domain)
      return true if exists(domain + name)
      return true if exists(domain + name + '.js')
      return true if exists(domain + name + '.coffee')
      domain = nextDomain
    return false


 If there is one thing to learn from it is is that you absolutely **DO NOT omit extensions and keep .js and .coffee versions in the same folder**
 or you will quickly become very frustrated as to why your coffee changes arent doing anything.

### Require Priority

Requires are attempted resolved with the following priority:

    if require string is relative
      resolve absolutized require string on current domain
    else if require string includes domain prefix
      resolve require string on specified domain
    else //arbiter search
      resolve require string on the M8 domain

    if none of the above worked
      resolve on all other domains

    //error

In other words, collisions should not occur unless you have duplicate files in different domains, and you are very relaxed about your domain specifiers or arbiter prefixes.

### Hooking into define

modul8 defines way to help you attach objects/fn to certain domains both live on the client and from the server via `data()`.
The [API docs](api.html) have full information on this.
