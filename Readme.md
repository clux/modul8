# Modul8 - web application modularity

 Modul8 is a modularity enforcing code packager for JavaScript web applications.
 It will dynamically pull in dependencies from multiple paths and compile and combine the dynamically ordered set of dependencies
 into a single browser compatible JavaScript file. This means your application can consist entirely of (synchronous) JavaScript/CoffeeScript CommonJS modules, and your code
 can be used verbatim on the server as long as it does not reference browser only dependencies like the DOM.

 Modul8 encourages some of the best practices of software development by allowing code sharing,
 sharing of code by between the client and server by allowing several
 _require domains_ on the client - represented by different paths on the server. Code from any of these domains can reference each other and the the
 require tree will resolve

 Code from your main app domain will pull in depencenies from the
 other domains as needed, and your client code will be callbackless and smooth. What code gets pulled in is loggable as an npm like dependency tree.


## Features
  - client-side require without extra callbacks
  - compiles CommonJS compatible JavaScript or CoffeeScript
  - compilation of application code is dynamic and based only on the entry point and its dependency tree
  - non-CommonJS compatible files can be listed in the order they should be included (will be before the rest of the app)
  - CommonJS modules can work in both NodeJS and the browser if they do not reference external dependencies
  - low footprint - only ~70 lines pre-pended to the compiled file (no extra file to include - no assumed dependencies)
  - enforces modularity best practices (no circular dependencies allowed from the start, and helps analyse your require tree)
  - require tree is displayed in the style of `npm list`
  - only pulls in what is explicitly required - no need to ever manipulate your include list
  - application specific data can be pulled into the compilation process and the result is also required on the browser
  - minimizes browser global usage -> attaches your application data to the namespaced `window.(namespace || 'M8')`
  - ideal for single page web applications - only 1 or 2 HTTP requests to get all your code + possibly templates
  - Can bundle your code separately from your web server code with a short Cakefile

## Installation

via npm: `npm install modul8`
Master branch should be avoided as it is generally unstable.


## Usage

```js
modul8('app.js')
  .domains()
    .add('app', '/app/client/')
    .add('shared', '/app/shared/')
  .compile('dm.js')
```
##

```js
modul8('app.cs')
  .set('domloader', (code) -> code)
  .set('namespace', 'QQ')
  .libraries()
    .list(['jQuery.js','history.js'])
    .path('/app/client/libs/')
    .target('dm-libs.js')
  .domains()
    .add('app', '/app/client/')
    .add('shared', '/app/shared/')
  .data()
    .add('models', '{user:{name: {type:String, max: 10, min: 5}}}')
    .add('versions', '{users/view:[0.2.5]}')
  .analysis()
    .prefix(true)
    .suffix(false)
  .in('development')
    .analysis().output(console.log)
    .post(modul8.minifier)
  .in('all')
    .pre(modul8.testcutter)
    .compile('dm.js')
```

### Bake Options

 - `target`         File to write to (must be referenced by your template).
 - `domains`        Object of form domainName, domainPath in no particular order. Think of these as your require paths on the browser. You can define as many/few as you want, but you need at least one 'main' domain.
 - `mainDomain`     Specifies what key in above domains parameter is the main domain name. Default is 'app'.
 - `data`           Object of form key,val == name, pullFn. This will make the output of the pullFn requireable on the browser under 'data::name'. Useful for generating dynamic (app specific) data in the targetjs.
 - `entryPoint`     Name of the main file from which your app is launched. Defaults to 'main.coffee'. It must lie on the 'mainDomain'.
 - `namespace`      Global variable to encapsulate browser code into. Defaults to 'M8'. Unless you go digging in the output source, this should never need to be referenced directly.
 - `libDir`         Directory to find external libraries that you wish to include outside of the require system.
 - `libFiles`       List of files to include in order. Note: libDir+libFiles[i] must exist for all i.
 - `libsOnlyTarget` Optional file to write lib files to. This makes the output quickly distinguishable from your big libraries, and people won't have to redownload that part of the code everytime you change your app code.
 - `minify`         Whether to pass the the output file through a minifier before writing to disk. Defaults to false.
 - `minifier`       What minifier to use. Supply a `(codeStr) -> minifiedStr` function. Defaults to [UglifyJS](http://github.com/mishoo/UglifyJS).
 - `DOMLoadWrap`    DOMContentLoaded wrapper function. It defaults to the famous `(code) -> "$(function(){"+code+"});"` function - commonly known as the jQuery wrapper. Lacking jQuery; supply your function of choice.
 - `localTests`     Bool to determine whether to chuck the standalone module code before bundling/looking for dependencies. Avoids pulling in test dependencies or test code.
 It is a bit raw at the moment, as it indiscriminately chucks everything from and including the line where 'require.main' is referenced in your code. Enable with caution for now.


There are also 4 optional booleans for configuring the prettified require tree:
 - `treeTarget`     Where to write the current prettified require tree to. Useful for code analysis. Not set by default.
 - `logTree`        Boolean to determine if you want the prettified dependency passed to console.log. Default false. If neither treeTarget nor logTree is set, then the remaining options are meaningless.
 - `extSuffix`      Boolean to determine whether the extension name is suffixed to the name of each file in the require tree. Default false.
 - `domPrefix`      Boolean to determine whether the domain of the file is prefixed to the name of each file in the require tree. Default false.


## Notes on the data domain
This is the main entry point for plugins. Here are some appropriate things that it is useful for:

- 1a. exporting all your templates to data::templates.
- 1b. exporting template versions to data::versions to make sure cached templates are up to date (if not, you could $.get them as you needed)
- 2.  exporting model structure to data::models to avoid duplicating mongoose (say) logic
- 3.  exporting applications default options for drop downs to data::defaults

All you have to do to use this is either directly attach the data you have, or build a simple parser to make things browser friendly.




## Comments and Feedback
Modul8 is still a relatively fresh project of mine. Feel free to give me traditional github feedback or help out.
Modul is Norwegian for module in case people do not understand 1337.
