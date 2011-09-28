(function() {
  var CodeAnalysis, compile, cutTests, detective, domains, exists, fs, isRelative, name, o, objCount, path, reqPoint, toAbsPath, tree, _ref;
  var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; }, __hasProp = Object.prototype.hasOwnProperty;
  fs = require('fs');
  path = require('path');
  detective = require('detective');
  _ref = require('./utils'), compile = _ref.compile, exists = _ref.exists;
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
  CodeAnalysis = function(basePoint, domains, useLocalTests) {
    var name, _i, _len, _ref2, _ref3;
    this.basePoint = basePoint;
    this.domains = domains;
    this.useLocalTests = useLocalTests;
    this.domainMap = {};
    _ref2 = this.domains;
    for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
      _ref3 = _ref2[_i], name = _ref3[0], path = _ref3[1];
      this.domainMap[name] = path;
    }
    this.resolveDependencies();
  };
  CodeAnalysis.prototype.resolveRequire = function(absReq, domain, wasRelative) {
    var dataReg, dom, name, orig, scannable, _i, _len;
    orig = absReq;
    scannable = [domain].concat((function() {
      var _i, _len, _ref2, _ref3, _results;
      _ref2 = this.domains;
      _results = [];
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        _ref3 = _ref2[_i], name = _ref3[0], path = _ref3[1];
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
      if (exists(this.domainMap[dom] + absReq)) {
        return {
          absReq: absReq,
          dom: dom
        };
      }
    }
    throw new Error("brownie code analysis: require references a file which cound not be found: " + orig + ", we looked in " + scannable + " for " + absReq);
  };
  cutTests = function(code) {
    return code.replace(/\n.*require.main[\w\W]*$/, '');
  };
  CodeAnalysis.prototype.loadDependencies = function(name, subFolders, domain) {
    var absReq, code, dep, dom, _ref2;
    _ref2 = this.resolveRequire(name, domain, isRelative(name)), absReq = _ref2.absReq, dom = _ref2.dom;
    code = compile(this.domainMap[dom] + absReq);
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
      domain: dom
    };
  };
  CodeAnalysis.prototype.resolveDependencies = function() {
    var circularCheck, tree, uncircularize;
    this.tree = tree = {
      name: this.basePoint,
      deps: {},
      subFolders: [],
      domain: 'client',
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
          throw new Error("circular dependency detected: " + (chain.join(' <- ')) + " <- " + dep);
        }
      }
    };
    uncircularize = function(t) {
      var dep;
      delete t.parent;
      for (dep in t.deps) {
        arguments.callee(t.deps[dep]);
      }
    };
    (__bind(function(t) {
      var dep, deps, domain, _i, _len, _ref2;
      _ref2 = this.loadDependencies(t.name, t.subFolders, t.domain), deps = _ref2.deps, domain = _ref2.domain;
      t.domain = domain;
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
    }, this))(tree);
    uncircularize(tree);
  };
  CodeAnalysis.prototype.sanitizedTree = function() {
    var m;
    m = {};
    (function(t, mPos) {
      var dep, obj, _ref2;
      _ref2 = t.deps;
      for (dep in _ref2) {
        obj = _ref2[dep];
        arguments.callee(t.deps[dep], mPos[obj.name] = {});
      }
    })(this.tree, m[this.basePoint] = {});
    return m;
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
  CodeAnalysis.prototype.printed = function(hideExtensions) {
    var lines;
    lines = [];
    (function(branch, level, parentAry) {
      var bSize, forkChar, hasChildren, i, idx, indents, isLast, key, nkey, turnChar, val;
      idx = 0;
      bSize = objCount(branch);
      for (key in branch) {
        val = branch[key];
        hasChildren = objCount(branch[key]) > 0;
        forkChar = hasChildren ? "┬" : "─";
        isLast = ++idx === bSize;
        turnChar = isLast ? "└" : "├";
        indents = [];
        if (level > 1) {
          for (i = 1; 1 <= level ? i < level : i > level; 1 <= level ? i++ : i--) {
            indents.push((parentAry[i] ? " " : "│") + "  ");
          }
        }
        nkey = hideExtensions ? key.split('.')[0] : key;
        lines.push(level <= 0 ? nkey : indents.join('') + turnChar + "──" + forkChar + nkey);
        arguments.callee(branch[key], level + 1, parentAry.concat(isLast));
      }
    })(this.sanitizedTree(), 0, []);
    return lines.join('\n');
  };
  CodeAnalysis.prototype.sorted = function() {
    var ary, name, obj;
    obj = {};
    obj[this.basePoint] = [0, 'client'];
    (function(treePos) {
      var dep, name, _ref2;
      _ref2 = treePos.deps;
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
    return ((function() {
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
  module.exports = function(basePoint, domains, useLocalTests) {
    var o;
    if (useLocalTests == null) {
      useLocalTests = false;
    }
    if (!basePoint) {
      throw new Error("brownie code analysis: basePoint required");
    }
    if (!domains || !domains instanceof Array || !domains[0] instanceof Array) {
      throw new Error("brownie code analysis: domains needed as array of arrays" + domains);
    }
    o = new CodeAnalysis(basePoint, domains, useLocalTests);
    return {
      print: function(hideExts) {
        if (hideExts == null) {
          hideExts = false;
        }
        return o.printed.call(o, hideExts);
      },
      sorted: function() {
        return o.sorted.call(o);
      }
    };
  };
  if (module === require.main) {
    domains = [['client', '/home/clux/repos/deathmatchjs/app/client/'], ['shared', '/home/clux/repos/deathmatchjs/app/shared/']];
    o = new CodeAnalysis('app.coffee', domains, true);
    console.log(o.printed());
    console.log(o.sorted());
    return;
  }
  if (module === require.main) {
    reqPoint = 'models/user';
    name = './event';
    tree = {
      name: 'app',
      deps: {
        'A': {
          name: 'A',
          deps: {
            'F': {
              name: 'F',
              deps: {}
            },
            'G': {
              name: 'G',
              deps: {}
            },
            'H': {
              name: 'H',
              deps: {
                'Z': {
                  name: 'Z',
                  deps: {
                    'WWW': {
                      name: 'W',
                      deps: {}
                    }
                  }
                }
              }
            },
            'underWWW': {
              name: 'underWWW',
              deps: {}
            }
          }
        },
        'B': {
          name: 'B',
          deps: {
            'C': {
              name: 'C',
              deps: {
                'E': {
                  name: 'E',
                  deps: {}
                }
              }
            },
            'D': {
              name: 'D',
              deps: {}
            }
          }
        }
      }
    };
    console.log(JSON.stringify(sanitizeTree(tree)));
    return;
  }
}).call(this);
