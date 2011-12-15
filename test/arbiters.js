var assert    = require('assert')
  , fs        = require('fs')
  , path      = require('path')
  , zombie    = require('zombie')
  , rimraf    = require('rimraf')
  , mkdirp    = require('mkdirp').sync
  , coffee    = require('coffee-script')
  , detective = require('detective')
  , modul8    = require('./../index.js')
  , utils     = require('./../lib/utils')
  , analysis  = require('./../lib/analysis')
  , resolver  = require('./../lib/resolver')
  , join      = path.join
  , dir       = __dirname
  , read      = utils.read
  , Resolver = resolver.Resolver;

function setup (sub, libPrefix) {
  if (libPrefix == null) libPrefix = 'glob';

  var options = {
    paths: {
      app     : join(dir, 'arbiters', sub, 'app')
    , shared  : join(dir, 'arbiters', sub, 'shared')
    , libs    : join(dir, 'arbiters', sub, 'libs')
    }
  , out: {
      app     : join(dir, 'output', 'outarb' + sub + '.js')
    , libs    : join(dir, 'output', 'outarblibs' + sub + '.js')
    }
  };

  function makeApp (requireLibs) {
    Object.keys(opitons.paths).forEach(function (p) {
      mkdirp(join(dir, 'arbiters', sub, p + '.js'), 0755)
    });

    var l = [];
    var nums = [0, 1, 2];
    nums.forEach(function (i) {
      fs.writeFileSync(join(options.paths.libs, libPrefix + i + '.js'), "(function(){window['" + libPrefix + i + "'] = 'ok';})();");
      fs.writeFileSync(join(options.paths.app, i + '.js'), "module.exports = 'ok';");
      fs.writeFileSync(join(options.paths.shared, i + '.js'), "module.exports = 'ok';");
      l.push("exports.app_" + i + " = require('./" + i + "'); ");
      l.push("exports.shared_" + i + " = require('shared::" + i + "');");
      if (requireLibs) {
        l.push("exports.libs_" + i + " = require('M8::" + libPrefix + i + "');");
      }
    });
    return fs.writeFileSync(path.join(options.paths.app, 'entry.js'), l.join('\n'));
  };
  var compileApp = function(useLibs, separateLibs, useArbiters) {
    var arbs, i, k, keys, _i, _len;
    keys = (function() {
      var _results;
      _results = [];
      for (i = 0; i < 3; i++) {
        _results.push(libPrefix + i);
      }
      return _results;
    })();
    arbs = {};
    for (_i = 0, _len = keys.length; _i < _len; _i++) {
      k = keys[_i];
      arbs[k] = k;
    }



    modul8(options.paths.app + 'entry.js')
      .analysis()
      .output(!libPrefix ? console.log : false)
      .suffix(true)
      .arbiters(useLibs && useArbiters ? arbs : {})
      .set('logging', false)
      .set('domloader', function(a) {
        return a;
      })
      .set('force', true)
      .libraries()
        .list(useLibs ? (function() {
          var _results;
          _results = [];
          for (i = 0; i < 3; i++) {
            _results.push(libPrefix + i + '.js');
          }
          return _results;
        })() : false)
        .path(options.paths.libs)
        .target(separateLibs ? options.out.libs : false)
      .domains()
        .add('shared', options.paths.shared)
      .compile(options.out.app);
  };
  return [makeApp, compileApp, options];
}

compile = utils.makeCompiler();

exports["test arbiters#priority"] = function() {
  try {
    rimraf.sync(join(dir, 'arbiters'));
  } catch (e) {}
  mkdirp(join(dir, 'arbiters'), 0755);


  count = 0;
  exts = ['', '.js', '.coffee'];
  compile = utils.makeCompiler();
  run = function(suf, libReq) {
    var arbs, ca, compileApp, doms, makeApp, name, opts, order, path, wantedLen, _ref, _ref2;
    _ref = setup('noglob' + suf, ''), makeApp = _ref[0], compileApp = _ref[1], opts = _ref[2];
    doms = {};
    _ref2 = opts.paths;
    for (name in _ref2) {
      path = _ref2[name];
      if (name !== 'libs') doms[name] = path;
    }
    makeApp(libReq);
    arbs = libReq ? {
      '0': ['0'],
      '1': ['1'],
      '2': ['2']
    } : {};
    ca = analysis({
      entryPoint: 'entry.js',
      domains: doms,
      arbiters: arbs,
      exts: exts,
      ignoreDoms: []
    }, function(a) {
      return a;
    }, compile);
    order = ca.sorted();
    assert.includes(order[order.length - 1], 'entry.js', "ordered list includes entry when libsRequired=" + libReq);
    order.pop();
    wantedLen = 6;
    assert.equal(order.length, wantedLen, "order contains all files when libsRequired=" + libReq);
    return count += 2;
  };
  run('a', false);
  run('b', true);
  return console.log('arbiters#priority - completed:', count);
};

