# Workspace Rules & Development Standards

## Project Specifications

This project follows the official KOReader plugin development and review standards documented in [`DEVELOPMENT_SPEC.md`](file:///d:/Develop/github/plugins/readingfolio.koplugin/DEVELOPMENT_SPEC.md).

### Mandatory Rules for AI Agents & Developers:
1. **Version Parity**: Keep `_meta.lua`, `README.md` (Changelog), and Git tags identical.
2. **Documentation & Feature Match**: Never document features or settings keys that are not implemented in code.
3. **Screen Saver & Rotation Safety**: Intercept `Screensaver.show` safely with fallback when `ui.document` is absent. Always restore `Screen:setRotationMode` upon wake (`onResume`) or closing preview.
4. **Live Preview & Keep Menu Open**: Ensure menu parameter changes maintain open state (`keep_menu_open = true`) and refresh preview cleanly.
5. **E-Ink DPI Scaling & Safe Math**: Wrap element dimensions with `scaled(n)`. Ensure nil checks for book metadata (title, author, cover, reading stats).
6. **Input Validation**: Validate all user input dialog numbers with `tonumber` and bounds checking before persisting.
7. **Style & Locale Interface Contract**: Follow Interface v1 in `style_interface.lua` and keep 1:1 key parity between `locales/zh_CN.lua` and `locales/en.lua`.
