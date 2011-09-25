fs          = require 'fs'
path        = require 'path'
detective   = require 'detective'
{compile, cutTests} = require './utils'

# simple fs extension to check if a file exists [used to verify require calls' validity]
exists = (file) ->
  try
    fs.statSync(file)
    return true
  catch e
    return false

# criteria for whether a require string is relative, rather than absolute
# absolute require strings will scan on the defined require paths (@domainPaths)
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
Organizer = (@basePoint, @domainPaths, @useLocalTests) ->
  @resolveDependencies() #automatically resolves dependency tree on construction, stores in @tree
  return

# resolveDependencies helpers
Organizer::resolveRequire = (absReq, domain, wasRelative) -> # finds file, reports where it wound it
  # always scan current domain first, but only scan current domain path if require string was relative
  orderedPaths = if wasRelative then [domain] else [domain].concat @domainPaths.filter((e) -> e isnt domain)
  return {absReq: absReq, basePath: path} for path in orderedPaths when exists(path+absReq)

  errorStr = if wasRelative then "the relatively required domain: #{domain}" else "any of the client require domains #{JSON.stringify(@domainPaths)}"
  throw new Error("require call for #{absReq} not matched on #{errorStr}")
  return

Organizer::loadDependencies = (name, subFolders, domain) -> # compiles code to str, use node-detective to find require calls, report up with them
  {absReq, basePath} = @resolveRequire(name, domain, isRelative(name))
  code = compile(basePath+absReq)
  code = cutTests(code) if @useLocalTests
  r =
    deps    : (toAbsPath(dep, subFolders) for dep in detective(code)) # convert all require paths to absolutes here
    domain  : basePath


# big resolver, called on Organizer instantiation. creates 3 recursive functions within
# one to remove cirular parent references in the tree that fn 3 is building
# one to scan the parent references at each level to make sure no circular refeneces exists in app code
# and the final (anonymous one) to call detective recursively to find and resolve require calls in current file
Organizer::resolveDependencies = -> # private
  @tree = tree = {name: @basePoint, deps: {}, subFolders: [], domain: @domainPaths[0], level: 0}

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

  ((treePos) =>
    {deps, domain} = @loadDependencies(treePos.name, treePos.subFolders, treePos.domain)
    treePos.domain = domain
    for dep in deps
      treePos.deps[dep] = {name : dep, parent: treePos, deps: {}, subFolders: dep.split('/')[0...-1], level: treePos.level+1 }
      circularCheck(treePos, dep)
      arguments.callee.call(@, treePos.deps[dep])
    return
  )(tree) # call detective recursively and resolve each require
  uncircularize(tree)
  return


# helpers for codeAnalysis
Organizer::sanitizedTree = () -> # private
  m = {}
  m[@basePoint] = {}
  ((treePos, mPos) ->
    arguments.callee(treePos.deps[dep], mPos[dep]={}) for dep of treePos.deps
    return
  )(@tree,m[@basePoint])
  m

getBranchSize = (branch) ->
  i = 0
  i++ for key of branch
  i

# public method, returns an npm like dependency tree
Organizer::codeAnalysis = (hideExtensions=false) ->
  lines = []
  ((branch, level, parentAry) ->
    idx = 0
    bSize = getBranchSize(branch)
    for key,val of branch
      hasChildren = getBranchSize(branch[key]) > 0
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


# public method, used by brownie to get the list
Organizer::codeOrder = -> # must flatten the tree, and order based on
  obj = {}
  obj[@basePoint] = 0
  ((treePos) ->
    for name,dep of treePos.deps
      obj[name] = {} if !obj[name]
      obj[name][0] = Math.max(dep.level, obj[name].level or 0)
      obj[name][1] = dep.domain
      arguments.callee(dep)
    return
  )(@tree) # creates an object of arrays of form [level, domain], so key,val of obj => val = [level, domain]
  ([key,val] for key,val of obj).sort((a,b) -> b[1][1] - a[1][1]).map((e) -> [e[0], e[1][1]]) # returns array of pairs where pair = [name, domain]
Organizer::writeCodeTree = (target) ->


# requiring this gives a function which returns a closured object with access to only the public methods of a bound instance
# TODO: include some strings to ignore [e.g. stuff from internal that require will handle outside default behaviour]
module.exports = (basePoint, domains, useLocalTests=false) ->
  throw new Error("brownie organizer: basePoint required") if !basePoint
  throw new Error("brownie organizer: domains needed as array, got "+domains) if !domains or !(a instanceof Array)
  o = new Organizer(basePoint, domain, useLocalTests)
  r =
    analyze   : o.codeAnalysis
    orderCode : o.codeOrder



# tests
if module is require.main
  clientPath = '/home/clux/repos/deathmatchjs/app/client/'
  sharedPath = '/home/clux/repos/deathmatchjs/app/shared/'
  o = new Organizer('app.coffee', [clientPath,sharedPath], true)
  console.log o.codeAnalysis()
  #console.log o.codeOrder()
  #console.log o.loadDependencies('app.coffee',[],clientPath)

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
