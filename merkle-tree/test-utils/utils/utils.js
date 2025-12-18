const path = require('path');

function getPathFromType(type) {
  if (type === '0') {
    return path.join(__dirname, `../test-outputs/genesis_sequencer_tree.json`);
  } else if (type === '1') {
    return path.join(__dirname, `../test-outputs/contributor_tree.json`);
  }
  throw new Error('Invalid type');
}

module.exports = {
    getPathFromType
}