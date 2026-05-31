use crate::config;
use num_bigint::BigInt;
use num_traits::One;
use serde::{Deserialize, Serialize};

// Arkworks MNT4-753 ATE_LOOP_COUNT: byte 0 => -1, 1 => 0, 2 => +1.
const ATE_LOOP_ENC_HEX: &str = "0201020102010201010201010001020102010001000101020101010001000100010102010101010201000102010102010101010101010100010001010102010100010100010100010201000101010001020101010001010001020100010101000101000102010100010001020102010101010101010101000101020102010102010001010101020102010201000100010102010102010001020100010101010001010102010201010001010001020100010101010101010101020101000102010001020101010001010001010001010102010201010201020102010201010201010102010101000101010201000101020100010201020100010201010001000100010101010102010001020101010201020100010101020102010100010102010001000101010201010101020102010102010001000101010102010101000102010201010100010100010101020102010001010101010201010101020101000101000102010101020100010101010101010101010101010101";

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[repr(u8)]
pub enum MicroOp {
    Sqr = 0,
    DblP = 1,
    DblR = 2,
    AddP = 3,
    AddR = 4,
    MulC = 5,
    MulCInv = 6,
    MulFrobCInv = 7,
    Hold = 8,
    Stop = 9,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Schedule {
    pub rows: Vec<MicroOp>,
}

impl Schedule {
    pub fn real_operation_count(&self) -> usize {
        self.rows.iter().take_while(|op| !matches!(op, MicroOp::Hold | MicroOp::Stop)).count()
    }

    pub fn hold_count(&self) -> usize {
        self.rows.iter().filter(|op| matches!(op, MicroOp::Hold)).count()
    }
}

pub fn ate_loop_digits() -> Vec<i8> {
    ATE_LOOP_ENC_HEX
        .as_bytes()
        .chunks_exact(2)
        .map(|pair| {
            let byte = ((pair[0] as char).to_digit(16).unwrap() << 4)
                | (pair[1] as char).to_digit(16).unwrap();
            match byte {
                0 => -1,
                1 => 0,
                2 => 1,
                _ => unreachable!("invalid ate-loop digit"),
            }
        })
        .collect()
}

pub fn build_schedule() -> Schedule {
    let mut rows = Vec::with_capacity(config::TRACE_SIZE);
    for digit in ate_loop_digits().into_iter().skip(1) {
        rows.extend([MicroOp::Sqr, MicroOp::DblP, MicroOp::DblR]);
        if digit != 0 {
            rows.extend([MicroOp::AddP, MicroOp::AddR]);
            rows.push(if digit == 1 { MicroOp::MulCInv } else { MicroOp::MulC });
        }
    }
    rows.extend([MicroOp::AddP, MicroOp::AddR, MicroOp::MulFrobCInv]);
    assert_eq!(rows.len(), config::REAL_OPERATIONS);
    rows.resize(config::TRACE_SIZE - 1, MicroOp::Hold);
    rows.push(MicroOp::Stop);
    Schedule { rows }
}

pub fn residue_kappa() -> BigInt {
    let mut kappa = -BigInt::one();
    for digit in ate_loop_digits().into_iter().skip(1) {
        kappa *= 2;
        if digit == 1 {
            kappa -= 1;
        } else if digit == -1 {
            kappa += 1;
        }
    }
    kappa -= BigInt::from_biguint(num_bigint::Sign::Plus, config::fq_modulus_biguint());
    kappa
}
