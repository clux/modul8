coffee      = require 'coffee-script'
fs          = require 'fs'
path        = require 'path'
detective   = require 'detective'
{compile}   = require './utils'

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


Organizer = (@basePoint, @domainPaths) ->
  #@resolveDependencies() #resolve dependency tree and sanitize it for use under @tree
  return

#NB: domainPaths must be COMPLETE PATHS UP TO BASE POINT: i.e. ['/home/e/repos/dmjs/app/client/', '/home/e/repos/dmjs/app/shared/', '/home/e/repos/dmjs/app/client/modules/']
#But obviously, they can be relativized up to require point. i.e. if node started in /home/e/repos/dmjs/ then can write ['./app/client/', ... ]

Organizer::resolveRequire = (absReq, domain, wasRelative) ->
  # always scan current domain first, but only scan current domain path if require string was relative
  orderedPaths = if wasRelative then [domain] else [domain].concat @domainPaths.filter((e) -> e isnt domain)
  return {path: path+absReq, base: path} for path in orderedPaths when exists(path+absReq)

  errorStr = if wasRelative then "the relatively required domain: #{domain}" else "any of the client require domains #{JSON.stringify(@domainPaths)}"
  throw new Error("require call for #{absReq} not found on #{errorStr}")
  return


# resolve and compile a target file to js, then apply detective on it
Organizer::loadDependencies = (name, subFolders, domain) ->
  {path, foundDomain} = @resolveRequire(toAbsPath(name, subFolders), domain, isRelative(name))
  r =
    deps    : detective(compile(path))
    domain  : foundDomain



# test everything up to this point
if module is require.main
  clientPath = '~/repos/node/app/client/'
  sharedPath = '~/repos/node/app/shared/'
  #o = new Organizer('app.coffee', [clientPath])
  #console.log o.loadDependencies('app',[],'client')

  console.log exists "~/repos/node/app/client/"+'app.coffee' #weird
  return # dont define more stuff


# big resolver, creates 3 recursive functions within
# one to remove cirular parent references in the tree that fn 3 is building
# one to scan the parent references at each level to make sure no circular refeneces exists in app code
# and the final (anonymous one) to call detective recursively to find and resolve require calls in current file
Organizer::resolveDependencies = -> # private
  tree = {name: @basePoint, deps: {}, reqFolders: [], domain: @domainPaths['client'], level: 0}

  uncircularize = (treePos) ->
    delete treePos.parent # does not have to exist to be cleared
    uncircularize(treePos.deps[dep]) for dep of treePos.deps
    return

  circularCheck = (treePos, dep) -> # makes sure no circular references exists for dep going up from current point in tree (tree starts at top)
    loop
      return if treePos.parent is undefined # got all the way to @basePoint without finding self => good
      treePos = treePos.parent

      if treePos.name is currentDep.name
        uncircularize(tree) # so that node is able to console.log it (cant log a circular structure)
        throw new Error("#{treePos.name} has a circular dependency: it gets re-required by its requirement for module: #{currentDep.parent.name}", tree)
    return

  ((treePos) ->
    subFolders = treePos.name.split(path.basename(treePos.name))[0][0...-1].split('/') # array of folders to move into relative to basepoint to get to the file that required dep below
    for dep in @loadDependencies(treePos.name, treePos.subFolders, treePos.domain) # use detective to get this 'deps' fn
      circularCheck(treePos, dep.name)
      treePos.deps[dep.name] = {name : dep.name, parent: treePos, deps: {}, subFolders: subFolders, domain: dep.domain, level: treePos.level+1 }
      arguments.callee(treePos.deps[dep.name])
    return
  )(tree) # call detective recursively and resolve each require

  uncircularize(tree)
  @tree = @sanitize(tree)
  console.log @tree


Organizer::sanitize = (tree) -> # private
  m = {}
  m[@basePoint] = {}
  ((treePos, mPos) ->
    arguments.callee(treePos.deps[dep], mPos[dep]={}) for dep of treePos.deps
    return
  )(tree,m[@basePoint])
  m

Organizer::getCodeOrder = -> # must flatten the tree, and order based on
  obj = {}
  ((treePos) ->
    obj[treePos.name] = Math.max(treePos.level, obj[treePos.name] or 0)
    arguments.callee(dep) for dep of treePos.deps
    return
  )(@tree)
  ([key,val] for key,val of obj).sort((a,b) -> b[1] - a[1]).map((e) -> e[0])
Organizer::writeCodeTree = (target) ->

organizer = (b,d) -> new Organizer(b,d)


getBranchSize = (branch) ->
  i = 0
  i++ for key of branch
  i

getReadableDep = (tree) -> # requires a sanitized tree as input
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

      lines.push(if level <= 0 then key else indents.join('')+turnChar+"──"+forkChar+key)
      arguments.callee(branch[key], level+1, parentAry.concat(isLast)) #recurse into key's tree (NB: parentAry.length === level)
    return
  )(tree, 0, [])
  lines.join('\n')


module.exports = (o) ->
  organizer = organizer()
  if o.targetTree
    #fs.writeFileSync(o.treeTarget, sanitizeTree(tree)) if o.treeTarget # write sanitized version of the tree to the target file for code review
    console.log sanitizeTree(tree)
    return
  sortDependencies(tree)


if module is require.main
  reqPoint = 'models/user'
  name = './event'
  reqFolders = reqPoint.split(path.basename(reqPoint))[0][0...-1].split('/') #remove name, last slash and convert to folders
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
