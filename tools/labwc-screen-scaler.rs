// labwc-screen-scaler — port in Rust del "Screen scaling" di Q4OS (TDE)
// per la sessione labwc/Wayland.
//
// Logica originale (q4os-screenscaler 4.3.1, GPL), ricostruita dal binario:
//   * DPI dello schermo primario = larghezza_px * 25.4 / larghezza_mm, arrotondato;
//     valori fuori da 40..400 sono ignorati.
//   * DPI corrente letto dalla configurazione (in TDE: Xft.dpi).
//   * slider in percentuale, 100% = 96 DPI; minimo 100%, oppure il DPI corrente
//     se e' sotto 96 DPI; massimo max(probe, corrente) * 1.7, fra 289 e 500.
//   * Applica scrive il DPI e chiede di rientrare; Defaults azzera e chiede
//     conferma; Cancel chiude.
//
// Nel port Wayland il DPI diventa il blocco di variabili letto da labwc
// (Xft.dpi, GDK_SCALE/GDK_DPI_SCALE, QT_SCALE_FACTOR, XCURSOR_SIZE).
//
// Compilazione (nessuna dipendenza esterna, solo GTK3 gia' presente):
//   rustc --edition 2021 -O tools/labwc-screen-scaler.rs -o labwc-screen-scaler \
//     -C link-arg=-l:libgtk-3.so.0 -C link-arg=-l:libcairo.so.2 \
//     -C link-arg=-l:libgobject-2.0.so.0 -C link-arg=-l:libglib-2.0.so.0

use std::cell::RefCell;
use std::env;
use std::ffi::CString;
use std::fs;
use std::io;
use std::os::raw::{c_char, c_int, c_void};
use std::path::{Path, PathBuf};
use std::process::Command;

const VERSION: &str = "1";
const BASELINE_DPI: f64 = 96.0;
const MARK_BEGIN: &str = "# >>> labwc-screen-scaler";
const MARK_END: &str = "# <<< labwc-screen-scaler";

// ---------------------------------------------------------------- GTK3 FFI --

#[repr(C)]
struct GtkWidget {
    _private: [u8; 0],
}

extern "C" {
    fn gtk_init_check(argc: *mut c_int, argv: *mut *mut *mut c_char) -> c_int;
    fn gtk_main();
    fn gtk_main_quit();

    fn gtk_window_new(kind: c_int) -> *mut GtkWidget;
    fn gtk_window_set_title(w: *mut GtkWidget, title: *const c_char);
    fn gtk_window_set_default_size(w: *mut GtkWidget, width: c_int, height: c_int);
    fn gtk_window_set_position(w: *mut GtkWidget, pos: c_int);
    fn gtk_window_set_resizable(w: *mut GtkWidget, resizable: c_int);
    fn gtk_window_set_modal(w: *mut GtkWidget, modal: c_int);
    fn gtk_window_set_transient_for(w: *mut GtkWidget, parent: *mut GtkWidget);
    fn gtk_window_set_icon_name(w: *mut GtkWidget, name: *const c_char);

    fn gtk_container_set_border_width(c: *mut GtkWidget, width: u32);
    fn gtk_container_add(c: *mut GtkWidget, child: *mut GtkWidget);

    fn gtk_box_new(orientation: c_int, spacing: c_int) -> *mut GtkWidget;
    fn gtk_box_pack_start(b: *mut GtkWidget, c: *mut GtkWidget, expand: c_int, fill: c_int, pad: u32);
    fn gtk_box_pack_end(b: *mut GtkWidget, c: *mut GtkWidget, expand: c_int, fill: c_int, pad: u32);
    fn gtk_scrolled_window_new(hadj: *mut c_void, vadj: *mut c_void) -> *mut GtkWidget;
    fn gtk_scrolled_window_set_policy(s: *mut GtkWidget, h: c_int, v: c_int);

    fn gtk_label_new(text: *const c_char) -> *mut GtkWidget;
    fn gtk_label_set_text(l: *mut GtkWidget, text: *const c_char);
    fn gtk_label_set_xalign(l: *mut GtkWidget, align: f32);

    fn gtk_widget_set_halign(w: *mut GtkWidget, align: c_int);
    fn gtk_widget_set_margin_start(w: *mut GtkWidget, margin: c_int);
    fn gtk_widget_set_margin_end(w: *mut GtkWidget, margin: c_int);
    fn gtk_widget_set_margin_top(w: *mut GtkWidget, margin: c_int);
    fn gtk_widget_set_margin_bottom(w: *mut GtkWidget, margin: c_int);
    fn gtk_widget_set_size_request(w: *mut GtkWidget, width: c_int, height: c_int);
    fn gtk_widget_set_tooltip_text(w: *mut GtkWidget, text: *const c_char);
    fn gtk_widget_show_all(w: *mut GtkWidget);
    fn gtk_widget_hide(w: *mut GtkWidget);
    fn gtk_widget_destroy(w: *mut GtkWidget);
    fn gtk_widget_get_allocated_width(w: *mut GtkWidget) -> c_int;
    fn gtk_widget_queue_draw(w: *mut GtkWidget);

    fn gtk_scale_new_with_range(orientation: c_int, min: f64, max: f64, step: f64) -> *mut GtkWidget;
    fn gtk_range_get_value(r: *mut GtkWidget) -> f64;
    fn gtk_range_set_value(r: *mut GtkWidget, value: f64);
    fn gtk_range_set_increments(r: *mut GtkWidget, step: f64, page: f64);
    fn gtk_scale_set_digits(s: *mut GtkWidget, digits: c_int);
    fn gtk_scale_set_value_pos(s: *mut GtkWidget, pos: c_int);

    fn gtk_check_button_new_with_label(text: *const c_char) -> *mut GtkWidget;
    fn gtk_toggle_button_get_active(b: *mut GtkWidget) -> c_int;
    fn gtk_button_new_with_label(text: *const c_char) -> *mut GtkWidget;

    fn gtk_dialog_new() -> *mut GtkWidget;
    fn gtk_dialog_add_button(d: *mut GtkWidget, text: *const c_char, id: c_int) -> *mut GtkWidget;
    fn gtk_dialog_run(d: *mut GtkWidget) -> c_int;
    fn gtk_dialog_get_content_area(d: *mut GtkWidget) -> *mut GtkWidget;

    fn gtk_drawing_area_new() -> *mut GtkWidget;

    fn g_signal_connect_data(
        instance: *mut c_void,
        signal: *const c_char,
        handler: *mut c_void,
        data: *mut c_void,
        destroy: *mut c_void,
        flags: c_int,
    ) -> u64;

    fn cairo_set_source_rgba(cr: *mut c_void, r: f64, g: f64, b: f64, a: f64);
    fn cairo_set_line_width(cr: *mut c_void, width: f64);
    fn cairo_move_to(cr: *mut c_void, x: f64, y: f64);
    fn cairo_line_to(cr: *mut c_void, x: f64, y: f64);
    fn cairo_stroke(cr: *mut c_void);
    fn cairo_rectangle(cr: *mut c_void, x: f64, y: f64, width: f64, height: f64);
    fn cairo_fill(cr: *mut c_void);
    fn cairo_select_font_face(cr: *mut c_void, family: *const c_char, slant: c_int, weight: c_int);
    fn cairo_set_font_size(cr: *mut c_void, size: f64);
    fn cairo_show_text(cr: *mut c_void, text: *const c_char);
}

