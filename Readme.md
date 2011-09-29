# Brownie - Bake and glaze web applications

 Brownie is a modularity enforcing code and style bundler for [NodeJS](http://nodejs.org) web applications.
 The code bundler, `brownie.bake`, will dynamically pull in dependencies from multiple domains and compile the dynamically ordered set of dependencies
 down to a single browser compatible JavaScript file. It compiles CommonJS modules written in JavaScript or CoffeeScript, in such a way that they remain
 fully compatible with NodeJS whenever they do not reference browser only dependencies (e.g. the DOM, non-CommonJS browser libs).
 This compatibility opens up for shared code domains that can be required by both the server and the client seemlessly, but dont be alarmed, what code
 gets pulled is loggable as an npm like dependency tree.

 The style bundler, `brownie.glaze`, is in production for the moment, but its aims are similar.


## Bake Features
  - client-side require
  - compiles CommonJS compatible JavaScript or CoffeeScript
  - compilation of application code is dynamic and based only on an input of the entry point
  - non-CommonJS compatible files can be listed in the order they should be included (before the rest of the app)
  - CommonJS modules can work in both NodeJS and the browser if they do not reference external dependencies
  - low footprint - only ~70 lines pre-pended to the compiled file (no extra file to include - no assumed dependencies)
  - enforces modularity best practices (no circular dependencies allowed from the start, and helps analyse your require tree)
  - require tree is displayed in the style of `npm list`
  - compilation only pulls in what is explicitly required - no need to ever manipulate your include list
  - application specific data can be pulled into the compilation process and the result is also required on the browser
  - minimizes browser global usage -> attaches you application data to the namespaced `window.(namespace || 'Brownie')`
  - ideal for single page web applications - only 1 or 2 HTTP requests to get all your code + possibly templates

## Installation

via npm: coming


# Baking - Compiling scripts

### Usage
```js
brownie = require('brownie');
brownie.bake({
  target   : dir+'/public/js/target.js',
  domains  : {
    shared    : dir+'/shared/',
    app       : dir+'/app/'
  },
  libDir   : dir+'/libs/',
  libFiles : ['jquery.js', 'history.js'],

  minify   : (environment == 'production')
});
```
### Bake Options

 - `target`         File to write to (must be referenced by your template).
 - `domains`        Object of form domainName, domainPath in no particular order. Think of these as your require paths on the browser. You can define as many/few as you want, but you need at least one 'main' domain.
 We use an array for this interface rather than an object because order may become important. At the moment, all non-client code gets included first, then all the client code.
 - `mainDomain`     What key in above domains parameter is the main domain? Default 'app'.
 - `data`           Object of form key,val == name, pullFn. This will make the output of the pullFn requireable on the browser under 'data::name'. Useful for generating dynamic (app specific) data in the targetjs.
 - `entryPoint`     Name of the main file from which your app is launched. Defaults to 'main.coffee'. It must lie on the 'mainDomain'.
 - `namespace`      Global variable to encapsulate browser state to. Defaults to 'Brownie'. Unless you go digging in the output source, this should never need to be referenced directly.
 - `libDir`         Directory to find external libraries that you wish to include outside of the require system.
 - `libFiles`       List of files to include in order. Note: libDir+libFiles[i] must exist for all i.
 - `libsOnlyTarget` Optional file to write lib files to. This makes the output of brownie quickly distinguishable from your big libraries, and people won't have to redownload that part of the code everytime you change your app code.
 - `minify`         Whether to pass the the output file through a minifier before writing to disk. Defaults to false.
 - `minifier`       What minifier to use. Supply a `(codeStr) -> minifiedStr` function. Defaults to [UglifyJS](http://github.com/mishoo/UglifyJS).
 - `DOMLoadWrap`    DOMContentLoaded wrapper function. It defaults to the famous `(code) -> "$(function(){"+code+"});"` function - commonly known as the jQuery wrapper. Lacking jQuery; supply your function of choice.
 - `localTests`     Bool to determine whether to chuck the standalone module code before bundling/looking for dependencies. Avoids pulling in test dependencies or test code.
 It is a bit raw at the moment, as it indiscriminately chucks everything from and including the line where 'require.main' is referenced in your code. Enable with caution for now.


There are also 4 optional booleans for configuring the prettified require tree:
 - `treeTarget`     Where to write the current prettified require tree to. Useful for code analysis. Not set by default.
 - `logTree`        Boolean to determine if you want the prettified dependency passed to console.log. Default false. If neither treeTarget nor logTree is set, then the remaining values are discarded.
 - `extSuffix`      Boolean to determine whether the extension name is suffixed to the name of each file in the require tree. Default false.
 - `domPrefix`      Boolean to determine whether the domain of the file is prefixed to the name of each file in the require tree. Default false.

## Notes on require()

There are four different ways to use require:

 - **Globally**:        I.e. `require('subfolder/module')`. This will scan all the domains (except data) for a matching structure, starting the search at your current location.
 A gloabl require does not care about your current location.

 - **Relatively**:      I.e. `require('./module.js')`. This will scan only the current domain and the current folder
 You can keep chaining on '../' to go up directories, but this has to happen in the beginning of the require string:
 `require('./../subfolder/../basemodule.js')` **is not legal** while `require('./../basemodule.js')` **is**.

 - **Domain Specific**  I.e. `require('shared::val.js')`. Scans a specific domain (only) as if it were a global require from within that domain.
 You cannot do relative requires combined with domain prefixes as this is either non-sensical (cross domain case: folder structure between domains lost on the browser),
 or unnecessary (same origin case: you should be using relative requires).

 - **Data Domain**:     I.e. `require('data::datakey')`. The data domain is special. It is there to allow requiring of data that was passed in through the `data` option to `bake`.
 It does not arise from physical files, and will not show up in the dependency tree. It is simply data you have attached deliberately.

 **Note** File extensions are never required, but you can include them for specificity (except for on the data domain).
 While resolving (on the server), Brownie will try first the name, then try to append .js to the string, finally try to append .coffee. If any of these resolve it will be included.
 This means there's more chance for overlap if you omit the extensions: so _do not keep .js and .coffee versions in the same folder_ or you will become frustrated fast).

## Notes on the data domain
This is the main entry point for plugins. Here are some appropriate things that it is useful for:

- 1a. exporting all your templates to data::templates.
- 1b. exporting template versions to data::versions to make sure cached templates are up to date (if not, you could $.get them as you needed)
- 2.  exporting model structure to data::models to avoid duplicating mongoose (say) logic
- 3.  exporting applications default options for drop downs to data::defaults

All you have to do to use this is either directly attach the data you have, or build a simple parser to make things browser friendly.

## Modularity Notes
Global variable are evil, and should be kept to a minimum. We know this, and this is were a require system really shines, but it is not going to help you get rid of global usage altogether.
However, it is possible to make yourself completely independent of globals!

You could dedicate your life to a life of non-CommonJS celibacy, or, more sensibly, you could make arbiters for all your old libraries.
jQuery for instance, could be exported through another jQuery.js file with `module.exports = window.jQuery; delete window.jQuery; delete window.$` in its body.
This means you can use `$ = require('jQuery')` so everything will be explicitly defined, plus you've deleted the global shortcuts so that you will know when you forgot to require.

Clearly this as some advantages. By having all requires of jQuery explicitly defined you know exactly what parts of your code depend on it. It will show up in your require tree, and
you will quickly identify what code is actually DOM dependent, and what isnt or shouldnt be.

Brownie already does some of this for you anyway, it allows at most your mainDomain to wait for the DOM. If you can figure out how to separate on the domain level, then you are already
good on your way to resolving spaghetti hell. Perhaps coupling this remaining domain tightly with jQuery isnt _that_ bad. Probably not. But by not having it available everywhere,
it is easier to see what actually needs it and what doesn't. Who knows, maybe we can make some smarter or more elegant MVC or MVC like frameworks with such things in mind.

An extra point here to note is that most of the time you will want to require the plugin extended jQuery, not just the basic version. `require('jQuery')` does not imply extensions.
However, all jQuery plugins have extend a global variable, so they can all be listed on the libFiles list in order. Thus, since all required code, including our arbiter,
is added after libFiles, require will always fetch the extended version. So this is sort of okay. You dont really want every plugin to show up at every point in the require tree anyway,
so it's good that it's happening only once, but you also have no control of this code from inside your app.

Anyway. With jQuery you have bigger modularity issues to battle with than these, for those still struggling with these:
#### My advice is
Think about the behaviour you are defining, if it is for

- non-request based DOM interactivity - it is almost always better to write a plugin (include these as libFiles)
- request based DOM interactivity - you should use controllers/views + above plugins and or possibly more DOM plugins.
- calculations needed for DOM manipulation - you should make a standalone calulation module that should work on its own - call it at appropriate stages above.

This way if something breaks, you should be easily able to narrow down the problem to a UI error, a flow error, or a calculation error. => Debugging becomes 3 times easier.

#### Ultimately
Brownie just provides a lot of basic rules for helping build maintainable code.
You need to always remember to:

- Not blend all the above behaviour together in one file.
- Limit the domains you reference global variables.
- Split independent code onto different domains.
- Always keep looking at your code and try to figure out if you defining multiple types of behaviour somewhere. If you are, split it up.
- Enforce basic rules of JavaScript modularity: don't try to make circular dependencies work, analyse your require tree. If you are requiring the same library from every file, chances are you are doing something wrong.

Decouple your code this way and you will save yourself the trouble of later having to learn from your mistakes the hard way.
Hopefully, Brownie can help.

## Comments and Feedback
Brownie is still a relatively fresh project of mine. Feel free to give me traditional github feedback or help out.
The `bake` API is, in my opinion, pretty much done.
However, the CSS bundling implementation - `glaze` - is still up in the air.
...
# Glazing - Compiling stylesheets
In development. The API will look something like this.

```coffee
brownie.glaze
  target : './public/css/target.css'
  minify : environment is 'production'
```


## License

(The MIT License)

Copyright (c) 2009-2010 Eirik Albrigtsen;

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
