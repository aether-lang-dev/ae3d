### Menu themes

- `menu.set_theme(stack, Theme)` draws a stack's menus in a game's colours,
  and `menu.set_menu_theme(menu, Theme)` gives one menu its own
  (`clear_menu_theme` takes it back). A menu's colours were fixed in
  `menu.draw`, so a game's menus could not match its HUD (Hushlight's #16:
  a market and a main menu in grey-blue beside soot-and-brass plates).
- A `Theme` holds:
  - `dim_screen`: the veil over what is under a menu;
  - `panel` and `panel_line`;
  - `face`, `face_hover` and `face_down`;
  - `text` and `text_dim`;
  - `accent`;
  - `field`.
- `menu.theme_default()` is the look menus had. A new stack draws in it.
- `test_menu`: the default on a new stack; the stack's theme and none of
  the default; a menu's own over the stack's; and back.
- `docs/ui.md`, "Menus".
