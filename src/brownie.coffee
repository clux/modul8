fs          = require 'fs'
path        = require 'path'
codeAnalyis = require './codeanalysis'
{compile, exists, anonWrap, jQueryWrap, objCount, objFirst} = require './utils'
{uglify, parser} = require 'uglify-js'

# helpers
pullData = (parser, name) -> # parser interface
  throw new Error("#{name}_parser is not a function") if not parser instanceof Function
  parser()

minify = (code) -> # minify function, this can potentially also be passed in if we require alternative compilers..
  uglify.gen_code(uglify.ast_squeeze(uglify.ast_mangle(parser.parse(code))))


# IF we call them SpineAjax we must require SpineAjax
# IF we call them Spine.Ajax we must require Spine.Ajax (which may lead people to believe we can require Spine and reference Spine.Ajax which simply isnt true)
# SOLN: either:
#   1. include them in order as libraries and add an arbiter for the whole of spine (since we technically use it as one)
#   2. explicitly require submodules of spine at the same time as spine was required => order gets correct
# 2. however comes with the problem of having these spine submodules having a particular name!

bundle = (codeList, o) ->
  l = []
  # 0. attach libs if we didnt want to split them into a separate file
  l.push = (compile(o.libDir+file) for file in o.libFiles).join('\n') if !o.libsOnlyTarget and o.libDir and o.libFiles # concatenate files as is

  # 1. construct the namespace object
  namespace = {client:{}, internal: {}, shared: {}, modules: {}}  # TODO: userLocals + require use of internals (wont work with codeanalysis - as they are not really files)
  l.push "var #{o.appName} = #{JSON.stringify(namespace)};"

  # 2. pull in data from parsers
  l.push "#{o.appName}.internal.#{name} = #{pullData(parser,name)};" for name, parser of o.parsers

  # 3. attach require code
  l.push "var requireNamespace = '#{o.appName}';" # require needs to know where to look
  l.push compile('./require.coffee')

  # 4. include framework specific code
  l.push (compile(o.internalDir + file) for file in o.internalDir).join('\n') if o.internalDir

  # 5. include CommonJS compatible code - wrap each file in a define function for relative requires
  defineWrap = (code, exportName, domain) -> "#{o.appName}.define(exportName, domain,function(require, exports, module){#{code}});"

  # THESE POINTS HERE FUCK UP A BIT:
  # each domain should have different rules, modules and shared should not be wrapped in DOMLOADED for instance
  # => need to rewrite a bit of codeanalysis to make it so that output from sort give me simply the key from the object!

  # 5.a) include modules (these should not be dependant on the App or the DOM)
  # l.push (defineWrap(compile(osmething), modulename, 'modules') for somethogn in o.modules).join('\n')

  # 5.b) include compiled files from codeList in correct order
  #l.push jQueryWrap( (defineWrap(compile(file[1]+file[0]), file[0], getDomain(file[1])) for file in codeList).join('\n') )

  l.join '\n'


exports.bake = (i) ->
  throw new Error("brownie needs valid basePoint and domains")  if !i.basePoint or !i.domains
  throw new Error("brownie needs the first domain to be the location of the basePoint") if !objCount(i.domains) > 0 or !exists(objFirst(i.domains)+i.basePoint)

  #reverseDomains = {}
  #reverseDomains[path] = name for name, path of i.domains

  i.appName ?= 'Brownie'
  ca = codeAnalyis(i.basePoint, i.domains)

  #TODO: should internalDir be in the global require scope? Should perhaps be hidden away? Local files with same name will override requires...

  if i.target
    c = bundle(ca.sorted(), i)
    c = minify(c) if i.minify
    fs.writeFileSync(i.target, c)

    if i.libsOnlyTarget and i.libDir and i.libFiles # => libs where not included in above bundle
      libs = (compile(i.libDir+file) for file in i.libFiles).join('\n') # concatenate libs as is
      libs = minify(libs) if i.minifylibs
      fs.writeFileSync(i.libsOnlyTarget, libs)

  fs.writeFileSync(i.treeTarget, ca.printed()) if i.treeTarget
  console.log ca.printed() if i.logTree


exports.decorate = (i) ->
  stylus = require 'stylus'
  nib = require 'nib'

  stylus(fs.readFileSync(i.input, 'utf8'))
  .set('compress',i.minify)
  .set('filename',i.input)
  #.use(nib())
  #.include(nib.path)
  #.include(options.nibs)
  .render (err, css) ->
    if (err) then throw New Error(err)

    if i.minify
      uglifycss = require 'uglifycss'
      options =
        maxLineLen: 0
        expandVars: false
        cuteComments: false
      css = uglifycss.processString(css, options)

    return css if !i.target
    fs.writeFileSync(i.target, css)
