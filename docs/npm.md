# npm support

### Usage
Set the node modules directory using the `.npm()` command as follows.

    modul8('./app/client/app.js')
      .npm('./node_modules')
      .compile('./out.js');

### Compatibility
Getting node modules to work on the client requires these modules to be not server reliant.
modul8 goes a long way trying to integrate common node modules (like path), but not everything is going to work.
If you rely on fs file IO, for instance, things will not work.

### Requirability
Everything in the npm folder specified can be required, but it is optimized to obtain modules in the root.
Modules are required like on the server, but you have to specify the npm domain to avoid accidentally pulling in big files when requiring from the main domain.

E.g. `require('npm::backbone')` would pull in underscore, but `require('underscore')` would not necessarily work.

`require('npm::backbone')` with backbone installed, would pull its underscore dependency from either backbone/node_modules/underscore, or underscore.
For underscore to also be easily requirable (and to prevent pulling in copies or different versions),
you should install dependencies like underscore in root, before installing backbone.

In other words, if you want a module's dependencies as well, try to make `npm list` look like this:

    app
     ├───backbone
     └───underscore

rather than this:

    app
     └──┬backbone
        └───underscore

## Builtins

Certain core node modules are conditionally included if they are required.
This is to allow npm modules that only use these core modules in a browser compatible way to work on the client.

Builtins currently include:

- path
- events

Node modules can require buitins as normal, and the app domain can require them from the npm domain directly, e.g. `require('npm::path')`.

Note that path is always included, as it is used ensure the require algorithm used is identical on the server and the browser.
Therefore, requiring it comes at no extra size cost.


