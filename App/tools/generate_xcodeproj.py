"""Generate a minimal, dependency-free Xcode project for the SwiftUI app."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = [
    "AppStore.swift",
    "ReminderService.swift",
    "VisualStyle.swift",
    "CycleTimerApp.swift",
    "HomeView.swift",
    "ProjectEditor.swift",
    "TimerScreen.swift",
    "HistoryView.swift",
]
CORE = ["Models.swift", "PlanCompiler.swift", "TimerSession.swift"]


def key(prefix: str, n: int) -> str:
    return f"{prefix}{n:023X}"


file_entries = []
build_entries = []
source_entries = []
app_children = []
core_children = []
for index, name in enumerate(APP + CORE, start=1):
    ref = key("B", index)
    build = key("C", index)
    file_entries.append(
        f'{ref} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {name}; sourceTree = "<group>"; }};'
    )
    build_entries.append(
        f"{build} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {ref} /* {name} */; }};"
    )
    source_entries.append(f"{build} /* {name} in Sources */,")
    (app_children if index <= len(APP) else core_children).append(f"{ref} /* {name} */,")

text = f"""// !$*UTF8*$!
{{
    archiveVersion = 1;
    classes = {{}};
    objectVersion = 56;
    objects = {{

/* Begin PBXBuildFile section */
        {chr(10).join(build_entries)}
        A00000000000000000000010 /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = A0000000000000000000000F /* Assets.xcassets */; }};
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
        {chr(10).join(file_entries)}
        A00000000000000000000005 /* CycleTimer.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = CycleTimer.app; sourceTree = BUILT_PRODUCTS_DIR; }};
        A0000000000000000000000F /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>"; }};
/* End PBXFileReference section */

/* Begin PBXGroup section */
        A00000000000000000000001 = {{isa = PBXGroup; children = (A00000000000000000000002 /* App */, A00000000000000000000003 /* Core */, A0000000000000000000000F /* Assets.xcassets */, A00000000000000000000004 /* Products */,); sourceTree = "<group>"; }};
        A00000000000000000000002 /* App */ = {{isa = PBXGroup; children = ({chr(10).join(app_children)}); name = App; path = Sources/CycleTimer; sourceTree = "<group>"; }};
        A00000000000000000000003 /* Core */ = {{isa = PBXGroup; children = ({chr(10).join(core_children)}); name = Core; path = Sources/CycleTimerCore; sourceTree = "<group>"; }};
        A00000000000000000000004 /* Products */ = {{isa = PBXGroup; children = (A00000000000000000000005 /* CycleTimer.app */,); name = Products; sourceTree = "<group>"; }};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
        A00000000000000000000006 /* CycleTimer */ = {{
            isa = PBXNativeTarget;
            buildConfigurationList = A0000000000000000000000B /* Build configuration list for PBXNativeTarget "CycleTimer" */;
            buildPhases = (A00000000000000000000007 /* Sources */, A00000000000000000000011 /* Resources */,);
            buildRules = ();
            dependencies = ();
            name = CycleTimer;
            productName = CycleTimer;
            productReference = A00000000000000000000005 /* CycleTimer.app */;
            productType = "com.apple.product-type.application";
        }};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
        A00000000000000000000008 /* Project object */ = {{
            isa = PBXProject;
            attributes = {{BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 1500; TargetAttributes = {{A00000000000000000000006 = {{CreatedOnToolsVersion = 15.0; }}; }}; }};
            buildConfigurationList = A0000000000000000000000C /* Build configuration list for PBXProject "CycleTimer" */;
            compatibilityVersion = "Xcode 15.0";
            developmentRegion = en;
            hasScannedForEncodings = 0;
            knownRegions = (en, Base,);
            mainGroup = A00000000000000000000001;
            productRefGroup = A00000000000000000000004 /* Products */;
            projectDirPath = "";
            projectRoot = "";
            targets = (A00000000000000000000006 /* CycleTimer */,);
        }};
/* End PBXProject section */

/* Begin PBXSourcesBuildPhase section */
        A00000000000000000000007 /* Sources */ = {{isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({chr(10).join(source_entries)}); runOnlyForDeploymentPostprocessing = 0; }};
/* End PBXSourcesBuildPhase section */

/* Begin PBXResourcesBuildPhase section */
        A00000000000000000000011 /* Resources */ = {{isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (A00000000000000000000010 /* Assets.xcassets in Resources */,); runOnlyForDeploymentPostprocessing = 0; }};
/* End PBXResourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
        A00000000000000000000009 /* Debug */ = {{isa = XCBuildConfiguration; buildSettings = {{
            ALWAYS_SEARCH_USER_PATHS = NO;
            CLANG_ENABLE_MODULES = YES;
            CODE_SIGN_STYLE = Automatic;
            DEBUG_INFORMATION_FORMAT = dwarf;
            GCC_OPTIMIZATION_LEVEL = 0;
            IPHONEOS_DEPLOYMENT_TARGET = 17.0;
            SDKROOT = iphoneos;
            SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
            SWIFT_VERSION = 5.0;
        }}; name = Debug; }};
        A0000000000000000000000A /* Release */ = {{isa = XCBuildConfiguration; buildSettings = {{
            ALWAYS_SEARCH_USER_PATHS = NO;
            CLANG_ENABLE_MODULES = YES;
            CODE_SIGN_STYLE = Automatic;
            DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
            IPHONEOS_DEPLOYMENT_TARGET = 17.0;
            SDKROOT = iphoneos;
            SWIFT_COMPILATION_MODE = wholemodule;
            SWIFT_OPTIMIZATION_LEVEL = "-O";
            SWIFT_VERSION = 5.0;
        }}; name = Release; }};
        A0000000000000000000000D /* Debug */ = {{isa = XCBuildConfiguration; buildSettings = {{
            ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
            ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
            CURRENT_PROJECT_VERSION = 1;
            GENERATE_INFOPLIST_FILE = YES;
            INFOPLIST_KEY_CFBundleDisplayName = "Cycle Timer";
            INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
            INFOPLIST_KEY_UILaunchScreen_Generation = YES;
            IPHONEOS_DEPLOYMENT_TARGET = 17.0;
            MARKETING_VERSION = 0.1.0;
            PRODUCT_BUNDLE_IDENTIFIER = com.example.cycletimer;
            PRODUCT_NAME = "$(TARGET_NAME)";
            SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
            SWIFT_EMIT_LOC_STRINGS = YES;
            SWIFT_VERSION = 5.0;
            TARGETED_DEVICE_FAMILY = 1;
        }}; name = Debug; }};
        A0000000000000000000000E /* Release */ = {{isa = XCBuildConfiguration; buildSettings = {{
            ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
            ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
            CURRENT_PROJECT_VERSION = 1;
            GENERATE_INFOPLIST_FILE = YES;
            INFOPLIST_KEY_CFBundleDisplayName = "Cycle Timer";
            INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
            INFOPLIST_KEY_UILaunchScreen_Generation = YES;
            IPHONEOS_DEPLOYMENT_TARGET = 17.0;
            MARKETING_VERSION = 0.1.0;
            PRODUCT_BUNDLE_IDENTIFIER = com.example.cycletimer;
            PRODUCT_NAME = "$(TARGET_NAME)";
            SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
            SWIFT_EMIT_LOC_STRINGS = YES;
            SWIFT_VERSION = 5.0;
            TARGETED_DEVICE_FAMILY = 1;
        }}; name = Release; }};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
        A0000000000000000000000B /* Build configuration list for PBXNativeTarget "CycleTimer" */ = {{isa = XCConfigurationList; buildConfigurations = (A0000000000000000000000D /* Debug */, A0000000000000000000000E /* Release */,); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }};
        A0000000000000000000000C /* Build configuration list for PBXProject "CycleTimer" */ = {{isa = XCConfigurationList; buildConfigurations = (A00000000000000000000009 /* Debug */, A0000000000000000000000A /* Release */,); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }};
/* End XCConfigurationList section */
    }};
    rootObject = A00000000000000000000008 /* Project object */;
}}
"""

out = ROOT / "CycleTimer.xcodeproj" / "project.pbxproj"
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(text)
print(out)
