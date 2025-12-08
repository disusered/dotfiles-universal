/// Represents an RGB color
#[derive(Debug, Clone)]
pub struct Color {
    pub r: u8,
    pub g: u8,
    pub b: u8,
}

impl Color {
    /// Parse a hex color string (with or without #)
    pub fn from_hex(hex: &str) -> Result<Self, String> {
        let hex = hex.trim_start_matches('#');
        if hex.len() != 6 {
            return Err(format!("Invalid hex color: {}", hex));
        }
        Ok(Color {
            r: u8::from_str_radix(&hex[0..2], 16).map_err(|e| e.to_string())?,
            g: u8::from_str_radix(&hex[2..4], 16).map_err(|e| e.to_string())?,
            b: u8::from_str_radix(&hex[4..6], 16).map_err(|e| e.to_string())?,
        })
    }

    /// Output as hex without # (e.g., "89b4fa")
    pub fn to_hex(&self) -> String {
        format!("{:02x}{:02x}{:02x}", self.r, self.g, self.b)
    }

    /// Output as hex with # (e.g., "#89b4fa")
    pub fn to_hex_hash(&self) -> String {
        format!("#{:02x}{:02x}{:02x}", self.r, self.g, self.b)
    }

    /// Output as hex with # in uppercase (e.g., "#89B4FA")
    pub fn to_hex_hash_upper(&self) -> String {
        format!("#{:02X}{:02X}{:02X}", self.r, self.g, self.b)
    }

    /// Output as space-separated RGB (e.g., "137 180 250")
    pub fn to_rgb(&self) -> String {
        format!("{} {} {}", self.r, self.g, self.b)
    }

    /// Output as CSS rgb() (e.g., "rgb(137, 180, 250)")
    pub fn to_rgb_css(&self) -> String {
        format!("rgb({}, {}, {})", self.r, self.g, self.b)
    }

    /// Output as Hyprlang format (e.g., "rgb(89b4fa)")
    pub fn to_hyprlang(&self) -> String {
        format!("rgb({:02x}{:02x}{:02x})", self.r, self.g, self.b)
    }

    /// Output as RGBA with alpha (e.g., "rgba(137, 180, 250, 0.9)")
    pub fn to_rgba(&self, alpha: f32) -> String {
        format!("rgba({}, {}, {}, {})", self.r, self.g, self.b, alpha)
    }

    /// Output as Hyprlang RGBA (e.g., "rgba(89b4fae6)" where e6 = 0.9 * 255)
    pub fn to_hyprlang_rgba(&self, alpha: f32) -> String {
        let alpha_byte = (alpha * 255.0).round() as u8;
        format!("rgba({:02x}{:02x}{:02x}{:02x})", self.r, self.g, self.b, alpha_byte)
    }
}

/// Format a color in the specified format
pub fn format_color(color: &Color, format: &str, alpha: f32) -> String {
    match format {
        "hex" => color.to_hex(),
        "hex-hash" => color.to_hex_hash(),
        "rgb" => color.to_rgb(),
        "rgb-css" => color.to_rgb_css(),
        "hyprlang" => color.to_hyprlang(),
        "rgba" => color.to_rgba(alpha),
        "hyprlang-rgba" => color.to_hyprlang_rgba(alpha),
        _ => color.to_hex(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_from_hex() {
        let c = Color::from_hex("89b4fa").unwrap();
        assert_eq!(c.r, 137);
        assert_eq!(c.g, 180);
        assert_eq!(c.b, 250);

        let c = Color::from_hex("#1e1e2e").unwrap();
        assert_eq!(c.r, 30);
        assert_eq!(c.g, 30);
        assert_eq!(c.b, 46);
    }

    #[test]
    fn test_formats() {
        let c = Color::from_hex("89b4fa").unwrap();
        assert_eq!(c.to_hex(), "89b4fa");
        assert_eq!(c.to_hex_hash(), "#89b4fa");
        assert_eq!(c.to_rgb(), "137 180 250");
        assert_eq!(c.to_rgb_css(), "rgb(137, 180, 250)");
        assert_eq!(c.to_hyprlang(), "rgb(89b4fa)");
        assert_eq!(c.to_rgba(0.9), "rgba(137, 180, 250, 0.9)");
    }
}
