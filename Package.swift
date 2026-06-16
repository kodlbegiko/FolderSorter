// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "FolderSorter",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "FolderSorter", targets: ["FolderSorter"]),
        .executable(name: "foldersorter", targets: ["FolderSorterCLI"]),
        .library(name: "FolderSorterCore", targets: ["FolderSorterCore"])
    ],
    targets: [
        .target(name: "FolderSorterCore"),
        .executableTarget(
            name: "FolderSorter",
            dependencies: ["FolderSorterCore"]
        ),
        .executableTarget(
            name: "FolderSorterCLI",
            dependencies: ["FolderSorterCore"]
        ),
        .testTarget(
            name: "FolderSorterCoreTests",
            dependencies: ["FolderSorterCore"]
        )
    ]
)
