fs          = require 'fs'
path        = require 'path'
detective   = require 'detective'
utils       = require './utils'


# constructor
CodeAnalysis = (@entryPoint, @domains, @mainDomain, @premw, @arbiters) ->
  @resolveRequire = utils.makeResolver(@domains) # (reqStr, domain) -> {absReq, dom}
  @resolveDependencies() # automatically resolves dependency tree on construction, stores in @tree
  return

CodeAnalysis::loadDependencies = (reqStr, subFolders, domain) -> # compiles code to str, use node-detective to find require calls, report up with them
  # we will only get name as absolute names because we convert everything that comes in 4 lines below (and initial is entryPoint)
  {absReq, dom} = @resolveRequire(reqStr, domain)
  code = utils.compile(@domains[dom]+absReq)
  code = @premw(code) if @premw # apply pre-processing middleware here
  {
    # convert all require paths to absolutes immediately so we dont have to deal with them later
    deps    : (utils.toAbsPath(dep, subFolders, domain) for dep in detective(code) when utils.isLegalDomain(dep))
    domain  : dom
    absReq  : absReq
  }


# big resolver, called on CodeAnalysis instantiation. creates 3 recursive functions within
# one to remove cirular parent references in the tree that fn 3 is building
# one to scan the parent references at each level to make sure no circular refeneces exists in app code
# and the final (anonymous one) to call detective recursively to find and resolve require calls in current file
CodeAnalysis::resolveDependencies = -> # private
  @tree = {name: @entryPoint, deps: {}, subFolders: [], domain: @mainDomain, level: 0}

  circularCheck = (treePos, dep) -> # makes sure no circular references exists for dep going up from current point in tree (tree starts at top)
    requiree = treePos.name
    chain = [dep]
    loop
      return if treePos.parent is undefined # got all the way to @entryPoint without finding self => good
      chain.push treePos.name
      treePos = treePos.parent # follow the chain up
      throw new Error("modul8::analysis revealed a circular dependency: #{chain.join(' <- ')} <- #{dep}") if treePos.name is dep
    return

  ((t) =>
    {deps, domain, absReq} = @loadDependencies(t.name, t.subFolders, t.domain)
    t.domain = domain
    t.name = absReq
    t.name = utils.stripDomain(t.name) # can now safely remove domain:: part from domain specific requires (note the key of the deps object retains full value)
    for dep in deps #not to be confused with t.deps which is an object, deps from loadDependencies is an array
      if dep of @arbiters or 'M8::'+dep of @arbiters # was an arbiter string required verbatim?
        # this require does not have a file representation, but we may want it to show up in the tree
        t.deps[dep] = {name : utils.stripDomain(dep), parent: t, deps: {}, subFolders: [], level: t.level+1, domain: 'M8'}
      else
        t.deps[dep] = {name: dep, parent: t, deps: {}, subFolders: utils.stripDomain(dep).split('/')[0...-1], level: t.level+1}
        t.deps[dep].domain = @resolveRequire(t.deps[dep].name, t.domain, utils.isRelative(dep)).dom # ensures file exists

        circularCheck(t, dep)
        arguments.callee.call(@, t.deps[dep]) # preserve context and recurse
    return
  )(@tree) # call detective recursively and resolve each require
  return

# helpers for print
objCount = (obj) ->
  i = 0
  i++ for own key of obj
  i

formatName = (name, extSuffix, domPrefix, dom) ->
  n = if extSuffix then name else name.split('.')[0]
  n = dom+'::'+n if domPrefix
  n

# public method, returns an npm like dependency tree
CodeAnalysis::printed = (extSuffix=false, domPrefix=true) ->
  lines = [formatName(@entryPoint, extSuffix, domPrefix, @mainDomain)]
  ((branch, level, parentAry) ->
    idx = 0
    bSize = objCount(branch.deps)
    for key, {name, deps, domain} of branch.deps
      hasChildren = objCount(deps) > 0
      forkChar = if hasChildren then "┬" else "─" # this char only occurs near the leaf
      isLast = ++idx is bSize
      turnChar = if isLast then "└" else "├"
      indent = " "+((if parentAry[i] then " " else "│")+"  " for i in [0...level]).join('')

      displayName = formatName(name, extSuffix, domPrefix, domain)
      lines.push indent+turnChar+"──"+forkChar+displayName
      arguments.callee(branch.deps[key], level+1, parentAry.concat(isLast)) if hasChildren #recurse into key's dependency tree keeping track of parent lines
    return
  )(@tree, 0, [])
  lines.join('\n')


# public method, get ordered array of code to be used by the compiler
CodeAnalysis::sorted = -> # must flatten the tree, and order based on level
  obj = {}
  obj[@mainDomain+'::'+@entryPoint] = 0
  arbs = @arbiters
  ((t) ->
    for name,dep of t.deps
      continue if name of arbs # dont include arbiters in code list, bundle wont be able to include them
      name = dep.domain+'::'+dep.name
      obj[name] = Math.max(dep.level, obj[name] or 0)
      arguments.callee(dep)
    return
  )(@tree) # populates obj of form: key=domain::name, val=level

  ([name,level] for name,level of obj) # convert obj to (sortable) array
    .sort((a,b) -> b[1] - a[1])        # sort by level
    .map (e) ->                        # return after mapping to pairs of form [domain, name]
      ary = e[0].split('::')
      [ary[1], ary[0]]


# requiring this gives a function which returns a closured object with access to only the public methods of a bound instance
module.exports = (entryPoint, domains, mainDomain, premw, arbiters) ->
  throw new Error("modul8::analysis requires an entryPoint") if !entryPoint
  throw new Error("modul8::analysis requires a domains object and a matching mainDomain. Got #{domains}, main: #{mainDomain}") if !domains or !domains[mainDomain]
  throw new Error("modul8::analysis requires a composed function of pre-processing middlewares to work. Got #{premw}") if !premw instanceof Function
  o = new CodeAnalysis(entryPoint, domains, mainDomain, premw, arbiters)
  {
    printed : -> o.printed.apply(o, arguments)   # returns a big string
    sorted  : -> o.sorted.apply(o, arguments)    # returns array of pairs of form [name, domain]
  }

