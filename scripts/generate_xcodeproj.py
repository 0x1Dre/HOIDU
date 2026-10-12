#!/usr/bin/env python3
"""Erzeugt CCTVOfferCalculator.xcodeproj aus der Ordnerstruktur.

Nach dem Hinzufügen oder Entfernen von Dateien unter CCTVOfferCalculator/ erneut ausführen:

    python3 scripts/generate_xcodeproj.py

Die IDs sind deterministisch (MD5 des Pfads), damit Änderungen im Diff nachvollziehbar bleiben.
"""
import hashlib
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP_DIR = "CCTVOfferCalculator"
PROJECT = "CCTVOfferCalculator.xcodeproj"
TARGET = "CCTVOfferCalculator"
PACKAGE_PATH = "Packages/CCTVCore"
PACKAGE_PRODUCT = "CCTVCore"
BUNDLE_ID = "ch.example.cctvoffercalculator"
DEPLOYMENT_TARGET = "17.0"
RESOURCE_SUFFIXES = (".xcassets", ".xcprivacy", ".ttf")
EXCLUDED_FILES = {"Info.plist"}


def oid(key: str) -> str:
    return hashlib.md5(key.encode("utf-8")).hexdigest()[:24].upper()


def q(value) -> str:
    text = str(value)
    if re.fullmatch(r"[A-Za-z0-9_./]+", text):
        return text
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def file_type(name: str) -> str:
    if name.endswith(".swift"):
        return "sourcecode.swift"
    if name.endswith(".xcassets"):
        return "folder.assetcatalog"
    if name.endswith(".xcprivacy"):
        return "text.xml"
    if name.endswith(".plist"):
        return "text.plist.xml"
    if name.endswith(".ttf"):
        return "file"
    return "text"


class Node:
    def __init__(self, name, path, is_group):
        self.name = name
        self.path = path
        self.is_group = is_group
        self.children = []


def scan(rel_dir: str) -> Node:
    node = Node(os.path.basename(rel_dir), rel_dir, True)
    entries = sorted(os.listdir(os.path.join(ROOT, rel_dir)), key=lambda s: s.lower())
    dirs, files = [], []
    for entry in entries:
        if entry.startswith("."):
            continue
        rel = os.path.join(rel_dir, entry)
        full = os.path.join(ROOT, rel)
        if os.path.isdir(full) and not entry.endswith(".xcassets"):
            child = scan(rel)
            if child.children:
                dirs.append(child)
        elif entry.endswith(".swift") or entry.endswith(RESOURCE_SUFFIXES) or entry.endswith(".plist"):
            files.append(Node(entry, rel, False))
    node.children = dirs + files
    return node


def walk_files(node):
    for child in node.children:
        if child.is_group:
            yield from walk_files(child)
        else:
            yield child


