var fs = require('fs')
  , md = require("node-markdown").Markdown;

function generateDocs() {
  var head = fs.readFileSync('head.html', 'utf8')
    , tail = fs.readFileSync('tail.html', 'utf8')
    , files = ['api', 'cli', 'xcjs', 'plugins', 'modularity', 'npm', 'require'];

  files.forEach(function (file) {
    var out = fs.readFileSync('../docs/' + file + '.md', 'utf8');
    fs.writeFileSync('./docs/' + file + '.html', head + md(out) + tail);
  });
}

generateDocs();

