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
detective   = require 'detective'
{compile}   = require './utils'

domainToPath = (domain) ->
  switch domain
    when 'shared' then 'shared/'
    when 'client' then 'client/'
    when 'modules' then 'client/modules'
    else 'client/libs'

findAppropriate = (file) ->
  # must be able to use the require algorithm...

loadDependencies = (file) -> # name is the require string.. we need to map this to the file => need to use the require function in require.coffee
  code = compile(findAppropriate(file))
  detective(code)

class Resolver
  constructor : ({@basePoint, @baseFolder}) ->
    #NB: this must use the same require algorithm... to be sure that it can resolve the files
    #IE must create the global object as if we were to use it...

  getTree : () ->
    tree = {name : @basePoint, deps : {}}

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
      for dep in loadDependencies(treePos.name) # use detective to get this 'deps' fn
        branchScanUp(treePos, dep) # make sure this dep does not exist above it in the tree
        treePos.deps[dep] = {name : dep, parent: treePos, deps: {}}
        arguments.callee(treePos.deps[dep])
      return

    recursiveDetective(tree, @basePoint)
    clearParentEntries(tree)
    console.log tree

  sortDependencies : () ->


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
