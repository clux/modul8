coffee      = require 'coffee-script'
fs          = require 'fs'
path        = require 'path'

# code wrapper helpers
jQueryWrap = (code) ->
  '$(function(){'+code+'});'

anonWrap = (code) ->
  '(function(){'+code+'})();'

cjsWrap = (code, exportLocation) ->
  # So we can attach properties on exports
  start = "var exports = #{exportLocation}, module = {};"
  # If we defined this then we either wanted to define the whole export object at once, or to export a non-object, so overwrite
  end = "if (module.exports) {#{exportLocation} = module.exports;}"
  (start + code + end)


#This is good, but need define available somewhere on the browser: i can either attach it to app_name.modules, app_name, or window

defineWrap = (code) ->
  'define(function(require, exports, module) {'+code+'});'

compile = (fileName) ->
  switch path.extname(fileName)
    when '.js'
      fs.readFileSync(fileName, 'utf8')
    when '.coffee'
      coffee.compile(fs.readFileSync(fileName, 'utf8'),{bare:true}) # all coffee files must be wrapped later
    else
      throw new Error("file: #{fileName} does not have a valid javascript/coffeescript extension")

parse = (parser, name) -> # parser interface
  throw new Error("#{name}_parser is not a function") if not parser instanceof Function
  parser()

listToTree = (list) -> # create the object tree from input list of files
  moduleScan = (o, partial) ->
    f = partial[0]
    o[f] = {} if !o[f]?
    return if partial.length is 1
    moduleScan(o[f], partial[1..])
  obj = {}
  moduleScan(obj, file.replace(/\..*/,'').split('/')) for file in list
  obj

class Brownie # all main behaviour should go in here
  constructor  : (i) ->
    @app_name         = i.app_name ? 'Brownie'
    @model_parser     = i.model_parser
    @template_parser  = i.template_paser
    @version_parser   = i.version_parser
    @lib_dir          = i.lib_dir
    @lib_files        = i.lib_files       ? []
    @lib_files_cjs    = i.lib_files_cjs   ? []
    @client_dir       = i.client_dir
    @client_files     = i.client_files    ? []
    @internal_dir     = i.internal_dir
    @internal_files   = i.internal_files  ? []
    @shared_dir       = i.shared_dir
    @shared_files     = i.shared_files    ? []

    @basePoint = 'app.coffee'



  commonjs : (file, baseDir, baseName) ->
    code = compile(baseDir+'/'+file).replace(/\n.*require.main[\w\W]*$/, '')  # ignore the if require.main {} part - CHEAPLY chucks end of file (only solution atm)
    anonWrap(cjsWrap(code, "#{@app_name}.#{baseName}.#{file.split(path.extname(file))[0].replace(/\//,'.')}")) # take out extension and replace /->. to find tree

  globalObj   : ->
      client    : listToTree(@client_files)
      shared    : listToTree(@shared_files)
      server    : {}
      internal  : {models: {}, userLocals: {}, versions: {}}

  bake   : (l) ->
    # create the global window object
    l.push "#{@app_name} = #{JSON.stringify(@globalObj())};"
    # attach the strings created in the parsers to it
    l.push "#{@app_name}.internal.models = #{parse(@model_parser,'model')};" if @model_parser
    l.push "#{@app_name}.internal.versions = #{parse(@version_parser,'version')};" if @version_parser
    l.push "#{@app_name}.internal.templates = #{parse(@template_parser,'template')};" if @template_parser

    # attach internal require and define code
    l.push "requireAppName = '#{@app_name}';" # otherwise client require doesnt know where to look
    #l.push (anonWrap(compile('./client/' + file)) for file in ['require.coffee']).join('\n') # these files must come bundled with brownie
    #l.push (@commonjs(file, 'modules') for file in ['require.coffee']).join('\n')


    # attach external libraries (to window) [so they can be required via: spine ?= require('spine')]
    if @lib_dir
      l.push (compile(@lib_dir+file) for file in @lib_files).join('\n') # non-commonJS compatible libraries are exported raw (NOT FUNCTION WRAPPED!)
      l.push (@commonjs(file, @lib_dir, 'modules') for file in @lib_files_cjs).join('\n') #CJS ones will be safety wrapped

    # include framework specific code
    l.push (compile(@internal_dir + file) for file in @internal_files).join('\n') if @internal_dir

    # include shared code (cant reference non-shared code)
    l.push (@commonjs(file, @shared_dir, 'shared') for file in @shared_files).join('\n') if @shared_dir

    # include app code (to be executed on DOMLoaded)
    l.push jQueryWrap((@commonjs(file, @client_dir, 'client') for file in @client_files).join('\n')) if @client_dir

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
