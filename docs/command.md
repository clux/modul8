# Command line tool

modul8 defines an optional command line tool if installed globally with npm, i.e.

    $ npm install -g modul8

This tool is more restrictive than modul8, because it tries to expose the core functionality in as minimal way as possible.
You cannot use it to include your libraries, but these are just concatenated on before the main output anyway, so you could do this manually yourself.

## Usage

### Basic
If you have a directory structure like so:

    code
    ├───app
    └───shared

With your main application files in `code/app/`, with an entry point `entry.js` on that path, and shared code in `code/shared/`,
then it suffices to:

    $ modul8 app/entry.js -d shared:shared/ > output.js

from the `code/` directory.

This assumes the name of the main domain is the name of the folder where `entry` lives, i.e. `app` in this case.

### Advanced

#### Domains
Extra domains are specified using a comma separated list of name:path values.

    $ modul8 app/entry.js -d shared:shared/,bot:../libs/bot/ > output.js

### Arbiters
Loading of arbiters works pretty much like the programmatic API:

    $ modul8 app/entry.js -d shared:shared/ -a jQuery:jQuery.$,Spine > output.js

Omitting the colon on the second arbiter for `Spine` means create a shortcut for `Spine` taken from `window.Spine` then delete this global.
The former means create a shortcut for `jQuery` using `window.jQuery` and delete this and `window.$`.

### Data Injection
Data injection works fundamentally different from the shell than from your node program. Here you rely on your data pre-existing in a `.json` file and specify what key to attach it to.

    $ modul8 app/entry.js -d shared:shared/ - > output.js


#### Misc Options

    -n or --namespace sets the global namespace used inside the output code
    -l or --logging enables logging of client side requires
    -t or --testcut enables the use of the built in modul8.testcutter
    -m or --minify enables the use of the built in modul8.minifier
    -z or --analyze enables the analyzer and returns its output rather than the compiled result