def main():
    tree = scan(APP_DIR)
    objects = {}

    def add(key, body):
        objects[key] = body

    project_id = oid("project")
    main_group = oid("group:main")
    products_group = oid("group:products")
    app_product = oid("product:app")
    target_id = oid("target:app")
    sources_phase = oid("phase:sources")
    frameworks_phase = oid("phase:frameworks")
    resources_phase = oid("phase:resources")
    package_ref = oid("package:local")
    package_dep = oid("package:product")
    package_build = oid("build:package")
    project_config_list = oid("configlist:project")
    target_config_list = oid("configlist:target")
    project_debug = oid("config:project:debug")
    project_release = oid("config:project:release")
    target_debug = oid("config:target:debug")
    target_release = oid("config:target:release")

    source_builds, resource_builds = [], []

    def emit_group(node, is_root=False):
        gid = oid("group:" + node.path)
        children = []
        for child in node.children:
            if child.is_group:
                children.append(emit_group(child))
            else:
                fid = oid("file:" + child.path)
                children.append(fid)
                add(fid, {
                    "isa": "PBXFileReference",
                    "lastKnownFileType": file_type(child.name),
                    "path": child.name,
                    "sourceTree": "<group>",
                })
                if child.name in EXCLUDED_FILES:
                    continue
                bid = oid("build:" + child.path)
                if child.name.endswith(".swift"):
                    source_builds.append((bid, fid, child.name))
                    add(bid, {"isa": "PBXBuildFile", "fileRef": fid, "_comment": child.name + " in Sources"})
                elif child.name.endswith(RESOURCE_SUFFIXES):
                    resource_builds.append((bid, fid, child.name))
                    add(bid, {"isa": "PBXBuildFile", "fileRef": fid, "_comment": child.name + " in Resources"})
        add(gid, {
            "isa": "PBXGroup",
            "children": children,
            "path": node.name,
            "sourceTree": "<group>",
        })
        return gid

    app_group = emit_group(tree, is_root=True)

    add(main_group, {"isa": "PBXGroup", "children": [app_group, products_group], "sourceTree": "<group>"})
    add(products_group, {"isa": "PBXGroup", "children": [app_product], "name": "Products", "sourceTree": "<group>"})
    add(app_product, {
        "isa": "PBXFileReference",
        "explicitFileType": "wrapper.application",
        "includeInIndex": "0",
        "path": TARGET + ".app",
        "sourceTree": "BUILT_PRODUCTS_DIR",
    })
    add(package_build, {"isa": "PBXBuildFile", "productRef": package_dep, "_comment": PACKAGE_PRODUCT + " in Frameworks"})

    add(sources_phase, {
        "isa": "PBXSourcesBuildPhase",
        "buildActionMask": "2147483647",
        "files": [b[0] for b in source_builds],
        "runOnlyForDeploymentPostprocessing": "0",
    })
    add(frameworks_phase, {
        "isa": "PBXFrameworksBuildPhase",
        "buildActionMask": "2147483647",
        "files": [package_build],
        "runOnlyForDeploymentPostprocessing": "0",
    })
    add(resources_phase, {
        "isa": "PBXResourcesBuildPhase",
        "buildActionMask": "2147483647",
        "files": [b[0] for b in resource_builds],
        "runOnlyForDeploymentPostprocessing": "0",
    })

    add(package_ref, {"isa": "XCLocalSwiftPackageReference", "relativePath": PACKAGE_PATH})
    add(package_dep, {"isa": "XCSwiftPackageProductDependency", "package": package_ref, "productName": PACKAGE_PRODUCT})

    add(target_id, {
        "isa": "PBXNativeTarget",
        "buildConfigurationList": target_config_list,
        "buildPhases": [sources_phase, frameworks_phase, resources_phase],
        "buildRules": [],
        "dependencies": [],
        "name": TARGET,
        "packageProductDependencies": [package_dep],
        "productName": TARGET,
        "productReference": app_product,
        "productType": "com.apple.product-type.application",
    })

    common_project = {
        "ALWAYS_SEARCH_USER_PATHS": "NO",
        "ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS": "YES",
        "CLANG_ANALYZER_NONNULL": "YES",
        "CLANG_CXX_LANGUAGE_STANDARD": "gnu++20",
        "CLANG_ENABLE_MODULES": "YES",
        "CLANG_ENABLE_OBJC_ARC": "YES",
        "CLANG_ENABLE_OBJC_WEAK": "YES",
        "CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING": "YES",
        "CLANG_WARN_BOOL_CONVERSION": "YES",
        "CLANG_WARN_COMMA": "YES",
        "CLANG_WARN_CONSTANT_CONVERSION": "YES",
        "CLANG_WARN_DOCUMENTATION_COMMENTS": "YES",
        "CLANG_WARN_EMPTY_BODY": "YES",
        "CLANG_WARN_ENUM_CONVERSION": "YES",
        "CLANG_WARN_INFINITE_RECURSION": "YES",
        "CLANG_WARN_INT_CONVERSION": "YES",
        "CLANG_WARN_STRICT_PROTOTYPES": "YES",
        "CLANG_WARN_SUSPICIOUS_MOVE": "YES",
        "CLANG_WARN_UNREACHABLE_CODE": "YES",
        "COPY_PHASE_STRIP": "NO",
        "ENABLE_STRICT_OBJC_MSGSEND": "YES",
        "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
        "GCC_C_LANGUAGE_STANDARD": "gnu17",
        "GCC_NO_COMMON_BLOCKS": "YES",
        "GCC_WARN_64_TO_32_BIT_CONVERSION": "YES",
        "GCC_WARN_ABOUT_RETURN_TYPE": "YES_ERROR",
        "GCC_WARN_UNDECLARED_SELECTOR": "YES",
        "GCC_WARN_UNINITIALIZED_AUTOS": "YES_AGGRESSIVE",
        "GCC_WARN_UNUSED_FUNCTION": "YES",
        "GCC_WARN_UNUSED_VARIABLE": "YES",
        "IPHONEOS_DEPLOYMENT_TARGET": DEPLOYMENT_TARGET,
        "LOCALIZATION_PREFERS_STRING_CATALOGS": "YES",
        "MTL_FAST_MATH": "YES",
        "SDKROOT": "iphoneos",
        "SWIFT_VERSION": "6.0",
    }
    debug_project = dict(common_project, **{
        "DEBUG_INFORMATION_FORMAT": "dwarf",
        "ENABLE_TESTABILITY": "YES",
        "GCC_DYNAMIC_NO_PIC": "NO",
        "GCC_OPTIMIZATION_LEVEL": "0",
        "GCC_PREPROCESSOR_DEFINITIONS": ["DEBUG=1", "$(inherited)"],
        "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE",
        "ONLY_ACTIVE_ARCH": "YES",
        "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG $(inherited)",
        "SWIFT_OPTIMIZATION_LEVEL": "-Onone",
    })
    release_project = dict(common_project, **{
        "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
        "ENABLE_NS_ASSERTIONS": "NO",
        "MTL_ENABLE_DEBUG_INFO": "NO",
        "SWIFT_COMPILATION_MODE": "wholemodule",
        "VALIDATE_PRODUCT": "YES",
    })
    target_settings = {
        "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
        "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
        "CODE_SIGN_STYLE": "Automatic",
        "CURRENT_PROJECT_VERSION": "1",
        "DEVELOPMENT_TEAM": "",
        "ENABLE_PREVIEWS": "YES",
        "GENERATE_INFOPLIST_FILE": "YES",
        "INFOPLIST_FILE": APP_DIR + "/Resources/Info.plist",
        "INFOPLIST_KEY_CFBundleDisplayName": "Ostsicht",
        "INFOPLIST_KEY_LSApplicationCategoryType": "public.app-category.business",
        "INFOPLIST_KEY_UIApplicationSceneManifest_Generation": "YES",
        "INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents": "YES",
        "INFOPLIST_KEY_UILaunchScreen_Generation": "YES",
        "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad": "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight",
        "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone": "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight",
        "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks"],
        "MARKETING_VERSION": "1.0",
        "PRODUCT_BUNDLE_IDENTIFIER": BUNDLE_ID,
        "PRODUCT_NAME": "$(TARGET_NAME)",
        "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator",
        "SUPPORTS_MACCATALYST": "NO",
        "SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD": "NO",
        "SWIFT_EMIT_LOC_STRINGS": "YES",
        "SWIFT_STRICT_CONCURRENCY": "complete",
        "SWIFT_VERSION": "6.0",
        "TARGETED_DEVICE_FAMILY": "1,2",
    }

    add(project_debug, {"isa": "XCBuildConfiguration", "buildSettings": debug_project, "name": "Debug"})
    add(project_release, {"isa": "XCBuildConfiguration", "buildSettings": release_project, "name": "Release"})
    add(target_debug, {"isa": "XCBuildConfiguration", "buildSettings": target_settings, "name": "Debug"})
    add(target_release, {"isa": "XCBuildConfiguration", "buildSettings": target_settings, "name": "Release"})
    add(project_config_list, {
        "isa": "XCConfigurationList",
        "buildConfigurations": [project_debug, project_release],
        "defaultConfigurationIsVisible": "0",
        "defaultConfigurationName": "Release",
    })
    add(target_config_list, {
        "isa": "XCConfigurationList",
        "buildConfigurations": [target_debug, target_release],
        "defaultConfigurationIsVisible": "0",
        "defaultConfigurationName": "Release",
    })

    add(project_id, {
        "isa": "PBXProject",
        "attributes": {
            "BuildIndependentTargetsInParallel": "1",
            "LastSwiftUpdateCheck": "1600",
            "LastUpgradeCheck": "1600",
            "TargetAttributes": {target_id: {"CreatedOnToolsVersion": "15.0"}},
        },
        "buildConfigurationList": project_config_list,
        "compatibilityVersion": "Xcode 15.0",
        "developmentRegion": "de-CH",
        "hasScannedForEncodings": "0",
        "knownRegions": ["Base", "de", "de-CH", "en"],
        "mainGroup": main_group,
        "packageReferences": [package_ref],
        "productRefGroup": products_group,
        "projectDirPath": "",
        "projectRoot": "",
        "targets": [target_id],
    })

    def render_value(value, indent):
        pad = "\t" * indent
        if isinstance(value, dict):
            lines = ["{"]
            for key in sorted(value):
                if key.startswith("_"):
                    continue
                lines.append(f"{pad}\t{q(key)} = {render_value(value[key], indent + 1)};")
            lines.append(pad + "}")
            return "\n".join(lines)
        if isinstance(value, list):
            if not value:
                return "(\n" + pad + ")"
            lines = ["("]
            for item in value:
                lines.append(f"{pad}\t{render_value(item, indent + 1)},")
            lines.append(pad + ")")
            return "\n".join(lines)
        return q(value)

    def render_object(key, body):
        ordered = {"isa": body["isa"]}
        ordered.update({k: v for k, v in body.items() if k != "isa"})
        parts = []
        for k in ordered:
            if k.startswith("_"):
                continue
            parts.append(f"\t\t\t{q(k)} = {render_value(ordered[k], 3)};")
        return f"\t\t{key} = {{\n" + "\n".join(parts) + "\n\t\t};"

    sections = {}
    for key, body in objects.items():
        sections.setdefault(body["isa"], []).append((key, body))

    out = ["// !$*UTF8*$!", "{", "\tarchiveVersion = 1;", "\tclasses = {", "\t};", "\tobjectVersion = 60;", "\tobjects = {"]
    for isa in sorted(sections):
        out.append("")
        out.append(f"/* Begin {isa} section */")
        for key, body in sorted(sections[isa]):
            out.append(render_object(key, body))
        out.append(f"/* End {isa} section */")
    out += ["\t};", f"\trootObject = {project_id};", "}", ""]

    project_dir = os.path.join(ROOT, PROJECT)
    os.makedirs(project_dir, exist_ok=True)
    with open(os.path.join(project_dir, "project.pbxproj"), "w", encoding="utf-8") as fh:
        fh.write("\n".join(out))

    workspace_dir = os.path.join(project_dir, "project.xcworkspace")
    os.makedirs(workspace_dir, exist_ok=True)
    with open(os.path.join(workspace_dir, "contents.xcworkspacedata"), "w", encoding="utf-8") as fh:
        fh.write('<?xml version="1.0" encoding="UTF-8"?>\n<Workspace\n   version = "1.0">\n   <FileRef\n      location = "self:">\n   </FileRef>\n</Workspace>\n')

    scheme_dir = os.path.join(project_dir, "xcshareddata", "xcschemes")
    os.makedirs(scheme_dir, exist_ok=True)
    app_ref = (
        f'<BuildableReference\n               BuildableIdentifier = "primary"\n               BlueprintIdentifier = "{target_id}"\n'
        f'               BuildableName = "{TARGET}.app"\n               BlueprintName = "{TARGET}"\n'
        f'               ReferencedContainer = "container:{PROJECT}">\n            </BuildableReference>'
    )
    scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1600"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            {app_ref}
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES"
      shouldAutocreateTestPlan = "YES">
      <Testables>
         <TestableReference
            skipped = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "CCTVCoreTests"
               BuildableName = "CCTVCoreTests"
               BlueprintName = "CCTVCoreTests"
               ReferencedContainer = "container:{PACKAGE_PATH}">
            </BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         {app_ref}
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         {app_ref}
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
'''
    with open(os.path.join(scheme_dir, TARGET + ".xcscheme"), "w", encoding="utf-8") as fh:
        fh.write(scheme)

    print(f"{PROJECT}: {len(source_builds)} Swift-Dateien, {len(resource_builds)} Ressourcen")


if __name__ == "__main__":
    main()
