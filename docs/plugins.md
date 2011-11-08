# Plugins

## Overview

Plugins are shortcuts for exporting both data and code to a domain. They facilitate getting data and their helpers to the browser as one unit,
and help encapsulate logic for the server. Additionally, if designed well, code can be reused on the server on the client.

Plugins can typically be used by calling `.use()` with a `new PluginName(opts)` instance.

    modul8('./client/app.js')
      .use(new PluginName(opts))
      .compile('./out.js');

Note that all code that is exported by plugins have to be explicitly required to actually get pulled into the bundle.


## Available Plugins
A small current selection of available plugins follow. This section might be moved to the wiki.

### Template Version Control System
A simple version control system for web application templates.

If a web application wishes to store all its templates in localStorage, then they can become out of date with the server as they update there.
This module allows these states to simply synchronize with the server.

See the [project itself](https://github.com/clux/m8-templation) for more information and sample model implementations.

### Mongoose in the Browser
A way to use mongoose models on the server to generate validation logic on the client.

A web application using mongodb as its backend and using mongoose as an ORM layer on the server ends up defining a lot of validation logic on the server.
Logic that should be reused on the client. The mongoose plugin will export sanitized versions of your explicitly exported mongoose models, along with helpers
to utilize this data in a helpful way.

See the [project itself](https://github.com/clux/m8-mongoose) for more information.


# Writing Plugins
A plugin can export as many things as it wants to be used on the server, but it needs a class instance of a particular format to be compatible with modul8.

## Structure
The skeleton of such a plugin class should look something like this in CoffeeScript

    class Plugin
      constructor : (@o={}) ->
        @o.domain or= 'domainName'
        @o.key    or= 'dataKey'

      data  : ->
        [@o.key, s]

      domain : ->
        [@o.domain, __dirname+'/dom/']

### data method
The `data` method must return a pair [key, s] or a triple [key, s, serialized], where `key` is the key to attach `s` to on the data domain.
If a triple is exported, the thirt element, `serialized` must be a bool indicating whether `s` is already serialized. If it is a raw object, pass false or just exclude the variable.
If it is a pre-serialized object that requires no further serialization, and evaluates to an object via `eval`, you must return a triple, with `serialized` equal to true.

The value of `s` can be whatever the value sent to modul8's `.data().add(key,s)`. The same [warnings apply](api.html#data) for data injection - avoid putting behaviour on `s`.
Anything that does not serialize well (or contains something that does not), should be pre-serialized to something that will `eval` to what you want.

### domain method
The `domain` method must return a pair [name, path] where name is the domain name to export, and path is the path corresponding to the root of this domain.
If a domain is exported, it should be clear on the server what files are available to the client by looking at the directory structure of the plugin.
It is recommended to put all these files within a `dom` subdirectory of your node module `lib` root.

The domain name and the data key should be configurable from the class constructor, and should have semantic defaults.

## Domain
The domain method, if set, will add a domain for the modul8 build. It will not append the files to the output, unless any of them have been required from the client.
If they are, however, they will pull in the dependencies (althoug only from this domain) they need to operate.

To make most use of domains, try to not duplicate work and note code under `dom/` can be required on the server from the `lib` directory.
For that reason, you may want this code to stay browser agnostic. Of course, sometimes this is not always possible.
If you do have to rely on certain browser elements, do not allow the code to run from this domain (because no non-app domains will wait for the DOM).
Instead make functions that, when called, expects the DOM to be ready, and only use these functions from the app domain.
