#!/usr/bin/env python3
"""Generate the public-only Catalyst project from shared Bewie sources."""
from pathlib import Path
import hashlib
import json
import plistlib

root = Path(__file__).resolve().parent.parent
objects = {}
def ident(name):
    return hashlib.sha1(('bewie.mac.' + name).encode()).hexdigest()[:24].upper()
def obj(label, isa, **fields):
    key = ident(label)
    objects[key] = dict(isa=isa, **fields)
    return key
def file(path, kind):
    return obj('file:' + path, 'PBXFileReference', lastKnownFileType=kind, path=path, sourceTree='SOURCE_ROOT')
def phase(name, kind, refs):
    return obj(name, kind, buildActionMask=2147483647, files=[obj(name + r, 'PBXBuildFile', fileRef=r) for r in refs], runOnlyForDeploymentPostprocessing=0)
def configs(name, settings):
    refs = []
    for config in ['Debug', 'Release']:
        values = dict(settings)
        values.update(SWIFT_OPTIMIZATION_LEVEL='-Onone' if config == 'Debug' else '-O', ONLY_ACTIVE_ARCH='NO', DEBUG_INFORMATION_FORMAT='dwarf' if config == 'Debug' else 'dwarf-with-dsym')
        if config == 'Debug':
            values['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = 'DEBUG $(inherited)'
            values['ENABLE_TESTABILITY'] = 'YES'
        refs.append(obj(name + config, 'XCBuildConfiguration', name=config, buildSettings=values))
    return obj(name + 'list', 'XCConfigurationList', buildConfigurations=refs, defaultConfigurationIsVisible=0, defaultConfigurationName='Release')

# Private code is absent from the Mac target, including all enrollment and push services.
private = {'PlayerGuideMarkers', 'PushMessageView', 'PushNotifications'}
sources = [file(str(p.relative_to(root)), 'sourcecode.swift') for p in sorted((root / 'Bewie').glob('*.swift')) if not p.stem.startswith('Travel') and p.stem not in private]
sources.append(file('MessagesShared/VideoAssets.swift', 'sourcecode.swift'))
resources = [file('Bewie/Assets.xcassets', 'folder.assetcatalog'), file('Bewie/AppIcon.icon', 'folder.iconcomposer.icon'), file('Bewie/Resources/Fonts/PTMono-Regular.ttf', 'file')]
resources += [file(str(p.relative_to(root)), 'text') for p in sorted((root / 'Bewie/Resources/Lyrics').glob('*.lrc'))]
for name in ['Public.strings', 'InfoPlist.strings', 'Credits.rtf']:
    refs = [obj('localized:' + str(p.relative_to(root)), 'PBXFileReference', lastKnownFileType='text.rtf' if name.endswith('rtf') else 'text.plist.strings', name=p.parent.stem, path=str(p.relative_to(root)), sourceTree='SOURCE_ROOT') for p in sorted((root / ('Configuration/MacLocalizations' if name == 'InfoPlist.strings' else 'Bewie/Resources')).glob('*.lproj/' + name))]
    resources.append(obj('localized:' + name, 'PBXVariantGroup', children=refs, name=name, sourceTree='<group>'))
product = obj('product', 'PBXFileReference', explicitFileType='wrapper.application', path='Bewie.app', sourceTree='BUILT_PRODUCTS_DIR', includeInIndex=0)
extproduct = obj('extproduct', 'PBXFileReference', explicitFileType='wrapper.app-extension', path='MusicDownloaderMac.appex', sourceTree='BUILT_PRODUCTS_DIR', includeInIndex=0)
extsource = file('MusicDownloader/MusicDownloader.swift', 'sourcecode.swift')
products = obj('products', 'PBXGroup', children=[product, extproduct], name='Products', sourceTree='<group>')
group = obj('rootgroup', 'PBXGroup', children=sources + resources + [extsource, products], sourceTree='<group>')
base = dict(CLANG_ENABLE_MODULES='YES', SWIFT_VERSION='5.0', SDKROOT='iphoneos', SUPPORTED_PLATFORMS='macosx', SUPPORTS_MACCATALYST='YES', SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD='NO', DERIVE_MACCATALYST_PRODUCT_BUNDLE_IDENTIFIER='NO', TARGETED_DEVICE_FAMILY='2', IPHONEOS_DEPLOYMENT_TARGET='26.0', MACOSX_DEPLOYMENT_TARGET='26.0', ARCHS='arm64 x86_64', CODE_SIGN_STYLE='Automatic', DEVELOPMENT_TEAM='7G949WYL6E', CURRENT_PROJECT_VERSION='1', MARKETING_VERSION='1.0', ENABLE_USER_SCRIPT_SANDBOXING='YES', ENABLE_APP_SANDBOX='YES', ENABLE_HARDENED_RUNTIME='YES', GENERATE_INFOPLIST_FILE='YES')
mainconfig = configs('main', dict(base, PRODUCT_NAME='Bewie', PRODUCT_BUNDLE_IDENTIFIER='bewie.atelierindustriel.be', INFOPLIST_FILE='Configuration/Mac-Info.plist', CODE_SIGN_ENTITLEMENTS='Configuration/Mac.entitlements', ASSETCATALOG_COMPILER_APPICON_NAME='AppIcon', INFOPLIST_KEY_CFBundleDisplayName='Bewie', INFOPLIST_KEY_LSApplicationCategoryType='public.app-category.music', LD_RUNPATH_SEARCH_PATHS='$(inherited) @executable_path/../Frameworks'))
extconfig = configs('extension', dict(base, PRODUCT_NAME='MusicDownloaderMac', PRODUCT_BUNDLE_IDENTIFIER='bewie.atelierindustriel.be.musicdownloader', INFOPLIST_FILE='Configuration/MusicDownloader-Info.plist', CODE_SIGN_ENTITLEMENTS='Configuration/Mac-MusicDownloader.entitlements', SKIP_INSTALL='YES', APPLICATION_EXTENSION_API_ONLY='YES', LD_RUNPATH_SEARCH_PATHS='$(inherited) @executable_path/../../../../Frameworks'))
exttarget = obj('exttarget', 'PBXNativeTarget', name='MusicDownloaderMac', productName='MusicDownloaderMac', productReference=extproduct, productType='com.apple.product-type.extensionkit-extension', buildConfigurationList=extconfig, buildPhases=[phase('extsources', 'PBXSourcesBuildPhase', [extsource]), phase('extframeworks', 'PBXFrameworksBuildPhase', [])], buildRules=[], dependencies=[])
proxy = obj('extproxy', 'PBXContainerItemProxy', containerPortal=ident('project'), proxyType=1, remoteGlobalIDString=exttarget, remoteInfo='MusicDownloaderMac')
dep = obj('extdep', 'PBXTargetDependency', target=exttarget, targetProxy=proxy)
embedfile = obj('embedfile', 'PBXBuildFile', fileRef=extproduct, settings={'ATTRIBUTES': ['RemoveHeadersOnCopy']})
embed = obj('embed', 'PBXCopyFilesBuildPhase', buildActionMask=2147483647, files=[embedfile], runOnlyForDeploymentPostprocessing=0, dstPath='$(EXTENSIONS_FOLDER_PATH)', dstSubfolderSpec=16, name='Embed Background Downloader')
target = obj('target', 'PBXNativeTarget', name='BewieMac', productName='Bewie', productReference=product, productType='com.apple.product-type.application', buildConfigurationList=mainconfig, buildPhases=[phase('sources', 'PBXSourcesBuildPhase', sources), phase('frameworks', 'PBXFrameworksBuildPhase', []), phase('resources', 'PBXResourcesBuildPhase', resources), embed], buildRules=[], dependencies=[dep])
testnames = ['TestAudio', 'VideoAssetTests', 'PublicLocalizationTests', 'MapStartLocationTests', 'TrackFlightKeyframeTests', 'SynchronizedLyricsTests', 'PearlRevealTests', 'AssetDownloadTests', 'AlbumDownloadPreparationTests', 'DirectPackPlaybackTests', 'DownloadBarProgressTests', 'SystemPlaybackTests', 'ContinuousPlaybackTests', 'TrackArrivalPlayerTests']
testsources = [file('BewieTests/' + name + '.swift', 'sourcecode.swift') for name in testnames] + [file('BewieMacTests/PublicMacTests.swift', 'sourcecode.swift')]
testaudio = file('MusicAssets/Audio', 'folder')
testproduct = obj('testproduct', 'PBXFileReference', explicitFileType='wrapper.cfbundle', path='BewieMacTests.xctest', sourceTree='BUILT_PRODUCTS_DIR', includeInIndex=0)
objects[products]['children'].append(testproduct)
objects[group]['children'] += testsources + [testaudio]
testconfig = configs('tests', dict(base, PRODUCT_NAME='BewieMacTests', PRODUCT_BUNDLE_IDENTIFIER='bewie.atelierindustriel.be.mactests', SKIP_INSTALL='YES', TEST_HOST='$(BUILT_PRODUCTS_DIR)/Bewie.app/Contents/MacOS/Bewie', BUNDLE_LOADER='$(TEST_HOST)', LD_RUNPATH_SEARCH_PATHS='$(inherited) @executable_path/../Frameworks @loader_path/../Frameworks'))
testproxy = obj('testproxy', 'PBXContainerItemProxy', containerPortal=ident('project'), proxyType=1, remoteGlobalIDString=target, remoteInfo='BewieMac')
testdep = obj('testdep', 'PBXTargetDependency', target=target, targetProxy=testproxy)
testtarget = obj('testtarget', 'PBXNativeTarget', name='BewieMacTests', productName='BewieMacTests', productReference=testproduct, productType='com.apple.product-type.bundle.unit-test', buildConfigurationList=testconfig, buildPhases=[phase('testsources', 'PBXSourcesBuildPhase', testsources), phase('testframeworks', 'PBXFrameworksBuildPhase', []), phase('testresources', 'PBXResourcesBuildPhase', [])], buildRules=[], dependencies=[testdep])
project = obj('project', 'PBXProject', attributes={'BuildIndependentTargetsInParallel': 'YES', 'LastUpgradeCheck': '2720', 'TargetAttributes': {target: {'CreatedOnToolsVersion': '27.2'}, exttarget: {'CreatedOnToolsVersion': '27.2'}}}, buildConfigurationList=configs('project', base), compatibilityVersion='Xcode 15.0', developmentRegion='en', knownRegions=['en', 'fr', 'en-GB', 'de', 'es', 'es-MX', 'it', 'ja', 'pt-BR', 'Base'], mainGroup=group, productRefGroup=products, projectDirPath='', projectRoot='', targets=[target, exttarget, testtarget])
def serialize(value, depth=0):
    if isinstance(value, dict):
        return '{\n' + ''.join('\t' * (depth + 1) + json.dumps(str(k)) + ' = ' + serialize(v, depth + 1) + ';\n' for k, v in value.items()) + '\t' * depth + '}'
    if isinstance(value, list):
        return '( ' + ', '.join(serialize(v, depth + 1) for v in value) + ' )'
    return str(value) if isinstance(value, int) else json.dumps(value)
projectdir = root / 'BewieMac.xcodeproj'
(projectdir / 'xcshareddata/xcschemes').mkdir(parents=True, exist_ok=True)
(projectdir / 'project.pbxproj').write_text('// !$*UTF8*$!\n' + serialize(dict(archiveVersion=1, classes={}, objectVersion=60, objects=objects, rootObject=project)) + '\n')
reference = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="Bewie.app" BlueprintName="BewieMac" ReferencedContainer="container:BewieMac.xcodeproj"/>'
scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2720" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{reference}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.PosixSpawn" shouldUseLaunchSchemeArgsEnv="NO"><Testables><TestableReference skipped="NO" parallelizable="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{testtarget}" BuildableName="BewieMacTests.xctest" BlueprintName="BewieMacTests" ReferencedContainer="container:BewieMac.xcodeproj"/></TestableReference></Testables><EnvironmentVariables><EnvironmentVariable key="BEWIE_UNIT_TESTS" value="1" isEnabled="YES"/></EnvironmentVariables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.PosixSpawn" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable><BackgroundAssetPacksFolderResolver identifier="absolute:{root}/build/AssetPacks"/></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>
'''
(projectdir / 'xcshareddata/xcschemes/BewieMac.xcscheme').write_text(scheme)
