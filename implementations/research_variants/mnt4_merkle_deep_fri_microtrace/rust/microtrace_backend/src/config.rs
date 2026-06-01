use ark_ff::{BigInteger, PrimeField};
use ark_mnt4_753::{Fq, Fr};
use num_bigint::{BigInt, BigUint, Sign};
use serde::{Deserialize, Serialize};

pub const VERSION: u16 = 1;
pub const TRACE_SIZE: usize = 2048;
pub const BLOWUP: usize = 16;
pub const LDE_SIZE: usize = TRACE_SIZE * BLOWUP;
pub const REAL_OPERATIONS: usize = 1500;
pub const HOLD_OPERATIONS: usize = 547;
pub const FRI_ROUNDS: usize = 8;
pub const FINAL_FRI_DEGREE_BOUND: usize = 8;
pub const FIXED_COLUMNS: usize = 17;
pub const TRACE_COLUMNS: usize = 4;
pub const QUOTIENT_SEGMENTS: usize = 2;
pub const AIR_CONSTRAINTS: usize = 44;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[repr(u8)]
pub enum Profile {
    Benchmark32 = 1,
    Conservative128 = 2,
}

impl Profile {
    pub fn query_count(self) -> usize {
        match self {
            Self::Benchmark32 => 32,
            Self::Conservative128 => 128,
        }
    }

    pub fn name(self) -> &'static str {
        match self {
            Self::Benchmark32 => "benchmark-32q",
            Self::Conservative128 => "conservative-128q",
        }
    }
}

pub fn fq_modulus_biguint() -> BigUint {
    BigUint::from_bytes_le(&Fq::MODULUS.to_bytes_le())
}

pub fn scalar_modulus_biguint() -> BigUint {
    BigUint::from_bytes_le(&Fr::MODULUS.to_bytes_le())
}

pub fn scalar_modulus_bigint() -> BigInt {
    BigInt::from_biguint(Sign::Plus, scalar_modulus_biguint())
}

