_: {
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
    jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    # media-session.enable = true;

    ## Per-device HFP block for AirPods. WP's bluez5.roles and the
    ## global bluetooth.autoswitch-to-headset-profile setting are not
    ## per-device-overridable, so to keep HFP working for other
    ## headsets we use a small Lua hook that watches this card and
    ## reverts any switch to a headset-head-unit-* profile back to the
    ## highest-priority a2dp-sink profile.
    wireplumber.extraConfig."52-airpods-block-headset" = {
      "wireplumber.components" = [
        {
          name = "airpods/block-headset.lua";
          type = "script/lua";
          provides = "custom.airpods-block-headset";
        }
      ];
      "wireplumber.profiles" = {
        main = {"custom.airpods-block-headset" = "required";};
      };
    };
    wireplumber.extraScripts."airpods/block-headset.lua" = ''
      cutils = require ("common-utils")
      log = Log.open_topic ("s-bluez-policy")

      -- Apple's Bluetooth vendor ID. Matches all AirPods variants
      -- (Pro, Pro 2, Max, regular). Combined with the form-factor
      -- check below, excludes Magic Mouse / Magic Keyboard / etc.
      local APPLE_VENDOR_ID = "bluetooth:004c"
      local AIRPODS_FORM_FACTORS = {
        headphone = true,
        headset = true,
        earbuds = true,
      }

      local function isAirPods (device)
        local props = device.properties
        return props ["device.vendor.id"] == APPLE_VENDOR_ID
            and AIRPODS_FORM_FACTORS [props ["device.form-factor"] or ""]
      end

      local function getCurrentProfile (device)
        for p in device:iterate_params ("Profile") do
          return cutils.parseParam (p, "Profile")
        end
        return nil
      end

      local function highestPrioA2dpSink (device)
        local found = nil
        for p in device:iterate_params ("EnumProfile") do
          local profile = cutils.parseParam (p, "EnumProfile")
          if profile and profile.available ~= "no"
              and string.find (profile.name, "^a2dp%-sink") then
            if found == nil or found.priority < profile.priority then
              found = profile
            end
          end
        end
        return found
      end

      SimpleEventHook {
        name = "airpods/block-headset-profile",
        interests = {
          EventInterest {
            Constraint { "event.type", "=", "device-params-changed" },
            Constraint { "event.subject.param-id", "=", "Profile" },
          },
        },
        execute = function (event)
          local device = event:get_subject ()
          if not isAirPods (device) then return end

          local cur = getCurrentProfile (device)
          if cur == nil then return end

          if not (string.find (cur.name, "^headset%-head%-unit") or
                  cur.name == "bap-duplex") then
            return
          end

          local target = highestPrioA2dpSink (device)
          if target == nil then
            log:warning (device, "on " .. cur.name ..
                " but no a2dp-sink available; not reverting")
            return
          end

          log:info (device, "reverting " .. cur.name .. " -> " ..
              target.name .. " (AirPods HFP block)")
          device:set_params ("Profile", Pod.Object {
            "Spa:Pod:Object:Param:Profile", "Profile",
            index = target.index,
            save = true,
          })
        end,
      }:register ()
    '';

    ## Optimize PipeWire audio processing for maximum quality
    extraConfig.pipewire."99-quality-settings" = {
      "context.properties" = {
        ## Use highest quality resampling algorithm
        ## Valid range: 0-14 (default is 4)
        ## Quality 10 = good balance, 14 = maximum quality (uses significantly more CPU)
        "resample.quality" = 14;

        ## Reduce quantum (buffer size) for lower latency while maintaining quality
        ## 1024 frames gives a good latency / stability tradeoff
        "default.clock.quantum" = 1024;
        "default.clock.min-quantum" = 1024;
        "default.clock.max-quantum" = 2048;
      };
    };
  };
}
