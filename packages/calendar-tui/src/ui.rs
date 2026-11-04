use crate::backend::{self, Cache, Entry, LABELS};
use anyhow::Result;
use chrono::{DateTime, Duration, Local, NaiveDate, Timelike};
use crossterm::event::{self, Event, KeyCode, KeyEvent, KeyEventKind, KeyModifiers};
use ratatui::{prelude::*, widgets::*};
use serde_json::Value;
use std::{
    sync::mpsc,
    time::{Duration as Timeout, Instant},
};
const BG: Color = Color::Rgb(40, 40, 40);
const PANEL: Color = Color::Rgb(50, 48, 47);
const TODAY_BG: Color = Color::Rgb(60, 56, 54);
const FG: Color = Color::Rgb(235, 219, 178);
const DIM: Color = Color::Rgb(146, 131, 116);
const LINE: Color = Color::Rgb(80, 73, 69);
const GOLD: Color = Color::Rgb(250, 189, 47);
const RED: Color = Color::Rgb(251, 73, 52);
const TEAL: Color = Color::Rgb(66, 154, 142);
const BLUE: Color = Color::Rgb(75, 153, 210);
const ORANGE: Color = Color::Rgb(214, 93, 14);
const PURPLE: Color = Color::Rgb(164, 121, 177);
const EVENT_RED: Color = Color::Rgb(204, 36, 29);
const OLIVE: Color = Color::Rgb(152, 151, 26);
const AMBER: Color = Color::Rgb(215, 153, 33);
const COLORS: [Color; 7] = [TEAL, BLUE, ORANGE, PURPLE, EVENT_RED, OLIVE, AMBER];
fn color(cache: &Cache, id: &str) -> Color {
    let name = cache
        .calendars
        .iter()
        .find(|c| c.id == id)
        .map(|c| c.name.to_lowercase())
        .unwrap_or_default();
    match name.as_str() {
        "fall 2026 classes" => TEAL,
        "15112" | "15-112 staff f26" => BLUE,
        "extracirriculars" => ORANGE,
        "mlanghor@andrew.cmu.edu" | "katy@langhorst.com" | "im sports" | "tutoring" => PURPLE,
        "sdc buggy raceday 27" | "sdc ultimate - fall 2026" => EVENT_RED,
        "lab 1 -  start dates" => OLIVE,
        "lab /tech 1- due dates" => AMBER,
        "holidays in united states" => OLIVE,
        _ => {
            let hash = id.bytes().fold(0usize, |hash, b| {
                hash.wrapping_mul(31).wrapping_add(usize::from(b))
            });
            COLORS[hash % COLORS.len()]
        }
    }
}
fn event_text(color: Color) -> Color {
    if color == ORANGE || color == EVENT_RED {
        Color::White
    } else {
        Color::Rgb(19, 19, 20)
    }
}
fn visible(cache: &Cache, start: NaiveDate) -> Vec<&Entry> {
    let mut entries: Vec<_> = cache
        .events
        .iter()
        .filter(|e| e.overlaps(start, start + Duration::days(7)))
        .collect();
    entries.sort_by_key(|e| (e.start().ok(), e.title()));
    entries
}
fn text(frame: &mut Frame, area: Rect, value: impl Into<Text<'static>>, style: Style) {
    if area.width > 0 && area.height > 0 {
        frame.render_widget(Paragraph::new(value).style(style), area);
    }
}
fn popup_rect(area: Rect) -> Rect {
    let width = area.width.saturating_sub(4).min(100);
    let height = area.height.saturating_sub(2).min(34);
    Rect::new(
        area.x + (area.width - width) / 2,
        area.y + (area.height - height) / 2,
        width,
        height,
    )
}
struct Editor {
    entry: Entry,
    fields: [String; 5],
    field: usize,
    cursor: usize,
    review: Option<Value>,
    error: String,
    saving: bool,
    deleting: bool,
    delete_confirmation: String,
    scroll: u16,
}
impl Editor {
    fn new(entry: Entry) -> Self {
        let fields = backend::fields(&entry);
        let cursor = fields[0].len();
        Self {
            entry,
            fields,
            field: 0,
            cursor,
            review: None,
            error: String::new(),
            saving: false,
            deleting: false,
            delete_confirmation: String::new(),
            scroll: 0,
        }
    }
    fn next(&mut self, back: bool) {
        self.field = (self.field + if back { 4 } else { 1 }) % 5;
        self.cursor = self.fields[self.field].len();
    }
    fn input(&mut self, key: KeyEvent) {
        let value = &mut self.fields[self.field];
        match key.code {
            KeyCode::Tab | KeyCode::BackTab => self.next(key.code == KeyCode::BackTab),
            KeyCode::Enter if self.field == 4 => {
                value.insert(self.cursor, '\n');
                self.cursor += 1;
            }
            KeyCode::Enter => self.next(false),
            KeyCode::Char('u') if key.modifiers.contains(KeyModifiers::CONTROL) => {
                value.clear();
                self.cursor = 0;
            }
            KeyCode::Home => self.cursor = 0,
            KeyCode::End => self.cursor = value.len(),
            KeyCode::Left if self.cursor > 0 => {
                self.cursor = value[..self.cursor]
                    .char_indices()
                    .last()
                    .map(|(i, _)| i)
                    .unwrap_or(0);
            }
            KeyCode::Right if self.cursor < value.len() => {
                self.cursor += value[self.cursor..].chars().next().unwrap().len_utf8();
            }
            KeyCode::Backspace if self.cursor > 0 => {
                let previous = value[..self.cursor].char_indices().last().unwrap().0;
                value.replace_range(previous..self.cursor, "");
                self.cursor = previous;
            }
            KeyCode::Delete if self.cursor < value.len() => {
                let end = self.cursor + value[self.cursor..].chars().next().unwrap().len_utf8();
                value.replace_range(self.cursor..end, "");
            }
            KeyCode::Char(c)
                if !key
                    .modifiers
                    .intersects(KeyModifiers::CONTROL | KeyModifiers::ALT) =>
            {
                value.insert(self.cursor, c);
                self.cursor += c.len_utf8();
            }
            _ => {}
        }
    }
}
fn draw_editor(frame: &mut Frame, editor: &Editor, cache: &Cache) {
    let area = popup_rect(frame.area());
    frame.render_widget(Clear, area);
    let c = color(cache, &editor.entry.calendar.id);
    let title = if editor.saving {
        if editor.deleting {
            " Deleting and verifying… "
        } else {
            " Saving and verifying… "
        }
    } else if editor.deleting {
        " Delete event · type DELETE then Enter · Esc cancel "
    } else if editor.review.is_some() {
        " Confirm · y save / PgUp/PgDn scroll / Esc return "
    } else if editor.entry.calendar.writable {
        " Edit · Ctrl+S save · Ctrl+D delete · Esc cancel "
    } else {
        " Read-only event · Esc close "
    };
    frame.render_widget(
        Block::bordered()
            .title(title)
            .border_style(Style::default().fg(c))
            .style(Style::default().bg(PANEL).fg(FG)),
        area,
    );
    let inner = Rect::new(
        area.x + 2,
        area.y + 1,
        area.width.saturating_sub(4),
        area.height.saturating_sub(2),
    );
    let scope = if editor.entry.raw["recurringEventId"].is_string() {
        "This occurrence only"
    } else {
        "Single event"
    };
    let time = if editor.entry.all_day() {
        "Dates: YYYY-MM-DD · end date is exclusive"
    } else {
        "Times: YYYY-MM-DD h:mm AM/PM · local timezone"
    };
    text(
        frame,
        Rect::new(inner.x, inner.y, inner.width, 2),
        if editor.deleting {
            format!(
                "Account: {}\nCalendar: {}",
                backend::EMAIL,
                editor.entry.calendar.name
            )
        } else {
            format!(
                "{} · {}\n{scope} · {time}",
                backend::EMAIL,
                editor.entry.calendar.name
            )
        },
        Style::default().fg(DIM),
    );
    if editor.deleting {
        let f = backend::fields(&editor.entry);
        let scope = if editor.entry.raw["recurringEventId"].is_string() {
            "Only this occurrence will be deleted. The rest of the series stays."
        } else {
            "This event will be deleted from Google Calendar."
        };
        let message = format!(
            "{}\n\n{}\n→ {}\n\n{scope}\nGuest notifications: none\n\nType DELETE then Enter:\n{}▏",
            f[0], f[1], f[2], editor.delete_confirmation
        );
        frame.render_widget(
            Paragraph::new(message)
                .wrap(Wrap { trim: false })
                .style(Style::default().fg(FG)),
            Rect::new(
                inner.x,
                inner.y + 3,
                inner.width,
                inner.height.saturating_sub(5),
            ),
        );
    } else if editor.review.is_some() {
        let old = backend::fields(&editor.entry);
        let mut lines = vec![];
        for i in 0..5 {
            if old[i] != editor.fields[i] {
                lines.push(Line::styled(LABELS[i], Style::default().fg(GOLD)));
                lines.push(Line::styled(
                    format!("− {}", old[i]),
                    Style::default().fg(RED),
                ));
                lines.push(Line::styled(
                    format!("+ {}", editor.fields[i]),
                    Style::default().fg(COLORS[1]),
                ));
                lines.push(Line::raw(""));
            }
        }
        frame.render_widget(
            Paragraph::new(lines)
                .wrap(Wrap { trim: false })
                .scroll((editor.scroll, 0)),
            Rect::new(
                inner.x,
                inner.y + 3,
                inner.width,
                inner.height.saturating_sub(5),
            ),
        );
    } else {
        let mut y = inner.y + 3;
        for (i, label) in LABELS.iter().enumerate() {
            let height = if i == 4 {
                inner.bottom().saturating_sub(y + 3).max(1)
            } else {
                2
            };
            if y >= inner.bottom().saturating_sub(2) {
                break;
            }
            let active = i == editor.field && editor.entry.calendar.writable;
            let content = if active {
                let mut v = editor.fields[i].clone();
                v.insert(editor.cursor, '▏');
                v
            } else {
                editor.fields[i].clone()
            };
            text(
                frame,
                Rect::new(inner.x, y, inner.width, 1),
                format!("{} {label}", if active { "›" } else { " " }),
                Style::default().fg(if active { GOLD } else { DIM }),
            );
            let width = usize::from(inner.width.max(1));
            let mut wrapped: Vec<Line<'static>> = Vec::new();
            for line in content.split('\n') {
                let chars: Vec<char> = line.chars().collect();
                if chars.is_empty() {
                    wrapped.push(Line::raw(""));
                }
                for part in chars.chunks(width) {
                    wrapped.push(Line::raw(part.iter().collect::<String>()));
                }
            }
            let available = height.saturating_sub(1).max(1);
            let cursor_line = if active {
                editor.fields[i][..editor.cursor]
                    .split('\n')
                    .map(|line| line.chars().count() / width + 1)
                    .sum::<usize>()
                    .saturating_sub(1)
            } else {
                0
            };
            let scroll = if active {
                cursor_line.saturating_sub(usize::from(available.saturating_sub(1))) as u16
            } else if i == 4 {
                editor.scroll
            } else {
                0
            };
            frame.render_widget(
                Paragraph::new(wrapped)
                    .scroll((scroll, 0))
                    .style(Style::default().bg(if active { BG } else { PANEL })),
                Rect::new(inner.x, y + 1, inner.width, available),
            );
            y += height + 1;
        }
    }
    let hint = if editor.error.is_empty() {
        if editor.entry.calendar.writable {
            "Tab field · Ctrl+U clear · Ctrl+S review · Ctrl+D delete · Esc cancel"
        } else {
            "PgUp/PgDn scroll description · Esc close"
        }
        .to_string()
    } else {
        editor.error.clone()
    };
    text(
        frame,
        Rect::new(inner.x, inner.bottom().saturating_sub(2), inner.width, 2),
        hint,
        Style::default().fg(if editor.error.is_empty() { DIM } else { RED }),
    );
}
// Use projected half-hour intervals so events never paint over another event in the same cell.
fn lanes(events: &[(usize, i64, i64)]) -> Vec<(usize, usize, usize)> {
    let mut rows = events.to_vec();
    rows.sort_by_key(|e| e.1);
    let mut result = vec![];
    let mut begin = 0;
    while begin < rows.len() {
        let mut end = begin + 1;
        let mut group_end = rows[begin].2;
        while end < rows.len() && rows[end].1 < group_end {
            group_end = group_end.max(rows[end].2);
            end += 1;
        }
        let mut ends: Vec<i64> = vec![];
        let mut assigned = vec![];
        for &(index, a, b) in &rows[begin..end] {
            let lane = ends.iter().position(|v| *v <= a).unwrap_or(ends.len());
            if lane == ends.len() {
                ends.push(b);
            } else {
                ends[lane] = b;
            }
            assigned.push((index, lane));
        }
        result.extend(
            assigned
                .into_iter()
                .map(|(index, lane)| (index, lane, ends.len())),
        );
        begin = end;
    }
    result
}
fn time_range(start: DateTime<Local>, end: DateTime<Local>) -> String {
    let clock = |time: DateTime<Local>| {
        time.format(if time.minute() == 0 { "%-I" } else { "%-I:%M" })
            .to_string()
    };
    if (start.hour() < 12) == (end.hour() < 12) {
        format!("{}–{} {}", clock(start), clock(end), end.format("%p"))
    } else {
        format!(
            "{} {}–{} {}",
            clock(start),
            start.format("%p"),
            clock(end),
            end.format("%p")
        )
    }
}
fn clock_label(minute: i64) -> String {
    let hour = (minute / 60) % 24;
    format!(
        "{}:{:02} {}",
        if hour % 12 == 0 { 12 } else { hour % 12 },
        minute % 60,
        if hour < 12 { "AM" } else { "PM" }
    )
}
fn all_day_rows(entries: &[&Entry], start: NaiveDate) -> u16 {
    (0..7)
        .map(|day| {
            entries
                .iter()
                .filter(|e| {
                    e.all_day()
                        && e.overlaps(start + Duration::days(day), start + Duration::days(day + 1))
                })
                .count()
        })
        .max()
        .unwrap_or(0)
        .min(2) as u16
}
fn viewport_rows(height: u16, entries: &[&Entry], start: NaiveDate) -> u16 {
    let all = all_day_rows(entries, start);
    height
        .saturating_sub(1 + all + u16::from(all > 0))
        .clamp(1, 48)
}
fn clamp_offset(offset: i64, rows: u16) -> i64 {
    offset.clamp(0, (1440 - i64::from(rows) * 30).max(0))
}
struct MouseCapture;
impl Drop for MouseCapture {
    fn drop(&mut self) {
        let _ = crossterm::execute!(std::io::stdout(), event::DisableMouseCapture);
    }
}
fn draw_grid(
    frame: &mut Frame,
    area: Rect,
    entries: &[&Entry],
    cache: &Cache,
    start: NaiveDate,
    selected: usize,
    offset: i64,
) {
    if area.width < 40 || area.height < 8 {
        text(
            frame,
            area,
            "Enlarge the terminal to see the week grid.",
            Style::default().fg(GOLD),
        );
        return;
    }
    let axis = 8;
    let usable = area.width - axis;
    let max_all = all_day_rows(entries, start);
    let grid_y = area.y + 1 + max_all + u16::from(max_all > 0);
    let rows = area.bottom().saturating_sub(grid_y).min(48);
    let offset = clamp_offset(offset, rows);
    for day in 0..7u16 {
        let x = area.x + axis + usable * day / 7;
        let right = area.x + axis + usable * (day + 1) / 7;
        let width = right - x;
        let date = start + Duration::days(i64::from(day));
        let today = date == Local::now().date_naive();
        if today {
            frame.render_widget(
                Block::default().style(Style::default().bg(TODAY_BG)),
                Rect::new(x, area.y, width, area.height),
            );
        }
        text(
            frame,
            Rect::new(x, area.y, width, 1),
            format!(" {}", date.format("%a %d")),
            Style::default()
                .fg(if today { GOLD } else { FG })
                .add_modifier(Modifier::BOLD),
        );
        let all: Vec<_> = entries
            .iter()
            .enumerate()
            .filter(|(_, e)| e.all_day() && e.overlaps(date, date + Duration::days(1)))
            .collect();
        let skip = all
            .iter()
            .position(|(index, _)| *index == selected)
            .map(|pos| (pos + 1).saturating_sub(usize::from(max_all)))
            .unwrap_or(0);
        for (row, (index, e)) in all.iter().skip(skip).take(usize::from(max_all)).enumerate() {
            let label = if all.len() > usize::from(max_all)
                && row + 1 == usize::from(max_all)
                && *index != selected
            {
                format!("+{} all day", all.len() - skip - row)
            } else {
                format!(
                    "{}{}",
                    if *index == selected { "›" } else { " " },
                    e.title()
                )
            };
            text(
                frame,
                Rect::new(x, area.y + 1 + row as u16, width.saturating_sub(1), 1),
                label,
                Style::default()
                    .fg(event_text(color(cache, &e.calendar.id)))
                    .bg(color(cache, &e.calendar.id))
                    .add_modifier(if *index == selected {
                        Modifier::BOLD | Modifier::UNDERLINED
                    } else {
                        Modifier::empty()
                    }),
            );
        }
        for row in 0..rows {
            let minute = offset + i64::from(row) * 30;
            let line = if minute % 60 == 0 { "─" } else { "·" };
            text(
                frame,
                Rect::new(x, grid_y + row, width, 1),
                format!("│{}", line.repeat(width.saturating_sub(1) as usize)),
                Style::default().fg(LINE),
            );
        }
        let intervals: Vec<_> = entries
            .iter()
            .enumerate()
            .filter(|(_, e)| !e.all_day() && e.overlaps(date, date + Duration::days(1)))
            .map(|(i, e)| {
                let (a, b) = e.minute(date);
                (i, a / 30, (b + 29) / 30)
            })
            .collect();
        for (index, lane, count) in lanes(&intervals) {
            let e = entries[index];
            let (a, b) = e.minute(date);
            let top = (a / 30 - offset / 30).max(0);
            let bottom = ((b + 29) / 30 - offset / 30).min(i64::from(rows));
            if bottom <= top {
                continue;
            }
            let span = usize::from(width.saturating_sub(1));
            let left = span * lane / count;
            let right = span * (lane + 1) / count;
            if right <= left {
                continue;
            }
            let rect = Rect::new(
                x + 1 + left as u16,
                grid_y + top as u16,
                (right - left) as u16,
                (bottom - top) as u16,
            );
            let c = color(cache, &e.calendar.id);
            let chosen = index == selected;
            let style = Style::default()
                .fg(event_text(c))
                .bg(c)
                .add_modifier(if chosen {
                    Modifier::BOLD | Modifier::UNDERLINED
                } else {
                    Modifier::empty()
                });
            frame.render_widget(Block::default().style(style), rect);
            let title = format!("{}{}", if chosen { "›" } else { "" }, e.title());
            let title_height = if rect.height > 1 { rect.height - 1 } else { 1 };
            let title = if title_height == 1 {
                clipped(&title, usize::from(rect.width))
            } else {
                title
            };
            frame.render_widget(
                Paragraph::new(title)
                    .wrap(Wrap { trim: false })
                    .style(style),
                Rect::new(rect.x, rect.y, rect.width, title_height),
            );
            if rect.height > 1 {
                text(
                    frame,
                    Rect::new(rect.x, rect.bottom() - 1, rect.width, 1),
                    {
                        let range = time_range(e.start().unwrap(), e.end().unwrap());
                        if Line::raw(range.as_str()).width() > usize::from(rect.width) {
                            range.replace(" AM", "AM").replace(" PM", "PM")
                        } else {
                            range
                        }
                    },
                    style,
                );
            }
        }
    }
    text(
        frame,
        Rect::new(area.x, area.y + 1, axis, 1),
        "all",
        Style::default().fg(DIM),
    );
    for row in 0..rows {
        let minute = offset + i64::from(row) * 30;
        if minute >= 1440 {
            continue;
        }
        text(
            frame,
            Rect::new(area.x, grid_y + row, axis, 1),
            clock_label(minute),
            Style::default().fg(DIM),
        );
    }
    let now = Local::now();
    let day = (now.date_naive() - start).num_days();
    let minute = i64::from(now.hour() * 60 + now.minute());
    if (0..7).contains(&day) && minute >= offset && minute < offset + i64::from(rows) * 30 {
        let x = area.x + axis + usable * (day as u16) / 7;
        text(
            frame,
            Rect::new(x, grid_y + ((minute - offset) / 30) as u16, 1, 1),
            "●",
            Style::default().fg(RED),
        );
    }
}
fn focus(entries: &[&Entry], selected: usize, offset: &mut i64, rows: u16) {
    if let Some(e) = entries.get(selected).filter(|e| !e.all_day()) {
        let minute = i64::from(e.start().unwrap().hour() * 60 + e.start().unwrap().minute());
        let window = i64::from(rows).max(1) * 30;
        if minute < *offset {
            *offset = (minute / 60 * 60).max(0);
        } else if minute >= *offset + window {
            *offset = ((minute - window + 90) / 60 * 60).clamp(0, 1380);
        }
    }
}
fn clipped(value: &str, width: usize) -> String {
    if Line::raw(value).width() <= width {
        return value.into();
    }
    if width == 0 {
        return String::new();
    }
    let mut result = String::new();
    let mut used = 0;
    for c in value.chars() {
        let next = Span::raw(c.to_string()).width();
        if used + next > width - 1 {
            break;
        }
        result.push(c);
        used += next;
    }
    result.push('…');
    result
}
fn calendar_label(name: &str) -> &str {
    match name.to_lowercase().as_str() {
        "fall 2026 classes" => "Classes",
        "15-112 staff f26" => "112 Staff",
        "extracirriculars" => "Clubs & Lab",
        "mlanghor@andrew.cmu.edu" => "Personal",
        "katy@langhorst.com" => "Family",
        "lab /tech 1- due dates" => "Lab Due",
        "lab 1 -  start dates" => "Lab Start",
        "sdc buggy raceday 27" => "SDC Buggy",
        "sdc ultimate - fall 2026" => "SDC Ultimate",
        "holidays in united states" => "US Holidays",
        _ => name,
    }
}
fn body_layout(area: Rect) -> (Rect, Rect) {
    let sidebar_width = if area.width >= 120 { 16 } else { 12 }.min(area.width.saturating_sub(40));
    let body =
        Layout::horizontal([Constraint::Min(40), Constraint::Length(sidebar_width)]).split(area);
    (body[0], body[1])
}
fn calendar_sidebar(
    frame: &mut Frame,
    area: Rect,
    cache: &Cache,
    preferences: &backend::Preferences,
) {
    if area.width < 3 {
        return;
    }
    frame.render_widget(
        Block::default()
            .borders(Borders::LEFT)
            .border_style(Style::default().fg(LINE)),
        area,
    );
    let mut lines = vec![
        Line::styled(
            "Calendars",
            Style::default().fg(FG).add_modifier(Modifier::BOLD),
        ),
        Line::styled("c · choose", Style::default().fg(DIM)),
    ];
    for calendar in cache
        .calendars
        .iter()
        .filter(|c| preferences.enabled(&c.id))
    {
        lines.push(Line::styled(
            clipped(
                &format!("● {}", calendar_label(&calendar.name)),
                usize::from(area.width.saturating_sub(2)),
            ),
            Style::default().fg(color(cache, &calendar.id)),
        ));
    }
    frame.render_widget(
        Paragraph::new(lines),
        Rect::new(area.x + 2, area.y, area.width - 2, area.height),
    );
}
fn calendar_menu(
    frame: &mut Frame,
    cache: &Cache,
    preferences: &backend::Preferences,
    state: &mut ListState,
) {
    let area = popup_rect(frame.area());
    frame.render_widget(Clear, area);
    frame.render_widget(
        Block::bordered()
            .title(" Calendars · Space toggle · a all · n none · Esc close ")
            .style(Style::default().bg(PANEL).fg(FG))
            .border_style(Style::default().fg(GOLD)),
        area,
    );
    let inner = Rect::new(
        area.x + 2,
        area.y + 1,
        area.width.saturating_sub(4),
        area.height.saturating_sub(2),
    );
    let mut calendars: Vec<_> = cache.calendars.iter().collect();
    calendars.sort_by_key(|c| c.name.to_lowercase());
    let items: Vec<ListItem> = calendars
        .iter()
        .map(|c| {
            ListItem::new(Line::styled(
                format!(
                    "[{}] {}{}",
                    if preferences.enabled(&c.id) { "x" } else { " " },
                    c.name,
                    if c.writable { "" } else { " · read-only" }
                ),
                Style::default().fg(if preferences.enabled(&c.id) {
                    color(cache, &c.id)
                } else {
                    DIM
                }),
            ))
        })
        .collect();
    frame.render_stateful_widget(
        List::new(items)
            .highlight_style(Style::default().bg(LINE))
            .highlight_symbol("› "),
        Rect::new(
            inner.x,
            inner.y,
            inner.width,
            inner.height.saturating_sub(2),
        ),
        state,
    );
    text(
        frame,
        Rect::new(inner.x, inner.bottom().saturating_sub(2), inner.width, 2),
        "Saved automatically on this laptop. Hidden calendars stay cached and synced.",
        Style::default().fg(DIM),
    );
}
fn filtered<'a>(
    cache: &'a Cache,
    start: NaiveDate,
    preferences: &backend::Preferences,
) -> Vec<&'a Entry> {
    visible(cache, start)
        .into_iter()
        .filter(|entry| preferences.enabled(&entry.calendar.id))
        .collect()
}
pub fn app(terminal: &mut ratatui::DefaultTerminal) -> Result<()> {
    crossterm::execute!(std::io::stdout(), event::EnableMouseCapture)?;
    let _mouse = MouseCapture;
    let mut cache = backend::read_cache().unwrap_or_default();
    let mut start = backend::week(Local::now().date_naive());
    let mut selected = 0;
    let mut offset = 7 * 60;
    let (tx, rx) = mpsc::channel::<(&'static str, Result<Cache>)>();
    let sync_tx = tx.clone();
    std::thread::spawn(move || {
        let _ = sync_tx.send(("synced", backend::sync(false)));
    });
    let mut syncing = true;
    let mut editor: Option<Editor> = None;
    let mut preferences = backend::read_preferences()?;
    let mut menu: Option<ListState> = None;
    let mut status = String::new();
    let mut poll = Instant::now();
    let mut last_sync = Instant::now();
    let mut stamp = std::fs::metadata(backend::cache_dir()?.join("events.json"))
        .and_then(|m| m.modified())
        .ok();
    loop {
        while let Ok((operation, result)) = rx.try_recv() {
            syncing = false;
            match result {
                Ok(new) => {
                    cache = new;
                    status = if operation != "synced" {
                        format!("Event {operation} and verified on Google Calendar")
                    } else {
                        String::new()
                    };
                    if operation != "synced" {
                        editor = None;
                    }
                }
                Err(e) => {
                    status = format!("{e:#}");
                    if let Some(editor) = editor.as_mut() {
                        editor.saving = false;
                        editor.deleting = false;
                        editor.delete_confirmation.clear();
                        editor.review = None;
                        editor.error = status.clone();
                    }
                }
            }
        }
        if poll.elapsed() >= Timeout::from_secs(1) {
            poll = Instant::now();
            let new_stamp = std::fs::metadata(backend::cache_dir()?.join("events.json"))
                .and_then(|m| m.modified())
                .ok();
            if new_stamp != stamp {
                if let Ok(new) = backend::read_cache() {
                    cache = new;
                }
                stamp = new_stamp;
            }
        }
        if !syncing && last_sync.elapsed() >= Timeout::from_secs(300) {
            let tx = tx.clone();
            std::thread::spawn(move || {
                let _ = tx.send(("synced", backend::sync(false)));
            });
            syncing = true;
            last_sync = Instant::now();
        }
        let entries = filtered(&cache, start, &preferences);
        selected = selected.min(entries.len().saturating_sub(1));
        offset = clamp_offset(
            offset,
            viewport_rows(terminal.size()?.height.saturating_sub(3), &entries, start),
        );
        terminal.draw(|frame| {
            frame.render_widget(
                Block::default().style(Style::default().bg(BG).fg(FG)),
                frame.area(),
            );
            let chunks = Layout::vertical([
                Constraint::Length(1),
                Constraint::Min(8),
                Constraint::Length(2),
            ])
            .split(frame.area());
            let freshness = if syncing {
                "syncing…".into()
            } else if cache.last_week == 0 {
                "waiting for first sync".into()
            } else {
                format!(
                    "week {}m · full {}m",
                    (chrono::Utc::now().timestamp() - cache.last_week).max(0) / 60,
                    (chrono::Utc::now().timestamp() - cache.last_full).max(0) / 60
                )
            };
            text(
                frame,
                chunks[0],
                format!(
                    " CMU · {} – {} · {freshness}",
                    start.format("%b %d"),
                    (start + Duration::days(6)).format("%b %d, %Y")
                ),
                Style::default().fg(FG),
            );
            let (grid, sidebar) = body_layout(chunks[1]);
            draw_grid(frame, grid, &entries, &cache, start, selected, offset);
            calendar_sidebar(frame, sidebar, &cache, &preferences);
            let message = if !status.is_empty() {
                status.clone()
            } else {
                cache.error.clone()
            };
            let selected_time = entries
                .get(selected)
                .filter(|e| !e.all_day())
                .map(|e| time_range(e.start().unwrap(), e.end().unwrap()));
            let footer = if message.is_empty() {
                format!(
                    "{}PgUp/PgDn scroll · Home/End day · Del delete · t today · r sync",
                    selected_time.map(|t| format!("{t} · ")).unwrap_or_default()
                )
            } else {
                message.clone()
            };
            text(
                frame,
                chunks[2],
                format!(
                    "←/→ week · j/k event · wheel scroll · c calendars · Enter edit · q quit\n{}",
                    footer
                ),
                Style::default().fg(if message.is_empty() { DIM } else { GOLD }),
            );
            if let Some(editor) = &editor {
                draw_editor(frame, editor, &cache);
            }
            if let Some(menu) = menu.as_mut() {
                calendar_menu(frame, &cache, &preferences, menu);
            }
        })?;
        if !event::poll(Timeout::from_millis(100))? {
            continue;
        }
        let key = match event::read()? {
            Event::Key(key) => key,
            Event::Mouse(mouse)
                if matches!(
                    mouse.kind,
                    event::MouseEventKind::ScrollUp | event::MouseEventKind::ScrollDown
                ) =>
            {
                let delta = if mouse.kind == event::MouseEventKind::ScrollUp {
                    -30
                } else {
                    30
                };
                if let Some(menu) = menu.as_mut() {
                    let current = menu.selected().unwrap_or(0);
                    menu.select(Some(if delta < 0 {
                        current.saturating_sub(1)
                    } else {
                        (current + 1).min(cache.calendars.len().saturating_sub(1))
                    }));
                } else if let Some(editor) = editor.as_mut() {
                    if delta < 0 {
                        editor.scroll = editor.scroll.saturating_sub(2);
                    } else {
                        editor.scroll = editor.scroll.saturating_add(2);
                    }
                } else {
                    offset += delta;
                }
                continue;
            }
            _ => continue,
        };
        if key.kind != KeyEventKind::Press {
            continue;
        }
        if let Some(state) = menu.as_mut() {
            let mut calendars: Vec<_> = cache.calendars.iter().collect();
            calendars.sort_by_key(|c| c.name.to_lowercase());
            let mut updated = preferences.clone();
            let mut changed = false;
            match key.code {
                KeyCode::Esc | KeyCode::Char('c') => {
                    menu = None;
                    continue;
                }
                KeyCode::Down | KeyCode::Char('j') => state.select(Some(
                    (state.selected().unwrap_or(0) + 1).min(calendars.len().saturating_sub(1)),
                )),
                KeyCode::Up | KeyCode::Char('k') => {
                    state.select(Some(state.selected().unwrap_or(0).saturating_sub(1)))
                }
                KeyCode::Char(' ') | KeyCode::Enter => {
                    if let Some(c) = state.selected().and_then(|i| calendars.get(i)) {
                        updated.toggle(&c.id);
                        changed = true;
                    }
                }
                KeyCode::Char('a') => {
                    updated.hidden_calendars.clear();
                    changed = true;
                }
                KeyCode::Char('n') => {
                    updated
                        .hidden_calendars
                        .extend(calendars.iter().map(|c| c.id.clone()));
                    changed = true;
                }
                _ => {}
            }
            if changed {
                match backend::write_preferences(&updated) {
                    Ok(()) => {
                        preferences = updated;
                        selected = 0;
                        status.clear();
                    }
                    Err(e) => status = format!("Could not save calendar selection: {e:#}"),
                }
            }
            continue;
        }
        if let Some(edit) = editor.as_mut() {
            if edit.saving {
                continue;
            }
            if edit.deleting {
                match key.code {
                    KeyCode::Esc => {
                        edit.deleting = false;
                        edit.delete_confirmation.clear();
                    }
                    KeyCode::Backspace => {
                        edit.delete_confirmation.pop();
                    }
                    KeyCode::Char(c)
                        if !key
                            .modifiers
                            .intersects(KeyModifiers::CONTROL | KeyModifiers::ALT)
                            && edit.delete_confirmation.len() < 6 =>
                    {
                        edit.delete_confirmation.push(c);
                    }
                    KeyCode::Enter if edit.delete_confirmation == "DELETE" => {
                        let entry = edit.entry.clone();
                        let tx = tx.clone();
                        edit.saving = true;
                        std::thread::spawn(move || {
                            let _ = tx.send(("deleted", backend::delete(entry)));
                        });
                    }
                    _ => {}
                }
                continue;
            }
            if edit.review.is_some() {
                if key.code == KeyCode::PageDown {
                    edit.scroll = edit.scroll.saturating_add(5);
                    continue;
                }
                if key.code == KeyCode::PageUp {
                    edit.scroll = edit.scroll.saturating_sub(5);
                    continue;
                }
                if key.code == KeyCode::Esc {
                    edit.review = None;
                    continue;
                }
                if key.code == KeyCode::Char('y') {
                    let entry = edit.entry.clone();
                    let patch = edit.review.clone().unwrap();
                    let tx = tx.clone();
                    edit.saving = true;
                    std::thread::spawn(move || {
                        let _ = tx.send(("saved", backend::save(entry, patch)));
                    });
                }
                continue;
            }
            if key.code == KeyCode::Esc {
                editor = None;
                continue;
            }
            if !edit.entry.calendar.writable {
                match key.code {
                    KeyCode::PageDown => edit.scroll = edit.scroll.saturating_add(3),
                    KeyCode::PageUp => edit.scroll = edit.scroll.saturating_sub(3),
                    _ => {}
                }
                continue;
            }
            if key.code == KeyCode::Char('d') && key.modifiers.contains(KeyModifiers::CONTROL) {
                match backend::validate_delete(&edit.entry) {
                    Ok(()) => {
                        edit.deleting = true;
                        edit.delete_confirmation.clear();
                        edit.error.clear();
                    }
                    Err(e) => edit.error = e.to_string(),
                }
                continue;
            }
            if key.code == KeyCode::Char('s') && key.modifiers.contains(KeyModifiers::CONTROL) {
                match backend::patch(&edit.entry, &edit.fields) {
                    Ok(patch) if patch.as_object().is_some_and(|p| p.is_empty()) => {
                        edit.error = "No changes to save".into();
                    }
                    Ok(patch) => {
                        edit.review = Some(patch);
                        edit.scroll = 0;
                        edit.error.clear();
                    }
                    Err(e) => edit.error = format!("{e:#}"),
                }
            } else {
                edit.input(key);
            }
            continue;
        }
        match key.code {
            KeyCode::Char('c') if !key.modifiers.contains(KeyModifiers::CONTROL) => {
                menu = Some(ListState::default().with_selected(Some(0)))
            }
            KeyCode::Char('q') | KeyCode::Esc => break,
            KeyCode::Char('c') if key.modifiers.contains(KeyModifiers::CONTROL) => break,
            KeyCode::Down | KeyCode::Char('j') => {
                selected = (selected + 1).min(entries.len().saturating_sub(1));
                focus(
                    &entries,
                    selected,
                    &mut offset,
                    viewport_rows(terminal.size()?.height.saturating_sub(3), &entries, start),
                );
            }
            KeyCode::Up | KeyCode::Char('k') => {
                selected = selected.saturating_sub(1);
                focus(
                    &entries,
                    selected,
                    &mut offset,
                    viewport_rows(terminal.size()?.height.saturating_sub(3), &entries, start),
                );
            }
            KeyCode::Home => offset = 0,
            KeyCode::End => offset = 1440,
            KeyCode::PageUp => offset = (offset - 180).max(0),
            KeyCode::PageDown => offset = (offset + 180).min(1380),
            KeyCode::Left | KeyCode::Right | KeyCode::Char('t') => {
                let next = match key.code {
                    KeyCode::Left => start - Duration::days(7),
                    KeyCode::Right => start + Duration::days(7),
                    _ => backend::week(Local::now().date_naive()),
                };
                let (a, b) = backend::coverage(Local::now().date_naive());
                if next + Duration::days(7) > a && next < b {
                    start = next;
                    selected = 0;
                    status.clear();
                } else {
                    status = "End of the four-month cache".into();
                }
            }
            KeyCode::Char('r') if !syncing => {
                let tx = tx.clone();
                std::thread::spawn(move || {
                    let _ = tx.send(("synced", backend::sync(true)));
                });
                syncing = true;
                last_sync = Instant::now();
            }
            KeyCode::Delete => {
                if let Some(entry) = entries.get(selected) {
                    match backend::validate_delete(entry) {
                        Ok(()) => {
                            let mut popup = Editor::new((*entry).clone());
                            popup.deleting = true;
                            editor = Some(popup);
                        }
                        Err(e) => status = e.to_string(),
                    }
                }
            }
            KeyCode::Enter => {
                if let Some(entry) = entries.get(selected) {
                    editor = Some(Editor::new((*entry).clone()));
                }
            }
            _ => {}
        }
    }
    Ok(())
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn event_ranges_use_compact_us_times() {
        use chrono::TimeZone;
        let t = |hour, minute| {
            Local
                .with_ymd_and_hms(2026, 1, 15, hour, minute, 0)
                .unwrap()
        };
        assert_eq!(time_range(t(9, 0), t(10, 0)), "9–10 AM");
        assert_eq!(time_range(t(9, 30), t(10, 45)), "9:30–10:45 AM");
        assert_eq!(time_range(t(11, 30), t(13, 0)), "11:30 AM–1 PM");
        assert_eq!(
            time_range(t(23, 0), t(1, 0) + Duration::days(1)),
            "11 PM–1 AM"
        );
        assert_eq!(time_range(t(0, 0), t(1, 0)), "12–1 AM");
    }
    #[test]
    fn us_clock_formats_day_boundaries() {
        assert_eq!(clock_label(0), "12:00 AM");
        assert_eq!(clock_label(720), "12:00 PM");
        assert_eq!(clock_label(1410), "11:30 PM");
    }
    #[test]
    fn scrolling_reaches_both_ends_without_dead_steps() {
        let rows = 20;
        assert_eq!(clamp_offset(-30, rows), 0);
        let last = clamp_offset(1440, rows);
        assert_eq!(last + i64::from(rows - 1) * 30, 1410);
        assert_eq!(clamp_offset(last - 30, rows), last - 30);
    }
    #[test]
    fn overlaps_get_separate_lanes() {
        let result = lanes(&[(0, 10, 12), (1, 11, 13), (2, 13, 14)]);
        assert_eq!(result, vec![(0, 0, 2), (1, 1, 2), (2, 0, 1)]);
    }
    #[test]
    fn touching_events_share_full_width() {
        assert_eq!(
            lanes(&[(0, 10, 12), (1, 12, 14)]),
            vec![(0, 0, 1), (1, 0, 1)]
        );
    }
    #[test]
    fn connected_overlap_group_uses_peak_lanes() {
        let result = lanes(&[(0, 10, 20), (1, 12, 14), (2, 14, 16)]);
        assert_eq!(result, vec![(0, 0, 2), (1, 1, 2), (2, 1, 2)]);
    }
    #[test]
    fn editor_handles_unicode() {
        let e = Entry {
            calendar: backend::Calendar {
                id: "x".into(),
                name: "x".into(),
                writable: true,
            },
            raw: serde_json::json!({"summary":"é"}),
        };
        let mut editor = Editor::new(e);
        editor.input(KeyEvent::new(KeyCode::Backspace, KeyModifiers::NONE));
        assert_eq!(editor.fields[0], "");
    }
}

#[cfg(test)]
mod rendering_tests {
    use super::*;
    use ratatui::backend::TestBackend;
    fn fixture() -> (Cache, NaiveDate) {
        let start = NaiveDate::from_ymd_opt(2026, 10, 26).unwrap();
        let calendar = backend::Calendar {
            id: "physics".into(),
            name: "Classes".into(),
            writable: true,
        };
        let a = backend::midnight(start).unwrap() + Duration::hours(9);
        let e = Entry {
            calendar: calendar.clone(),
            raw: serde_json::json!({"id":"demo","summary":"Physics","start":{"dateTime":a.to_rfc3339()},"end":{"dateTime":(a+Duration::hours(1)).to_rfc3339()}}),
        };
        (
            Cache {
                events: vec![e],
                calendars: vec![calendar],
                ..Cache::default()
            },
            start,
        )
    }
    #[test]
    fn windowed_sizes_keep_week_sidebar_and_titles_readable() {
        let (cache, start) = fixture();
        let preferences = backend::Preferences::default();
        for (width, height) in [(140, 39), (100, 28), (80, 24)] {
            let mut terminal = Terminal::new(TestBackend::new(width, height)).unwrap();
            terminal
                .draw(|frame| {
                    let area = Rect::new(0, 1, width, height - 3);
                    let (grid, sidebar) = body_layout(area);
                    assert!(sidebar.width <= 16);
                    assert_eq!(grid.right(), sidebar.x);
                    draw_grid(
                        frame,
                        grid,
                        &visible(&cache, start),
                        &cache,
                        start,
                        usize::MAX,
                        420,
                    );
                    calendar_sidebar(frame, sidebar, &cache, &preferences);
                })
                .unwrap();
            let buffer = terminal.backend().buffer();
            let content = buffer
                .content
                .iter()
                .map(|c| c.symbol())
                .collect::<String>();
            assert!(
                content.contains("Physics"),
                "Event title must remain visible at {width}x{height}"
            );
            assert!(content.contains("Sun 01"));
            assert!(content.contains("Calendars"));
        }
    }
    #[test]
    fn disabled_calendar_is_hidden_without_removing_cache() {
        let (cache, start) = fixture();
        let mut preferences = backend::Preferences::default();
        assert_eq!(filtered(&cache, start, &preferences).len(), 1);
        preferences.toggle("physics");
        assert!(filtered(&cache, start, &preferences).is_empty());
        assert_eq!(cache.events.len(), 1);
        preferences.toggle("physics");
        assert_eq!(filtered(&cache, start, &preferences).len(), 1);
    }
    #[test]
    fn grid_renders_time_axis_and_calendar_color() {
        let (cache, start) = fixture();
        let mut terminal = Terminal::new(TestBackend::new(140, 38)).unwrap();
        terminal
            .draw(|frame| {
                draw_grid(
                    frame,
                    frame.area(),
                    &visible(&cache, start),
                    &cache,
                    start,
                    0,
                    420,
                );
            })
            .unwrap();
        let buffer = terminal.backend().buffer();
        let content = buffer
            .content
            .iter()
            .map(|c| c.symbol())
            .collect::<String>();
        assert!(content.contains("9–10 AM"));
        assert!(content.contains("Physics"));
        assert!(content.contains("Mon 26"));
        assert!(buffer
            .content
            .iter()
            .any(|cell| cell.bg == color(&cache, "physics")));
    }
    #[test]
    fn selected_all_day_event_remains_visible() {
        let (mut cache, start) = fixture();
        let calendar = cache.calendars[0].clone();
        cache.events=(0..6).map(|i|Entry{calendar:calendar.clone(),raw:serde_json::json!({"id":i.to_string(),"summary":format!("All day {i}"),"start":{"date":start.to_string()},"end":{"date":(start+Duration::days(1)).to_string()}})}).collect();
        let mut terminal = Terminal::new(TestBackend::new(140, 38)).unwrap();
        terminal
            .draw(|frame| {
                draw_grid(
                    frame,
                    frame.area(),
                    &visible(&cache, start),
                    &cache,
                    start,
                    5,
                    420,
                );
            })
            .unwrap();
        let content = terminal
            .backend()
            .buffer()
            .content
            .iter()
            .map(|c| c.symbol())
            .collect::<String>();
        assert!(content.contains("All day 5"));
    }
}
