(function() {
  var anonWrap, bundle, codeAnalyis, compile, exists, fs, jQueryWrap, minify, parser, path, pullData, uglify, _ref, _ref2;
  fs = require('fs');
  path = require('path');
  codeAnalyis = require('./codeanalysis');
  _ref = require('./utils'), compile = _ref.compile, exists = _ref.exists;
  _ref2 = require('uglify-js'), uglify = _ref2.uglify, parser = _ref2.parser;
  pullData = function(parser, name) {
    if (!parser instanceof Function) {
      throw new Error("parser for " + name + " is not a function");
    }
    return parser();
  };
  minify = function(code) {
    return uglify.gen_code(uglify.ast_squeeze(uglify.ast_mangle(parser.parse(code))));
  };
  jQueryWrap = function(code) {
    return '$(function(){' + code + '});';
  };
  anonWrap = function(code) {
    return '(function(){' + code + '})();';
  };
  bundle = function(codeList, ns, o) {
    var defineWrap, dom, domain, file, l, name, nsObj, pull_fn, requireConfig, _ref3;
    l = [];
    if (!o.libsOnlyTarget && o.libDir && o.libFiles) {
      l.push(((function() {
        var _i, _len, _ref3, _results;
        _ref3 = o.libFiles;
        _results = [];
        for (_i = 0, _len = _ref3.length; _i < _len; _i++) {
          file = _ref3[_i];
          _results.push(compile(o.libDir + file));
        }
        return _results;
      })()).join('\n'));
    }
    nsObj = {};
    for (name in o.domains) {
      nsObj[name] = {};
    }
    nsObj.data = {};
    l.push("var " + ns + " = " + (JSON.stringify(nsObj)) + ";");
    _ref3 = o.data;
    for (name in _ref3) {
      pull_fn = _ref3[name];
      l.push("" + ns + ".data." + name + " = " + (pullData(pull_fn, name)) + ";");
    }
    requireConfig = {
      namespace: ns,
      domains: (function() {
        var _i, _len, _ref4, _ref5, _results;
        _ref4 = o.domains;
        _results = [];
        for (_i = 0, _len = _ref4.length; _i < _len; _i++) {
          _ref5 = _ref4[_i], dom = _ref5[0], path = _ref5[1];
          _results.push(dom);
        }
        return _results;
      })(),
      fallback: o.fallBackFn
    };
    l.push("var requireConfig = " + (JSON.stringify(requireConfig)) + ";");
    l.push(anonWrap(compile(__dirname + '/require.coffee')));
    defineWrap = function(exportName, domain, code) {
      return "" + ns + ".define('" + exportName + "','" + domain + "',function(require, module, exports){" + code + "});";
    };
    l.push(((function() {
      var _i, _len, _ref4, _results;
      _results = [];
      for (_i = 0, _len = codeList.length; _i < _len; _i++) {
        _ref4 = codeList[_i], name = _ref4[0], domain = _ref4[1];
        if (domain !== 'client') {
          _results.push(defineWrap(name, domain, compile(o.domains[domain] + name)));
        }
      }
      return _results;
    })()).join('\n'));
    l.push(o.DOMLoadWrap(((function() {
      var _i, _len, _ref4, _results;
      _results = [];
      for (_i = 0, _len = codeList.length; _i < _len; _i++) {
        _ref4 = codeList[_i], name = _ref4[0], domain = _ref4[1];
        if (domain === 'client') {
          _results.push(defineWrap(name, 'client', compile(o.domains.client + name)));
        }
      }
      return _results;
    })()).join('\n')));
    return l.join('\n');
  };
  module.exports = function(o) {
    var c, ca, file, libs, tree, _ref3, _ref4, _ref5;
    if (!o.domains) {
      throw new Error("brownie needs domains parameter. Got " + JSON.stringify(o.domains));
    }
    if ((_ref3 = o.basePoint) == null) {
      o.basePoint = 'app.coffee';
    }
    if (!exists(o.domains.client + o.basePoint)) {
      throw new Error("brownie needs a client domain, and the basePoint to be contained in the client domain. Tried: " + clientDom + o.basePoint);
    }
    if (o.domains.data) {
      throw new Error("brownie reserves the 'data' domain for pulled in code");
    }
    if ((_ref4 = o.namespace) == null) {
      o.namespace = 'Brownie';
    }
    if ((_ref5 = o.DOMLoadWrap) == null) {
      o.DOMLoadWrap = jQueryWrap;
    }
    ca = codeAnalyis(o.basePoint, o.domains, o.localTests);
    if (o.target) {
      c = bundle(ca.sorted(), o.namespace, o);
      if (o.minify) {
        if (o.minifier) {
          if (!o.minifier instanceof Function) {
            throw new Error("brownie requires a function as a minifier");
          }
          c = o.minifier(c);
        } else {
          c = minify(c);
        }
      }
      fs.writeFileSync(o.target, c);
      if (o.libsOnlyTarget && o.libDir && o.libFiles) {
        libs = ((function() {
          var _i, _len, _ref6, _results;
          _ref6 = o.libFiles;
          _results = [];
          for (_i = 0, _len = _ref6.length; _i < _len; _i++) {
            file = _ref6[_i];
            _results.push(compile(o.libDir + file));
          }
          return _results;
        })()).join('\n');
        if (o.minifylibs) {
          libs = minify(libs);
        }
        fs.writeFileSync(o.libsOnlyTarget, libs);
      }
    }
    if (o.treeTarget || o.logTree) {
      tree = ca.printed(o.extSuffix, o.domPrefix);
      if (o.treeTarget) {
        fs.writeFileSync(o.treeTarget, tree);
      }
      if (o.logTree) {
        return console.log(tree);
      }
    }
  };
}).call(this);