const GTK_WINDOW_TOPLEVEL: c_int = 0;
const GTK_ORIENTATION_HORIZONTAL: c_int = 0;
const GTK_ORIENTATION_VERTICAL: c_int = 1;
const GTK_POS_CENTER: c_int = 1;
const GTK_ALIGN_END: c_int = 2;
const GTK_POS_BOTTOM: c_int = 3;
const GTK_POLICY_NEVER: c_int = 0;
const GTK_POLICY_AUTOMATIC: c_int = 1;
const GTK_RESPONSE_YES: c_int = -8;
const GTK_RESPONSE_NO: c_int = -9;

fn cstr(s: &str) -> CString {
    CString::new(s.replace('\0', "")).unwrap_or_default()
}

unsafe fn connect(instance: *mut GtkWidget, signal: &str, handler: usize) {
    let signal = cstr(signal);
    g_signal_connect_data(
        instance as *mut c_void,
        signal.as_ptr(),
        handler as *mut c_void,
        std::ptr::null_mut(),
        std::ptr::null_mut(),
        0,
    );
}

// -------------------------------------------------------------- stato app --

struct State {
    window: *mut GtkWidget,
    slider: *mut GtkWidget,
    menu_slider: *mut GtkWidget,
    header: *mut GtkWidget,
    value: *mut GtkWidget,
    menu_value: *mut GtkWidget,
    advanced_box: *mut GtkWidget,
    ruler: *mut GtkWidget,
    sample: *mut GtkWidget,
    probe_dpi: f64,
    advanced: bool,
}

thread_local! {
    static STATE: RefCell<Option<State>> = RefCell::new(None);
}

fn with_state<R>(f: impl FnOnce(&State) -> R) -> R {
    STATE.with(|s| {
        let guard = s.borrow();
        f(guard.as_ref().expect("stato GUI assente"))
    })
}

fn with_state_mut<R>(f: impl FnOnce(&mut State) -> R) -> R {
    STATE.with(|s| {
        let mut guard = s.borrow_mut();
        f(guard.as_mut().expect("stato GUI assente"))
    })
}

// ------------------------------------------------------------- file/percorsi --

fn home() -> PathBuf {
    PathBuf::from(env::var_os("HOME").unwrap_or_else(|| "/tmp".into()))
}

fn config_dir() -> PathBuf {
    env::var_os("XDG_CONFIG_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| home().join(".config"))
}

fn env_path() -> PathBuf {
    config_dir().join("labwc/environment")
}

fn scale_path() -> PathBuf {
    config_dir().join("labwc/screen-scale.conf")
}

fn rc_path() -> PathBuf {
    config_dir().join("labwc/rc.xml")
}

fn themerc_path() -> PathBuf {
    config_dir().join("labwc/themerc-override")
}

fn read_key(path: &Path, key: &str) -> Option<String> {
    let text = fs::read_to_string(path).ok()?;
    for raw in text.lines() {
        let line = raw.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        if let Some((k, v)) = line.split_once('=') {
            if k.trim() == key {
                return Some(v.trim().to_string());
            }
        }
    }
    None
}

fn write_atomic(path: &Path, content: &str) -> io::Result<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    let tmp = path.with_extension("tmp");
    fs::write(&tmp, content)?;
    fs::rename(&tmp, path)
}

// ------------------------------------------------------------- logica DPI --

fn dpi_from_pixels(pixels: f64, millimetres: f64) -> f64 {
    if pixels <= 0.0 || millimetres <= 0.0 {
        return 0.0;
    }
    let dpi = (pixels * 25.4 / millimetres).round();
    if (40.0..=400.0).contains(&dpi) {
        dpi
    } else {
        0.0
    }
}

fn parse_wlr_randr(text: &str) -> Option<(f64, f64)> {
    let mut mm = None;
    let mut current = None;
    for raw in text.lines() {
        let line = raw.trim();
        if let Some(rest) = line.strip_prefix("Physical size:") {
            let value = rest.trim().trim_end_matches("mm").trim();
            if let Some((w, _h)) = value.split_once('x') {
                if let Ok(w) = w.trim().parse::<f64>() {
                    mm = Some(w);
                }
            }
        } else if line.contains(" px") && line.contains("current") && current.is_none() {
            let head = line.split("px").next().unwrap_or("").trim();
            if let Some((w, _h)) = head.split_once('x') {
                if let Ok(w) = w.trim().parse::<f64>() {
                    current = Some(w);
                }
            }
        }
    }
    Some((current?, mm?))
}

