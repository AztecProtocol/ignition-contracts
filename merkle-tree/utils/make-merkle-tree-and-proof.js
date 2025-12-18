#!/usr/bin/env node

// Make merkle tree and proof
// - Create a merkle tree from a single address
// - returning the root - and it's inclusion proof
const { StandardMerkleTree } = require('@openzeppelin/merkle-tree');
const { AbiParameters } = require('ox');

const address = process.argv[2];

if (!address) {
  console.error('Please provide an address as argument');
  console.error('Usage: node make-merkle-tree-and-proof.js <address>');
  process.exit(1);
}

try {
  const tree = StandardMerkleTree.of([[address]], ["address"]);

  const root = tree.root;
  const abiEncoded = AbiParameters.encode(AbiParameters.from(["bytes32"]), [root]);

  console.log(abiEncoded);
} catch (error) {
  console.error('Error:', error.message);
  process.exit(1);
}
