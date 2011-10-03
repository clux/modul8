fs          = require 'fs'
path        = require 'path'
stylus      = require 'stylus'
nib         = require 'nib'
{exists}    = require './utils'

read = (name) ->
  fs.readFileSync(name, 'utf8')

minifier = (css) ->
  uglifycss = require 'uglifycss'
  uglifycss.processString css,
    maxLineLen: 0
    expandVars: false
    cuteComments: false

module.exports = (o) ->
  throw new Error('brownie glaze requires a target and an entryPoint') if !o.target or !o.entryPoint
  throw new Error('brownie glaze: entryPoint not found: tried: '+o.entryPoint) if !exists(o.entryPoint)

  stylus(read(o.entryPoint))
  .set('compress',o.minify)
  .set('filename',o.entryPoint)
  #.use(nib())
  #.include(nib.path)
  #.include(options.nibs)
  .render (err, css) ->
    if (err) then throw new Error(err)

    if o.minify
      minifier = o.minifier ? minifier
      throw new Error("brownie glaze: minifier must be a function") if !minifier instanceof Function
      css = minifier(css)



    return css if !o.target
    fs.writeFileSync(o.target, css)
