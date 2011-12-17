var fs            = require('fs')
  , path          = require('path')
  , _             = require('underscore')
  , analyzer      = require('./analyzer')
  , Persister     = require('./persist')
  , type          = require('./type')
  , utils         = require('./utils')
  , logule        = require('logule')
  , join          = path.join
  , dir           = __dirname
  , makeCompiler  = utils.makeCompiler
  , exists        = utils.exists
  , read          = utils.read
  , error         = utils.error;

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
function bundleApp(codeList, ns, domload, compile, before, o) {
  var l = [];

  // 1. construct the global namespace object
  l.push("window." + ns + " = {data:{}};");

  // 2. pull in serialized data
  Object.keys(o.data).forEach(function (name) {
    return l.push(ns + ".data." + name + " = " + o.data[name] + ";");
  });

  // 3. attach require code
  var config = {
    namespace: ns,
    domains: Object.keys(o.domains),
    arbiters: o.arbiters,
    logging: o.logLevel
  };

  l.push(anonWrap(read(join(dir, 'require.js'))
    .replace(/VERSION/, JSON.parse(read(join(dir, '..', 'package.json'))).version)
    .replace(/REQUIRECONFIG/, JSON.stringify(config))
  ));

  // 4. include CommonJS compatible code in the order they have to be defined
  var defineWrap = function (exportName, domain, code) {
    return ns + ".define('" + exportName + "','" + domain + "',function(require, module, exports){\n" + code + "\n});";
  };

  // 5. filter function splits code into app and non-app code and defineWraps
  var harvest = function (onlyMain) {
    return codeList.map(function (pair) {
      var dom = pair[0]
        , file = pair[1]
        , basename = file.split('.')[0];
      if ((dom === 'app') !== onlyMain) {
        return;
      }
      var code = before(compile(join(o.domains[dom], file)));
      return defineWrap(basename, dom, code);
    }).filter(function (e) {
      return !!e;
    });
  };

  // 6.a) include modules not on the app domain
  l.push("\n// shared code\n");
  l.push(harvest(false).join('\n'));

  // 6.b) include modules on the app domain, and wait for domloader if set
  l.push("\n// app code - safety wrap\n\n");
  l.push(domload(harvest(true).join('\n')));

  // 7. use a closure to encapsulate the private internal data and APIs
  return anonWrap(l.join('\n'));
}

module.exports = function (o) {
  var useLog = o.options.logging && !type.isFunction(o.target)
    , log = o.logger
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
  var a = analyzer(o, before, compile);

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
      , c = after(bundleApp(codeList, ns, dw, compile, before, o)); // application code

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

      if (o.libsOnlyTarget && libsUpdated && !type.isFunction(o.libsOnlyTarget)) {
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

