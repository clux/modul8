# API

modul8's API is extremely simple, all we need to do pass a entry point and an output - in its basic form.
To add extra require domains for the client pass a dictionary of form `{name : path}`.

    var modul8 = require('modul8');
    modul8('./client/app.js')
      .domains({'shared': './shared/'})
      .compile('./out.js');

Alternatively, you can `.add()` each domain separately.

    var modul8 = require('modul8');
    modul8('./client/app.js')
      .domains()
        .add('shared', './shared/')
        .add('framework', './libs/client/')
      .compile('./out.js');

You can add any number of domains to be scanned. Files on these domains can be required specifically with `require('domain::name')`.
Both the domain and file extension can be omitted if there are no conflicts (current domain gets scanned first, .js scanned before .coffee).

The following are equivalent from a file in the root of the application domain, having the file `validation.js` in the same folder

    require('./validation.js') //relative require searches only this domain
    require('./validation') //.js extension always gets searched before .coffee
    require('validation') // resolves this domain first (but moves on if this fails)

More information on `require()` priority is available in [this section](require.html)

## Injecting Data

One of the eternal problems with web development is how to export data from the server to the client reliably.
modul8 provides two simple ways of doing this.

 - Have an explicit file on a shared domain, exporting the objects you need
 - Add the object directly onto the `data` domain

The first is good if you have static data like definitions, because they are perhaps useful to the server as well,
but suppose you want to export more ephemeral data that the server has no need for, like perhaps templates or template versions.
To export these to the server, you will have to obtain the data somehow - your job - and allow modul8 to pull it into the script.

The data API is simply chaining `add()` onto `data()` with data key and function as arguments to add

    modul8(dir+'/app/client/app.js')
      .data()
        .add('versions', myVersionParser)
        .add('models', myModelParser)
        .add('templates', myTemplateCompiler)
      .compile('./out.js');

Alternatively, as with `.domains()`, you can do a single `.data()` call with an object instead of chaining `.add()` if you prefer.

Under the covers, modul8 attaches the output of the myX functions to the reserved `data` domain.
Data exported to this domain is requirable as if it were exported from a file (named versions|templates|models) on a domain named data:

 - `require('data::models')  //== myModelParser()`

In other words the function output is attached verbatim to modul8's exports.data container; if you provide bad data, you are solely responsible for breaking your build.
This is easy to detect in a console though.

As a small example our personal version parser operates something like the following:

    function versionParser(){
      //code to scan template directory for version numbers stored on the first line
      return "{'user/view':[0,2,4], 'user/register':[0,3,1]}";
    }

Chaining on `.add('versions', versionParser)` will allow:

    var versions = require('data::versions');
    console.log(versions['users/view']) // -> [0,2,4]

## Adding Libraries

Appending standard (window exporting) JavaScript and CoffeeScript files is easy. Call `.libraries()` and chain on your options as below.
CoffeeScript libs / AltJS libs are compiled with the safety wrapper, whereas plain JavaScript is simply concatenated on bare.

    modul8('./app/client/app.js')
      .libraries()
        .list(['jQuery.js','history.js'])
        .path('./app/client/libs/')
        .target('./out-libs.js')
      .compile('./out.js');

Note that without the `.target()` option added, the libraries would be inserted in the same file before you application code.

Alternatively, there is a succinct syntax to provide all libraries options in one call. Where the third parameter is not required.

    modul8(dir+'/app/client/app.js')
      .libraries(['jQuery.js','history.js'], './app/client/libs/', './out-libs.js')
      .compile('./out.js');


Note that libraries tend to update with a different frequency to the main client code. Thus, it can be useful to separate these from your main application code.
Modified files that have already been downloaded from the server simply will illicit an empty 304 Not Modified response when requested again. Thus, using `.target()` and
splitting these into a different file could be advantageous from a bandwidth perspective.

If you would like to integrate libraries into the require system check out the documentation on `arbiters()` below.

