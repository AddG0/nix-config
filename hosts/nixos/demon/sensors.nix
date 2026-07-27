# Super I/O fan tach + voltages on the ASUS X870E. ASUS hides the NCT chip
# behind ACPI, so nct6775 only binds with acpi_enforce_resources=lax.
{pkgs, ...}: {
  boot.kernelModules = ["nct6775"];
  boot.kernelParams = ["acpi_enforce_resources=lax"];
  environment.systemPackages = [pkgs.lm_sensors];
}
