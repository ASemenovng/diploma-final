pub mod air;
pub mod config;
pub mod deep_fri;
pub mod merkle;
pub mod polynomial;
pub mod schedule;
pub mod security;
pub mod serialize;
pub mod trace;
pub mod transcript;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn schedule_has_exact_microtrace_shape() {
        let schedule = schedule::build_schedule();
        assert_eq!(schedule.real_operation_count(), 1500);
        assert_eq!(schedule.hold_count(), 547);
        assert_eq!(schedule.rows.len(), config::TRACE_SIZE);
        assert!(matches!(schedule.rows.last(), Some(schedule::MicroOp::Stop)));
    }

    #[test]
    fn residue_exponent_is_minus_scalar_modulus() {
        assert_eq!(schedule::residue_kappa(), -config::scalar_modulus_bigint());
    }

    #[test]
    fn domain_parameters_have_required_orders() {
        let domain = polynomial::DomainParameters::new();
        domain.validate().unwrap();
    }

    #[test]
    fn compact_multiproof_round_trip() {
        let payloads = (0..32)
            .map(|i| vec![i as u8; 7])
            .collect::<Vec<_>>();
        let tree = merkle::MerkleTree::new(merkle::TreeTag::Trace, payloads);
        let opened = vec![0usize, 1, 7, 12, 18, 31];
        let proof = tree.open_compact(&opened);
        merkle::verify_compact(
            merkle::TreeTag::Trace,
            tree.root(),
            tree.leaf_count(),
            &proof,
        )
        .unwrap();
    }

    #[test]
    fn proof_round_trip_and_bit_flip_rejection() {
        let fixture = trace::Fixture::non_degenerate();
        let profile = config::Profile::Benchmark32;
        let bundle = deep_fri::prove(&fixture, profile).unwrap();
        deep_fri::verify(&bundle.public, &bundle.proof).unwrap();

        let mut tampered = bundle.proof.clone();
        tampered.trace.payloads[0][0] ^= 1;
        assert!(deep_fri::verify(&bundle.public, &tampered).is_err());
    }

    #[test]
    fn sanity_and_non_degenerate_residue_traces_close() {
        for fixture in [trace::Fixture::sanity(), trace::Fixture::non_degenerate()] {
            let fixed = trace::build_fixed_table(fixture.q, fixture.s);
            let witness = trace::build_trace(&fixture, &fixed);
            assert_eq!(witness.states[config::REAL_OPERATIONS], ark_mnt4_753::Fq4::from(1u64));
            assert_eq!(witness.states.len(), config::TRACE_SIZE);
        }
    }

    #[test]
    fn fixed_root_is_reproducible() {
        let fixture = trace::Fixture::non_degenerate();
        let first = deep_fri::fixed_artifacts(&fixture).unwrap();
        let second = deep_fri::fixed_artifacts(&fixture).unwrap();
        assert_eq!(first.root_fixed, second.root_fixed);
        assert_eq!(first.config_digest, second.config_digest);
    }

    #[test]
    fn serialized_proof_has_fixed_magic_and_model_size() {
        let fixture = trace::Fixture::non_degenerate();
        let bundle = deep_fri::prove(&fixture, config::Profile::Benchmark32).unwrap();
        let encoded = serialize::proof_bytes(&bundle.public, &bundle.proof);
        assert_eq!(&encoded[..4], b"M4DF");
        assert_eq!(encoded.len(), bundle.metrics.proof_bytes_model);
    }

    #[test]
    fn security_profiles_are_explicitly_separated() {
        let benchmark = security::report(config::Profile::Benchmark32);
        let conservative = security::report(config::Profile::Conservative128);
        assert_eq!(benchmark.query_count, 32);
        assert_eq!(conservative.query_count, 128);
        assert!(benchmark.caveat.contains("не заявляет production"));
    }

}
