exports.bake = require('./lib/bake.js');
exports.glaze = require('./lib/glaze.js');
/*
process.chdir(self.options['working directory']);
@env = process.env.NODE_ENV or 'development';
return @ if !@environmentMatches

Master::in = (env) ->
  @_env = env
  @

Master::use = (what) ->
  minification (then extra param is minifier if set)
  analysis (function to pipe to (default console log) || if string: location to write to), then extra params are suffix,prefix


Master::data = ()
  @_data = true # ugh, every other method has to false it apart from data methods..

alternatively:
Master::data = (obj) ->
  @_data = obj

Master::paths = (obj) ->
  @_paths = (obj)
*/
