# API

modul8's API is in its basic form extremely simple, all we need to do is `add()` domains to `domains()`,
an entry point for the first domain to modul8 itself, and the target JavaScript file to write

    var modul8 = require('modul8');
    var dir = __dirname;

    modul8('app.js')
      .domains()
        .add('app', dir+'/app/client/')
        .add('shared', dir+'/app/shared/')
      .compile('./out.js');


You can add any number of domains to be scanned, but the first domain added must be the location of the entry point; 'app.js'.
Files on these domains can be required specifically with `require('domain::name')`.
Both the domain and file extension can be omitted if there are no conflicts (if there are, the main domain will be scanned first).

The following are equivalent from the file: 'helper.js' on the 'shared' domain.

    require('shared::validation.js') //extension not necessary
    require('./helpers.js') //relative require searches only this domain
    require('./helpers') //.js extension always gets searched before .coffee

Additionally, `require('helpers')` will resolve to the same file if there are no helpers.js in the root of any other domains.
More information on `require` is available in [this section](require.html)

### API Chaining Note

As indicated by the first example, the modul8 API is controlled by chaining methods together. For style and semanticity
we apply extra indentation when we break into a subroutine like in the `.data()` call above, or, if only one method is chained on a subclass,
we sometimes write it on the same line.

We recommend sticking to this notation as subroutines from different methods often have identical names.
Regardless, the API will warn you if you try to apply methods from a subroutine after having broken out from them.

## Adding Data

At some point during development it is natural to feel that this data should be available on the client as well. modul8 supports two ways of doing this:

 - Have an explicit file on a shared domain, exporting the objects you need
 - Export the object directly onto the `data` domain

The first is good if you have static data like definitions, because they are perhaps useful to the server as well,
but suppose you want to export more ephemeral data that the server has no need for, like templates or template versions.
To export these to the server, you will have to obtain the data somehow - your job - and allow modul8 to pull it into the script.

The data API simply consists of `add()`ing data keys and functions to `data()`

    modul8('app.js')
      .domains().add('app', dir+'/app/client/')
      .data()
        .add('versions', myVersionParser)
        .add('models', myModelParser)
        .add('templates', myTemplateCompiler)
      .compile('./out.js');

Under the covers, modul8 attaches the output of the myX functions to the reserved `data` domain.
Data exported to this domain is `require()`able as if it were exported from a file (named versions|templates|models) on a domain named data:

 - `require('data::models')  //output of myModelParser`

In other words the function output is attached verbatim to modul8's exports container; if you provide bad data, you are solely responsible for breaking your build.
This should be easy to detect in a console though.

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

    modul8('app.js')
      .domains().add('app', dir+'/app/client/')
      .libraries()
        .list(['jQuery.js','history.js'])
        .path(dir+'/app/client/libs/')
        .target('out-libs.js')
      .compile('./out.js');

Note that without the `.target()` option added, the libraries would be inserted in the same file before you application code.

Libraries tend to update with a different frequency to the main client code. Thus, it can be useful to separate these from your main application code.
And nmodified files that have already been downloaded from the server simply will illicit an empty 304 Not Modified response. Thus, using `.target()` and
splitting these into a different file could be advantageous.

If you would like to integrate libraries into the require system check out the documentation on `arbiters()` below.

