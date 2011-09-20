###Need to scan basepoint for deps, then all the deps for deps. The least depended on modules should be included first
Need a function that can use node-detective/Burrito to scan for both require and shared calls, and give me an unambiguous array of filenames+paths
Need to store these results figure out what level they were required on with
E.g. if a module was found at level 3 and 5 that means they are required on level 2 and 4 so it must be included before the level 4 modules
What if basepoint requires A and B. And B requires A? => A gets level 3 and be gets level 2, FINE.
What if basepoint requires A and B. and B requires A and A requires B? => Impossible.
  First of all, that => we need to resolve circulars by keeping track of things..
  Secondly, whoever we decide to put first wont run as it requires the other one...?
  Would it work with window?
  A exports to window.A and it has required a module B. This require is done outside the functions =>
    it will attempt to resolve before B is exported => requires result var is undefined.
  If require returns a function that will TRY to resolve. Then both functions will potentially be able to export, but require mechanics would fail.?
  SOLUTION: DISALLOW CIRCULAR DEPENDENCY:
   PROBLEM: HOW DO WE IDENTIFY A CIRCLE:
   EXAMPLES:
    1. app <- A, B. and A<->B
    2. app <- A, B, C and A<-B<-C<-A
    3. app <- A <- AA, AB and AA<->AB
    4. app <- (A <- AA), (B <- BA) and AA<->BA
    5. app <- (A <- AA), (B <- BA), (C <- CA) and AA<-BA<-CA<-AA
    6. app <- A, (B <- BA) and A<->BA.
    7. app <- A <- B <- A <- ...
    8. app <- A <- B <- app <- A <- B => always illegal to require app (but the DOM can reference its exports without problems!)
    => Chains can happen not just on its own level => hard to identify
    => each file can get a require tree that we on EACH level check for members against its members' require tree
    I.e.
    level 1: {app: ['A','B']}
    level 2: {app: ['A','B'], A: ['C'], B: ['D']} <- fine because neither A or Bs tree includes 'app'
    level 3: {app: ['A','B'], A: ['C'], B: ['D'], C:['D'], D:['A']} <- should fail because D includes 'A' when tree.A contains C which requires D => D<->A
    difficult to algorithm this though
    level 1: {app: ['A','B']}
    level 2: {app: ['A','B'], A:['C','D'], B:['D','A']} <- here we flattened each files array
      => every time we find a new file:
        1. add it to the big tree, recursively scan for its includes, and flatten that array.
        2. take all the members of this flat array: add its values as keys to the big tree -> goto 1.
      => each key in the big tree must be an absolute include path
      => this seems more difficult than it perhaps has to be...

    other way: EACH REQUIRE CALL HAS TO NOT END UP REQUIRING THE REQUIRER
    => each require has to create a depenedency tree if a flattened version of that includes self, throw new Error
    this should be fine because an individual files tree either resolves completely OR it ends up trying to reference itself eventually
    PROBLEM: it will only give an error of what the first branch that requires itself will be (it will likely happen at the edges...)
    SOLUTION:
      1. create FULL tree for level i
      2. for each branch: for each leaf: if leaf INCLUDED in its parent branch somewhere? As in: if we go directly UP, will we find this leaf? A <- B <- C <- A



Anyway. It needs to give me a list of all shared code, client code (burrito can seperate) and give ME the order in which they are needed
Shared code will have numbers from the big function, but we will simply maintain their order restricted to the shared folder (shared does not depend on client)
client code will then exclude the shared code (already included), then use our metric for including the files
  How does it seperate cjs and non-cjs libs?
  1. hopefully jQuery exists in CJS format, although => have to host it ourselves...
  2. alternatively requires can be done conditionally $ ?= require('jQuery') for stuff we are not sure of
  3. spine attaches to module.exports conditionally, so we can export it into app_name.modules and everything else requires Spine will get it from there!
###

domainToPath = (domain) ->
  switch domain
    when 'shared' then 'shared/'
    when 'client' then 'client/'
    when 'modules' then 'client/modules'
    else 'client/libs'

loadDependencies = (name) -> # name is the require string.. we need to map this to the file => need to use the require function in require.coffee
  file = fs.readFileSync(name)
  detective(file)

class Resolver
  constructor : ({@basePoint, @baseFolder}) ->
    #NB: this must use the same require algorithm... to be sure that it can resolve the files
    #IE must create the global object as if we were to use it...

  getTree : () ->
    point = @basePoint
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
