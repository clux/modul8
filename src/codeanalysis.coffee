fs          = require 'fs'
path        = require 'path'
detective   = require 'detective'
{compile, objCount, exists}  = require './utils'

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

# constructor, private
CodeAnalysis = (@basePoint, @domains, @useLocalTests) ->
  @resolveDependencies() #automatically resolves dependency tree on construction, stores in @tree
  return

# resolveDependencies helpers
CodeAnalysis::resolveRequire = (absReq, domain, wasRelative) -> # finds file, reports where it wound it
  # always scan current domain first, but only scan current domain path if require string was relative
  scannable = if wasRelative then [@domains[domain]] else [domain].concat(name for name of @domains when name isnt domain)
  return {absReq, dom} for dom in scannable when exists(@domains[dom]+absReq)

  throw new Error("brownie code analysis: require references a file which cound not be found #{absReq}")

cutTests = (code) -> code.replace(/\n.*require.main[\w\W]*$/, '') # avoids pulling in test dependencies TODO: this can eventually use burrito, but not in use by default

CodeAnalysis::loadDependencies = (name, subFolders, domain) -> # compiles code to str, use node-detective to find require calls, report up with them
  {absReq, dom} = @resolveRequire(name, domain, isRelative(name))
  code = compile(@domains[dom]+absReq)
  code = cutTests(code) if @useLocalTests
  {
    deps    : (toAbsPath(dep, subFolders) for dep in detective(code)) # convert all require paths to absolutes here
    domain  : dom
  }


# big resolver, called on CodeAnalysis instantiation. creates 3 recursive functions within
# one to remove cirular parent references in the tree that fn 3 is building
# one to scan the parent references at each level to make sure no circular refeneces exists in app code
# and the final (anonymous one) to call detective recursively to find and resolve require calls in current file
CodeAnalysis::resolveDependencies = -> # private
  @tree = tree = {name: @basePoint, deps: {}, subFolders: [], domain: 'client', level: 0}

  uncircularize = (treePos) ->
    delete treePos.parent # does not have to exist to be cleared
    uncircularize(treePos.deps[dep]) for dep of treePos.deps
    return

  circularCheck = (treePos, dep) -> # makes sure no circular references exists for dep going up from current point in tree (tree starts at top)
    requiree = treePos.name
    chain = [dep]
    loop
      return if treePos.parent is undefined # got all the way to @basePoint without finding self => good
      chain.push treePos.name
      treePos = treePos.parent # follow the chain up
      throw new Error("circular dependency detected: #{chain.join(' <- ')} <- #{dep}") if treePos.name is dep
    return

  # console.log tree
  ((t) =>
    {deps, domain} = @loadDependencies(t.name, t.subFolders, t.domain)
    t.domain = domain
    for dep in deps #not to be confused with t.deps which is an object, deps from loadDependencies is an array
      t.deps[dep] = {name : dep, parent: t, deps: {}, subFolders: dep.split('/')[0...-1], level: t.level+1}
      t.deps[dep].domain = @resolveRequire(dep, t.domain, isRelative(dep)).dom
      circularCheck(t, dep)
      arguments.callee.call(@, t.deps[dep])
    return
  )(tree) # call detective recursively and resolve each require
  uncircularize(tree)
  return


# helpers for print
CodeAnalysis::sanitizedTree = () -> # private
  m = {}
  ((treePos, mPos) ->
    arguments.callee(treePos.deps[dep], mPos[dep]={}) for dep of treePos.deps
    return
  )(@tree,m[@basePoint]={})
  m

# public method, returns an npm like dependency tree
CodeAnalysis::printed = (hideExtensions=false) ->
  lines = []
  ((branch, level, parentAry) ->
    idx = 0
    bSize = objCount(branch)
    for key,val of branch
      hasChildren = objCount(branch[key]) > 0
      forkChar = if hasChildren then "┬" else "─"
      isLast = ++idx is bSize
      turnChar = if isLast then "└" else "├"

      indents = []
      if level > 1
        indents.push((if parentAry[i] then " " else "│")+"  ") for i in [1...level] # extra double whitespace correspond to double dash used to connect

      nkey = if hideExtensions then key.split('.')[0] else key
      lines.push(if level <= 0 then nkey else indents.join('')+turnChar+"──"+forkChar+nkey)
      arguments.callee(branch[key], level+1, parentAry.concat(isLast)) #recurse into key's tree (NB: parentAry.length === level)
    return
  )(@sanitizedTree(), 0, [])
  lines.join('\n')


# public method, used by brownie to get ordered array of code
CodeAnalysis::sorted = -> # must flatten the tree, and order based on level
  obj = {}
  obj[@basePoint] = [0, 'client']
  ((treePos) ->
    for name,dep of treePos.deps
      obj[name] = {} if !obj[name]
      obj[name][0] = Math.max(dep.level, obj[name].level or 0)
      obj[name][1] = dep.domain
      arguments.callee(dep)
    return
  )(@tree) # creates an object of arrays of form [level, domain], so key,val of obj => val = [level, domain]
  ([key,val] for key,val of obj).sort((a,b) -> b[1][1] - a[1][1]).map((e) -> [e[0], e[1][1]]) # returns array of pairs where pair = [name, domain]




# requiring this gives a function which returns a closured object with access to only the public methods of a bound instance
# TODO: include some strings to ignore [e.g. stuff from internal that require will handle outside default behaviour]
module.exports = (basePoint, domains, useLocalTests=false) ->
  throw new Error("brownie code analysis: basePoint required") if !basePoint
  throw new Error("brownie code analysis: domains needed as object"+domains) if !domains or !domains.client
  o = new CodeAnalysis(basePoint, domain, useLocalTests)
  {
    print   : o.printed # returns a big string
    sorted  : o.sorted  # returns array of pairs of form [name, domain]
  }






# tests
if module is require.main
  domains =
    client : '/home/clux/repos/deathmatchjs/app/client/'
    shared : '/home/clux/repos/deathmatchjs/app/shared/'
  o = new CodeAnalysis('app.coffee', domains, true)
  console.log o.printed()
  console.log o.sorted()

  #s = 'app.coffee'
  #console.log s.split(path.basename(s))[0][0...-1].split('/') #<- problem, need this to return empty array
  #i.e. might have split around the domain name as well!, but will that work?
  #technically, each name SHOULD NOT INCLUDE MORE THAN ITS RELATIVE PATH: FIX SO THAT THIS IS RIGHT

  #console.log exists "/home/clux/repos/deathmatchjs/app/client/"+'app.coffee' #weird
  return # dont define more stuff


if module is require.main
  reqPoint = 'models/user'
  name = './event'
  #console.log reqFolders
  #console.log toAbsPath(name, reqFolders)

  tree =
    name : 'app'
    deps :
      'A'  :
        name : 'A'
        deps : { 'F':{name:'F',deps:{}},  'G':{name:'G',deps:{}}  ,  'H':{name:'H',deps:{'Z':{name:'Z', deps:{  'WWW':{name:'W',deps:{}}   }}}},  'underWWW':{name:'underWWW',deps:{}}   }
      'B'  :
        name : 'B'
        deps : {'C': {name:'C', deps: {'E':{name:'E',deps:{}}}  }, 'D' :{name:'D', deps: {}} }
  console.log JSON.stringify sanitizeTree tree

  #smallTree = sanitizeTree tree
  #console.log getReadableDep(smallTree)
  return
