use std::{collections::HashMap, fs, path::Path};

use ratatui::{
    style::{Color, Modifier, Style},
    widgets::{Block, Borders},
};

#[derive(Debug, Clone)]
pub struct UiTheme {
    pub name: String,
    pub palette: Palette,
}

#[derive(Debug, Clone, Copy)]
pub struct Palette {
    pub text: Color,
    pub subtle: Color,
    pub surface0: Color,
    pub blue: Color,
    pub pink: Color,
    pub green: Color,
    pub yellow: Color,
    pub cyan: Color,
    pub red: Color,
}

impl UiTheme {
    pub fn load(root: &Path) -> Self {
        let name = fs::read_to_string(root.join("presets/allc/themes/current"))
            .ok()
            .map(|value| value.trim().to_string())
            .filter(|value| !value.is_empty())
            .unwrap_or_else(|| "catppuccin-mocha".into());

        let palette =
            fs::read_to_string(root.join("presets/allc/themes").join(format!("{name}.sh")))
                .ok()
                .map(|raw| parse_palette(&raw))
                .unwrap_or_else(Palette::default_dark);

        Self { name, palette }
    }

    pub fn panel_block(&self, title: impl Into<String>, focused: bool) -> Block<'static> {
        Block::default()
            .borders(Borders::ALL)
            .border_style(if focused {
                self.focused_border()
            } else {
                self.inactive_border()
            })
            .title(title.into())
    }

    pub fn focused_border(&self) -> Style {
        Style::new()
            .fg(self.palette.cyan)
            .add_modifier(Modifier::BOLD)
    }

    pub fn inactive_border(&self) -> Style {
        Style::new().fg(self.palette.subtle)
    }

    pub fn border(&self) -> Style {
        self.inactive_border()
    }

    pub fn muted(&self) -> Style {
        Style::new().fg(self.palette.subtle)
    }

    pub fn selected(&self) -> Style {
        Style::new()
            .fg(self.palette.blue)
            .bg(self.palette.surface0)
            .add_modifier(Modifier::BOLD)
    }

    pub fn title(&self) -> Style {
        Style::new()
            .fg(self.palette.text)
            .add_modifier(Modifier::BOLD)
    }

    pub fn help_title(&self) -> Style {
        Style::new()
            .fg(self.palette.cyan)
            .add_modifier(Modifier::BOLD)
    }

    pub fn kind(&self) -> Style {
        Style::new().fg(self.palette.blue)
    }

    pub fn runner_backend(&self) -> Style {
        Style::new()
            .fg(self.palette.green)
            .add_modifier(Modifier::BOLD)
    }
}

impl Palette {
    fn default_dark() -> Self {
        Self {
            text: Color::Rgb(205, 214, 244),
            subtle: Color::Rgb(108, 112, 134),
            surface0: Color::Rgb(49, 50, 68),
            blue: Color::Rgb(137, 180, 250),
            pink: Color::Rgb(245, 194, 231),
            green: Color::Rgb(166, 227, 161),
            yellow: Color::Rgb(249, 226, 175),
            cyan: Color::Rgb(148, 226, 213),
            red: Color::Rgb(243, 139, 168),
        }
    }
}

fn parse_palette(raw: &str) -> Palette {
    let values = raw
        .lines()
        .filter_map(parse_assignment)
        .collect::<HashMap<_, _>>();
    let fallback = Palette::default_dark();

    Palette {
        text: color(&values, "TEXT").unwrap_or(fallback.text),
        subtle: color(&values, "SUBTLE").unwrap_or(fallback.subtle),
        surface0: color(&values, "SURFACE0").unwrap_or(fallback.surface0),
        blue: color(&values, "BLUE").unwrap_or(fallback.blue),
        pink: color(&values, "PINK").unwrap_or(fallback.pink),
        green: color(&values, "GREEN").unwrap_or(fallback.green),
        yellow: color(&values, "YELLOW").unwrap_or(fallback.yellow),
        cyan: color(&values, "CYAN").unwrap_or(fallback.cyan),
        red: color(&values, "RED").unwrap_or(fallback.red),
    }
}

fn parse_assignment(line: &str) -> Option<(String, String)> {
    let (key, value) = line.split_once('=')?;
    let key = key.trim();
    let value = value.trim().trim_matches('"').trim_matches('\'');
    key.chars()
        .all(|character| character.is_ascii_uppercase() || character == '_')
        .then(|| (key.to_string(), value.to_string()))
}

fn color(values: &HashMap<String, String>, key: &str) -> Option<Color> {
    values.get(key).and_then(|value| parse_hex_color(value))
}

fn parse_hex_color(value: &str) -> Option<Color> {
    let hex = value.strip_prefix('#')?;
    (hex.len() == 6)
        .then(|| {
            let red = u8::from_str_radix(&hex[0..2], 16).ok()?;
            let green = u8::from_str_radix(&hex[2..4], 16).ok()?;
            let blue = u8::from_str_radix(&hex[4..6], 16).ok()?;
            Some(Color::Rgb(red, green, blue))
        })
        .flatten()
}
