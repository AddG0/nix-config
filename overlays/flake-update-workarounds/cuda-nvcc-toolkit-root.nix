# cmake 4.3's FindCUDAToolkit stopped falling back to $PATH for nvcc once
# CUDAToolkit_ROOT is set. nixpkgs' setupCudaHook builds that root only from
# target-offset (buildInputs) deps carrying the include-in-cudatoolkit-root
# marker; cuda_nvcc rides in nativeBuildInputs, so nvcc is on $PATH but absent
# from the root, and every CUDA cmake configure fails with "Could not find
# `nvcc`" (hit by cudnn-frontend, onnxruntime, ollama-cuda, sunshine on this
# pin). Patch the shared hook to add nvcc's own toolkit root to the set it
# collects, so the single -DCUDAToolkit_ROOT flag and CUDAToolkit_ROOT env both
# include it. Fixing the hook covers every consumer at once — including those
# enabled via `.override { cudaSupport = true; }`, which an overrideAttrs on the
# final attr wouldn't survive. Rebuilds only cuda_nvcc + cuda_cudart (cheap
# repackaging); cudnn and the rest are untouched. Drop once nixpkgs puts nvcc in
# CUDAToolkit_ROOT (or cmake restores the $PATH fallback).
# CHECK-ATTR: cudaPackages.cudnn-frontend
_: _final: prev: {
  cudaPackages = prev.cudaPackages.overrideScope (_cudaFinal: cudaPrev: {
    setupCudaHook = cudaPrev.setupCudaHook.overrideAttrs (old: {
      buildCommand =
        (old.buildCommand or "")
        + ''
                  substituteInPlace $out/nix-support/setup-hook \
                    --replace-fail 'setupCUDAToolkit_ROOT() {' 'setupCUDAToolkit_ROOT() {
          if command -v nvcc >/dev/null 2>&1; then cudaHostPathsSeen["$(dirname "$(dirname "$(command -v nvcc)")")"]=1; fi'
        '';
    });
  });
}
