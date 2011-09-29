sub2 = require('./sub2') # relative require

# we can attach properties on exports if we want to export an object
# alternatively, we can attach anything directly to module.exports
# this will allow you to both export everything at once,
# and also export less common things like a string, function, array..

# here we export an object with a doComplex property
exports.doComplex = (str) -> # sub1 is an arbiter for sub2
  sub2(str+' (now the job is easy <sub1/>)')