fn probe_dpi() -> f64 {
    let output = Command::new("wlr-randr").output();
    match output {
        Ok(out) if out.status.success() => {
            let text = String::from_utf8_lossy(&out.stdout);
            match parse_wlr_randr(&text) {
                Some((px, mm)) => dpi_from_pixels(px, mm),
                None => 0.0,
            }
        }
        _ => 0.0,
    }
}

fn saved_dpi() -> f64 {
    if let Some(value) = read_key(&scale_path(), "dpi") {
        if let Ok(dpi) = value.parse::<f64>() {
            if dpi > 39.0 {
                return dpi;
            }
        }
    }
    if let Some(value) = read_key(&env_path(), "Xft.dpi") {
        if let Ok(dpi) = value.parse::<f64>() {
            if dpi > 39.0 {
                return dpi;
            }
        }
    }
    BASELINE_DPI
}

fn stored_menu_value() -> f64 {
    stored_value("menu_scale", 10.0)
}

fn stored_window_value() -> f64 {
    stored_value("scale", 10.0)
}

fn stored_value(key: &str, default: f64) -> f64 {
    read_key(&scale_path(), key)
        .and_then(|v| v.parse::<f64>().ok())
        .map(|factor| (factor * 10.0).round().clamp(0.0, 20.0))
        .unwrap_or(default)
}

/// Valore dello slider (0-20, 10 = 1.0x) -> fattore di scala.
fn value_to_factor(value: f64) -> f64 {
    (value.max(1.0) / 10.0).clamp(0.1, 2.0)
}

/// Valore dello slider -> DPI applicato.
fn value_to_dpi(value: f64) -> f64 {
    (value_to_factor(value) * BASELINE_DPI).round()
}

/// DPI -> valore dello slider.
fn dpi_to_value(dpi: f64) -> f64 {
    (dpi / BASELINE_DPI * 10.0).round().clamp(1.0, 20.0)
}

fn env_block(value: f64) -> Option<String> {
    let dpi = value_to_dpi(value).clamp(10.0, 480.0);
    if (dpi - BASELINE_DPI).abs() < 0.5 {
        return None;
    }
    let factor = value_to_factor(value);
    let gdk_scale = factor.floor().max(1.0);
    let gdk_dpi = factor / gdk_scale;
    let cursor = (24.0 * factor).round().max(8.0);
    Some(format!(
        "{MARK_BEGIN}\n\
         Xft.dpi={dpi:.0}\n\
         GDK_SCALE={gdk_scale:.0}\n\
         GDK_DPI_SCALE={gdk_dpi:.2}\n\
         QT_SCALE_FACTOR={factor:.2}\n\
         QT_AUTO_SCREEN_SCALE_FACTOR=0\n\
         XCURSOR_SIZE={cursor:.0}\n\
         {MARK_END}\n"
    ))
}

/// Sostituisce il blocco gestito dal tool, preservando il resto del file.
fn rewrite_environment(path: &Path, block: Option<&str>) -> io::Result<()> {
    let content = fs::read_to_string(path).unwrap_or_default();
    let mut out = String::new();
    let mut skipping = false;
    for line in content.lines() {
        let trimmed = line.trim();
        if trimmed == MARK_BEGIN {
            skipping = true;
            continue;
        }
        if trimmed == MARK_END {
            skipping = false;
            continue;
        }
        if !skipping {
            out.push_str(line);
            out.push('\n');
        }
    }
    if let Some(block) = block {
        if !out.is_empty() && !out.ends_with('\n') {
            out.push('\n');
        }
        out.push_str(block);
    }
    write_atomic(path, &out)
}

fn read_int_key(path: &Path, key: &str) -> Option<i64> {
    read_key(path, key)?.trim().parse().ok()
}

fn themerc_int(text: &str, key: &str) -> Option<i64> {
    let mut value = None;
    for raw in text.lines() {
        let line = raw.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        if let Some((k, v)) = line.split_once(':') {
            if k.trim() == key {
                // L'ultima occorrenza e' quella effettiva (override touch).
                value = v.trim().parse().ok();
            }
        }
    }
    value
}

fn themerc_set(text: &str, key: &str, value: i64) -> String {
    let mut out = String::new();
    let mut found = false;
    for raw in text.lines() {
        let line = raw.trim_start();
        if !line.starts_with('#') {
            if let Some((k, _)) = line.split_once(':') {
                if k.trim() == key {
                    out.push_str(&format!("{key}: {value}\n"));
                    found = true;
                    continue;
                }
            }
        }
        out.push_str(raw);
        out.push('\n');
    }
    if !found {
        out.push_str(&format!("{key}: {value}\n"));
    }
    out
}

fn set_themerc_keys(path: &Path, pairs: &[(&str, i64)]) -> io::Result<()> {
    let mut text = fs::read_to_string(path).unwrap_or_default();
    for (key, value) in pairs {
        text = themerc_set(&text, key, *value);
    }
    write_atomic(path, &text)
}

fn rc_font_size(text: &str, place: &str) -> Option<i64> {
    let mut current: Option<&str> = None;
    for line in text.lines() {
        if line.contains("<font place=\"") {
            current = line
                .split("place=\"")
                .nth(1)
                .and_then(|rest| rest.split('"').next());
        }
        if current == Some(place) {
            if let Some(value) = line
                .split("<size>")
                .nth(1)
                .and_then(|rest| rest.split("</size>").next())
            {
                if let Ok(size) = value.trim().parse::<i64>() {
                    return Some(size);
                }
            }
        }
        if line.contains("</font>") {
            current = None;
        }
    }
    None
}

