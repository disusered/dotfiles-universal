/// Sample texts for font preview
pub struct FontSamples;

impl FontSamples {
    /// Short pangram for size previews
    pub const PANGRAM: &'static str = "The quick brown fox jumps over the lazy dog";

    /// Full character set - lowercase
    pub const LOWERCASE: &'static str = "abcdefghijklmnopqrstuvwxyz";

    /// Full character set - uppercase
    pub const UPPERCASE: &'static str = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";

    /// Digits
    pub const DIGITS: &'static str = "0123456789";

    /// Common symbols
    pub const SYMBOLS: &'static str = "!@#$%^&*()_+-=[]{}|;':\",./<>?";

    /// Programming ligatures test
    pub const LIGATURES: &'static str = "=> -> <- <-> != !== == === <= >= |>";

    /// Nerd Font glyphs sample (common icons)
    pub const NERD_GLYPHS: &'static str = "\u{f002d} \u{e606} \u{e73c} \u{f0e7} \u{f120} \u{f121} \u{f1d3} \u{f07c} \u{f023} \u{f013}";
}
