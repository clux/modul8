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
    var d, defineWrap, dom, domMap, domain, file, l, name, nsObj, pull_fn, requireConfig, _i, _j, _len, _len2, _ref3, _ref4, _ref5, _ref6, _ref7;
    l = [];
    d = o.domains;
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
    _ref3 = o.domains;
    for (_i = 0, _len = _ref3.length; _i < _len; _i++) {
      _ref4 = _ref3[_i], name = _ref4[0], path = _ref4[1];
      nsObj[name] = {};
    }
    nsObj.data = {};
    l.push("var " + ns + " = " + (JSON.stringify(nsObj)) + ";");
    _ref5 = o.data;
    for (name in _ref5) {
      pull_fn = _ref5[name];
      l.push("" + ns + ".data." + name + " = " + (pullData(pull_fn, name)) + ";");
    }
    requireConfig = {
      namespace: ns,
      domains: (function() {
        var _j, _len2, _ref6, _ref7, _results;
        _ref6 = o.domains;
        _results = [];
        for (_j = 0, _len2 = _ref6.length; _j < _len2; _j++) {
          _ref7 = _ref6[_j], dom = _ref7[0], path = _ref7[1];
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
    domMap = {};
    _ref6 = o.domains;
    for (_j = 0, _len2 = _ref6.length; _j < _len2; _j++) {
      _ref7 = _ref6[_j], name = _ref7[0], path = _ref7[1];
      domMap[name] = path;
    }
    l.push(((function() {
      var _k, _len3, _ref8, _results;
      _results = [];
      for (_k = 0, _len3 = codeList.length; _k < _len3; _k++) {
        _ref8 = codeList[_k], name = _ref8[0], domain = _ref8[1];
        if (domain !== 'client') {
          _results.push(defineWrap(name, domain, compile(domMap[domain] + name)));
        }
      }
      return _results;
    })()).join('\n'));
    l.push(o.DOMLoadWrap(((function() {
      var _k, _len3, _ref8, _results;
      _results = [];
      for (_k = 0, _len3 = codeList.length; _k < _len3; _k++) {
        _ref8 = codeList[_k], name = _ref8[0], domain = _ref8[1];
        if (domain === 'client') {
          _results.push(defineWrap(name, 'client', compile(domMap.client + name)));
        }
      }
      return _results;
    })()).join('\n')));
    return l.join('\n');
  };
  module.exports = function(o) {
    var c, ca, clientDom, file, hasData, libs, name, tree, _i, _j, _len, _len2, _ref3, _ref4, _ref5, _ref6, _ref7, _ref8, _ref9;
    if (!o.domains) {
      throw new Error("brownie needs valid basePoint and domains. Got " + JSON.stringify(o.domains));
    }
    if ((_ref3 = o.basePoint) == null) {
      o.basePoint = 'app.coffee';
    }
    _ref4 = o.domains;
    for (_i = 0, _len = _ref4.length; _i < _len; _i++) {
      _ref5 = _ref4[_i], name = _ref5[0], path = _ref5[1];
      if (name === 'client') {
        clientDom = path;
      }
    }
    if (!o.domains.length > 0 || !exists(clientDom + o.basePoint)) {
      throw new Error("brownie needs a client domain, and the basePoint to be contained in the client domain. Tried: " + clientDom + o.basePoint);
    }
    hasData = false;
    _ref6 = o.domains;
    for (_j = 0, _len2 = _ref6.length; _j < _len2; _j++) {
      _ref7 = _ref6[_j], name = _ref7[0], path = _ref7[1];
      if (name === 'data') {
        hasData = true;
        break;
      }
    }
    if (hasData) {
      throw new Error("brownie reserves the 'data' domain for pulled in code");
    }
    if ((_ref8 = o.namespace) == null) {
      o.namespace = 'Brownie';
    }
    if ((_ref9 = o.DOMLoadWrap) == null) {
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
          var _k, _len3, _ref10, _results;
          _ref10 = o.libFiles;
          _results = [];
          for (_k = 0, _len3 = _ref10.length; _k < _len3; _k++) {
            file = _ref10[_k];
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