fn set_rc_font_sizes(path: &Path, size: i64) -> io::Result<()> {
    let text = match fs::read_to_string(path) {
        Ok(text) => text,
        Err(err) if err.kind() == io::ErrorKind::NotFound => return Ok(()),
        Err(err) => return Err(err),
    };
    let mut out = String::new();
    let mut in_font = false;
    for line in text.lines() {
        let mut newline = line.to_string();
        if line.contains("<font place=\"") {
            in_font = true;
        }
        if in_font && line.contains("<size>") && line.contains("</size>") {
            if let (Some(prefix), Some(suffix)) =
                (line.split("<size>").next(), line.split("</size>").nth(1))
            {
                newline = format!("{prefix}<size>{size}</size>{suffix}");
            }
        }
        if line.contains("</font>") {
            in_font = false;
        }
        out.push_str(&newline);
        out.push('\n');
    }
    write_atomic(path, &out)
}

struct UiBases {
    font: i64,
    pad_x: i64,
    pad_y: i64,
    width_min: i64,
    width_max: i64,
    title_pad_w: i64,
    title_pad_h: i64,
    button_w: i64,
    button_h: i64,
    button_gap: i64,
}

impl UiBases {
    fn capture(rc_text: &str, themerc_text: &str) -> Self {
        Self {
            font: rc_font_size(rc_text, "MenuItem").unwrap_or(10),
            pad_x: themerc_int(themerc_text, "menu.items.padding.x").unwrap_or(10),
            pad_y: themerc_int(themerc_text, "menu.items.padding.y").unwrap_or(6),
            width_min: themerc_int(themerc_text, "menu.width.min").unwrap_or(180),
            width_max: themerc_int(themerc_text, "menu.width.max").unwrap_or(360),
            title_pad_w: themerc_int(themerc_text, "window.titlebar.padding.width").unwrap_or(8),
            title_pad_h: themerc_int(themerc_text, "window.titlebar.padding.height").unwrap_or(6),
            button_w: themerc_int(themerc_text, "window.button.width").unwrap_or(26),
            button_h: themerc_int(themerc_text, "window.button.height").unwrap_or(26),
            button_gap: themerc_int(themerc_text, "window.button.spacing").unwrap_or(2),
        }
    }
}

fn load_bases() -> Option<UiBases> {
    let path = scale_path();
    Some(UiBases {
        font: read_int_key(&path, "menu_font_base")?,
        pad_x: read_int_key(&path, "menu_pad_x")?,
        pad_y: read_int_key(&path, "menu_pad_y")?,
        width_min: read_int_key(&path, "menu_wmin")?,
        width_max: read_int_key(&path, "menu_wmax")?,
        title_pad_w: read_int_key(&path, "title_pad_w")?,
        title_pad_h: read_int_key(&path, "title_pad_h")?,
        button_w: read_int_key(&path, "button_w")?,
        button_h: read_int_key(&path, "button_h")?,
        button_gap: read_int_key(&path, "button_gap")?,
    })
}

fn write_scale_conf(
    scale: f64,
    menu_scale: f64,
    dpi: f64,
    bases: &UiBases,
) -> io::Result<()> {
    write_atomic(
        &scale_path(),
        &format!(
            "# Generato da labwc-screen-scaler — non modificare a mano.\n\
             scale={scale:.2}\nmenu_scale={menu_scale:.2}\ndpi={dpi:.0}\n\
             menu_font_base={}\nmenu_pad_x={}\nmenu_pad_y={}\n\
             menu_wmin={}\nmenu_wmax={}\n\
             title_pad_w={}\ntitle_pad_h={}\n\
             button_w={}\nbutton_h={}\nbutton_gap={}\n",
            bases.font,
            bases.pad_x,
            bases.pad_y,
            bases.width_min,
            bases.width_max,
            bases.title_pad_w,
            bases.title_pad_h,
            bases.button_w,
            bases.button_h,
            bases.button_gap,
        ),
    )
}

fn scaled(value: i64, factor: f64, minimum: i64) -> i64 {
    ((value as f64) * factor).round().max(minimum as f64) as i64
}

fn scale_ui(factor: f64, bases: &UiBases) -> io::Result<()> {
    let rc = rc_path();
    set_rc_font_sizes(&rc, scaled(bases.font, factor, 6))?;
    let mut width_min = scaled(bases.width_min, factor, 80);
    let width_max = scaled(bases.width_max, factor, 120);
    if width_max < width_min {
        width_min = width_max;
    }
    set_themerc_keys(
        &themerc_path(),
        &[
            ("menu.items.padding.x", scaled(bases.pad_x, factor, 2)),
            ("menu.items.padding.y", scaled(bases.pad_y, factor, 1)),
            ("menu.width.min", width_min),
            ("menu.width.max", width_max),
            ("window.titlebar.padding.width", scaled(bases.title_pad_w, factor, 2)),
            ("window.titlebar.padding.height", scaled(bases.title_pad_h, factor, 1)),
            ("window.button.width", scaled(bases.button_w, factor, 12)),
            ("window.button.height", scaled(bases.button_h, factor, 12)),
            ("window.button.spacing", scaled(bases.button_gap, factor, 0)),
        ],
    )
}

fn current_bases() -> UiBases {
    let rc_text = fs::read_to_string(rc_path()).unwrap_or_default();
    let themerc_text = fs::read_to_string(themerc_path()).unwrap_or_default();
    UiBases::capture(&rc_text, &themerc_text)
}

