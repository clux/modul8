fs          = require 'fs'
path        = require 'path'
stylus      = require 'stylus'
nib         = require 'nib'
{exists,read}    = require './utils'

minifier = (css) ->
  uglifycss = require 'uglifycss'
  uglifycss.processString css,
    maxLineLen: 0
    expandVars: false
    cuteComments: false

cssWrap = (style, name) ->
  name+"()\n  @css{\n" + style + "\n  }" # => can do import 'name', name() in stylus

module.exports = (o) ->
  throw new Error('brownie glaze requires a target and an entryPoint') if !o.target or !o.entryPoint
  throw new Error('brownie glaze: entryPoint not found: tried: '+o.entryPoint) if !exists(o.entryPoint)

  stylus(read(o.entryPoint))
  .set('compress',o.minify)
  .set('filename',o.entryPoint)
  .use(nib())
  .import('nib')
  #.include(nib.path)
  #.include(options.nibs)
  .render (err, css) ->
    throw err if err

    #if o.minify
    #  minifier = o.minifier ? minifier
    #  throw new Error("brownie glaze: minifier must be a function") if !minifier instanceof Function
    #  css = minifier(css)



    return css if !o.target
    fs.writeFileSync(o.target, css)
