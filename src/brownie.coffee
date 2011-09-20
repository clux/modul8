coffee      = require 'coffee-script'
fs          = require 'fs'
path        = require 'path'
detective   = require 'detective'
{cjsWrap, compile, anonWrap, jQueryWrap, pullData} = require './utils'


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


    #@lib_files        = i.lib_files       ? []
    #@lib_files_cjs    = i.lib_files_cjs   ? []
    #@client_files     = i.client_files    ? []
    #@internal_files   = i.internal_files  ? []
    #@shared_files     = i.shared_files    ? []



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


exports.bake = (i) ->
  b = (new Brownie i).bake([])
  if i.minify
    {uglify, parser} = require 'uglify-js'
    b = uglify.gen_code(uglify.ast_squeeze(uglify.ast_mangle(parser.parse(b))))

  if i.target then fs.writeFileSync(i.target, b) else b

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
