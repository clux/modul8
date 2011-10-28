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

    $ modul8 app/entry.js -p shared:shared/ > output.js

from the `code/` directory.

This assumes the name of the main domain is the name of the folder where `entry` lives, i.e. `app` in this case.

If you want to hold of the DOM using jQuery, append the `-w jQuery` option (see wrapper below).

### Advanced

#### Domains
Multiple domains are specified using a comma separated list of name:path values.

    $ modul8 app/entry.js -p shared:shared/,bot:../libs/bot/ > output.js

### Arbiters
Loading of arbiters works like the programmatic API:

    $ modul8 app/entry.js -a jQuery:jQuery.$,Spine:Spine > output.js

We can omit the colon for arbiters were the shortcut has the same name as the global.

    $ modul8 app/entry.js -a jQuery:jQuery.$,Spine > output.js

The globals to delete for a given shortcut is delimited by a dot.

### Data Injection
Data injection works fundamentally different from the shell than from your node program. Here you rely on your data pre-existing in a `.json` file and specify what key to attach it to.

    $ modul8 app/entry.js -d myKey:myData.json > output.js

Multiple data files can be imported by comma separating the above -d input

    $ modul8 app/entry.js -d myKey:myData.json,mySecondKey:mySecondData.json > output.js


### Extra Options

    -w or --wrapper <str> - name of global domloader (see API) function used to wait for DOM ready
    -n or --namespace <str> - name of the single global object used by modul8's live API

#### Booleans

    -l or --logging enables logging of client side requires
    -t or --testcut enables the use of the built in modul8.testcutter
    -m or --minify enables the use of the built in modul8.minifier
    -z or --analyze enables the analyzer and returns its output rather than the compiled result
