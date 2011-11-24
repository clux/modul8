fs          = require('fs')
crypto      = require('crypto')
_           = require('underscore')
{read}      = require('./utils')


# creates a unique filename to use for the serializers
# uniqueness based on execution path, target.js and targetlibs.js - should be sufficient
makeGuid = (vals) ->
  vals.push fs.realpathSync()
  str = (v+'' for v in vals).join('_')
  crypto.createHash('md5').update(str).digest("hex")


Persister = (guidVals, @persistFile, @log = ->) ->
  guid = makeGuid(guidVals)
  #@log('persisting to '+persistFile)
  @pdata = if @persistFile then JSON.parse(read(@persistFile)) else {}
  @cfg = @pdata[guid] ?= {}
  @opts = @cfg['opts'] ?= {}
  return

Persister::filesModified = (fileList, doms, type) ->
  mTimesOld = @cfg[type] or {}
  mTimes = {}
  mTimes[d+'::'+f] = fs.statSync(doms[d]+f).mtime.valueOf() for [d, f] in fileList

  @cfg[type] = mTimes
  @save()

  if _.isEqual(mTimes, {})
    @log("initializing "+type)
    return true
  for f,m of mTimes
    if !(f of mTimesOld)
      @log("files added to "+type)
      return true
    if mTimesOld[f] isnt m
      @log("files updated in "+type)
      return true
  for f of mTimesOld
    if !(f of mTimes)
      @log("files removed from "+type)
      return true
  false

Persister::optionsModified = (o) ->
  #@log('isEqual JSON', _.isEqual(@opts, JSON.parse(JSON.stringify(o))))
  return false if _.isEqual(@opts, JSON.parse(JSON.stringify(o)))

  @cfg.opts = o
  @save()
  true

Persister::save = ->
  fs.writeFileSync(@persistFile, JSON.stringify(@pdata)) if @persistFile

module.exports = Persister
