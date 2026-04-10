{pkgs}:
pkgs.writeShellScriptBin "hypr-software-brightness" ''
      set -eu

      if [ "$#" -lt 1 ]; then
        echo "hypr-software-brightness failed: expected apply, up, down, reset, or set" >&2
        exit 2
      fi

      action="$1"
      shift

      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/hypr"
      runtime_dir="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr"
      state_file="$state_dir/software-brightness"
      base_shader_file="$state_dir/software-brightness-base-shader"
      shader_file="$runtime_dir/software-dimming.glsl"

      mkdir -p "$state_dir" "$runtime_dir"

      current="1.00"
      if [ -f "$state_file" ]; then
        current=$(tr -d '\n' < "$state_file")
      fi

      apply_only=0

      case "$action" in
        apply)
          next="$current"
          apply_only=1
          ;;
        up)
          next=$(${pkgs.gawk}/bin/awk -v cur="$current" 'BEGIN { n = cur + 0.05; if (n > 1.0) n = 1.0; printf "%.2f", n }')
          ;;
        down)
          next=$(${pkgs.gawk}/bin/awk -v cur="$current" 'BEGIN { n = cur - 0.05; if (n < 0.05) n = 0.05; printf "%.2f", n }')
          ;;
        reset)
          next="1.00"
          ;;
        set)
          if [ "$#" -ne 1 ]; then
            echo "hypr-software-brightness failed: set expects one value" >&2
            exit 2
          fi
          next=$(${pkgs.gawk}/bin/awk -v raw="$1" 'BEGIN { n = raw + 0; if (n > 1.0) n = n / 100.0; if (n > 1.0) n = 1.0; if (n < 0.05) n = 0.05; printf "%.2f", n }')
          ;;
        *)
          echo "hypr-software-brightness failed: unknown action '$action'" >&2
          exit 2
          ;;
      esac

      printf '%s\n' "$next" > "$state_file"

      current_shader="$(${pkgs.hyprshade}/bin/hyprshade current 2>/dev/null || true)"
      if [ "$apply_only" = 0 ] && [ "$current" = "1.00" ] && [ "$next" != "1.00" ]; then
        case "$current_shader" in
          ""|"$shader_file")
            :
            ;;
          *)
            printf '%s\n' "$current_shader" > "$base_shader_file"
            ;;
        esac
      fi

      if [ "$next" = "1.00" ]; then
        if [ "$apply_only" = 1 ]; then
          exit 0
        fi

        if [ -f "$base_shader_file" ]; then
          base_shader=$(tr -d '\n' < "$base_shader_file")
          rm -f "$base_shader_file"
          if [ -n "$base_shader" ]; then
            exec ${pkgs.hyprshade}/bin/hyprshade on "$base_shader"
          fi
        fi

        exec ${pkgs.hyprshade}/bin/hyprshade off
      fi

      cat > "$shader_file" <<EOF
  #version 300 es
  precision highp float;

  in vec2 v_texcoord;
  uniform sampler2D tex;
  out vec4 fragColor;

  const float dimFactor = $next;

  void main() {
      vec4 pixColor = texture(tex, v_texcoord);
      fragColor = vec4(pixColor.rgb * dimFactor, pixColor.a);
  }
  EOF

      exec ${pkgs.hyprshade}/bin/hyprshade on "$shader_file"
''
