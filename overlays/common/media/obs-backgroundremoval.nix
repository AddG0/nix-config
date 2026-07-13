# OBS Background Removal 1.3.6 with CUDA support, patched to use the ResNet50
# RVM backbone and FP32 RMBG model (higher quality than the bundled defaults).
_: _final: prev: let
  # RVM ResNet50 model (107MB vs 15MB MobileNetV3) for better quality
  rvmResnet50Model = prev.fetchurl {
    url = "https://github.com/PeterL1n/RobustVideoMatting/releases/download/v1.0.0/rvm_resnet50_fp32.onnx";
    hash = "sha256-JdswD8tu4n+UGhtSyXhW6NHxPH81gX+BphL4mvDoqFw=";
  };
  # RMBG 1.4 FP32 full precision model (176MB vs 44MB quantized) for better quality
  rmbgFp32Model = prev.fetchurl {
    url = "https://huggingface.co/briaai/RMBG-1.4/resolve/main/onnx/model.onnx";
    hash = "sha256-jK/PdwsGdXxOrO0hsaiOV/0rZt4BuARfNfAVNbp0Lg8=";
  };
in {
  obs-studio-plugins =
    prev.obs-studio-plugins
    // {
      obs-backgroundremoval = prev.obs-studio-plugins.obs-backgroundremoval.overrideAttrs (old: {
        version = "1.3.6";
        src = prev.fetchFromGitHub {
          owner = "royshil";
          repo = "obs-backgroundremoval";
          rev = "1.3.6";
          hash = "sha256-2BVcOH7wh1ibHZmaTMmRph/jYchHcCbq8mn9wo4LQOU=";
        };
        nativeBuildInputs = old.nativeBuildInputs ++ [prev.pkg-config];
        buildInputs =
          (map
            (dep:
              if dep.pname or "" == "onnxruntime"
              then prev.onnxruntime.override {cudaSupport = true;}
              else dep)
            old.buildInputs)
          ++ [prev.curl];
        cmakeFlags =
          (map
            (flag:
              if flag == "--preset linux-x86_64"
              then "--preset ubuntu-x86_64"
              else if flag == "-DDISABLE_ONNXRUNTIME_GPU=ON"
              then "-DDISABLE_ONNXRUNTIME_GPU=OFF"
              else flag)
            old.cmakeFlags)
          # Use pkg-config mode for finding dependencies (nixpkgs doesn't have cmake CONFIG files)
          ++ ["-DVCPKG_TARGET_TRIPLET=" "-DUSE_PKGCONFIG=ON"];
        # Patch source to support ResNet50 channel dimensions (16,32,64,128 vs MobileNetV3's 16,20,40,64)
        postPatch =
          (old.postPatch or "")
          + ''
            sed -i 's/(i == 1) ? 16 : (i == 2) ? 20 : (i == 3) ? 40 : 64/(i == 1) ? 16 : (i == 2) ? 32 : (i == 3) ? 64 : 128/g' src/models/ModelRVM.h
          '';
        # Replace models with higher quality versions
        installPhase =
          (old.installPhase or "")
          + ''
            mkdir -p $out/share/obs/obs-plugins/obs-backgroundremoval/models
            # RVM: MobileNetV3 -> ResNet50 (107MB)
            rm -f $out/share/obs/obs-plugins/obs-backgroundremoval/models/rvm_mobilenetv3_fp32.onnx
            cp ${rvmResnet50Model} $out/share/obs/obs-plugins/obs-backgroundremoval/models/rvm_mobilenetv3_fp32.onnx
            # RMBG: Quantized -> FP32 (176MB)
            rm -f $out/share/obs/obs-plugins/obs-backgroundremoval/models/bria_rmbg_1_4_qint8.onnx
            cp ${rmbgFp32Model} $out/share/obs/obs-plugins/obs-backgroundremoval/models/bria_rmbg_1_4_qint8.onnx
          '';
      });
    };
}
