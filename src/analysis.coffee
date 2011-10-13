fs          = require 'fs'
path        = require 'path'
detective   = require 'detective'
utils       = require './utils'
{Resolver, isLegalRequire} = require './resolver'


# constructor
CodeAnalysis = (@entryPoint, @domains, @mainDomain, @premw, arbiters, @ignoreDomains) ->
  @resolver = new Resolver(@domains, arbiters, @mainDomain)
  @resolveDependencies() # automatically resolves dependency tree on construction, stores in @tree
  return

# finds all dependencies of a module (+whether or not they are fake) based on reqStr + domain & subFolders array of requirees position
CodeAnalysis::loadDependencies = (absReq, subFolders, dom) ->
  # we will only get name as absolute names because we convert everything that comes in 4 lines below (and initial is entryPoint)
  code = utils.compile(@domains[dom]+absReq)
  code = @premw(code) if @premw # apply pre-processing middleware here
  @resolver.locate(dep, subFolders, dom) for dep in detective(code) when isLegalRequire(dep)




# main analyzer - called on CodeAnalysis instatiation
# recursively walks the tree and calls loadDependencies on it
CodeAnalysis::resolveDependencies = -> # private
  @tree = {name: @entryPoint, deps: {}, subFolders: [], domain: @mainDomain, fake: false, level: 0}

  circularCheck = (t, dep, dom) -> # makes sure no circular references exists for dep going up from current point in tree (tree starts at top)
    chain = [dom+'::'+dep]
    loop
      return if t.parent is undefined # got all the way to @entryPoint without finding self => good
      chain.push t.domain+'::'+t.name
      t = t.parent # follow the chain up
      throw new Error("modul8::analysis revealed a circular dependency: #{chain.join(' <- ')}") if chain[chain.length-1] is chain[0]
    return

  ((t) =>
    for [dep, domain, fake] in @loadDependencies(t.name, t.subFolders, t.domain)
      uid = domain+'::'+dep
      t.deps[uid] = {name: dep, parent: t, deps: {}, subFolders: dep.split('/')[0...-1], domain: domain, level: t.level+1, fake: fake}

      if !fake
        circularCheck(t, dep, domain) # also checks for self-inclusions
        arguments.callee.call(@, t.deps[uid]) # preserve context and recurse
    return
  )(@tree) # call detective recursively and resolve each require
  return

# helpers for print
makeCounter = (ignores) ->
  (obj) ->
    i = 0
    i++ for own key of obj when !(obj[key].domain in ignores)
    i

formatName = (name, extSuffix, domPrefix, dom) ->
  n = if extSuffix then name else name.split('.')[0] # fine as all names at this point have been absolutized
  n = dom+'::'+n if domPrefix
  n

# public method, returns an npm like dependency tree
CodeAnalysis::printed = (extSuffix=false, domPrefix=true) ->
  lines = [formatName(@entryPoint, extSuffix, domPrefix, @mainDomain)]
  objCount = makeCounter(ignores=@ignoreDomains)
  ((branch, level, parentAry) ->
    idx = 0
    bSize = objCount(branch.deps)
    for key, {name, deps, domain} of branch.deps when !(domain in ignores)
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
  ((t) ->
    for name,dep of t.deps
      continue if dep.fake # dont include arbiters/externals in code list, bundle wont be able to use them
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
module.exports = (entryPoint, domains, mainDomain, premw, arbiters, ignoreDomains) ->
  throw new Error("modul8::analysis requires an entryPoint") if !entryPoint
  throw new Error("modul8::analysis requires a domains object and a matching mainDomain. Got #{domains}, main: #{mainDomain}") if !domains or !domains[mainDomain]
  throw new Error("modul8::analysis requires a composed function of pre-processing middlewares to work. Got #{premw}") if !premw instanceof Function
  o = new CodeAnalysis(entryPoint, domains, mainDomain, premw, arbiters, ignoreDomains)
  {
    printed : -> o.printed.apply(o, arguments)   # returns a big string
    sorted  : -> o.sorted.apply(o, arguments)    # returns array of pairs of form [name, domain]
  }

