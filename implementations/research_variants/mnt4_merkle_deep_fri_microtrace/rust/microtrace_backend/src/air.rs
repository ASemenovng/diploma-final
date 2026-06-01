use crate::{config, trace};
use ark_ff::{Field, One, Zero};
use ark_mnt4_753::{Fq, Fq2, Fq4, G1Affine};

#[derive(Debug, Clone)]
pub struct AirPublic {
    pub p: G1Affine,
    pub r: G1Affine,
    pub c: Fq4,
    pub c_inv: Fq4,
}

pub fn fixed_h_columns(table: &trace::FixedTable) -> Vec<Vec<Fq>> {
    let mut columns = vec![vec![Fq::zero(); config::TRACE_SIZE]; config::FIXED_COLUMNS];
    for (row_index, row) in table.rows.iter().enumerate() {
        let mut values = row.columns();
        if row_index == 0 {
            values[9] = Fq::one();
        }
        if row_index == config::REAL_OPERATIONS {
            values[10] = Fq::one();
        }
        for (column, value) in columns.iter_mut().zip(values) {
            column[row_index] = value;
        }
    }
    columns
}

pub fn trace_h_columns(witness: &trace::TraceWitness) -> Vec<Vec<Fq>> {
    let mut columns = vec![Vec::with_capacity(config::TRACE_SIZE); config::TRACE_COLUMNS];
    for state in &witness.states {
        for (column, value) in columns.iter_mut().zip(trace::flatten(*state)) {
            column.push(value);
        }
    }
    columns
}

pub fn constraints(current: [Fq; 4], next: [Fq; 4], fixed: &[Fq], public: &AirPublic) -> [Fq; config::AIR_CONSTRAINTS] {
    assert_eq!(fixed.len(), config::FIXED_COLUMNS);
    let mut out = [Fq::zero(); config::AIR_CONSTRAINTS];
    let current4 = trace::unflatten(current);
    let line = trace::NormalizedLine {
        k0: Fq2::new(fixed[11], fixed[12]),
        k1: Fq2::new(fixed[13], fixed[14]),
        k2: Fq2::new(fixed[15], fixed[16]),
        addition: false,
    };
    let mut frob_c_inv = public.c_inv;
    frob_c_inv.frobenius_map_in_place(1);
    let expected = [
        current4.square(),
        current4 * trace::evaluate_line(line, public.p.x, public.p.y),
        current4 * trace::evaluate_line(line, public.r.x, -public.r.y),
        current4 * trace::evaluate_line(trace::NormalizedLine { addition: true, ..line }, public.p.x, public.p.y),
        current4 * trace::evaluate_line(trace::NormalizedLine { addition: true, ..line }, public.r.x, -public.r.y),
        current4 * public.c,
        current4 * public.c_inv,
        current4 * frob_c_inv,
        current4,
    ];
    let mut offset = 0;
    for (selector, candidate) in fixed[..9].iter().zip(expected) {
        for (candidate_coordinate, next_coordinate) in trace::flatten(candidate).into_iter().zip(next) {
            out[offset] = *selector * (candidate_coordinate - next_coordinate);
            offset += 1;
        }
    }
    for (coordinate, c_inv_coordinate) in current.into_iter().zip(trace::flatten(public.c_inv)) {
        out[offset] = fixed[9] * (coordinate - c_inv_coordinate);
        offset += 1;
    }
    for coordinate in current {
        out[offset] = fixed[10] * (coordinate - if offset % 4 == 0 { Fq::one() } else { Fq::zero() });
        offset += 1;
    }
    debug_assert_eq!(offset, config::AIR_CONSTRAINTS);
    out
}

pub fn combined_numerator(current: [Fq; 4], next: [Fq; 4], fixed: &[Fq], public: &AirPublic, beta: Fq) -> Fq {
    let mut power = Fq::one();
    let mut sum = Fq::zero();
    for constraint in constraints(current, next, fixed, public) {
        sum += power * constraint;
        power *= beta;
    }
    sum
}

