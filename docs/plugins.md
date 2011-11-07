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

The skeleton of such a plugin class should look something like this in CoffeeScript

    class Plugin
      constructor : (@o={}) ->
        @o.domain or= 'domainName'
        @o.key    or= 'dataKey'

      data  : ->
        [@o.key, s]

      domain : ->
        [@o.domain, __dirname+'/dom/']

The `data` method must return a pair [key, s] where `key` is the key to attach `s` to on the data domain.

You can return almost anything as `s`. The domain of what is legal is the set of `s` where `JSON.parse(JSON.stringify(s))` is the identity.
Objects, Arrays, and Numbers satisfy this because they serialize and unserialize with ease.
On the other hand Date objects do not parse, and functions do not properly serialize because they expect closured state at creation place.
If you wish to send such objects (or Objects containing such objects), you should pre-serialize it to a JavaScript string that will `eval` to what you want.

The `domain` method must return a pair [name, path] where name is the domain name to export, and path is the path corresponding to the root of this domain.
If a domain is exported, it should be clear on the server what files are available to the client by looking at the directory structure of the plugin.
It is recommended to put all these files within a `dom` subdirectory of your node module `lib` root.

The domain name and the data key should be configurable from the class constructor, and should have semantic defaults.
