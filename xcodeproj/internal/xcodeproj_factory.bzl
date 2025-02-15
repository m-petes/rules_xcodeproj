"""Module to create `xcodeproj` rules and transitions."""

load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "use_cpp_toolchain")
load(":xcodeproj_legacy_aspect.bzl", "xcodeproj_legacy_aspect")
load(":xcodeproj_legacy_rule.bzl", "xcodeproj_legacy_rule")
load(":xcodeproj_transitions.bzl", "XCODEPROJ_TRANSITION_ATTRS")

def _make_xcodeproj_aspect(
        *,
        build_mode,
        generator_name):
    attrs = xcodeproj_legacy_aspect.attrs(
        build_mode = build_mode,
        generator_name = generator_name,
    )
    implementation = xcodeproj_legacy_aspect.impl

    return aspect(
        implementation = implementation,
        attr_aspects = ["*"],
        attrs = attrs,
        fragments = ["apple", "cpp", "objc"],
        toolchains = use_cpp_toolchain(),
    )

def _make_xcodeproj_rule(
        *,
        is_fixture = False,
        target_transitions = None,
        xcodeproj_aspect,
        xcodeproj_transition = None):
    attrs = xcodeproj_legacy_rule.attrs(
        is_fixture = is_fixture,
        target_transitions = target_transitions,
        xcodeproj_aspect = xcodeproj_aspect,
    )
    impl = xcodeproj_legacy_rule.impl

    return rule(
        doc = "Creates an `.xcodeproj` file in the workspace when run.",
        cfg = xcodeproj_transition,
        implementation = impl,
        attrs = attrs | XCODEPROJ_TRANSITION_ATTRS,
        executable = True,
    )

xcodeproj_factory = struct(
    make_aspect = _make_xcodeproj_aspect,
    make_rule = _make_xcodeproj_rule,
)