fn reconfigure() {
    let pid = env::var("LABWC_PID").ok().or_else(|| {
        Command::new("pgrep")
            .arg("-x")
            .arg("labwc")
            .output()
            .ok()
            .and_then(|out| {
                String::from_utf8_lossy(&out.stdout)
                    .lines()
                    .next()
                    .map(str::trim)
                    .filter(|pid| !pid.is_empty())
                    .map(str::to_string)
            })
    });
    let mut cmd = Command::new("labwc");
    cmd.arg("--reconfigure");
    if let Some(pid) = pid {
        cmd.env("LABWC_PID", pid);
    }
    let _ = cmd.spawn();
}

fn apply_value(win_value: f64, menu_value: f64) -> io::Result<()> {
    let bases = load_bases().unwrap_or_else(current_bases);
    let block = env_block(win_value);
    rewrite_environment(&env_path(), block.as_deref())?;
    scale_ui(value_to_factor(menu_value), &bases)?;
    write_scale_conf(
        value_to_factor(win_value),
        value_to_factor(menu_value),
        value_to_dpi(win_value),
        &bases,
    )?;
    reconfigure();
    Ok(())
}

fn reapply_ui() -> io::Result<()> {
    let path = scale_path();
    let scale = read_key(&path, "scale")
        .and_then(|v| v.parse::<f64>().ok())
        .unwrap_or(1.0);
    let menu_scale = read_key(&path, "menu_scale")
        .and_then(|v| v.parse::<f64>().ok())
        .unwrap_or(scale);
    let dpi = read_key(&path, "dpi")
        .and_then(|v| v.parse::<f64>().ok())
        .unwrap_or(BASELINE_DPI);
    let bases = load_bases().unwrap_or_else(current_bases);
    scale_ui(menu_scale, &bases)?;
    write_scale_conf(scale, menu_scale, dpi, &bases)
}

fn reset_scaling() -> io::Result<()> {
    apply_value(10.0, 10.0)
}

fn logout() {
    if env::var_os("SYSTEM_INSTALL").is_some() {
        return;
    }
    let _ = Command::new("labwc").arg("--exit").spawn();
}

// --------------------------------------------------------------- dialogs --

unsafe fn message_dialog(parent: *mut GtkWidget, title: &str, text: &str, confirm: bool) -> bool {
    let dialog = gtk_dialog_new();
    let title_c = cstr(title);
    gtk_window_set_title(dialog, title_c.as_ptr());
    gtk_window_set_modal(dialog, 1);
    if !parent.is_null() {
        gtk_window_set_transient_for(dialog, parent);
    }
    gtk_container_set_border_width(dialog, 12);
    let content = gtk_dialog_get_content_area(dialog);
    let label = gtk_label_new(cstr(text).as_ptr());
    gtk_label_set_xalign(label, 0.0);
    gtk_widget_set_margin_start(label, 8);
    gtk_widget_set_margin_end(label, 8);
    gtk_widget_set_margin_top(label, 8);
    gtk_widget_set_margin_bottom(label, 8);
    gtk_container_add(content, label);
    let yes = cstr("Yes");
    let no = cstr("No");
    let ok = cstr("OK");
    if confirm {
        gtk_dialog_add_button(dialog, no.as_ptr(), GTK_RESPONSE_NO);
        gtk_dialog_add_button(dialog, yes.as_ptr(), GTK_RESPONSE_YES);
    } else {
        gtk_dialog_add_button(dialog, ok.as_ptr(), GTK_RESPONSE_YES);
    }
    gtk_widget_show_all(dialog);
    let response = gtk_dialog_run(dialog);
    gtk_widget_destroy(dialog);
    response == GTK_RESPONSE_YES
}

// --------------------------------------------------------------- callbacks --

unsafe fn refresh_labels() {
    let (percent, menu_percent, advanced, probe) = with_state(|s| {
        (
            gtk_range_get_value(s.slider),
            gtk_range_get_value(s.menu_slider),
            s.advanced,
            s.probe_dpi,
        )
    });
    let dpi = value_to_dpi(percent);
    let shown = format!("{percent:.0}");
    let menu_shown = format!("{menu_percent:.0}");
    if advanced {
        let value = format!("{shown}  /  {dpi:.0}  /  {probe:.0}");
        with_state(|s| {
            gtk_label_set_text(
                s.header,
                cstr("Scaling factor — windows  /  DPI value to apply  /  Primary screen guessed")
                    .as_ptr(),
            );
            gtk_label_set_text(s.value, cstr(&value).as_ptr());
            gtk_label_set_text(s.menu_value, cstr(&menu_shown).as_ptr());
        });
    } else {
        with_state(|s| {
            gtk_label_set_text(s.header, cstr("Scaling factor — windows").as_ptr());
            gtk_label_set_text(s.value, cstr(&shown).as_ptr());
            gtk_label_set_text(s.menu_value, cstr(&menu_shown).as_ptr());
        });
    }
    let _ = menu_shown;
}

extern "C" fn on_slider(_w: *mut GtkWidget, _d: *mut c_void) {
    unsafe {
        refresh_labels();
        with_state(|s| {
            gtk_widget_queue_draw(s.ruler);
            gtk_widget_queue_draw(s.sample);
        });
    }
}

extern "C" fn on_menu_slider(_w: *mut GtkWidget, _d: *mut c_void) {
    unsafe {
        refresh_labels();
    }
}

extern "C" fn on_advanced(w: *mut GtkWidget, _d: *mut c_void) {
    unsafe {
        let active = gtk_toggle_button_get_active(w) != 0;
        with_state_mut(|s| {
            s.advanced = active;
            if active {
                gtk_widget_show_all(s.advanced_box);
            } else {
                gtk_widget_hide(s.advanced_box);
            }
        });
        refresh_labels();
    }
}

