# API
Want more details about certain sections? There's a more [extensive API doc](api.html) available.

## modul8() and .compile()

Statically analyze `entryFile` and its requirements recursively,
and bundle up all dependencies in a browser compatible `targetFile`.

    var modul8 = require('modul8');
    modul8(entryFile)
      //chain on options here
      .compile(targetFile);

## Options
The following can be inserted verbatim as chained options on the modul8
constructor, and a working `.compile()` call will end any further chaining.

### domains()
Allow requiring code from namespaced domains,

    .domains()
      .add('shared', './shared')
      .add('internal', './internal')

Or equivalently:

    .domains({
      'shared'   : './shared'
    , 'internal' : './internal'
    })

Both would allow `require('shared::file')` to resolve on the client when
`file.js` exists on `./shared`.

Reserved domain names:

 - M8
 - data
 - external
 - npm

### data()
Injects raw data in the `data` domain from the server.

    .data()
      .add('models', {user: {name: 'clux', type: 'String'})
      .add('versions', "{'templates' : 123}")

Or equivalently

    .data({
      models  : {user: {name: 'clux', type: 'String'}}
    , version : "{'templates' : 123}"
    })

Values will be serialized using `JSON.stringify` if they are not strings,
otherwise, they are assumed to be serialized.

### use()
Call with [Plugin](plugins.html) instance(s).

    .use(new Plugin())

### analysis()
View the analyzers prettified output somehow.

    .analysis()
      .output(console.log)
      .prefix(false)
      .suffix(true)
      .hide('external')

Or equivalently:

    .analysis(console.log, false, true, 'external')

#### output()
Function or file to pipe to.
#### prefix()
Show the domain of each file in the dependency tree. Default true.
#### suffix()
Show the extension of each file in the dependency tree. Default false.
#### hide()
Call with domain(s) to hide from the tree. Default [].

### libraries()
Pre-concatenate in an ordered list of libraries to the target output,
or save this concatenation to a separate `libs` file.

    .libraries()
      .list(['jQuery.js', 'history.js'])
      .path('./app/client/libs/')
      .target('./libs.js')

Or equivalently:

    .libraries(['jQuery.js', 'history.js'], './app/client/libs/', './libs.js')

AltJS libraries are compiled with a safety wrapper, whenever
the the registered language supports this.

### npm()
Set the node_modules directory to allow requiring npm installed modules.

    .npm('./node_modules')

### before()
Pre-process all code before it gets sent to analysis with input function(s).

    .before(function (code) { return code;})

`modul8.testcutter` is an example of such a function.

### after()
Post-process all code after it has been bundled.

    .before(function (code) { return code; })

`modul8.minifier` is an example of such a function.

### set()
Set a few extra options. Available options to set are:

   - `domloader`
   - `namespace`
   - `logging`
   - `force`

#### set('domloader', value)
`domloader` is the name of a global or arbitered function, or a direct substitution
function, which wraps the application domain code and (usually) waits for the DOM.

Examples values:

 - `jQuery`
 - `$(document).ready`
 - function (code) { return "jQuery(function () {" + code + "})"; }
 - `` // blank string - default

The last example simply wraps the app domain code in an anonymous,
self-executing funciton.

#### set('namespace', value)
The name of the global variable used in the browser to export console helpers to.
The default value for this is `M8`.

#### set('logging', value)
This will set the amount of messages sent on the client. Allowed values:

- 'ERROR' - only failed requires are logs **DEFAULT**
- 'DEBUG' - additionally adds debug of what is sent to require
- `false` - no client side logging

### logger()
Pass down a [logule](https://github.com/clux/logule) sub to fully control server side log
output. A passed down instance will attempt to call `.info()`, `.debug()` and `.error()`.

Error messages are used to aid on throws, recommended kept unsuppressed.
If not used, only debug messages are suppressed.

### in()
Only do chainOfStuff() when __NODE_ENV__ matches environment.

    in(environment).chainOfStuff()

To break out of the environment chain, use: `in('all')` or `in(otherEnv)`.

### register()
Register an AltJS language with a compilation function. CoffeeScript can be supported using:

    .register('.coffee', function (code, bare){
      coffee.compile(code, {bare: bare})
    })

### arbiters()
Move browser globals to the require system safely.

    .arbiters()
      .add('jQuery', ['$', 'jQuery'])
      .add('Spine')

Or with object style:

    .arbiters({
      jQuery : ['$', 'jQuery']
      Spine  : 'Spine'
    })

Values are either a list of global names to alias under the key's name, or a single name to alias,
or - when using the chaining add style - undefined to indicate same as key.

## Client API
modul8 exports debug functions and extension functions on the single global variable configurable
via set('namespace').

The following functions exists on this global in the browser only, illustrated with `ns` as the global.
### require()
A console specific version of require can require relatively from the main `app` domain.

    ns.require('./fileOnAppRoot'); // exportObj of file

### data()
Extend the data domain with a new key:

    ns.data('libX', libXobj);
    require('data::libX'); // -> libXobj

Modify a key on the data domain:

    ns.data('libX', {});
    require('data::libX'); // -> {}

Delete a key  on the data domain:

    ns.data('libX'); //unsets
    require('data::libX'); // -> undefined
### external()
Has identical behaviour to `ns.data()`, but modifies the `external` domain,
which is only modified on the server, wheras the `data` domain is initialized on the server.

### domains()
List the domains initialized by modul8

    ns.domains(); // ['data', 'external', 'npm', 'app'] or similar

### inspect()
Logs the contents of a specific domain by name

    ns.inspect('app'); // logs object of keys -> raw export object

Can not be used to actually require things in the console.
