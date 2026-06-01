use crate::config::Profile;
use serde::Serialize;

#[derive(Debug, Clone, Serialize)]
pub struct SecurityReport {
    pub profile: &'static str,
    pub query_count: usize,
    pub blowup_factor: usize,
    pub fri_rounds: usize,
    pub statement: &'static str,
    pub caveat: &'static str,
}

pub fn report(profile: Profile) -> SecurityReport {
    SecurityReport {
        profile: profile.name(),
        query_count: profile.query_count(),
        blowup_factor: crate::config::BLOWUP,
        fri_rounds: crate::config::FRI_ROUNDS,
        statement: "Профиль фиксирует число запросов для воспроизводимого gas-эксперимента.",
        caveat: "Модуль не заявляет production-уровень криптографической стойкости до независимого аудита полной DEEP-FRI soundness-модели.",
    }
}