#### Libraries CDN Note
Note that for huge libraries like jQuery, you may benefit (bandwidth wise) by using the [Google CDN](http://code.google.com/apis/libraries/devguide.html#jquery).
In general, offsourcing static components to load from a CDN is a good first step to scale your website.
There is also evidence to suggest that splitting up your files into a few big chunks may help the browser load your page faster, by downloading the scripts in parallel.
Don't overdo this, however. HTTP requests are still expensive. Two or three JavaScript files for your site should be plenty using HTTP.

## Middleware

Middleware come in two forms: pre-processing and post-processing:

 - `.before()` middleware is applied before analysing dependencies as well as before compiling.
 - `.after()` middleware is only applied to the output right before it gets written.

modul8 comes bundled with one of each of these:

 - `modul8.minifier` - post-processing middleware that minifies using `UglifyJS`
 - `modul8.testcutter` - pre-processing middleware that cuts out the end of a file (after require.main is referenced) to avoid pulling in test dependencies.

To use these they must be chained on `modul8()` via `before()` or `after()` depending on what type of middleware it is.

    modul8('app.js')
      .before(modul8.testcutter)
      .after(modul8.minifier)
      .compile('./out.js');

**WARNING:** testcutter is not very intelligent at the moment, if you reference `require.main` in your module,
expect that everything from the line of reference to be removed.
If you do use it, always place tests at the bottom of each file, and never use wrapper functions inside your scripts (as the `});` bit will get chopped off).
This should be easy as modul8 wraps everything for you anyway - it even wraps to hold off execution until the DOM is ready.

## Settings

Below are the settings available:

   - `domloader`  A function or name of a global fn that safety wraps code with a DOMContentLoaded barrier
   - `namespace`  The namespace modul8 uses in your browser, to export console helpers to, defaulting to `M8`
   - `logging`    Boolean to set whether to log `require()` calls in the console, defaults to `false`
   - `force`      Boolean to set whether to force recompilation or not - should only be useful when working on modul8 itself.

**You SHOULD** set `domloader` to something. Without this option, it will NOT wait for the DOM and simply wrap all main application code
in a anonymous self-executing function.

If you are using jQuery simply set this option to `jQuery` (and it will also deal with the possibility of jQuery being arbitered).

Alternatively, you could write your own implementation function and pass it as the parameter to `.set('domloader', param)`.
The following is the equivalent function that is generated if `jQuery` is passed in:

    domloader_fn = function(code){
     return "jQuery(function(){"+code+"});"
    };

Note that the namespace does not actually contain the exported objects from each module, or the data attachments.
This information is encapsulated in a closure. The namespace'd object simply contains the public debug API.
It is there if you want to write a simpler prefix than than capital M, 8 all the time, maybe you would like 'QQ' or 'TT'.

Options can be set by chaining them on `modul8()` using the `set(option, value)` method. For example:

    modul8('./client/app.js')
      .set('namespace', 'QQ')
      .set('domloader', '$(document).ready')
      .set('logging', 'ERROR')
      .compile('./out.js');

Logging has 3 levels at the moment

- ERROR
- INFO
- DEBUG

They have cumulative ordering:

- ERROR will only give failed to resolve require messages in the client console via `console.error`.
- INFO additionally gives recompile information on the server (via internal logger class).
- DEBUG adds log messages from require on the client to show what is attempted resolved via `console.log`.

ERROR level will not give any messages on the server, but if you don't even want the fail messages from require, you may disable logging altogether by pasing in false.
Note that ERROR is the default.

## Code Analysis

To dynamically resolve dependencies from a single entry point, modul8 does a recursive analysis of the `require()`d code.
Note that modul8 enforces a **no circular dependencies rule**. Granted, this is possible with sufficient fiddling,
but it brings one major disadvantages to the table:

A circularly dependent set of modules are tightly coupled; they are really no longer a set of moudles, but more of a library.
There are numerous sources talking about [why is tight coupling is bad](http://www.google.com/search?q=tight+coupling+bad) so this
will not be covered here. Regardless of whether or not you end up using modul8: ignore this warnig at your own risk.

Additionally, the dependency diagram cannot be easily visualized as it has gone from being a tree, to a tree with cycles.
With the no circulars rule enforced, we can print a pretty `npm list`-like dependency tree for your client code.

    app::main
    ├──┬app::controllers/user
    │  └───app::models/user
    ├──┬app::controllers/entries
    │  └───app::models/entry
    └──┬shared::validation
       └───shared::defs

While this usually grows much lot bigger than what is seen here, by putting this in your face, it helps you identify what pieces of code
that perhaps should not need to be required at a particular point. In essence, we feel this helps promote more loosely coupled applications.
We strongly encourage you to use it if possible. The API consists of chaining 1-3 methods on `analysis()`:

    modul8('app.js')
      .domains({app : dir+'/app/client/'})
      .analysis()
        .output(console.log)
        .prefix(false)
        .suffix(true)
        .hide('external')
      .compile('./out.js');

The `output()` method must be set for `analysis()` to have any effect.
It must take either a function to pipe the tree to, or a filepath to write it out to.

The additional boolean methods, `prefix()` and `suffix()` simply control the layout of the printed dependency tree.
Prefix refers to the domain (name::) prefix that may or may not have been used in the require, and similarly, suffix refers to the file extension.
Defaults for thes are : `{prefix: true, suffix: false}`.

The `.hide()` call specifies what domains to suppress in the dependency tree. Takes a domain name string or an array of such strings.

The analysis call can be shortcutted with a direct (up to) four parameter call to `.analysis()` with parameters output, prefix, suffix, hide.
So the above could be done with

    .analysis(console.log, false, true 'external')

## Environment Conditionals

We can conditionally perform the following action, if __NODE_ENV__ matches specified environment.

    modul8(dir+'/app/client/app.js')
      .in('development').after(modul8.minifier)
      .in('development').compile('./out.js')
      .in('production').compile('./out.js');

The environment conditionals may be applied to several calls:

    modul8(dir+'/app/client/app.js')
      .in('development')
        .after(modul8.minifier)
        .analysis()
          .output(console.log)
          .prefix(true)
          .suffix(false)
        .domains()
          .add('debug', dir+'/app/debug/')
      .in('production')
        .libraries()
          .list(['analytics.js'])
          .path(dir+'/app/client/libs/')
      .in('all')
       .compile('./out.js');

If we perform the same action for environments, set them before
the first `in()` call, or use `in('all')`.

## Live Extensions

It is plausible you may want to store requirable data or code inside modul8's module containers.
Perhaps you have a third-party asynchronous script loader, and you want to attach the resulting object onto some appropriate domain.

This is an issue, because `require()` calls are analysed on the server before compilation, and if you reference something that will be loaded in
separately, it will not be found on the server. The solution to this is the same solution modul8 uses to allow data domain references; whitelisting.

The domains `M8`, `data` and `external` have been whitelisted for this purpose, and an API exists on the client.
The `M8` domain is reserved for arbiters and can only be extended from the server, but the other two have a public API from the client.
But note that no other domains can be manipulated on the client.

You can access the API from your application code by referencing modul8's single global object. The name of this object can be changed through the `namespace` setting,
and by default it is set to `M8`, but we refer to it here simply as `ns` to avoid confusion with the `M8` domain.

Note that the `ns` object stores simply the API to interact with the data, not the actual data. You have to `require()` if you want to actually get it.

  - `ns.data` - is a function(name, object) - manipulating data::name
  - `ns.external` -  function(name, object) - manipulating external::name

Both these functions will overwrite on repeat calls. For example:

    ns.data('libX', libXobj);
    require('data::libX'); // -> libXobj

    ns.data('libX', {});
    require('data::libX'); // -> {}

    ns.data('libX'); //unsets
    require('data::libX'); // -> undefined

And similarly for `ns.external`.
See the debug section for how to log the `external` and `data` domains.

## Debugging

If you have wrongly entered data to `require()`, you will not get any information other than an undefined reference back.
Since all the exported data is encapsulated in a closure, you will also not be able to locate it from the console.

To see where the object you are looking for should live or lives, you may find it useful to log the specified domain object
with the globally available `ns.inspect(domainName)` method. Additionally, you may retrieve the list of domains modul8 tracks using the
`ns.domains()` command.

If you want every `require()` call to be logged to the console, you can set the `logging` setting appropriately.
The `ERROR` level is recommended as it will tell you when a `require()` call failed.

There is additionally a console friendly require version globally available at `ns.require()`.
This acts as if you were a file called 'CONSOLE' in the same folder as your entrypoint, so you can use relative requires to get application code there..

## Arbiters

These help reveal invisible dependencies by reduce the amounts global variables in your code.

    modul8(dir+'/app/client/app.js')
      .libraries(['jQuery.js','Spile.coffee'], dir+'/app/client/libs/')
      .arbiters()
        .add('jQuery', ['$', 'jQuery'])
        .add('Spine')
      .compile(dir+'/out.js');

This code would delete objects `$`, `jQuery` and `Spine` from `window` and under the covers add closure bound alternatives you can `require()`.
The second parameter to `arbiters().add()` is the variable name/names to be deleted. If only a single variable should be deleted,
it can be entered as a string, but if this is the same as as the arbiter's name, then it can be omitted completely - as with Spine above.

Arbitered libraries can be should be referenced simply with `require('jQuery')`, or `require('M8::jQuery')` it there is a conflicting
jQuery.js file on your current domain. Normally this specificity should not be required.

Alternative adding syntax is to add an object directly to `arbiters()`

    .arbiters({
      jQuery : ['$', 'jQuery']
      Spine  : Spine
    })

Or even simpler:

    .arbiters(['$','jQuery', 'Spine'])

But note that this version has a slightly different meaning - it adds them all without a second parameter, i.e.

- `require('$')` and `require('jQuery')` would both resolve whereas above only `require('jQuery')` would.


## Registering a Compile-to-JS Language

It is possible to extend the parsers capabilities by sending the extension and compiler down to modul8.
For instance, registering Coffee-Script (if it wasn't already done automatically) would be done like this

    var coffee = require('coffee-script');
    modul8('./client/app.js')
      .register('.coffee', function(code, bare){
        coffee.compile(code, {bare:bare})
      })
      .compile('./out.js');

Note the boolean `bare` option is to let modul8 fine tune when it is necessary to include the safety wrapper - if the compile to language includes one by default.

CoffeeScript uses a safety wrapper by default, but it is irrelevant for application code as we define wrap each file in a function anyway.
However, if you included library code written in CoffeeScript, then modul8 will call the compile function with bare:false.

You should implement the bare compilation option if your language supports it, as an optimization (less function wrapping for app code). If your code already contains wrapper,
or if your language always safety-wraps, then this is fine too.
