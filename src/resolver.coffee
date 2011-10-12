{exists} = require './utils'

# criteria for whether a require string is relative, rather than absolute
# absolute require strings will scan on the defined require paths (@domains)
isRelative = (reqStr) -> reqStr[0...2] is './'

# ignorelist regex check and filter fn to be used on each detective result
domainIgnoresReg = /^data(?=::)|^external(?=::)|^M8(?=::)/
domainReg = /^(.*::)/
isLegalRequire = (reqStr) ->
  return false if domainIgnoresReg.test(reqStr)
  if domainReg.test(reqStr) and isRelative(stripDomain(reqStr))
    throw new Error("modul8::analysis found illegal require string combining domain prefix + relative")
  true

# take out domain prefix from request string if exists
stripDomain = (reqStr) -> reqStr.replace(domainReg,'')

# absolutize path + separate out domain if specified
toAbsPath = (name, subFolders, domain) -> # subFolders is array of folders after domain base that we were requiring from
  return [stripDomain(name), name.match(domainReg)[1][0...-2]] if domainReg.test(name) # domain specific require includes domain in string
  return [name, undefined] if !isRelative(name) # absolute require, we do not know domain
  name = name[2...]
  while name[0...3] is '../'
    subFolders = subFolders[0...-1] # slice away the top folder every time we see a '../' string
    name = name[3...]
  folderStr = subFolders.join('/')
  prependStr = if folderStr then folderStr+'/' else ''
  [prependStr+name, domain] # relative request => domain is this domain

# resolver constructor
Resolver = (@domains, @arbiters, @mainDomain) ->

# locate location of file from absReq (assumed only called on files that pass isLegalRequire)
Resolver::locate = (reqStr, subFolders, domain) ->
  [absReq, foundDomain] = toAbsPath(reqStr, subFolders, domain)
  throw new Error("modul8::analysis could not resolve a require for an unconfigured domain: #{foundDomain}") if foundDomain? and !@domains[foundDomain]
  return [absReq, 'M8', true] if foundDomain is 'M8' or absReq of @arbiters # arbiter or API require
  return [absReq, foundDomain, true] if foundDomain is 'external' # externally loaded
  throw new Error("modul8 does not allow other domains to reference the main #{@mainDomain} domain. required from #{domain}") if foundDomain is @mainDomain and domain isnt @mainDomain

  # else we have to verify the file exists (if we know domain, easy, else, scan all, starting in requiree's domain)
  scannable = if foundDomain then [foundDomain] else [domain].concat(name for name of @domains when name isnt domain)

  for dom in scannable
    # try raw require, then with js extension, then coffee extension
    if exists(@domains[dom]+absReq)
      return [absReq, dom, false]
    if exists(@domains[dom]+absReq+'.js')
      return [absReq+'.js', dom, false]
    if exists(@domains[dom]+absReq+'.coffee')
      return [absReq+'.coffee', dom, false]

  throw new Error("modul8::analysis could not resolve a require for #{reqStr} from #{domain} - looked in #{scannable}")

module.exports = {
  isLegalRequire
  Resolver
}