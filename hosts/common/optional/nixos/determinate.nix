# Determinate Nix on hosts that evaluate (rebuild or deploy from); its parallel evaluator roughly halves eval time.
{inputs, ...}: {
  imports = [inputs.determinate.nixosModules.default];

  # Determinate Nix evaluates on one core unless told otherwise.
  nix.settings.eval-cores = 0;
}
