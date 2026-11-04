mod backend;
mod ui;
use anyhow::Result;
fn main() -> Result<()> {
    let args: Vec<String> = std::env::args().collect();
    if args.iter().any(|a| a == "--sync" || a == "--sync-full") {
        let cache = backend::sync(args.iter().any(|a| a == "--sync-full"))?;
        println!("CMU cache: {} events, {} calendars; current week every 5 minutes, full range every hour",cache.events.len(),cache.calendars.len());
        return Ok(());
    }
    if args.iter().any(|a| a == "--check") {
        let cache = backend::read_cache()?;
        println!(
            "CMU cache: {} events, coverage {:?} through {:?}, last full {}, last week {}",
            cache.events.len(),
            cache.from,
            cache.until,
            cache.last_full,
            cache.last_week
        );
        if !cache.error.is_empty() {
            anyhow::bail!("{}", cache.error);
        }
        return Ok(());
    }
    let mut terminal = ratatui::init();
    let result = ui::app(&mut terminal);
    ratatui::restore();
    result
}
