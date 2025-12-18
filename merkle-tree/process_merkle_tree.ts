import * as fs from 'fs';
import * as path from 'path';
import { StandardMerkleTree } from '@openzeppelin/merkle-tree';
import { Address } from 'ox';
import crypto from 'crypto';

async function processAddresses() {
  const genesisSequencerCsvPath = path.join(__dirname, './input/genesis_sequencer_whitelist.csv');
  const contributorCsvPath = path.join(__dirname, './input/contributor_whitelist.csv');
  const genesisSequencerContent = fs.readFileSync(genesisSequencerCsvPath, 'utf-8');
  const contributorContent = fs.readFileSync(contributorCsvPath, 'utf-8');

  const outputDir = path.join(__dirname, './outputs');
  // Create outputs directory if it doesn't exist
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  const genesisSequencerFileHash = crypto.createHash('sha256').update(genesisSequencerContent).digest('hex');
  const contributorFileHash = crypto.createHash('sha256').update(contributorContent).digest('hex');

  let existingHashes: Record<string, string> = {};
  try {
    const hashesFile = fs.readFileSync(path.join(outputDir, 'hashes.json'), 'utf-8');
    existingHashes = JSON.parse(hashesFile) as Record<string, string>;
  } catch {
    existingHashes = {};
  }
  const hasGenesisInputFileChanged = existingHashes['genesis_sequencer'] !== genesisSequencerFileHash;
  const hasContributorInputFileChanged = existingHashes['contributor'] !== contributorFileHash;

  if (!hasGenesisInputFileChanged && !hasContributorInputFileChanged) {
    console.log('No input files have changed, skipping processing...');
    return;
  }

  /**
   * Process Genesis Sequencer
  */
  if (hasGenesisInputFileChanged) {
    console.log('Genesis Sequencer input file has changed, processing again...');
    const genesisSequencerJsonPath = path.join(outputDir, 'genesis_sequencer_valid_addresses.json');
    const genesisSequencerRootPath = path.join(outputDir, 'genesis_sequencer_root.txt');
    const genesisSequencerTreePath = path.join(outputDir, 'genesis_sequencer_tree.json');
    const genesisSequencerLines = genesisSequencerContent.trim().split('\n');
    const genesisSequencerValidAddresses: string[] = [];
    const genesisSequencerInvalidAddresses: string[] = [];

    console.log(`Processing Genesis Sequencer ${genesisSequencerLines.length} addresses...`);
    for (const line of genesisSequencerLines) {
      const addr = line.trim();
      if (addr) {
        try {
          if (Address.validate(addr)) {
            genesisSequencerValidAddresses.push(addr);
          } else {
            genesisSequencerInvalidAddresses.push(addr);
          }
        } catch (error) {
          genesisSequencerInvalidAddresses.push(addr);
        }
      }
    }
    console.log("------------------ Summary -----------------------")
    console.log("------------------ Genesis Sequencer -----------------------")
    console.log(`Genesis Sequencer Valid addresses: ${genesisSequencerValidAddresses.length}`);
    console.log(`Genesis Sequencer Invalid addresses: ${genesisSequencerInvalidAddresses.length}`);

    console.log('Writing valid genesis sequencer addresses to CSV...');
    fs.writeFileSync(genesisSequencerCsvPath, genesisSequencerValidAddresses.join('\n'));
    console.log('Writing valid genesis sequencer addresses to JSON...');
    fs.writeFileSync(genesisSequencerJsonPath, JSON.stringify(genesisSequencerValidAddresses, null, 2));

    console.log('Creating genesis sequencer Merkle tree...');
    const genesisSequencerValues = genesisSequencerValidAddresses.map(addr => [addr]);
    const genesisSequencerTree = StandardMerkleTree.of(genesisSequencerValues, ['address']);
    console.log('Genesis Sequencer Merkle Root:', genesisSequencerTree.root);

    console.log('Writing Merkle tree data...');
    fs.writeFileSync(genesisSequencerTreePath, JSON.stringify(genesisSequencerTree.dump()));

    console.log('Generating proofs and saving to files for genesis sequencer...');
    const time = performance.now();
    await generateProofAndSplitToFiles('genesis', genesisSequencerTree);
    console.log(`Genesis Sequencer proofs generated in ${Math.round(performance.now() - time)} milliseconds`);

    console.log('Writing genesis sequencer Merkle root...');
    fs.writeFileSync(genesisSequencerRootPath, genesisSequencerTree.root);
  }


  /**
   * Process Contributor
  */
  if (hasContributorInputFileChanged) {
    console.log('Contributor input file has changed, processing again...');
    const contributorJsonPath = path.join(outputDir, 'contributor_valid_addresses.json');
    const contributorRootPath = path.join(outputDir, 'contributor_root.txt');
    const contributorTreePath = path.join(outputDir, 'contributor_tree.json');
    const contributorLines = contributorContent.trim().split('\n');
    const contributorValidAddresses: string[] = [];
    const contributorInvalidAddresses: string[] = [];

    console.log(`Processing Contributor ${contributorLines.length} addresses...`);
    for (const line of contributorLines) {
      const addr = line.trim();
      if (addr) {
        if (Address.validate(addr)) {
          contributorValidAddresses.push(addr);
        } else {
          contributorInvalidAddresses.push(addr);
        }
      }
    }
    console.log("------------------ Contributor -----------------------")
    console.log(`Contributor Valid addresses: ${contributorValidAddresses.length}`);
    console.log(`Contributor Invalid addresses: ${contributorInvalidAddresses.length}`);

    console.log('Writing valid contributor addresses to CSV...');
    fs.writeFileSync(contributorCsvPath, contributorValidAddresses.join('\n'));

    console.log('Writing valid contributor addresses to JSON...');
    fs.writeFileSync(contributorJsonPath, JSON.stringify(contributorValidAddresses, null, 2));

    console.log('Creating contributor Merkle tree...');
    const contributorValues = contributorValidAddresses.map(addr => [addr]);
    const contributorTree = StandardMerkleTree.of(contributorValues, ['address']);
    console.log('Contributor Merkle Root:', contributorTree.root);

    console.log('Writing Merkle tree data...');
    fs.writeFileSync(contributorTreePath, JSON.stringify(contributorTree.dump()));

    console.log('Generating proofs and saving to files for contributor...');
    const time = performance.now();
    await generateProofAndSplitToFiles('contributor', contributorTree);
    console.log(`Contributor proofs generated in ${Math.round(performance.now() - time)} milliseconds`);

    console.log('Writing contributor Merkle root...');
    fs.writeFileSync(contributorRootPath, contributorTree.root);
  }

  console.log('Writing hashes to file...');
  fs.writeFileSync(path.join(outputDir, 'hashes.json'), JSON.stringify({
    genesis_sequencer: genesisSequencerFileHash,
    contributor: contributorFileHash,
  }, null, 2));


  console.log('Process completed successfully!');
}

async function generateProofAndSplitToFiles(track: string, tree: StandardMerkleTree<string[]>) {
  const groupByCharCount = 2;
  let proofs: Record<string, Record<string, string[]>> = {};

  const proofsDir = path.join(__dirname, './outputs/proofs');
  if (!fs.existsSync(proofsDir)) {
    fs.mkdirSync(proofsDir, { recursive: true });
  }

  for (const [i, value] of tree.entries()) {
    const proof = tree.getProof(i);
    const address = value[0].toLowerCase();
    const groupKey = address.slice(2, 2 + groupByCharCount); // First two chars is 0x

    if (!proofs[groupKey]) {
      proofs[groupKey] = {};
    }

    proofs[groupKey][address] = proof;
  }

  const writePromises: Promise<void>[] = [];
  for (const [key, value] of Object.entries(proofs)) {
    const fileName = `${track}_${key}.json`;
    const filePath = path.join(proofsDir, fileName);
    const writePromise = fs.promises.writeFile(filePath, JSON.stringify(value, null, 2));
    writePromises.push(writePromise);
  }
  await Promise.all(writePromises);
}

processAddresses().catch(console.error);