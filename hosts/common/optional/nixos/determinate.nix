# Determinate Nix on hosts that evaluate (rebuild or deploy from); its parallel evaluator roughly halves eval time.
{inputs, ...}: {
  imports = [inputs.determinate.nixosModules.default];

  nix.settings = {
    # Determinate Nix evaluates on one core unless told otherwise.
    eval-cores = 0;
    # Determinate's managed nix.conf turns this on, so every unit and etc derivation waited on all caches' misses.
    always-allow-substitutes = false;
  };
}
