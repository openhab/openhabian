const fs = require('fs');
const path = require('path');
const childProcess = require('child_process');

/* source is not used. This must be the first loader in the chain, using this.resource, so that sassc can include the scss file's directory in the include path */
module.exports = function() {
    this.cacheable();

    const workdir = fs.mkdtempSync("sassc-loader.");
    const out = path.join(workdir, "output.css");

    childProcess.execFileSync(
        'sassc',
        ['--load-path=node_modules', '--style=compressed', '--sourcemap', this.resource, out],
        { stdio: ['pipe', 'inherit', 'inherit'] });

    const css = fs.readFileSync(out, 'utf8');
    const cssmap = fs.readFileSync(out + ".map", 'utf8');

    fs.unlinkSync(out);
    fs.unlinkSync(out + ".map");
    fs.rmdirSync(workdir);

    this.callback(null, css, cssmap);
};
