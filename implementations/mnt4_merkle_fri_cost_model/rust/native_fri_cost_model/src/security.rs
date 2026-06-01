//! Численная ordinary-FRI оценка из формальной спецификации проекта.

/// Размер LDE-домена. Для MNT4-753 максимальный двоичный поддомен имеет
/// размер 2^15, что и используется в строгом ordinary-FRI baseline.
pub const LDE_SIZE: usize = 32_768;

/// Степенная оболочка RS-кода: все проверяемые полиномы имеют степень
/// строго меньше 4094, поэтому используется ближайшая степень двойки 4096.
pub const DEGREE_ENVELOPE: usize = 4_096;

/// Число запросов с запасом поверх минимального значения 544.
pub const PRODUCTION_QUERY_COUNT: usize = 576;

/// Численный отчет для доказанной ordinary-FRI оценки.
#[derive(Debug, Clone, PartialEq)]
pub struct OrdinaryFriSecurity {
    pub lde_size: usize,
    pub degree_envelope: usize,
    pub rate: f64,
    pub delta0: f64,
    pub minimum_queries_for_128_bits: usize,
    pub query_count: usize,
    pub fri_soundness_bits: f64,
    pub production_eligible: bool,
}

/// Вычисляет нижнюю границу расстояния:
///
/// delta_0 >= (1 - 3 rho) / 4 - 1 / sqrt(N) - 3N / |Fq|.
///
/// Последнее слагаемое для 753-битного поля меньше точности `f64`, поэтому
/// используется его безопасная верхняя аппроксимация `2^-700`.
pub fn ordinary_fri_security(query_count: usize) -> OrdinaryFriSecurity {
    let rate = DEGREE_ENVELOPE as f64 / LDE_SIZE as f64;
    let field_term_upper_bound = 2f64.powi(-700);
    let delta0 = (1.0 - 3.0 * rate) / 4.0 - 1.0 / (LDE_SIZE as f64).sqrt() - field_term_upper_bound;
    let minimum_queries_for_128_bits = (128.0 / (-(1.0 - delta0).log2())).ceil() as usize;
    let fri_soundness_bits = -(query_count as f64) * (1.0 - delta0).log2();

    OrdinaryFriSecurity {
        lde_size: LDE_SIZE,
        degree_envelope: DEGREE_ENVELOPE,
        rate,
        delta0,
        minimum_queries_for_128_bits,
        query_count,
        fri_soundness_bits,
        production_eligible: query_count >= PRODUCTION_QUERY_COUNT && fri_soundness_bits >= 128.0,
    }
}