extern "C" fn on_apply(_b: *mut GtkWidget, _d: *mut c_void) {
    unsafe {
        let (percent, menu_percent, window) = with_state(|s| {
            (
                gtk_range_get_value(s.slider),
                gtk_range_get_value(s.menu_slider),
                s.window,
            )
        });
        let result = apply_value(percent, menu_percent);
        let text = match &result {
            Ok(()) => "Screen scaling configuration has been saved. You need to login again for changes to take effect.".to_string(),
            Err(err) => format!("Could not save the configuration: {err}"),
        };
        message_dialog(window, "Screen scaling setup", &text, false);
        if result.is_ok() {
            gtk_widget_destroy(window);
            logout();
        }
    }
}

extern "C" fn on_defaults(_b: *mut GtkWidget, _d: *mut c_void) {
    unsafe {
        let window = with_state(|s| s.window);
        let confirmed = message_dialog(
            window,
            "Screen scaling setup",
            "Reset screen scaling configuration to system defaults now?",
            true,
        );
        if !confirmed {
            return;
        }
        let result = reset_scaling();
        let text = match &result {
            Ok(()) => "Screen scaling configuration has been saved. You need to login again for changes to take effect.".to_string(),
            Err(err) => format!("Could not save the configuration: {err}"),
        };
        message_dialog(window, "Screen scaling setup", &text, false);
        if result.is_ok() {
            gtk_widget_destroy(window);
            logout();
        }
    }
}

extern "C" fn on_cancel(_b: *mut GtkWidget, _d: *mut c_void) {
    unsafe {
        let window = with_state(|s| s.window);
        gtk_widget_destroy(window);
    }
}

extern "C" fn on_destroy(_w: *mut GtkWidget, _d: *mut c_void) {
    unsafe { gtk_main_quit() }
}

extern "C" fn draw_ruler(w: *mut GtkWidget, cr: *mut c_void, _d: *mut c_void) -> c_int {
    unsafe {
        let percent = with_state(|s| gtk_range_get_value(s.slider));
        let dpi = value_to_dpi(percent);
        let px_cm = dpi / 2.54;
        let width = gtk_widget_get_allocated_width(w) as f64;
        let baseline = 34.0;
        cairo_set_source_rgba(cr, 0.84, 0.88, 0.94, 0.95);
        cairo_set_line_width(cr, 1.2);
        cairo_move_to(cr, 6.0, baseline);
        cairo_line_to(cr, (width - 6.0).max(6.0), baseline);
        cairo_stroke(cr);
        let font = cstr("Sans");
        cairo_select_font_face(cr, font.as_ptr(), 0, 1);
        cairo_set_font_size(cr, 10.0);
        let mut x = 6.0 + px_cm;
        let mut cm = 1;
        while x < width - 8.0 {
            cairo_set_line_width(cr, 1.0);
            cairo_move_to(cr, x, baseline - 7.0);
            cairo_line_to(cr, x, baseline + 3.0);
            cairo_stroke(cr);
            let label = cstr(&cm.to_string());
            cairo_show_text(cr, label.as_ptr());
            // mezzo centimetro
            let half = x + px_cm / 2.0;
            if half < width - 8.0 {
                cairo_set_line_width(cr, 0.8);
                cairo_move_to(cr, half, baseline - 3.0);
                cairo_line_to(cr, half, baseline + 3.0);
                cairo_stroke(cr);
            }
            x += px_cm;
            cm += 1;
        }
        let unit = cstr("cm");
        cairo_show_text(cr, unit.as_ptr());
        0
    }
}

extern "C" fn draw_sample(w: *mut GtkWidget, cr: *mut c_void, _d: *mut c_void) -> c_int {
    unsafe {
        let percent = with_state(|s| gtk_range_get_value(s.slider));
        let factor = value_to_factor(percent);
        let width = gtk_widget_get_allocated_width(w) as f64;
        let box_w = (width - 16.0).min(180.0 * factor).max(80.0);
        let box_h = (26.0 * factor).clamp(24.0, 84.0);
        cairo_set_source_rgba(cr, 0.84, 0.88, 0.94, 0.16);
        cairo_rectangle(cr, 8.0, 8.0, box_w, box_h);
        cairo_fill(cr);
        let font = cstr("Sans");
        cairo_select_font_face(cr, font.as_ptr(), 0, 1);
        cairo_set_font_size(cr, (12.0 * factor).clamp(11.0, 40.0));
        cairo_set_source_rgba(cr, 0.92, 0.94, 0.98, 0.95);
        let text = cstr("Sample");
        cairo_move_to(cr, 16.0, 8.0 + box_h / 2.0 + 4.0);
        cairo_show_text(cr, text.as_ptr());
        0
    }
}

// -------------------------------------------------------------------- GUI --

