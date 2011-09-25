#coffee      = require 'coffee-script'
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


Organizer = (@basePoint, @domainPaths, @useLocalTests=true) ->
  @resolveDependencies() #resolve dependency tree and sanitize it for use under @tree
  return

#NB: domainPaths must be COMPLETE PATHS UP TO BASE POINT: i.e. ['/home/e/repos/dmjs/app/client/', '/home/e/repos/dmjs/app/shared/', '/home/e/repos/dmjs/app/client/modules/']
#But obviously, they can be relativized up to require point. i.e. if node started in /home/e/repos/dmjs/ then can write ['./app/client/', ... ]

Organizer::resolveRequire = (absReq, domain, wasRelative) ->
  # always scan current domain first, but only scan current domain path if require string was relative
  orderedPaths = if wasRelative then [domain] else [domain].concat @domainPaths.filter((e) -> e isnt domain)
  return {absReq: absReq, basePath: path} for path in orderedPaths when exists(path+absReq)

  errorStr = if wasRelative then "the relatively required domain: #{domain}" else "any of the client require domains #{JSON.stringify(@domainPaths)}"
  throw new Error("require call for #{absReq} not matched on #{errorStr}")
  return


# resolve and compile a target file to js, then apply detective on it
Organizer::loadDependencies = (name, subFolders, domain) ->
  {absReq, basePath} = @resolveRequire(name, domain, isRelative(name))
  code = compile(basePath+absReq)
  code = cutTests(code) if @useLocalTests
  #console.log 'loadDependencies for',name, subFolders, domain, '..FOUND:', detective(code)
  r =
    deps    : (toAbsPath(dep, subFolders) for dep in detective(code)) # convert all require paths to absolutes here
    domain  : basePath


# big resolver, creates 3 recursive functions within
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
    loop
      return if treePos.parent is undefined # got all the way to @basePoint without finding self => good
      treePos = treePos.parent

      if treePos.name is dep.name
        uncircularize(tree) # so that node is able to console.log it (cant log a circular structure)
        throw new Error("#{treePos.name} has a circular dependency: it gets re-required by its requirement for module: #{currentDep.parent.name}", tree)
    return

  ((treePos) =>
    {deps, domain} = @loadDependencies(treePos.name, treePos.subFolders, treePos.domain)
    treePos.domain = domain
    for dep in deps
      circularCheck(treePos, dep)
      treePos.deps[dep] = {name : dep, parent: treePos, deps: {}, subFolders: dep.split('/')[0...-1], level: treePos.level+1 }
      arguments.callee.call(@, treePos.deps[dep])
    return
  )(tree) # call detective recursively and resolve each require
  uncircularize(tree)
  return


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
  ([key,val] for key,val of obj).sort((a,b) -> b[1][1] - a[1][1]).map((e) -> [e[0], e[1][1]]) # returns arrray of pairs where pair = [name, domain]
Organizer::writeCodeTree = (target) ->

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

# returns an npm like dependency tree
Organizer::codeAnalysis = () -> # uses the sanitized tree
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

      #strippedkey = key.split('.')[0] #TODO: should use this, but then key cannot be a relative path...
      lines.push(if level <= 0 then key else indents.join('')+turnChar+"──"+forkChar+key)
      arguments.callee(branch[key], level+1, parentAry.concat(isLast)) #recurse into key's tree (NB: parentAry.length === level)
    return
  )(@sanitizedTree(), 0, [])
  lines.join('\n')


organizer = (b,d) -> new Organizer(b,d)

#module.exports = organizer
# TODO: should really encapsulate away the private methods here
# public methods:
# o = organizer(basePoint, domainPath) <-1st param filename to start from in domainPath[0], 2nd param array of paths to look for files in
# o.codeAnalysis() #returns a string containing containing the npm like depenency tree
# o.codeOrder() # returns an array containing the files required from basePoint in the order they need to be included in the browser



module.exports = (o) ->
  organizer = organizer()
  if o.targetTree
    #fs.writeFileSync(o.treeTarget, sanitizeTree(tree)) if o.treeTarget # write sanitized version of the tree to the target file for code review
    console.log sanitizeTree(tree)
    return
  sortDependencies(tree)


# test everything up to this point
if module is require.main
  clientPath = '/home/clux/repos/deathmatchjs/app/client/'
  sharedPath = '/home/clux/repos/deathmatchjs/app/shared/'
  o = new Organizer('app.coffee', [clientPath,sharedPath])
  console.log o.codeAnalysis()
  console.log o.codeOrder()
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
