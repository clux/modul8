var fs            = require('fs')
  , path          = require('path')
  , _             = require('underscore')
  , analyzer      = require('./analyzer')
  , Persister     = require('./persist')
  , type          = require('./type')
  , utils         = require('./utils')
  , log           = utils.logule
  , join          = path.join
  , dir           = __dirname
  , makeCompiler  = utils.makeCompiler
  , exists        = utils.exists
  , read          = utils.read
  , error         = utils.error
  , builtInDir    = join(__dirname, '..', 'builtins')
  , builtIns      = ['path', 'events']
  , serverModules = ['fs', 'sys', 'util'];

function id(a) {
  return a;
}

// helpers
function anonWrap(code) {
  return "(function(){\n" + code + "\n}());";
}

function makeWrapper(ns, fnstr, hasArbiter) {
  if (!fnstr) {
    return anonWrap;
  }
  var location = hasArbiter ? ns + ".require('M8::" + fnstr + "')" : fnstr;
  return function (code) {
    return location + "(function(){\n" + code + "\n});";
  };
}

// analyzer will find files of specified ext, but these may clash on client
function verifyCollisionFree(codeList) {
  codeList.forEach(function (pair) {
    var dom = pair[0]
      , file = pair[1]
      , uid = dom + '::' + file.split('.')[0];

    codeList.forEach(function (inner) {
      var d = inner[0]
        , f = inner[1]
        , uidi = d + '::' + f.split('.')[0];

      if (!(d === dom && f === file) && uid === uidi) {
        error("two files of the same name on the same path will not work on the client: " + dom + "::" + file + " and " + d + "::" + f);
      }
    });
  });
}

// main application packager
function bundleApp(codeList, ns, domload, compile, before, npmTree, o) {
  var l = []
    , usedBuiltIns = npmTree._builtIns
    , len = 0;
  delete npmTree._builtIns;

  // 1. construct the global namespace object
  l.push("window." + ns + " = {data:{}, path:{}};");

  // 2. attach path code to the namespace object so that require.js can efficiently resolve paths
  l.push('\n// include npm::path');
  var pathCode = read(join(builtInDir, 'path.posix.js'));
  l.push('(function (exports) {\n ' + pathCode + '\n}(window.' + ns + '.path));');

  // 3. pull in serialized data
  Object.keys(o.data).forEach(function (name) {
    return l.push(ns + ".data." + name + " = " + o.data[name] + ";");
  });

  // 4. attach require code
  var config = {
    namespace : ns
  , domains   : Object.keys(o.domains) // TODO: remove npm from here
  , arbiters  : o.arbiters
  , logging   : o.logLevel
  , npmTree   : npmTree
  , builtIns  : builtIns
  , slash     : '/' //TODO: figure out if different types can coexist, if so, determine in resolver, and on client
  };

  l.push(anonWrap(read(join(dir, 'require.js'))
    .replace(/VERSION/, JSON.parse(read(join(dir, '..', 'package.json'))).version)
    .replace(/REQUIRECONFIG/, JSON.stringify(config))
  ));

  // 5. include CommonJS compatible code in the order they have to be defined
  var defineWrap = function (exportName, domain, code) {
    return ns + ".define('" + exportName + "','" + domain + "',function (require, module, exports) {\n" + code + "\n});";
  };

  // 6. harvest function splits code into app and non-app code and defineWraps
  var harvest = function (onlyMain) {
    codeList.forEach(function (pair) {
      var dom = pair[0]
        , file = pair[1]
        , basename = file.split('.')[0];
      if ((dom === 'app') !== onlyMain) {
        return;
      }
      var code = before(compile(join(o.domains[dom], file)));
      l.push(defineWrap(basename, dom, code));
    });
  };

  // 7.a) include required builtIns
  l.push("\n// node builtins\n");
  len = l.length;
  usedBuiltIns.forEach(function (b) {
    if (b === 'path') { // already included
      return;
    }
    l.push(defineWrap(b, 'npm', read(join(builtInDir, b + '.js'))));
  });
  if (l.length === len) {
    l.pop();
  }

  // 7.b) include modules not on the app domain
  l.push("\n// shared code\n");
  len = l.length;
  harvest(false);
  if (l.length === len) {
    l.pop();
  }

  // 7.c) include modules on the app domain, and wait for domloader if set
  l.push("\n// app code - safety wrapped\n\n");
  domload(harvest(true));

  // 8. use a closure to encapsulate the private internal data and APIs
  return anonWrap(l.join('\n'));
}

module.exports = function (o) {
  var useLog = o.options.logging && !type.isFunction(o.target)
    , persist = new Persister([o.target, o.libsOnlyTarget], o.options.persist, log.get('debug'))
    , ns = o.options.namespace
    , dw = o.options.domloader
    , before = o.pre.length > 0 ? _.compose.apply({}, o.pre) : id
    , after = o.post.length > 0 ? _.compose.apply({}, o.post) : id
    , compile = makeCompiler(o.compilers)
    , forceUpdate = o.options.force || persist.optionsModified(o);

  // deleting output should force re-compile
  forceUpdate |= !type.isFunction(o.target) && !exists(o.target);

  if (!type.isFunction(dw)) { // special domloader string need to be converted to fn
    dw = makeWrapper(ns, dw, dw in o.arbiters);
  }

  // do the recursive analysis
  var a = analyzer(o, before, compile, builtIns, serverModules);

  if (o.treeTarget) {
    var tree = a.print(o.extSuffix, o.domPrefix);
    if (type.isFunction(o.treeTarget)) {
      o.treeTarget(tree);
    } else {
      fs.writeFileSync(o.treeTarget, tree);
    }
  }

  if (o.target) {
    var codeList = a.sort();

    verifyCollisionFree(codeList);


    var libsUpdated = false
      , appUpdated = persist.filesModified(codeList, o.domains, 'app')
      , c = after(bundleApp(codeList, ns, dw, compile, before, a.npm(), o)); // application code

    if (o.libDir && o.libFiles) {

      var libMap = o.libFiles.map(function (f) {
        return ['libs', f];
      });
      libsUpdated = persist.filesModified(libMap, {libs: o.libDir}, 'libs');
      var libs;

      if (libsUpdated || (appUpdated && !o.libsOnlyTarget) || forceUpdate) {
        libs = after(o.libFiles.map(function (file) {
          return compile(join(o.libDir, file));
        }).join('\n'));
      }

      var forceUpdateLibs = !type.isFunction(o.libsOnlyTarget) && !exists(o.libsOnlyTarget);

      if (o.libsOnlyTarget && (libsUpdated || forceUpdateLibs) && !type.isFunction(o.libsOnlyTarget)) {
        fs.writeFileSync(o.libsOnlyTarget, libs);
        log.info('compiling separate libs');
        libsUpdated = false;
      }
      else if (type.isFunction(o.libsOnlyTarget)) {
        o.libsOnlyTarget(libs);
      }
      else if (!o.libsOnlyTarget) {
        c = libs + c;
      }
    }

    if (type.isFunction(o.target)) {
      return o.target(c);
    }

    if (appUpdated || (libsUpdated && !o.libsOnlyTarget) || forceUpdate) {
      log.info('compiling app');
      fs.writeFileSync(o.target, c);
    }
  }
};

