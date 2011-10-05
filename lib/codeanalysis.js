(function() {
  var CodeAnalysis, compile, cutTests, detective, exists, formatName, fs, isRelative, objCount, path, toAbsPath, _ref;
  var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; }, __hasProp = Object.prototype.hasOwnProperty;
  fs = require('fs');
  path = require('path');
  detective = require('detective');
  _ref = require('./utils'), compile = _ref.compile, exists = _ref.exists, cutTests = _ref.cutTests;
  isRelative = function(reqStr) {
    return reqStr.slice(0, 2) === './';
  };
  toAbsPath = function(name, subFolders) {
    var folderStr, prependStr;
    if (!isRelative(name)) {
      return name;
    }
    name = name.slice(2);
    while (name.slice(0, 3) === '../') {
      subFolders = subFolders.slice(0, -1);
      name = name.slice(3);
    }
    folderStr = subFolders.join('/');
    prependStr = folderStr ? folderStr + '/' : '';
    return prependStr + name;
  };
  CodeAnalysis = function(entryPoint, domains, mainDomain, useLocalTests) {
    this.entryPoint = entryPoint;
    this.domains = domains;
    this.mainDomain = mainDomain;
    this.useLocalTests = useLocalTests;
    this.resolveDependencies();
  };
  CodeAnalysis.prototype.resolveRequire = function(absReq, domain, wasRelative) {
    var dataReg, dom, name, orig, scannable, _i, _len;
    orig = absReq;
    scannable = [domain].concat((function() {
      var _results;
      _results = [];
      for (name in this.domains) {
        if (name !== domain) {
          _results.push(name);
        }
      }
      return _results;
    }).call(this));
    if (wasRelative) {
      scannable = [domain];
    } else if ((dataReg = /^(.*)::/).test(absReq)) {
      scannable = [absReq.match(dataReg)[1]];
      absReq = absReq.split('::')[1];
    }
    for (_i = 0, _len = scannable.length; _i < _len; _i++) {
      dom = scannable[_i];
      if (exists(this.domains[dom] + absReq)) {
        return {
          absReq: absReq,
          dom: dom
        };
      }
      if (exists(this.domains[dom] + absReq + '.js')) {
        return {
          absReq: absReq + '.js',
          dom: dom
        };
      }
      if (exists(this.domains[dom] + absReq + '.coffee')) {
        return {
          absReq: absReq + '.coffee',
          dom: dom
        };
      }
    }
    throw new Error("brownie.bake code analysis: require references a file which cound not be found: " + orig + ", we looked in " + scannable + " for " + absReq);
  };
  CodeAnalysis.prototype.loadDependencies = function(name, subFolders, domain) {
    var absReq, code, dep, dom, _ref2;
    _ref2 = this.resolveRequire(name, domain, isRelative(name)), absReq = _ref2.absReq, dom = _ref2.dom;
    code = compile(this.domains[dom] + absReq);
    if (this.useLocalTests) {
      code = cutTests(code);
    }
    return {
      deps: (function() {
        var _i, _len, _ref3, _results;
        _ref3 = detective(code);
        _results = [];
        for (_i = 0, _len = _ref3.length; _i < _len; _i++) {
          dep = _ref3[_i];
          if (!/^data::/.test(dep)) {
            _results.push(toAbsPath(dep, subFolders));
          }
        }
        return _results;
      })(),
      domain: dom,
      absReq: absReq
    };
  };
  CodeAnalysis.prototype.resolveDependencies = function() {
    var circularCheck;
    this.tree = {
      name: this.entryPoint,
      deps: {},
      subFolders: [],
      domain: this.mainDomain,
      level: 0
    };
    circularCheck = function(treePos, dep) {
      var chain, requiree;
      requiree = treePos.name;
      chain = [dep];
      while (true) {
        if (treePos.parent === void 0) {
          return;
        }
        chain.push(treePos.name);
        treePos = treePos.parent;
        if (treePos.name === dep) {
          throw new Error("brownie.bake code analysis revealed a circular dependency: " + (chain.join(' <- ')) + " <- " + dep);
        }
      }
    };
    (__bind(function(t) {
      var absReq, dep, deps, domain, _i, _len, _ref2;
      _ref2 = this.loadDependencies(t.name, t.subFolders, t.domain), deps = _ref2.deps, domain = _ref2.domain, absReq = _ref2.absReq;
      t.domain = domain;
      t.name = absReq;
      t.name = t.name.replace(/^(.*::)/, '');
      for (_i = 0, _len = deps.length; _i < _len; _i++) {
        dep = deps[_i];
        t.deps[dep] = {
          name: dep,
          parent: t,
          deps: {},
          subFolders: dep.split('/').slice(0, -1),
          level: t.level + 1
        };
        t.deps[dep].domain = this.resolveRequire(dep, t.domain, isRelative(dep)).dom;
        circularCheck(t, dep);
        arguments.callee.call(this, t.deps[dep]);
      }
    }, this))(this.tree);
  };
  objCount = function(obj) {
    var i, key;
    i = 0;
    for (key in obj) {
      if (!__hasProp.call(obj, key)) continue;
      i++;
    }
    return i;
  };
  formatName = function(name, extSuffix, domPrefix, dom) {
    var n;
    n = extSuffix ? name : name.split('.')[0];
    if (domPrefix) {
      n = dom + '::' + n;
    }
    return n;
  };
  CodeAnalysis.prototype.printed = function(extSuffix, domPrefix) {
    var lines;
    if (extSuffix == null) {
      extSuffix = false;
    }
    if (domPrefix == null) {
      domPrefix = false;
    }
    lines = [formatName(this.entryPoint, extSuffix, domPrefix, this.mainDomain)];
    (function(branch, level, parentAry) {
      var bSize, deps, displayName, domain, forkChar, hasChildren, i, idx, indent, isLast, key, name, turnChar, _ref2, _ref3;
      idx = 0;
      bSize = objCount(branch.deps);
      _ref2 = branch.deps;
      for (key in _ref2) {
        _ref3 = _ref2[key], name = _ref3.name, deps = _ref3.deps, domain = _ref3.domain;
        hasChildren = objCount(deps) > 0;
        forkChar = hasChildren ? "┬" : "─";
        isLast = ++idx === bSize;
        turnChar = isLast ? "└" : "├";
        indent = ((function() {
          var _results;
          _results = [];
          for (i = 0; 0 <= level ? i < level : i > level; 0 <= level ? i++ : i--) {
            _results.push((parentAry[i] ? " " : "│") + "  ");
          }
          return _results;
        })()).join('');
        displayName = formatName(name, extSuffix, domPrefix, domain);
        lines.push(indent + turnChar + "──" + forkChar + displayName);
        if (hasChildren) {
          arguments.callee(branch.deps[key], level + 1, parentAry.concat(isLast));
        }
      }
    })(this.tree, 0, []);
    return lines.join('\n');
  };
  CodeAnalysis.prototype.sorted = function() {
    var a, ary, name, obj;
    obj = {};
    obj[this.entryPoint] = [0, this.mainDomain];
    (function(t) {
      var dep, name, _ref2;
      _ref2 = t.deps;
      for (name in _ref2) {
        dep = _ref2[name];
        if (!obj[dep.name]) {
          obj[dep.name] = [];
        }
        obj[dep.name][0] = Math.max(dep.level, obj[dep.name][0] || 0);
        obj[dep.name][1] = dep.domain;
        arguments.callee(dep);
      }
    })(this.tree);
    return a = ((function() {
      var _results;
      _results = [];
      for (name in obj) {
        ary = obj[name];
        _results.push([name, ary]);
      }
      return _results;
    })()).sort(function(a, b) {
      return b[1][0] - a[1][0];
    }).map(function(e) {
      return [e[0], e[1][1]];
    });
  };
  module.exports = function(entryPoint, domains, mainDomain, useLocalTests) {
    var o;
    if (useLocalTests == null) {
      useLocalTests = false;
    }
    if (!entryPoint) {
      throw new Error("brownie.bake code analysis: entryPoint required");
    }
    if (!domains || !domains[mainDomain]) {
      throw new Error("brownie.bake code analysis: domains needed, and needs to contain specified mainDomain " + mainDomain + ". Got " + domains);
    }
    o = new CodeAnalysis(entryPoint, domains, mainDomain, useLocalTests);
    return {
      printed: function() {
        return o.printed.apply(o, arguments);
      },
      sorted: function() {
        return o.sorted.apply(o, arguments);
      }
    };
  };
}).call(this);
