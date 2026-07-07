// pomo-cookies — tiny cross-browser cookie extractor for Pomo.
//
// Prints auth cookies (Netscape cookies.txt format) using the `rookie` crate, so
// a signed-in web-player session can be borrowed without a fresh login.
//
// Usage:
//   pomo-cookies [--soundcloud]              try all detected browsers
//   pomo-cookies [--soundcloud] <browser>    default profile of that browser
//   pomo-cookies [--soundcloud] <browser> <profile>
//                                      e.g. `pomo-cookies chrome "Profile 1"`
//                                      or   `pomo-cookies --soundcloud chrome`
use std::env;
use std::path::Path;

fn main() {
    let args: Vec<String> = env::args().collect();
    let mut soundcloud = false;
    let mut positional: Vec<String> = Vec::new();
    for arg in args.iter().skip(1) {
        if arg == "--soundcloud" {
            soundcloud = true;
        } else {
            positional.push(arg.clone());
        }
    }

    let browser = positional.first().map(|s| s.to_lowercase());
    let profile = positional.get(1).cloned();

    let domains = if soundcloud {
        Some(vec!["soundcloud.com".to_string()])
    } else {
        Some(vec!["youtube.com".to_string(), "google.com".to_string()])
    };

    let result = match (browser.as_deref(), profile.as_deref()) {
        (Some(b), Some(_)) | (Some(b), None) if b.starts_with('-') => {
            eprintln!("pomo-cookies: unknown option '{b}' — rebuild the app to pick up cookie-helper updates");
            std::process::exit(2);
        }
        (Some(b), Some(profile_dir)) => match chromium_cookie_db(b, profile_dir) {
            Some(db) => rookie::any_browser(&db, domains, None),
            None => {
                eprintln!("pomo-cookies: no cookie DB for {b} / '{profile_dir}'");
                std::process::exit(2);
            }
        },
        (Some("chrome"), None) => rookie::chrome(domains),
        (Some("brave"), None) => rookie::brave(domains),
        (Some("edge"), None) => rookie::edge(domains),
        (Some("arc"), None) => rookie::arc(domains),
        (Some("firefox"), None) => rookie::firefox(domains),
        (Some("safari"), None) => rookie::safari(domains),
        (Some("opera"), None) => rookie::opera(domains),
        (Some("chromium"), None) => rookie::chromium(domains),
        _ => rookie::load(domains),
    };

    let cookies = match result {
        Ok(cookies) => cookies,
        Err(err) => {
            eprintln!("pomo-cookies: {err}");
            std::process::exit(1);
        }
    };

    for cookie in cookies {
        let include_subdomains = if cookie.domain.starts_with('.') { "TRUE" } else { "FALSE" };
        let secure = if cookie.secure { "TRUE" } else { "FALSE" };
        let expires = cookie.expires.unwrap_or(0);
        println!(
            "{}\t{}\t{}\t{}\t{}\t{}\t{}",
            cookie.domain, include_subdomains, cookie.path, secure, expires, cookie.name, cookie.value
        );
    }
}

/// Path to a specific Chromium-family profile's cookie DB on macOS.
/// Newer Chrome stores it under `<profile>/Network/Cookies`; older directly.
fn chromium_cookie_db(browser: &str, profile: &str) -> Option<String> {
    let base = match browser {
        "chrome" => "Google/Chrome",
        "chromium" => "Chromium",
        "brave" => "BraveSoftware/Brave-Browser",
        "edge" => "Microsoft Edge",
        "vivaldi" => "Vivaldi",
        _ => return None,
    };
    let home = env::var("HOME").ok()?;
    let root = format!("{home}/Library/Application Support/{base}/{profile}");
    for candidate in [format!("{root}/Network/Cookies"), format!("{root}/Cookies")] {
        if Path::new(&candidate).exists() {
            return Some(candidate);
        }
    }
    None
}