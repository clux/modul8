
## API

 Modul8's API is in its basic form extremely simple, all we need to do is `add()` domains to `domains()`,
 an entry point for the first domain to modul8 itself, and the target JavaScript file to write

    var modul8 = require('modul8');
    var dir = __dirname;

    modul8('app.js')
      .domains()
        .add('app', dir+'/app/client/')
        .add('shared', dir+'/app/shared/')
      .compile('./out.js');


 You can add any number of domains to be scanned, but the first domain `add()`ed must be the location of the entry point ('app.js').
 Files on these domains can be `require()`d specifically with `require('domain::filename')`.
 Both the domain and file extension can be omitted if there are no conflicts (if there are the main domain will be scanned first).

 The following are equivalent from the file: 'helper.js' on the 'shared' domain.

    1. require('shared::validation.js') //3. => can remove extension
    2. require('./helpers.js') //relative require searches only this domain
    3. require('./helpers') //.js extension always gets searched before .coffee

 Additionally, `require('helpers')` will resolve to the same file if there are no helpers.js in the root of any other domains.
 More information on `require` is available in Readme.md

### Adding Libraries

 Not every JavaScript library is CommonJS compatible, and you also just want to keep exporting jQuery to window since it is so heavily intwined with
 your application code. Modul8 makes this easy by simply concatenating in the libraries you need first - in the order you specify.

    modul8('app.js')
      .domains().add('app', dir+'/app/client/')
      .libraries()
        .list(['jQuery.js','history.js'])
        .path(dir+'/app/client/libs/')
        .target('out-libs.js')
      .compile('./out.js');

 Libraries tend to update with a very different frequency to the main client code. Thus, it can be useful to separate these from your main application code.
 This can be done like the above example by calling `target()` on `libraries()`.

 Note that for huge libraries like jQuery, you may benefit (bandwidth wise) by using the [Google CDN](http://code.google.com/apis/libraries/devguide.html#jquery).
 In general, offsourcing static components to load from a CDN is a good first step to scale your website.
 There is also evidence to suggest that splitting up your files may help the browser finish loading your page faster (the browser can download scripts in parallel),
 just don't overdo it - HTTP requests are still expensive. Two or three JavaScript files for your site should be plenty using HTTP.

### Adding Data

 At some point during development it is natural to feel that this data should be available on the client as well. There are two fundamental ways of doing this with modul8.

 - Have an explicit file on a shared domain, exporting the objects you need
 - Export the object directly onto the data domain

 The first is good if you have static data like definitions, because they are perhaps useful to the server as well,
 but suppose you want to export more ephemeral data that the server has no need for, like templates or template versions.
 To export these to the server, you will have to obtain the data somehow - your job - and allow modul8 to pull it into the script.

 The data API simply consists of `add()`ing data keys and functions to `data()`

    modul8('app.js')
      .domains().add('app', dir+'/app/client/')
      .data()
        .add('versions', myVersionParser)
        .add('templates', myTemplateCompiler)
      .compile('./out.js');

 Under the covers, Modul8 attaches the output of the myX functions to an internal _data domain_ (so this domain is reserved).
 The end result is that you can require this data as if it were exported from a file (named versions|templates) on a domain named data.
 The second argument to add must be a function returning a string. Its result is attached verbatim to Modul8's require tree.

### Middleware

 Middleware come in two forms: pre-processing and post-processing.
 - Pre-processing is middleware that is applied before analysing dependencies as well as before compiling.
 - Post-processing is middleware that is only applied to the output right before it gets written.

 Modul8 comes bundled with one of each of these:

 - modul8.minifier - post-processing middleware that minifies using UglifyJS
 - modul8.testcutter - pre-processing middleware that cuts out the end of a file (after require.main is referenced) to avoid pulling in test dependencies.

 To use these they must be chained on `modul8()` via `before()` or `after()` depending on what type of middleware it is.

    modul8('app.js')
      .domains().add('app', dir+'/app/client/')
      .before(modul8.testcutter)
      .after(modul8.minifier)
      .compile('./out.js');

### Settings

 Below are the settings available:

   - `domloader` A function that safety wraps code with a DOMContentLoaded barrier
   - `namespace`  The namespace modul8 uses in your browser, defaulting to `M8`

 **You have to** set `domloader` if you do not use jQuery. If you are familiar with the DOM or any other library this should be fairly trivial.
 The default jQuery implementation is as follows:

     domloader_fn = function(code){
      return "jQuery(function(){"+code+"});"
    }
 You should never have to set namespace unless you go digging in the source and the M8 references offend you.

 Options can be set by chaining them on `modul8()` using the `set(option, value)` method. For example:

    modul8('app.js')
      .set('namespace', 'BOOM')
      .set('domloader', domloader_fn)
      .domains().add('app', dir+'/app/client/')
      .compile('./out.js');

### Code Analysis

 To dynamically resolve dependencies from a single entry point, modul8 does a recursive analysis of the `require()`d code.
 To avoid getting stuck in an infinite loop, modul8 enforces the **no circular dependencies rule**. Granted, this is possible
 with sufficient fiddling, but it brings one major disadvantages to the table:

 A circularly dependent set of modules are tightly coupled; they are really no longer a set of moudles, but more of a library.
 There are numerous sources talking about [why is tight coupling is bad](http://www.google.com/search?q=tight+coupling+bad) so this
 will not be covered here. Ignore this warnig at your own risk (regardless of whether or not you end up using modul8).

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
 The prefix refers to the domain (dom::) prefix that may or may not have been used in the require, and similarly, suffix refers to the file extension.
 Defaults for thes are : `{prefix: true, suffix: false}`.

### Environment Conditionals

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

