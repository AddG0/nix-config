{pkgs, ...}: {
  home.packages = with pkgs; [
    # Buf - modern protobuf toolchain
    buf # Linting, breaking change detection, and code generation

    # Protocol Buffers
    protobuf # Protocol buffer compiler (protoc)

    # gRPC tools
    grpcurl # Command-line tool for interacting with gRPC servers
    grpcui # Web UI for gRPC (like Postman for gRPC)
    evans # Interactive gRPC client

    # Go protobuf/gRPC code generation
    protoc-gen-go # Go code generator for protobuf
    protoc-gen-go-grpc # Go code generator for gRPC

    # Java gRPC code generation
    protoc-gen-grpc-java # Java code generator for gRPC

    # Additional protoc plugins
    protoc-gen-doc # Documentation generator
  ];
}
