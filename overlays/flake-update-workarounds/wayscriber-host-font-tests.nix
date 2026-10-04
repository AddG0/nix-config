# wayscriber 0.9.24 added a font picker whose tests enumerate the host's
# installed families through fontconfig, plus a region_action_bar test that
# asserts on painted text metrics. The sandbox has no fonts, so pango reports
# only its handful of fallback aliases and five tests fail — the picker offers 5
# rows where the test wants 12.
#
# 0.9.26 adds PDF-export, portal (dbus-daemon) and process-broker (setsid) tests the sandbox can't host.
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
        "canvas_export::pdf::tests::pdf_export_honours_the_text_halo_setting"
        "canvas_export::pdf::tests::rendered_pdf_reports_exact_page_count_and_ordered_sizes"
        "canvas_export::pdf::tests::worker_exports_three_page_pdf_from_unicode_metadata"
        "capture::portal::transport_tests::portal_transport_bus_disconnect_is_a_terminal_failure"
        "capture::portal::transport_tests::portal_transport_cancellation_remains_distinct_from_failure"
        "capture::portal::transport_tests::portal_transport_compatibility_path_installs_a_new_subscription"
        "capture::portal::transport_tests::portal_transport_delayed_response_reaches_the_original_subscription"
        "capture::portal::transport_tests::portal_transport_immediate_response_before_method_reply_is_not_lost"
        "capture::portal::transport_tests::portal_transport_silent_request_times_out_and_closes_once"
        "process_broker::tests::a_descendant_outside_the_helper_group_cannot_hold_the_broker_on_its_pipes"
      ];
  });
}
