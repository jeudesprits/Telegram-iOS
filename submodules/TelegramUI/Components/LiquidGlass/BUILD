load("@build_bazel_rules_swift//mixed_language:mixed_language_library.bzl", "mixed_language_library")

load(
    "@build_bazel_rules_apple//apple:resources.bzl",
    "apple_resource_bundle",
    "apple_resource_group",
)
load("//build-system/bazel-utils:plist_fragment.bzl",
    "plist_fragment",
)

filegroup(
    name = "LiquidGlassMetalSources",
    srcs = glob([
        "Metal/**/*.metal",
        "Metal/**/*.h",
    ]),
    visibility = ["//visibility:public"],
)

plist_fragment(
    name = "LiquidGlassMetalSourcesBundleInfoPlist",
    extension = "plist",
    template =
    """
    <key>CFBundleIdentifier</key>
    <string>org.telegram.LiquidGlassMetalSources</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleName</key>
    <string>DustEffect</string>
    """
)

apple_resource_bundle(
    name = "LiquidGlassMetalSourcesBundle",
    infoplists = [
        ":LiquidGlassMetalSourcesBundleInfoPlist",
    ],
    resources = [
        ":LiquidGlassMetalSources",
    ],
)

mixed_language_library(
    name = "LiquidGlass",
    module_name = "LiquidGlass",
    clang_srcs = glob([
	    "Sources/**/*.m",
    ]),
    hdrs = glob([
	   "Sources/**/*.h",
    ]) + [
        "Metal/LiquidGlassShaderTypes.h",
    ],
    swift_srcs = glob([
        "Sources/**/*.swift",
	
    ]),
    data = [
        ":LiquidGlassMetalSourcesBundle",
    ],
    deps = [
    ],
    visibility = [
        "//visibility:public",
    ],
)
