fs          = require 'fs'
path        = require 'path'
stylus      = require 'stylus'
nib         = require 'nib'

module.exports = (o) ->
  throw new Error('brownie glaze requires a target and an entryPoint') if !o.target

  stylus(fs.readFileSync(o.input, 'utf8'))
  .set('compress',o.minify)
  .set('filename',o.input)
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

    return css if !o.target
    fs.writeFileSync(o.target, css)
