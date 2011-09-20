# Brownie - browser bakery and glazery

 Brownie is a code and style bundler for the browser applications inspired by [RequireJS](http://requirejs.org/)
 and [Hem](http://github.com/maccman/hem). It is implemented with CoffeeScript for [node](http://nodejs.org),
 and allows bundling of shared code without heavy modification of your environment or require calls.
 
## STILL IN HEAVY PRODUCTION!

## Features

  - client-side require
  - bundles JavaScript or CoffeeScript
  - bundles classic window exporting modules
  - bundles CommonJS modules
  - enforces modularity best practices (no circular dependencies allowed)
  - automatically resolves the require tree and concatenates your required scripts in the right order
  - allows dumping of the prettified require tree for full overview of your code
  - configurable shared code directory can include libraries available both on the server and the client
  - pulls in templates / (mongoose?) models / template versions if configured
  - minimizes browser global usage -> attaches modules to a tree under window.(appName || 'Brownie')
  - ideal for single page web applications (bundles all you need)

## Installation

via npm: coming


## Usage


```coffee
brownie = require 'brownie'

brownie.bake
  target    : './public/js/target.js'
  minify    : environment is 'production'
  
  clientDir : './app/client/'
  libDir    : './app/client/lib/'
  sharedDir : './app/shared/'

brownie.glaze
  target : './public/css/target.css'
  minify : environment is 'production'
```

### Options

 - `target`       File to write to (must be referenced by your template) - required
 - `minify`       Defaults to false 
 - `clientDir`    Client code directory (should include all your personal MVC/MVVM/spaghetti code)
 - `sharedDir`    Shared code directory (should include files needed on both server and client, but have no external dependencies in client or server code)
 - `basePoint`    Base file where your app is launched. Defaults to 'app'.
 - `appName`      Global object to export everything to. Defaults to 'Brownie'.
 - `treeTarget`   Where to write the current prettified require tree to. Optional.


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