#### Libraries CDN Note
Note that for huge libraries like jQuery, you may benefit (bandwidth wise) by using the [Google CDN](http://code.google.com/apis/libraries/devguide.html#jquery).
In general, offsourcing static components to load from a CDN is a good first step to scale your website.
There is also evidence to suggest that splitting up your files into a few big chunks may help the browser load your page faster, by downloading the scripts in parallel.
Don't overdo this, however. HTTP requests are still expensive. Two or three JavaScript files for your site should be plenty using HTTP.

## Middleware

Middleware come in two forms: pre-processing and post-processing: in short terms before and after middleware.

 - `.before()` middleware is applied before analysing dependencies as well as before compiling.
 - `.after()` middleware is only applied to the output right before it gets written.

modul8 comes bundled with one of each of these:

 - `modul8.minifier` - post-processing middleware that minifies using `UglifyJS`
 - `modul8.testcutter` - pre-processing middleware that cuts out the end of a file (after require.main is referenced) to avoid pulling in test dependencies.

To use these they must be chained on `modul8()` via `before()` or `after()` depending on what type of middleware it is.

    modul8('app.js')
      .domains().add('app', dir+'/app/client/')
      .before(modul8.testcutter)
      .after(modul8.minifier)
      .compile('./out.js');

**WARNING:** testcutter is not very intelligent at the moment, if you reference `require.main` in your module,
expect that everything from the line of reference to be removed.

## Settings

Below are the settings available:

   - `domloader`  A function that safety wraps code with a DOMContentLoaded barrier
   - `namespace`  The namespace modul8 uses in your browser, to export console helpers to, defaulting to `M8`
   - `logging`    Boolean to set whether to log `require()` calls in the console, defaults to `false`

**You have to** set `domloader` if you do not use jQuery. If you are familiar with the DOM or any other library this should be fairly trivial.
The default jQuery implementation is as follows:

    domloader_fn = function(code){
     return "jQuery(function(){"+code+"});"
    }

Note that the namespace does not actually contain the exported objects from each module, or the data attachments.
This information is encapsulated in a closure. The namespace'd object simply contains the public debug API.
It is there if you want to write a simpler prefix than than capital M, 8 all the time, maybe you would like 'QQ' or 'TT'.

Options can be set by chaining them on `modul8()` using the `set(option, value)` method. For example:

    modul8('app.js')
      .set('namespace', 'QQ')
      .set('domloader', domloader_fn)
      .set('logging', true)
      .domains().add('app', dir+'/app/client/')
      .compile('./out.js');

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
      .domains().add('app', dir+'/app/client/')
      .analysis()
        .output(console.log)
        .prefix(false)
        .suffix(true)
      .compile('./out.js')

The `output()` method must be set for `analysis()` to have any effect.
It must take either a function to pipe the tree to, or a filepath to write it out to.

The additional boolean methods, `prefix()` and `suffix()` simply control the layout of the printed dependency tree.
Prefix refers to the domain (name::) prefix that may or may not have been used in the require, and similarly, suffix refers to the file extension.
Defaults for thes are : `{prefix: true, suffix: false}`.

## Environment Conditionals

We can conditionally perform the following action, if __NODE_ENV__ matches specified environment.

    modul8('app.js')
      .domains().add('app', dir+'/app/client/')
      .in('development').after(modul8.minifier)
      .in('development').compile('./out.js')
      .in('production').compile('./out.js')

The environment conditionals may be applied to several calls:

    modul8('app.js')
      .domains().add('app', dir+'/app/client/')
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
       .compile('./out.js')

If we perform the same action for environments, set them before
the first `in()` call, or use `in('all')`.

## Debugging

If you have wrongly entered data to `require()`, you will not get any information other than an undefined reference back.
Since all the exported data is encapsulated in a closure, you will not be able to find it directly from the console.

To see where the object you are looking for should live or lives, you may find it useful to log the specified domain object
with the globally available `M8.inspect(domainName)` method. Additionally, you may retrieve the list of domains modul8 tracks using the
`M8.domains()` command.

If you want every `require()` call to be logged to the console, you can set the `logging` setting.

There is additionally a console friendly require version globally available at `M8.require()`.
This acts as if you were a file called 'CONSOLE' on the root directory of your main application domains, so you can use relative requires there.

## Live Extensions

It is plausible you may want to store `require()`able data or code inside modul8's module containers.
Perhaps you have a third-party asynchronous script loader, and you want to attach the resulting object onto some appropriate domain.

This is an issue, because `require()` calls are analysed on the server before compilation, and if you reference something that will be loaded in
separately, it will not be found on the server. The solution to this is the same solution modul8 uses to allow data domain references; whitelisting.

The domains `M8`, `data` and `external` have been whitelisted for this purpose, and a `require()`able API exists on the client.

  - `require('M8::external')` - returns a function(name, object), which, when called will attach object to external::name
  - `require('M8::external')` - returns a function(name, object), which, when called will attach object to data::name

Both these functions will overwrite on repeat calls. For example:

     var dataAdd = require('M8::data');
     dataAdd('libX', libXobj);
     require('data::libX'); // -> libXobj
     dataAdd('libX', {});
     require('data::libX'); // -> {}

Although inteded for the console, if you don't like `require()`ing in these functions, they are aliased on the namespaced object.
Just remember that if you change the name of your namespace, you will have to change these references everywhere.
Also note that changing the namespace does not change the domain these two functions lie on. The aliases are as follows:

  - `M8.data === require('M8::data')`
  - `M8.external === require('M8::external')`

Or, more generally; `#{namespace}.data === require('M8::data')`.

## Arbiters

These help reveal invisible dependencies by reduce the amounts global variables in your code.

    modul8('app.js')
      .domains().add('app', dir+'/app/client/')
      .libraries()
        .list(['jQuery.js','Spile.coffee'])
        .path(dir+'/app/client/libs/')
      .arbiters()
        .add('jQuery', ['$', 'jQuery'])
        .add('Spine')
      .compile('./out.js')

This code would delete objects `$`, `jQuery` and `Spine` from `window` and under the covers add closure bound alternatives that are `require()`able.
The second parameter to `arbiters().add()` is the variable name/names to be deleted. If only a single variable should be deleted,
it can be entered as a string, but if this is the same as as the arbiter's name, then it can be omitted completely - as with Spine above.

Arbitered libraries can be should be referenced simply with `require('jQuery')`, or `require('M8::jQuery')` it there isnt a conflicting
jQuery.js file on your current domain. Normally this specificity should not be required.
