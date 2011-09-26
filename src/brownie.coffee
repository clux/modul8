fs          = require 'fs'
path        = require 'path'
{cjsWrap, compile, anonWrap, jQueryWrap, listToTree} = require './utils'
organizer   = require './organizer'

pullData = (parser, name) -> # parser interface
  throw new Error("#{name}_parser is not a function") if not parser instanceof Function
  parser()

class Brownie # all main behaviour should go in here
  constructor  : (i) ->
    @appName        = i.appName ? 'Brownie'
    @modelParser    = i.modelParser
    @templateParser = i.templateParser
    @versionParser  = i.versionParser
    @basePoint      = i.basePoint ? 'app.coffee'
    @clientDir      = i.clientDir
    @sharedDir      = i.sharedDir
    @internalDir    = i.internalDir
    @libDir         = i.libDir

    throw new Error("Brownie needs valid basePoint and clientDir") if !@basePoint or !@clientDir
    #@lib_files        = i.lib_files       ? []
    #@lib_files_cjs    = i.lib_files_cjs   ? []
    #@client_files     = i.client_files    ? []
    #@internal_files   = i.internal_files  ? []
    #@shared_files     = i.shared_files    ? []
    dp = []
    dp.push @moduleDir if @moduleDir # should not include stuff like jQuery, but Spine should be fine...
    dp.push @clientDir
    dp.push @sharedDir if @sharedDir
    @tree = resolver({basePoint: @basePoint, domainPaths: dp})



  commonjs : (file, baseDir, baseName) ->
    code = compile(baseDir+'/'+file).replace(/\n.*require.main[\w\W]*$/, '')  # ignore the if require.main {} part - CHEAPLY chucks end of file (only solution atm)
    anonWrap(cjsWrap(code, "#{@appName}.#{baseName}.#{file.split(path.extname(file))[0].replace(/\//,'.')}")) # take out extension and replace /->. to find tree

  globalObj   : ->
      #client    : listToTree(@client_files)
      #shared    : listToTree(@shared_files)
      server    : {}
      internal  : {models: {}, userLocals: {}, versions: {}}

  bake   : (l) ->
    # create the global window object
    l.push "#{@appName} = #{JSON.stringify(@globalObj())};"
    # attach the strings created in the parsers to it
    l.push "#{@appName}.internal.models = #{pullData(@modelParser,'model')};" if @modelParser
    l.push "#{@appName}.internal.versions = #{pullData(@versionParser,'version')};" if @versionParser
    l.push "#{@appName}.internal.templates = #{pullData(@templateParser,'template')};" if @templateParser

    # attach internal require and define code
    l.push "requireAppName = '#{@appName}';" # otherwise client require doesnt know where to look
    #l.push (anonWrap(compile('./client/' + file)) for file in ['require.coffee']).join('\n') # these files must come bundled with brownie
    #l.push (@commonjs(file, 'modules') for file in ['require.coffee']).join('\n')


    # attach external libraries (to window) [so they can be required via: spine ?= require('spine')]
    #if @lib_dir
    #  l.push (compile(@lib_dir+file) for file in @lib_files).join('\n') # non-commonJS compatible libraries are exported raw (NOT FUNCTION WRAPPED!)
    #  l.push (@commonjs(file, @lib_dir, 'modules') for file in @lib_files_cjs).join('\n') #CJS ones will be safety wrapped

    # include framework specific code
    #l.push (compile(@internal_dir + file) for file in @internal_files).join('\n') if @internal_dir

    # include shared code (cant reference non-shared code)
    #l.push (@commonjs(file, @shared_dir, 'shared') for file in @shared_files).join('\n') if @shared_dir

    # include app code (to be executed on DOMLoaded)
    #l.push jQueryWrap((@commonjs(file, @client_dir, 'client') for file in @client_files).join('\n')) if @client_dir

    l.join '\n'


bundle = (codeList, appName, libraries, parsers) ->
  l = []
  # 1. construct the global object
  # we can ALMOST make do with codeList, we only need to determine what domain these files are on and remove the beginning from that..
  # though this can be quite hard:
  # 1. domainPaths can be passed in relatively OR absolutely to Organizer, so simply splitting away this isnt going to work
  # 2. if passed in relatively and path is ./ then how the fuck do we determine domain from that? => impossible
  # SOLN: codeList must be an array of dicts: {path: pathrelativetodomain, domain: domainPath[x]}

  #filelist = (c[0] for c in codeList) might have to write a new listToTree that can take these pairs

  l.push "#{appName}.internal.#{name} = #{pullData(parser,name)};" for name, parser of parsers

  # 3. attach require code
  # 4. attach libraries that were included in list
  l.push (compile(@libDir+file) for file in @libFiles).join('\n') # non CJS modules are exported RAW (CS files compiled bare, TODO: maybe change?)

  # 5. Attach compiled files from codeList in correct order, and make use of our define implementation to attach it to our export tree
  defineWrap = (code, exportName, domain) -> "#{appName}.define(function(require, exports, module){#{code}}, exportName, domain);"
  l.push (defineWrap(compile(file.path), file.exportName, file.domain) for file in codeList).join('\n')


#app -> spine, controllers, models
#models,controllers -> spine
# => spine gets high rating (included in all of these) => gets included early in bundle
# but spine ought to have its modules included before itself if we mean to use them...
# => when WE use them, we require them at the same time as Spine (=>IF we require them, then this is fine (as they would get before))
# if we use them at the same time but simply Spine = require('Spine') and use Spine.Ajax (then Ajax module does not get required...) BAD
# SOLN: either:
#   1. include them in order as libraries and add an arbiter for the whole of spine (since we technically use it as one)
#   2. explicitly require submodules of spine at the same time as spine was required => order gets correct
# 2. however comes with the problem of having these spine submodules having a particular name!
# IF we call them SpineAjax we must require SpineAjax
# IF we call them Spine.Ajax we must require Spine.Ajax (which may lead people to believe we can require Spine and reference Spine.Ajax which simply isnt true)

exports.bake = (i) ->
  throw new Error("brownie: clientDir parameter is required") if !i.clientDir
  domains = [i.clientDir]
  domains.push [i.sharedDir] if i.sharedDir

  o = organizer(i.basePoint, domains)

  if i.target
    b = bundle(o.codeOrder(), i.appName ? 'Brownie', i.libs, i.parsers)
    if i.minify
      {uglify, parser} = require 'uglify-js'
      b = uglify.gen_code(uglify.ast_squeeze(uglify.ast_mangle(parser.parse(b))))
    fs.writeFileSync(i.target, b)

  if i.treeTarget
    fs.writeFileSync(i.treeTarget, o.codeAnalysis())

  if i.logTree
    console.log o.codeAnalysis()


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
