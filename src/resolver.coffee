###
KILLING CIRCULAR DEPENDENCIES
  1. create FULL tree for level i
  2. for each branch: for each leaf: if leaf INCLUDED in its parent branch somewhere? As in: if we go directly UP, will we find this leaf?



Anyway. It needs to give me a list of all shared code, client code (burrito can seperate) and give ME the order in which they are needed
Shared code will have numbers from the big function, but we will simply maintain their order restricted to the shared folder (shared does not depend on client)
client code will then exclude the shared code (already included), then use our metric for including the files
  How does it seperate cjs and non-cjs libs?
  1. hopefully jQuery exists in CJS format, although => have to host it ourselves...
  2. alternatively requires can be done conditionally $ ?= require('jQuery') for stuff we are not sure of
  3. spine attaches to module.exports conditionally, so we can export it into app_name.modules and everything else requires Spine will get it from there!
###

coffee      = require 'coffee-script'
fs          = require 'fs'
path        = require 'path'
#detective   = require 'detective'
{compile}   = require './utils'


toAbsPath = (name, reqFolders) ->
  if name[0...2] is './' # relative path
    name = name[2...]
    while name[0...3] is '../'
      reqFolders = reqFolders[0...-1] # slice away the top folder every time we see a '../' string (NB: currently allows excessive ups as slice is always legal - but illegal on client)
      name = name[3...]
  prependStr = if reqFolders.join('/') then reqFolders.join('/')+'/' else ''
  absPath = prependStr+name


class Resolver
  constructor : ({@basePoint, @domainPaths}) ->

  loadDependencies : (name, reqFolders, domain) ->
    code = compile(@findAppropriate(toAbsPath(name, reqFolders), domain))
    detective(code)

  findAppropriate : (absPath, domain) -> # what domain are we scanning?
    orderedPaths = [domain].concat @domainPaths.filter((e) -> e isnt domain) # means this domain is scanned first, else order is preserved
    for path in orderedPaths
      return
      #fs. check if path+file is an existing file, if it is return the compiled version of it + THE DOMAIN WE FOUND IT ON SO DETECTIVE KNOWR WHERE TO LOOK
    throw new Error("require call for #{file} not found on any of the client require domains", @domainPaths)
    return

    #cant use the require algorithms, but needs to know current domain for relative require strings
    # this should construct an ABSOLUTE path (which can be the ambiguous absolute version my require uses)


  getTree : () ->
    tree = {name: @basePoint, deps: {}, reqFolders: [], domain: @domainPaths['client']}

    clearParentEntries = (treePos) ->
      delete treePos.parent # does not have to exist to be cleared
      for dep of treePos.deps
        clearParentEntries(treePos.deps[dep])
      return

    branchScanUp = (treePos, dep) -> # makes sure no circular references exists for dep going up from current point in tree (tree starts at top)
      loop
        return if treePos.parent is undefined # got all the way to @basePoint without finding self => good
        treePos = treePos.parent

        if treePos.name is currentDep.name
          clearParentEntries(tree) # so that node is able to console.log it (cant log a circular structure)
          throw new Error("#{treePos.name} has a circular dependency: it gets re-required by its requirement for module: #{currentDep.parent.name}", tree)
      return

    recursiveDetective = (treePos, name) ->
      reqFolders = treePos.name.split(path.basename(treePos.name))[0][0...-1].split('/') # array of folders to move into relative to basepoint to get to the file that required dep below
      for dep in @loadDependencies(treePos.name, treePos.reqFolders, treePos.domain) # use detective to get this 'deps' fn
        branchScanUp(treePos, dep) # make sure this dep does not exist above it in the tree
        treePos.deps[dep] = {name : dep, parent: treePos, deps: {}, reqFolders: reqFolders }
        arguments.callee(treePos.deps[dep])
      return

    recursiveDetective(tree, @basePoint)
    clearParentEntries(tree)
    console.log tree

sortDependencies = (tree) -> # must flatten array into levels to get an ordered list of filenames w/resp. paths
  #need to:
  #1. add an index to the tree to indicate what level we are on (do in recursiveDetective step?)
  #2. create an ARRAY with path+level+$+level (so there will be multiple versions potentially, so remove worse ones as we go)
  for mod in tree
    stuff

  #3. then sort by level descending and remove the level from the name so that it can be used by builder verbatim : )
  arr.sort((a,b) -> b.split('$')[1] - a.split('$')[1]).map((e) -> e.split('$')[0]) # this will give you the inclusion order!


module.exports = (o) ->
  tree = (new Resolver(o)).getTree()
  if o.targetTree
    # write sanitized version of the tree to the target file for code review
    return

  sortDependencies(tree)


if module is require.main
  reqPoint = 'models/user'
  name = './event'
  reqFolders = reqPoint.split(path.basename(reqPoint))[0][0...-1].split('/') #remove name, last slash and convert to folders
  console.log reqFolders
  console.log toAbsPath(name, reqFolders)


###
tree = {
  name : 'app'
  deps : {
    'A' : {
      parent: tree
      name : 'A'
      deps : {}
    },
    'B' : {
      parent: tree
      name : 'B'
      deps :
        'BA' : {
          parent : tree.deps['B']
          name : 'BA'
          deps : {}
        }
      }
    }

  }
}

deps are simply in the form
['A','B','C'] => should map onto the keys in tree.deps(['A'].deps(['AB'].deps)) etc

at each point we can check parents by doing:

###
