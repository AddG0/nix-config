# wayscriber 0.9.24 added a font picker whose tests enumerate the host's
# installed families through fontconfig, plus a region_action_bar test that
# asserts on painted text metrics. The sandbox has no fonts, so pango reports
# only its handful of fallback aliases and five tests fail — the picker offers 5
# rows where the test wants 12. Skip those five; the other 4221 still run.
#
# Unlike its neighbours the package comes from a flake input, not nixpkgs, whose
# own wayscriber is an unrelated 0.9.21.
# CHECK-FLAKE-ATTR: wayscriber.packages.${system}.default
_: _final: prev:
prev.lib.optionalAttrs (prev ? wayscriber-unwrapped) {
  wayscriber-unwrapped = prev.wayscriber-unwrapped.overrideAttrs (old: {
    checkFlags =
      (old.checkFlags or [])
      ++ map (test: "--skip=${test}") [
        "input::state::core::font_picker::tests::a_short_output_scrolls_by_the_rows_it_actually_shows"
        "input::state::core::font_picker::tests::choosing_a_font_with_nothing_selected_sets_what_the_next_label_uses"
        "input::state::core::font_picker::tests::choosing_a_font_with_text_selected_restyles_it_and_leaves_the_tool_alone"
        "input::state::core::font_picker::tests::the_scroll_window_follows_the_highlight_by_the_least_it_can"
        "ui::region_action_bar::tests::short_surface_status_paint_stays_inside_its_row"
      ];
  });
}