unsafe fn build_gui(probe: f64) {
    let window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_title(window, cstr("Screen scaling").as_ptr());
    gtk_window_set_default_size(window, 520, 430);
    gtk_window_set_position(window, GTK_POS_CENTER);
    gtk_window_set_resizable(window, 1);
    gtk_window_set_icon_name(window, cstr("randr").as_ptr());
    gtk_container_set_border_width(window, 14);

    let outer = gtk_box_new(GTK_ORIENTATION_VERTICAL, 10);
    let scroll = gtk_scrolled_window_new(std::ptr::null_mut(), std::ptr::null_mut());
    gtk_scrolled_window_set_policy(scroll, GTK_POLICY_NEVER, GTK_POLICY_AUTOMATIC);
    gtk_container_add(scroll, outer);
    gtk_container_add(window, scroll);

    let header = gtk_label_new(cstr("Scaling factor").as_ptr());
    gtk_label_set_xalign(header, 0.0);
    gtk_box_pack_start(outer, header, 0, 0, 0);

    let value = gtk_label_new(cstr("1.00").as_ptr());
    gtk_label_set_xalign(value, 0.0);
    gtk_box_pack_start(outer, value, 0, 0, 0);

    let min = 0.0;
    let max = 20.0;
    let initial = dpi_to_value(saved_dpi());
    let slider = gtk_scale_new_with_range(GTK_ORIENTATION_HORIZONTAL, min, max, 1.0);
    gtk_range_set_increments(slider, 1.0, 5.0);
    gtk_scale_set_digits(slider, 0);
    gtk_scale_set_value_pos(slider, GTK_POS_BOTTOM);
    gtk_range_set_value(slider, initial);
    gtk_widget_set_tooltip_text(
        slider,
        cstr("10 = 1.0x (96 DPI). Below 10 shrinks, above 10 enlarges; applied at the next login.")
            .as_ptr(),
    );
    gtk_box_pack_start(outer, slider, 0, 0, 0);

    let hint = gtk_label_new(
        cstr("10 = 1.0x (96 DPI) · below 10 shrinks · above 10 enlarges").as_ptr(),
    );
    gtk_label_set_xalign(hint, 0.0);
    gtk_box_pack_start(outer, hint, 0, 0, 0);

    let menu_header = gtk_label_new(cstr("Scaling factor — menu").as_ptr());
    gtk_label_set_xalign(menu_header, 0.0);
    gtk_box_pack_start(outer, menu_header, 0, 0, 0);

    let menu_value = gtk_label_new(cstr("10").as_ptr());
    gtk_label_set_xalign(menu_value, 0.0);
    gtk_box_pack_start(outer, menu_value, 0, 0, 0);

    let menu_initial = stored_menu_value();
    let menu_slider = gtk_scale_new_with_range(GTK_ORIENTATION_HORIZONTAL, 0.0, 20.0, 1.0);
    gtk_range_set_increments(menu_slider, 1.0, 5.0);
    gtk_scale_set_digits(menu_slider, 0);
    gtk_scale_set_value_pos(menu_slider, GTK_POS_BOTTOM);
    gtk_range_set_value(menu_slider, menu_initial);
    gtk_widget_set_tooltip_text(
        menu_slider,
        cstr("10 = 1.0x. Scales the right-click menu, its text and the window title bars.")
            .as_ptr(),
    );
    gtk_box_pack_start(outer, menu_slider, 0, 0, 0);

    let menu_hint = gtk_label_new(
        cstr("10 = 1.0x · below 10 shrinks the menu · above 10 enlarges it").as_ptr(),
    );
    gtk_label_set_xalign(menu_hint, 0.0);
    gtk_box_pack_start(outer, menu_hint, 0, 0, 0);

    let advanced = gtk_check_button_new_with_label(cstr("Show advanced options").as_ptr());
    gtk_box_pack_start(outer, advanced, 0, 0, 0);

    let advanced_box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 6);
    let ruler_label = gtk_label_new(cstr("Ruler [cm]:").as_ptr());
    gtk_label_set_xalign(ruler_label, 0.0);
    gtk_box_pack_start(advanced_box, ruler_label, 0, 0, 0);
    let ruler = gtk_drawing_area_new();
    gtk_widget_set_size_request(ruler, 420, 48);
    gtk_box_pack_start(advanced_box, ruler, 0, 0, 0);
    let sample_label = gtk_label_new(cstr("Sample:").as_ptr());
    gtk_label_set_xalign(sample_label, 0.0);
    gtk_box_pack_start(advanced_box, sample_label, 0, 0, 0);
    let sample = gtk_drawing_area_new();
    gtk_widget_set_size_request(sample, 420, 92);
    gtk_box_pack_start(advanced_box, sample, 0, 0, 0);
    gtk_box_pack_start(outer, advanced_box, 0, 0, 0);
    gtk_widget_hide(advanced_box);

    let buttons = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
    gtk_widget_set_halign(buttons, GTK_ALIGN_END);
    for (label, handler) in [
        ("Defaults", on_defaults as *const () as usize),
        ("Apply", on_apply as *const () as usize),
        ("Cancel", on_cancel as *const () as usize),
    ] {
        let button = gtk_button_new_with_label(cstr(label).as_ptr());
        connect(button, "clicked", handler);
        gtk_box_pack_start(buttons, button, 0, 0, 0);
    }
    gtk_box_pack_end(outer, buttons, 0, 0, 0);

    STATE.with(|s| {
        *s.borrow_mut() = Some(State {
            window,
            slider,
            menu_slider,
            header,
            value,
            menu_value,
            advanced_box,
            ruler,
            sample,
            probe_dpi: probe,
            advanced: false,
        });
    });

    connect(window, "destroy", on_destroy as *const () as usize);
    connect(slider, "value-changed", on_slider as *const () as usize);
    connect(menu_slider, "value-changed", on_menu_slider as *const () as usize);
    connect(advanced, "toggled", on_advanced as *const () as usize);
    connect(ruler, "draw", draw_ruler as *const () as usize);
    connect(sample, "draw", draw_sample as *const () as usize);

    refresh_labels();
    gtk_widget_show_all(window);
    gtk_widget_hide(advanced_box);
    gtk_main();
}

fn gui() -> i32 {
    unsafe {
        if gtk_init_check(std::ptr::null_mut(), std::ptr::null_mut()) == 0 {
            eprintln!("labwc-screen-scaler: impossibile aprire il display (serve una sessione labwc/Wayland)");
            return 1;
        }
        build_gui(probe_dpi());
    }
    0
}

// ------------------------------------------------------------------- CLI --

fn status() {
    let probe = probe_dpi();
    let current = saved_dpi();
    let percent = dpi_to_value(current);
    let menu = stored_menu_value();
    println!(
        "probe_dpi={probe:.0} current_dpi={current:.0} scale={:.2} value={percent:.0} menu_scale={:.2} menu_value={menu:.0}",
        value_to_factor(percent),
        value_to_factor(menu)
    );
}

