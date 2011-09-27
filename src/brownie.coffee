fs          = require 'fs'
path        = require 'path'
codeAnalyis = require './codeanalysis'
{compile, exists, anonWrap, jQueryWrap, objCount} = require './utils'
{uglify, parser} = require 'uglify-js'

# helpers
pullData = (parser, name) -> # parser interface
  throw new Error("parser for #{name} is not a function") if not parser instanceof Function
  parser()

minify = (code) -> # minify function, this can potentially also be passed in if we require alternative compilers..
  uglify.gen_code(uglify.ast_squeeze(uglify.ast_mangle(parser.parse(code))))


# IF we call them SpineAjax we must require SpineAjax
# IF we call them Spine.Ajax we must require Spine.Ajax (which may lead people to believe we can require Spine and reference Spine.Ajax which simply isnt true)
# SOLN: either:
#   1. include them in order as libraries and add an arbiter for the whole of spine (since we technically use it as one)
#   2. explicitly require submodules of spine at the same time as spine was required => order gets correct
# 2. however comes with the problem of having these spine submodules having a particular name!

bundle = (codeList, ns, o) ->
  l = []
  d = o.domains
  # 0. attach libs if we didnt want to split them into a separate file
  if !o.libsOnlyTarget and o.libDir and o.libFiles
    l.push (compile(o.libDir+file) for file in o.libFiles).join('\n') # concatenate files as is

  # 1. construct the namespace object
  nsObj = {} # TODO: userLocals
  nsObj[name] = {} for [name, path] in o.domains
  nsObj.data = {}
  l.push "var #{ns} = #{JSON.stringify(nsObj)};"

  # 2. pull in data from parsers
  l.push "#{ns}.data.#{name} = #{pullData(pull_fn,name)};" for name, pull_fn of o.data # TODO: should this be requirable?

  # 3. attach require code
  requireConfig =
    namespace : ns
    domains   : dom for [dom, path] in o.domains
    fallback  : o.fallBackFn # if our require fails, give a name to a globally defined fn here that
  l.push "var requireConfig = #{JSON.stringify(requireConfig)};"
  l.push anonWrap(compile(__dirname + '/require.coffee'))

  # 4. include CommonJS compatible code in the order they have to be defined - wrap each file in a define function for relative requires
  defineWrap = (exportName, domain, code) -> "#{ns}.define('#{exportName}','#{domain}',function(require, module, exports){#{code}});"
  domMap = {}
  domMap[name] = path for [name,path] in o.domains

  # 4.a) include non-client CommonJS modules (these should be independant on the App and the DOM)
  l.push (defineWrap(name, domain, compile(domMap[domain] + name)) for [name, domain] in codeList when domain isnt 'client').join('\n')

  # 4.b) include compiled files from codeList in correct order
  l.push o.DOMLoadWrap((defineWrap(name, 'client', compile(domMap.client + name)) for [name, domain] in codeList when domain is 'client').join('\n'))


  l.join '\n'

exports.bake = (i) ->
  if !i.domains
    throw new Error("brownie needs valid basePoint and domains. Got "+JSON.stringify(i.domains))
  i.basePoint ?= 'app.coffee'
  clientDom = path for [name, path] in i.domains when name is 'client'
  if !i.domains.length > 0 or !exists(clientDom+i.basePoint)
    throw new Error("brownie needs a client domain, and the basePoint to be contained in the client domain. Tried: "+clientDom+i.basePoint)
  hasData = false
  for [name,path] in i.domains when name is 'data'
    hasData = true
    break
  if hasData
    throw new Error("brownie reserves the 'data' domain for pulled in code")

  i.namespace ?= 'Brownie'
  i.DOMLoadWrap ?= jQueryWrap

  ca = codeAnalyis(i.basePoint, i.domains, i.localTests)
  #NB: ca ignores require strings beginning with data::

  if i.target
    c = bundle(ca.sorted(), i.namespace, i)
    c = minify(c) if i.minify
    fs.writeFileSync(i.target, c)

    if i.libsOnlyTarget and i.libDir and i.libFiles # => libs where not included in above bundle
      libs = (compile(i.libDir+file) for file in i.libFiles).join('\n') # concatenate libs as is
      libs = minify(libs) if i.minifylibs
      fs.writeFileSync(i.libsOnlyTarget, libs)

  fs.writeFileSync(i.treeTarget, ca.print()) if i.treeTarget
  console.log ca.print() if i.logTree


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
