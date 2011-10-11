path        = require 'path'
fs          = require 'fs'
coffee      = require 'coffee-script'

# criteria for whether a require string is relative, rather than absolute
# absolute require strings will scan on the defined require paths (@domains)
isRelative = (reqStr) -> reqStr[0...2] is './'

# ignorelist regex check and filter fn to be used on each detective result
domain_ignore_list = /^data(?=::)|^external(?=::)|^M8(?=::)/
isLegalDomain = (reqStr) -> !domain_ignore_list.test(reqStr)

# take out domain prefix from request string if exists
stripDomain = (reqStr) -> reqStr.replace(/^(.*::)/,'')

# convert relative requires to absolute ones
# relative folder movement limited to ./(../)*n + normalpath [no backing out after normal folder movement has started]
# will returisLegaln a string (without a leading slash) that can be post-concatenated with the domain specific path
toAbsPath = (name, subFolders, domain) -> # subFolders is array of folders after domain base that we were requiring from
  return name if !isRelative(name)
  name = name[2...]
  while name[0...3] is '../'
    subFolders = subFolders[0...-1] # slice away the top folder every time we see a '../' string
    name = name[3...]
  folderStr = subFolders.join('/')
  prependStr = if folderStr then folderStr+'/' else ''
  domain+'::'+prependStr+name


makeResolver = (domains) ->
  (absReq, domain) ->
    orig = absReq

    # emulate client side require behaviour here
    if (domainReg = /^(.*)::/).test(absReq)
      scannable = [absReq.match(domainReg)[1]] # relative requires get pushed in here, because toAbsPath appends their domain
      absReq = absReq.split('::')[1]
    else
      scannable = [domain].concat(name for name of domains when name isnt domain)

    for dom in scannable
      # try raw require, then with coffee extension, then js extension
      return {absReq, dom} if exists(domains[dom]+absReq)
      return {absReq: absReq+'.js', dom: dom} if exists(domains[dom]+absReq+'.js')
      return {absReq: absReq+'.coffee', dom: dom} if exists(domains[dom]+absReq+'.coffee')

    throw new Error("modul8::analysis could not resolve a require for #{orig} (#{absReq}) - looked in #{scannable}")

# fs shortcut
read = (name) -> fs.readFileSync(name, 'utf8')

# internal compile shortcut
compile = (file, bare=true) ->
  switch path.extname(file)
    when '.js'
      read(file)
    when '.coffee'
      coffee.compile(read(file),{bare}) # all coffee files that eludes M8.define must get the standard safety wrapper to encapsulate private variables
    else
      throw new Error("file: #{file} does not have a valid javascript/coffeescript extension")

# simple fs extension to check if a file exists [used to verify require calls' validity]
exists = (file) ->
  try
    fs.statSync(file)
    return true
  catch e
    return false


module.exports = {
  compile
  exists
  read
  isRelative
  toAbsPath
  isLegalDomain
  makeResolver
  stripDomain
}
