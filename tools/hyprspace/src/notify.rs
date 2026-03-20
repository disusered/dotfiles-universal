use std::process::Command;

pub enum Urgency {
    Low,
    Normal,
    Critical,
}

impl Urgency {
    fn as_str(&self) -> &str {
        match self {
            Urgency::Low => "low",
            Urgency::Normal => "normal",
            Urgency::Critical => "critical",
        }
    }
}

pub fn notify(urgency: Urgency, summary: &str, body: &str) {
    let _ = Command::new("notify-send")
        .arg("-u")
        .arg(urgency.as_str())
        .arg(summary)
        .arg(body)
        .spawn();
}
