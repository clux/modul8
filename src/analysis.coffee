fs          = require 'fs'
path        = require 'path'
detective   = require 'detective'
{compile, exists}  = require './utils'

# criteria for whether a require string is relative, rather than absolute
# absolute require strings will scan on the defined require paths (@domains)
isRelative = (reqStr) -> reqStr[0...2] is './'

# convert relative requires to absolute ones
# relative folder movement limited to ./(../)*n + normalpath [no backing out after normal folder movement has started]
# will return a string (without a leading slash) that can be post-concatenated with the domain specific path
toAbsPath = (name, subFolders) -> # subFolders is array of folders after domain base that we were requiring from
  return name if !isRelative(name)
  name = name[2...]
  while name[0...3] is '../'
    subFolders = subFolders[0...-1] # slice away the top folder every time we see a '../' string
    name = name[3...]
  folderStr = subFolders.join('/')
  prependStr = if folderStr then folderStr+'/' else ''
  prependStr+name

# constructor
CodeAnalysis = (@entryPoint, @domains, @mainDomain, @premw) ->
  @resolveDependencies() #automatically resolves dependency tree on construction, stores in @tree
  return

# helpers for resolveDependencies
CodeAnalysis::resolveRequire = (absReq, domain, wasRelative) -> # finds file, reports where it wound it
  orig = absReq
  # always scan current domain first, but only scan current domain path if require string was relative
  scannable = [domain].concat(name for name of @domains when name isnt domain)
  if wasRelative
    scannable = [domain]
  else if (dataReg = /^(.*)::/).test(absReq)
    scannable = [absReq.match(dataReg)[1]]
    absReq = absReq.split('::')[1]

  for dom in scannable
    # try raw require, then with coffee extension, then js extension
    return {absReq, dom} if exists(@domains[dom]+absReq)
    return {absReq: absReq+'.js', dom: dom} if exists(@domains[dom]+absReq+'.js')
    return {absReq: absReq+'.coffee', dom: dom} if exists(@domains[dom]+absReq+'.coffee')

  throw new Error("modul8::analysis could not resolve a require for #{orig} (#{absReq}) - looked in #{scannable}")


CodeAnalysis::loadDependencies = (name, subFolders, domain) -> # compiles code to str, use node-detective to find require calls, report up with them
  # we will only get name as absolute names because we convert everything that comes in 4 lines below (and initial is entryPoint)
  {absReq, dom} = @resolveRequire(name, domain, isRelative(name))
  code = compile(@domains[dom]+absReq)
  code = @premw(code) if @premw # apply pre-processing middleware here
  {
    deps    : (toAbsPath(dep, subFolders) for dep in detective(code) when !(/^data::/).test(dep)) # convert all require paths to absolutes immediately so we dont have to deal
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
    t.name = t.name.replace(/^(.*::)/,'') # can now safely remove domain:: part from domain specific requires (note the key of the deps object retains full value)
    for dep in deps #not to be confused with t.deps which is an object, deps from loadDependencies is an array
      t.deps[dep] = {name : dep, parent: t, deps: {}, subFolders: dep.split('/')[0...-1], level: t.level+1}
      t.deps[dep].domain = @resolveRequire(dep, t.domain, isRelative(dep)).dom
      circularCheck(t, dep)
      arguments.callee.call(@, t.deps[dep])
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
CodeAnalysis::printed = (extSuffix=false, domPrefix=false) ->
  lines = [formatName(@entryPoint, extSuffix, domPrefix, @mainDomain)]
  ((branch, level, parentAry) ->
    idx = 0
    bSize = objCount(branch.deps)
    for key, {name, deps, domain} of branch.deps
      hasChildren = objCount(deps) > 0
      forkChar = if hasChildren then "┬" else "─" # this char only occurs near the leaf
      isLast = ++idx is bSize
      turnChar = if isLast then "└" else "├"
      indent = ((if parentAry[i] then " " else "│")+"  " for i in [0...level]).join('') # extra double whitespace correspond to double dash used to connect

      displayName = formatName(name, extSuffix, domPrefix, domain)
      lines.push indent+turnChar+"──"+forkChar+displayName
      arguments.callee(branch.deps[key], level+1, parentAry.concat(isLast)) if hasChildren #recurse into key's dependency tree keeping track of parent lines
    return
  )(@tree, 0, [])
  lines.join('\n')


# public method, get ordered array of code to be used by the compiler
CodeAnalysis::sorted = -> # must flatten the tree, and order based on level
  obj = {}
  obj[@entryPoint] = [0, @mainDomain]
  ((t) ->
    for name,dep of t.deps
      obj[dep.name] = [] if !obj[dep.name]
      obj[dep.name][0] = Math.max(dep.level, obj[dep.name][0] or 0)
      obj[dep.name][1] = dep.domain
      arguments.callee(dep)
    return
  )(@tree) # creates an object of arrays of form [level, domain], so key,val of obj => val = [level, domain]
  # This line converts to (sortable) array, then sorts by level, then maps to array of pairs of form [name, domain] (where we take out the domain:: part of name)
  a = ([name,ary] for name,ary of obj).sort((a,b) -> b[1][0] - a[1][0]).map((e) -> [e[0], e[1][1]])



# requiring this gives a function which returns a closured object with access to only the public methods of a bound instance
module.exports = (entryPoint, domains, mainDomain, premw) ->
  throw new Error("modul8::analysis requires an entryPoint") if !entryPoint
  throw new Error("modul8::analysis requires a domains object and a matching mainDomain. Got #{domains}, main: #{mainDomain}") if !domains or !domains[mainDomain]
  throw new Error("modul8::analysis requires a composed function of pre-processing middlewares to work. Got #{premw}") if !premw instanceof Function
  o = new CodeAnalysis(entryPoint, domains, mainDomain, premw)
  {
    printed : -> o.printed.apply(o, arguments)   # returns a big string
    sorted  : -> o.sorted.apply(o, arguments)    # returns array of pairs of form [name, domain]
  }

