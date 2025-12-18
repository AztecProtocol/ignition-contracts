#!/usr/bin/env node

const fs = require('fs');
const { StandardMerkleTree } = require('@openzeppelin/merkle-tree');
const { AbiParameters } = require('ox');
const { getPathFromType } = require('./utils');

const type = process.argv[2];

if (isNaN(type)) {
  console.error('Please provide a valid type as argument');
  console.error('Usage: node get-root.js <type> --- Type 0 = Genesis Sequencer, Type 1 = Contributor');
  process.exit(1);
}

try {
  const treeData = JSON.parse(fs.readFileSync(getPathFromType(type), 'utf8'));
  const tree = StandardMerkleTree.load(treeData);

  const encodedRoot = AbiParameters.encode(AbiParameters.from(["bytes32"]), [tree.root]);
  console.log(encodedRoot);
} catch (error) {
  console.error('Error:', error.message);
  process.exit(1);
}
