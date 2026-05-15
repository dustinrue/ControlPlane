// swift-tools-version: 6.0
// Requires Xcode — use `make run` rather than `swift run` directly.
// First run downloads mlx-community/Qwen3-4B-4bit (~2.8 GB) to ~/.cache/huggingface/hub/
import PackageDescription

let package = Package(
    name: "NLConfigMLX",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(
            url: "https://github.com/ml-explore/mlx-swift-lm.git",
            from: "3.31.3"
        ),
        .package(
            url: "https://github.com/ml-explore/mlx-swift.git",
            from: "0.21.0"
        ),
        // Method 2 (macro-compatible) integration:
        //   HuggingFace module → HubClient for downloading
        //   Tokenizers module → AutoTokenizer for tokenization
        .package(
            url: "https://github.com/huggingface/swift-huggingface",
            .upToNextMajor(from: "0.9.0")
        ),
        .package(
            url: "https://github.com/huggingface/swift-transformers",
            .upToNextMajor(from: "1.3.0")
        ),
    ],
    targets: [
        .executableTarget(
            name: "NLConfigMLX",
            dependencies: [
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "MLXHuggingFace", package: "mlx-swift-lm"),
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "HuggingFace", package: "swift-huggingface"),
                .product(name: "Tokenizers", package: "swift-transformers"),
            ],
            path: "Sources/NLConfigMLX",
            swiftSettings: [
                // Swift 5 language mode — avoids strict concurrency errors
                // in the test harness; production code should target Swift 6.
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
