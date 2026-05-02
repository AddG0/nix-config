_: {
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  hardware.bluetooth.settings = {
    General = {
      Experimental = true; # Enables better codec support
      ## Make the adapter respond faster when known devices (AirPods) start
      ## advertising on wake — without this, BlueZ often misses the brief
      ## advertisement window when AirPods leave the case.
      FastConnectable = true;
      JustWorksRepairing = "always";
    };
    Policy = {
      AutoEnable = true;
      ## Only auto-reconnect A2DP (audio) profiles, not HFP (hands-free).
      ## BlueZ's default reconnects HFP too, but AirPods reject it on Linux,
      ## causing a retry loop that makes the device "busy" and blocks A2DP —
      ## resulting in repeated full disconnects (~6/hr).
      ## HFP is still available on-demand via WirePlumber when a mic is requested.
      ## UUIDs: 110a = A2DP Source, 110b = A2DP Sink
      ReconnectUUIDs = "0000110a-0000-1000-8000-00805f9b34fb,0000110b-0000-1000-8000-00805f9b34fb";
      ReconnectAttempts = 7;
      ReconnectIntervals = "1,2,4,8,16,32,64";
    };
  };
}