fn self_test() -> i32 {
    assert_eq!(dpi_from_pixels(1920.0, 310.0), 157.0);
    assert_eq!(dpi_from_pixels(1920.0, 0.0), 0.0);
    assert_eq!(
        parse_wlr_randr(
            "eDP-1 \"panel\"\n  Physical size: 310x174 mm\n  Modes:\n    1920x1080 px, 60.000000 Hz (current)\n"
        ),
        Some((1920.0, 310.0))
    );
    assert_eq!(value_to_dpi(10.0), 96.0);
    assert_eq!(value_to_dpi(8.0), 77.0);
    assert_eq!(value_to_dpi(20.0), 192.0);
    assert_eq!(dpi_to_value(120.0), 13.0);
    assert_eq!(dpi_to_value(96.0), 10.0);
    assert_eq!(value_to_factor(5.0), 0.5);
    assert_eq!(value_to_factor(0.0), 0.1);

    let dir = env::temp_dir().join(format!("labwc-scaler-test-{}", std::process::id()));
    let _ = fs::remove_dir_all(&dir);
    fs::create_dir_all(&dir).unwrap();
    let env_file = dir.join("environment");
    fs::write(&env_file, "QT_QPA_PLATFORM=wayland;xcb\n").unwrap();
    let block = env_block(13.0).unwrap();
    assert!(block.contains("Xft.dpi=125"), "dpi 125 atteso");
    rewrite_environment(&env_file, Some(&block)).unwrap();
    rewrite_environment(&env_file, None).unwrap();
    let text = fs::read_to_string(&env_file).unwrap();
    assert!(!text.contains("Xft.dpi"), "blocco non rimosso");
    assert!(text.contains("QT_QPA_PLATFORM"), "contenuto perso");

    let rc_file = dir.join("rc.xml");
    fs::write(
        &rc_file,
        "<theme>\n<font place=\"MenuItem\">\n<name>Inter</name>\n<size>13</size>\n</font>\n</theme>\n",
    )
    .unwrap();
    let rc_text = fs::read_to_string(&rc_file).unwrap();
    assert_eq!(rc_font_size(&rc_text, "MenuItem"), Some(13));
    set_rc_font_sizes(&rc_file, 10).unwrap();
    let rc_text = fs::read_to_string(&rc_file).unwrap();
    assert_eq!(rc_font_size(&rc_text, "MenuItem"), Some(10));

    let th = dir.join("themerc");
    fs::write(&th, "menu.items.padding.x: 16\n").unwrap();
    let th_text = fs::read_to_string(&th).unwrap();
    let th_text = themerc_set(&th_text, "menu.items.padding.x", 13);
    assert_eq!(themerc_int(&th_text, "menu.items.padding.x"), Some(13));
    let th_text = themerc_set(&th_text, "menu.width.min", 208);
    assert_eq!(themerc_int(&th_text, "menu.width.min"), Some(208));

    let _ = fs::remove_dir_all(&dir);
    println!("SELFTEST_OK");
    0
}
fn usage() {
    println!(
        "labwc-screen-scaler {VERSION}\n\
         Scala dello schermo per labwc (port del tool Q4OS).\n\n\
         Uso:\n\
           labwc-screen-scaler              apre la finestra\n\
           labwc-screen-scaler --probe      stampa i DPI rilevati\n\
           labwc-screen-scaler --status     stampa DPI e scala correnti\n\
           labwc-screen-scaler --apply N    applica la scala finestre N (10 = 1.0x, 0 = minimo, 20 = 2.0x)\n\
           labwc-screen-scaler --apply-menu N  applica la scala menu N (10 = 1.0x)\n\
           labwc-screen-scaler --reapply    riapplica menu e titoli (dopo un cambio tema)\n\
           labwc-screen-scaler --reset      torna ai valori predefiniti\n\
           labwc-screen-scaler --self-test  test interno senza display\n\
           labwc-screen-scaler --version\n"
    );
}

fn main() {
    let args: Vec<String> = env::args().collect();
    let code = match args.get(1).map(String::as_str) {
        None => gui(),
        Some("--help" | "-h") => {
            usage();
            0
        }
        Some("--version") => {
            println!("labwc-screen-scaler {VERSION}");
            0
        }
        Some("--probe") => {
            println!("{:.0}", probe_dpi());
            0
        }
        Some("--status") => {
            status();
            0
        }
        Some("--self-test") => self_test(),
        Some("--reapply") => match reapply_ui() {
            Ok(()) => 0,
            Err(err) => {
                eprintln!("labwc-screen-scaler: {err}");
                1
            }
        },
        Some("--reset") => match reset_scaling() {
            Ok(()) => 0,
            Err(err) => {
                eprintln!("labwc-screen-scaler: {err}");
                1
            }
        },
        Some("--apply") => match args.get(2).and_then(|v| v.parse::<f64>().ok()) {
            Some(percent) if (0.0..=20.0).contains(&percent) => {
                match apply_value(percent, stored_menu_value()) {
                    Ok(()) => 0,
                    Err(err) => {
                        eprintln!("labwc-screen-scaler: {err}");
                        1
                    }
                }
            }
            _ => {
                eprintln!("labwc-screen-scaler: --apply richiede un valore fra 0 e 20 (10 = 1.0x)");
                2
            }
        },
        Some("--apply-menu") => match args.get(2).and_then(|v| v.parse::<f64>().ok()) {
            Some(percent) if (0.0..=20.0).contains(&percent) => {
                match apply_value(stored_window_value(), percent) {
                    Ok(()) => 0,
                    Err(err) => {
                        eprintln!("labwc-screen-scaler: {err}");
                        1
                    }
                }
            }
            _ => {
                eprintln!(
                    "labwc-screen-scaler: --apply-menu richiede un valore fra 0 e 20 (10 = 1.0x)"
                );
                2
            }
        },
        Some(other) => {
            eprintln!("labwc-screen-scaler: opzione sconosciuta: {other}");
            2
        }
    };
    std::process::exit(code);
}
