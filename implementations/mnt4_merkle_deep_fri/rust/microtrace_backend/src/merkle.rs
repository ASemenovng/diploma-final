use anyhow::{anyhow, ensure, Result};
use serde::{Deserialize, Serialize};
use sha3::{Digest, Keccak256};
use std::collections::{BTreeMap, BTreeSet};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(u8)]
pub enum TreeTag {
    Trace = 0x01,
    Fixed = 0x02,
    Quotient = 0x03,
    Deep = 0x04,
    Fri1 = 0x11,
    Fri2 = 0x12,
    Fri3 = 0x13,
    Fri4 = 0x14,
    Fri5 = 0x15,
    Fri6 = 0x16,
    Fri7 = 0x17,
}

impl TreeTag {
    pub fn fri(level: usize) -> Self {
        match level {
            1 => Self::Fri1,
            2 => Self::Fri2,
            3 => Self::Fri3,
            4 => Self::Fri4,
            5 => Self::Fri5,
            6 => Self::Fri6,
            7 => Self::Fri7,
            _ => panic!("FRI tree level out of range"),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct CompactProof {
    pub positions: Vec<usize>,
    pub payloads: Vec<Vec<u8>>,
    pub frontier: Vec<[u8; 32]>,
}

#[derive(Debug, Clone)]
pub struct MerkleTree {
    payloads: Vec<Vec<u8>>,
    levels: Vec<Vec<[u8; 32]>>,
}

impl MerkleTree {
    pub fn new(tag: TreeTag, payloads: Vec<Vec<u8>>) -> Self {
        assert!(payloads.len().is_power_of_two());
        let mut levels = vec![payloads
            .iter()
            .enumerate()
            .map(|(index, payload)| hash_leaf(tag, index, payload))
            .collect::<Vec<_>>()];
        let mut level = 0u8;
        while levels.last().unwrap().len() > 1 {
            let parent = levels
                .last()
                .unwrap()
                .chunks_exact(2)
                .map(|pair| hash_node(tag, level, pair[0], pair[1]))
                .collect::<Vec<_>>();
            levels.push(parent);
            level += 1;
        }
        Self { payloads, levels }
    }

    pub fn root(&self) -> [u8; 32] {
        self.levels.last().unwrap()[0]
    }

    pub fn leaf_count(&self) -> usize {
        self.payloads.len()
    }

    pub fn open_compact(&self, positions: &[usize]) -> CompactProof {
        let positions = positions.iter().copied().collect::<BTreeSet<_>>();
        assert!(positions.iter().all(|index| *index < self.leaf_count()));
        let payloads = positions.iter().map(|index| self.payloads[*index].clone()).collect();
        let mut known = positions.clone();
        let mut frontier = Vec::new();
        for level in 0..self.levels.len() - 1 {
            for index in &known {
                let sibling = index ^ 1;
                if !known.contains(&sibling) {
                    frontier.push(self.levels[level][sibling]);
                }
            }
            known = known.into_iter().map(|index| index >> 1).collect();
        }
        CompactProof { positions: positions.into_iter().collect(), payloads, frontier }
    }
}

pub fn verify_compact(tag: TreeTag, root: [u8; 32], leaf_count: usize, proof: &CompactProof) -> Result<()> {
    ensure!(leaf_count.is_power_of_two(), "leaf count is not a power of two");
    ensure!(proof.positions.len() == proof.payloads.len(), "payload count mismatch");
    ensure!(proof.positions.windows(2).all(|x| x[0] < x[1]), "positions are not strictly sorted");
    ensure!(proof.positions.iter().all(|x| *x < leaf_count), "position out of range");
    let mut known = proof
        .positions
        .iter()
        .copied()
        .zip(proof.payloads.iter())
        .map(|(index, payload)| (index, hash_leaf(tag, index, payload)))
        .collect::<BTreeMap<_, _>>();
    let mut frontier = proof.frontier.iter();
    let mut width = leaf_count;
    let mut level = 0u8;
    while width > 1 {
        let indexes = known.keys().copied().collect::<Vec<_>>();
        let current_set = indexes.iter().copied().collect::<BTreeSet<_>>();
        let mut next = BTreeMap::<usize, [u8; 32]>::new();
        for index in indexes {
            if index & 1 == 1 && current_set.contains(&(index ^ 1)) {
                continue;
            }
            let sibling = index ^ 1;
            let self_hash = known[&index];
            let sibling_hash = match known.get(&sibling) {
                Some(hash) => *hash,
                None => *frontier.next().ok_or_else(|| anyhow!("frontier hash missing"))?,
            };
            let (left, right) = if index & 1 == 0 { (self_hash, sibling_hash) } else { (sibling_hash, self_hash) };
            next.insert(index >> 1, hash_node(tag, level, left, right));
        }
        known = next;
        width >>= 1;
        level += 1;
    }
    ensure!(frontier.next().is_none(), "unused frontier hash");
    ensure!(known.get(&0) == Some(&root), "Merkle root mismatch");
    Ok(())
}

pub fn hash_leaf(tag: TreeTag, index: usize, payload: &[u8]) -> [u8; 32] {
    let mut input = Vec::with_capacity(10 + payload.len());
    input.push(0x00);
    input.push(tag as u8);
    input.extend_from_slice(&(index as u32).to_be_bytes());
    input.extend_from_slice(&(payload.len() as u32).to_be_bytes());
    input.extend_from_slice(payload);
    Keccak256::digest(input).into()
}

pub fn hash_node(tag: TreeTag, level: u8, left: [u8; 32], right: [u8; 32]) -> [u8; 32] {
    let mut input = Vec::with_capacity(67);
    input.push(0x01);
    input.push(tag as u8);
    input.push(level);
    input.extend_from_slice(&left);
    input.extend_from_slice(&right);
    Keccak256::digest(input).into()
}
