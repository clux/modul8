(function() {
  var anonWrap, bundle, codeAnalyis, compile, exists, fs, jQueryWrap, minify, parser, path, pullData, uglify, _ref, _ref2;
  fs = require('fs');
  path = require('path');
  codeAnalyis = require('./codeanalysis');
  _ref = require('./utils'), compile = _ref.compile, exists = _ref.exists, anonWrap = _ref.anonWrap, jQueryWrap = _ref.jQueryWrap;
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
  exports.bake = function(i) {
    var c, ca, clientDom, file, hasData, libs, name, tree, _i, _j, _len, _len2, _ref3, _ref4, _ref5, _ref6, _ref7, _ref8, _ref9;
    if (!i.domains) {
      throw new Error("brownie needs valid basePoint and domains. Got " + JSON.stringify(i.domains));
    }
    if ((_ref3 = i.basePoint) == null) {
      i.basePoint = 'app.coffee';
    }
    _ref4 = i.domains;
    for (_i = 0, _len = _ref4.length; _i < _len; _i++) {
      _ref5 = _ref4[_i], name = _ref5[0], path = _ref5[1];
      if (name === 'client') {
        clientDom = path;
      }
    }
    if (!i.domains.length > 0 || !exists(clientDom + i.basePoint)) {
      throw new Error("brownie needs a client domain, and the basePoint to be contained in the client domain. Tried: " + clientDom + i.basePoint);
    }
    hasData = false;
    _ref6 = i.domains;
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
    if ((_ref8 = i.namespace) == null) {
      i.namespace = 'Brownie';
    }
    if ((_ref9 = i.DOMLoadWrap) == null) {
      i.DOMLoadWrap = jQueryWrap;
    }
    ca = codeAnalyis(i.basePoint, i.domains, i.localTests);
    if (i.target) {
      c = bundle(ca.sorted(), i.namespace, i);
      if (i.minify) {
        if (i.minifier) {
          if (!i.minifier instanceof Function) {
            throw new Error("brownie requires a function as a minifier");
          }
          c = i.minifier(c);
        } else {
          c = minify(c);
        }
      }
      fs.writeFileSync(i.target, c);
      if (i.libsOnlyTarget && i.libDir && i.libFiles) {
        libs = ((function() {
          var _k, _len3, _ref10, _results;
          _ref10 = i.libFiles;
          _results = [];
          for (_k = 0, _len3 = _ref10.length; _k < _len3; _k++) {
            file = _ref10[_k];
            _results.push(compile(i.libDir + file));
          }
          return _results;
        })()).join('\n');
        if (i.minifylibs) {
          libs = minify(libs);
        }
        fs.writeFileSync(i.libsOnlyTarget, libs);
      }
    }
    if (i.treeTarget || i.logTree) {
      tree = ca.printed(i.extSuffix, i.domPrefix);
      if (i.treeTarget) {
        fs.writeFileSync(i.treeTarget, tree);
      }
      if (i.logTree) {
        return console.log(tree);
      }
    }
  };
  exports.decorate = function(i) {
    var nib, stylus;
    stylus = require('stylus');
    nib = require('nib');
    return stylus(fs.readFileSync(i.input, 'utf8')).set('compress', i.minify).set('filename', i.input).render(function(err, css) {
      var options, uglifycss;
      if (err) {
        throw New(Error(err));
      }
      if (i.minify) {
        uglifycss = require('uglifycss');
        options = {
          maxLineLen: 0,
          expandVars: false,
          cuteComments: false
        };
        css = uglifycss.processString(css, options);
      }
      if (!i.target) {
        return css;
      }
      return fs.writeFileSync(i.target, css);
    });
  };
}).call(this);
