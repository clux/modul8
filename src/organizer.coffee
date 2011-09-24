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
  console.log "resolveRequire (failed here):", absReq, domain, wasRelative
  orderedPaths = if wasRelative then [domain] else [domain].concat @domainPaths.filter((e) -> e isnt domain)
  return {absReq: absReq, basePath: path} for path in orderedPaths when exists(path+absReq)

  errorStr = if wasRelative then "the relatively required domain: #{domain}" else "any of the client require domains #{JSON.stringify(@domainPaths)}"
  throw new Error("require call for #{absReq} not matched on #{errorStr}")
  return


# resolve and compile a target file to js, then apply detective on it
Organizer::loadDependencies = (name, subFolders, domain) ->
  console.log 'LOADDEPS:',name, subFolders, domain
  {absReq, basePath} = @resolveRequire(toAbsPath(name, subFolders), domain, isRelative(name))
  code = compile(basePath+absReq)
  code = cutTests(code) if @useLocalTests
  r =
    deps    : detective(code)
    domain  : basePath
  console.log "from loadDeps for ",name,"out:",r
  r



# big resolver, creates 3 recursive functions within
# one to remove cirular parent references in the tree that fn 3 is building
# one to scan the parent references at each level to make sure no circular refeneces exists in app code
# and the final (anonymous one) to call detective recursively to find and resolve require calls in current file
Organizer::resolveDependencies = -> # private
  tree = {name: @basePoint, deps: {}, subFolders: [], domain: @domainPaths[0], level: 0}

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

  loadDeps = @loadDependencies # needed outside @
  ((treePos) =>
    subFolders = treePos.name.split('.')[0].split('/')[0...-1] # kill extension, get all folder names
    console.log "recDetectiveCall:",subFolders, treePos.name
    {deps, domain} = @loadDependencies(treePos.name, treePos.subFolders, treePos.domain) #TODO: this should perhaps be domain or concat with previous...
    for dep in  deps # use detective to get this 'deps' fn
      console.log dep,"use this:?", dep.split('/')[0...-1], "or this:?", subFolders, "or even this:", treePos.subFolders
      circularCheck(treePos, dep)
      treePos.deps[dep] = {name : dep, parent: treePos, deps: {}, subFolders: dep.split('/')[0...-1], domain: domain, level: treePos.level+1 }
      arguments.callee.call(@,treePos.deps[dep])
    return
  )(tree) # call detective recursively and resolve each require

  uncircularize(tree)
  @tree = @sanitize(tree)
  return


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

Organizer::getCoolCodeTree = () -> # uses the sanitized tree
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
  )(@tree, 0, [])
  lines.join('\n')



# test everything up to this point
if module is require.main
  clientPath = '/home/clux/repos/deathmatchjs/app/client/'
  sharedPath = '/home/clux/repos/deathmatchjs/app/shared/'
  o = new Organizer('app.coffee', [clientPath,sharedPath])
  console.log o.getCoolCodeTree()
  #console.log o.loadDependencies('app.coffee',[],clientPath)

  #s = 'app.coffee'
  #console.log s.split(path.basename(s))[0][0...-1].split('/') #<- problem, need this to return empty array
  #i.e. might have split around the domain name as well!, but will that work?
  #technically, each name SHOULD NOT INCLUDE MORE THAN ITS RELATIVE PATH: FIX SO THAT THIS IS RIGHT

  #console.log exists "/home/clux/repos/deathmatchjs/app/client/"+'app.coffee' #weird
  return # dont define more stuff


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
