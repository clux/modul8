var fs            = require('fs')
  , path          = require('path')
  , _             = require('underscore')
  , codeAnalyis   = require('./analysis')
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

function noop(a) {
  return a;
}

function anonWrap(code) {
  return "(function(){\n" + code + "\n}());";
}

function makeWrapper(ns, fnstr, hasArbiter) {
  if (!fnstr) return anonWrap;
  var location = hasArbiter ? ns + ".require('M8::" + fnstr + "')" : fnstr;
  return function(code) {
    return location + "(function(){\n" + code + "\n});";
  };
};

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

bundleApp = function (codeList, ns, domload, compile, before, o) {
  var l = [];

  l.push("window." + ns + " = {data:{}};");
  Object.keys(o.data).forEach(function (name) {
    var json;
    json = o.data[name];
    return l.push("" + ns + ".data." + name + " = " + json + ";");
  });


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

  var defineWrap = function (exportName, domain, code) {
    return ns + ".define('" + exportName + "','" + domain + "',function(require, module, exports){\n" + code + "\n});";
  };
  var harvest = function (onlyMain) {
    return codeList.map(function (pair) {
      var dom = pair[0]
        , file = pair[1]
        , basename = file.split('.')[0]
      if ((dom === 'app') !== onlyMain) {
        return;
      }
      var code = before(compile(join(o.domains[dom], file)));

      return defineWrap(basename, dom, code);
    }).filter(function (e) {
      return !!e;
    });
  };

  l.push("\n// shared code\n");
  l.push(harvest(false).join('\n'));

  l.push("\n// app code - safety wrap\n\n");
  l.push(domload(harvest(true).join('\n')));

  return anonWrap(l.join('\n'));
};

module.exports = function (o) {
  var useLog = o.options.logging && !type.isFunction(o.target)
    , log = o.logger
    , persist = new Persister([o.target, o.libsOnlyTarget], o.options.persist, log.get('debug'))
    , ns = o.options.namespace
    , dw = o.options.domloader
    , forceUpdate = o.options.force || persist.optionsModified(o);

  forceUpdate |= o.target && !type.isFunction(o.target) && !exists(o.target);

  if (!type.isFunction(dw)) {
    dw = makeWrapper(ns, dw, Object.keys(o.arbiters).indexOf(dw) >= 0);
  }

  var before = o.pre.length > 0 ? _.compose.apply({}, o.pre) : noop;
  var after = o.post.length > 0 ? _.compose.apply({}, o.post) : noop;
  var compile = makeCompiler(o.compilers);


  var ca = codeAnalyis(o, before, compile);

  if (o.treeTarget) {
    tree = ca.printed(o.extSuffix, o.domPrefix);
    if (type.isFunction(o.treeTarget)) {
      o.treeTarget(tree);
    } else {
      fs.writeFileSync(o.treeTarget, tree);
    }
  }
  if (o.target) {
    codelist = ca.sorted();
    verifyCollisionFree(codelist);
    appUpdated = persist.filesModified(codelist, o.domains, 'app');
    c = after(bundleApp(codelist, ns, dw, compile, before, o));
    if (o.libDir && o.libFiles) {
      libsUpdated = persist.filesModified(o.libFiles.map(function(f) {
        return ['libs', f];
      }), {
        libs: o.libDir
      }, 'libs');
      if (libsUpdated || (appUpdated && !o.libsOnlyTarget) || forceUpdate) {
        libs = after(o.libFiles.map(function(file) {
          return compile(join(o.libDir, file));
        }).join('\n'));
      }
      if (o.libsOnlyTarget && libsUpdated && !type.isFunction(o.libsOnlyTarget)) {
        fs.writeFileSync(o.libsOnlyTarget, libs);
        log.info('compiling separate libs');
        libsUpdated = false;
      } else if (type.isFunction(o.libsOnlyTarget)) {
        o.libsOnlyTarget(libs);
      } else if (!o.libsOnlyTarget) {
        c = libs + c;
      }
    } else {
      libsUpdated = false;
    }
    if (type.isFunction(o.target)) return o.target(c);
    if (appUpdated || (libsUpdated && !o.libsOnlyTarget) || forceUpdate) {
      log.info('compiling app');
      fs.writeFileSync(o.target, c);
    }
  }
};