testCount = 0;

num_tests = 7;

testsDone = function(count) {
  testCount += count;
  num_tests -= 1;
  if (!num_tests) return console.log('arbiters#handling - completed:', testCount);
};

exports["test arbiters#handling"] = function() {
  var arbiterOptions, arbitersOn, b, libsOn, libsRequired, libsSeparate, o, optionAry, requireLibs, separateLibs, testNum, useArbiters, useLibs, _fn, _i, _j, _k, _l, _len, _len2, _len3, _len4, _ref;
  try {
    rimraf.sync(path.join(dir, 'arbiters'));
  } catch (e) {

  }
  return;
  fs.mkdirSync(path.join(dir, 'arbiters'), 0755);
  requireLibs = false;
  useLibs = false;
  separateLibs = false;
  useArbiters = false;
  testNum = 0;
  b = [];
  o = [];
  _ref = [true, false];
  for (_i = 0, _len = _ref.length; _i < _len; _i++) {
    libsOn = _ref[_i];
    optionAry = libsOn ? [false, true] : [false];
    for (_j = 0, _len2 = optionAry.length; _j < _len2; _j++) {
      libsSeparate = optionAry[_j];
      for (_k = 0, _len3 = optionAry.length; _k < _len3; _k++) {
        arbitersOn = optionAry[_k];
        arbiterOptions = arbitersOn ? [true, false] : [false];
        _fn = function(k, useLibs, separateLibs, useArbiters, requireLibs) {
          var compileApp, makeApp, _ref2;
          _ref2 = setup(k), makeApp = _ref2[0], compileApp = _ref2[1], o[k] = _ref2[2];
          makeApp(requireLibs);
          compileApp(useLibs, separateLibs, useArbiters);
          b[k] = new zombie.Browser();
          return b[k].visit('file:///' + dir + "/empty.html", function(err, browser, status) {
            var count, domain, i, libCode, mainCode, path, _ref3;
            if (err) throw err;
            count = 2;
            if (separateLibs) {
              libCode = compile(o[k].out.libs);
              assert.isUndefined(browser.evaluate(libCode), ".compile() result evaluates successfully");
              assert.ok(browser.evaluate("window.glob0 === 'ok'"), "glob" + i + " exists before arbiters kick in (useArbiters = " + useArbiters + ")");
              count += 2;
            }
            mainCode = compile(o[k].out.app);
            assert.isUndefined(browser.evaluate(mainCode), ".compile() to " + o[k].out.app + " gives an evaluable result");
            assert.isDefined(browser.evaluate("M8"), "global namespace is defined");
            _ref3 = o[k].paths;
            for (domain in _ref3) {
              path = _ref3[domain];
              if (domain !== 'libs') {
                for (i = 0; i < 3; i++) {
                  assert.ok(browser.evaluate("M8.require('" + domain + "::" + i + ".js') === 'ok'"), "can require " + domain + "::" + i + " from app");
                  count += 1;
                }
              }
            }
            for (i = 0; i < 3; i++) {
              if (useLibs) {
                if (useArbiters) {
                  assert.isUndefined(browser.evaluate("window.glob" + i), "window.glob" + i + " has been deleted");
                  assert.ok(browser.evaluate("M8.require('M8::glob" + i + "') === 'ok'"), "glob" + i + " arbiter exist");
                } else {
                  assert.ok(browser.evaluate("window.glob" + i + " === 'ok'"), "glob" + i + " exists when !useArbiters");
                  assert.isUndefined(browser.evaluate("M8.require('M8::glob" + i + "')"), "glob" + i + " arbiter does not exist");
                }
              } else {
                assert.isUndefined(browser.evaluate("window.glob" + i), "window.glob" + i + " does not exist when !useLibs, useArbiters==" + useArbiters);
                assert.isUndefined(browser.evaluate("M8.require('M8::glob" + i + "')"), "glob" + i + " arbiter does not exist when !useLibs, useArbiters==" + useArbiters);
              }
              count += 2;
            }
            return testsDone(count);
          });
        };
        for (_l = 0, _len4 = arbiterOptions.length; _l < _len4; _l++) {
          libsRequired = arbiterOptions[_l];
          _fn(testNum, libsOn, libsSeparate, arbitersOn, libsRequired);
          testNum++;
        }
      }
    }
  }
};

