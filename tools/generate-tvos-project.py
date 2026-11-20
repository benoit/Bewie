#!/usr/bin/env python3
"""Generate the standalone TV project without modifying iOS/watch project settings."""
from pathlib import Path
import hashlib,json,plistlib,shutil
root=Path(__file__).resolve().parent.parent
objects={}
def ident(name):return hashlib.sha1(('bewie.tv.'+name).encode()).hexdigest()[:24].upper()
def obj(label,isa,**kw):
 i=ident(label);objects[i]={'isa':isa,**kw};return i
def file(path,typ):return obj('file:'+path,'PBXFileReference',lastKnownFileType=typ,path=path,sourceTree='SOURCE_ROOT')
def phase(name,kind,refs):
 files=[obj(name+':'+r,'PBXBuildFile',fileRef=r) for r in refs]
 return obj(name,kind,buildActionMask=2147483647,files=files,runOnlyForDeploymentPostprocessing=0)
shared=['AlbumTrack','AlbumPlayer','MusicLibrary','SystemPlayback','PublicText','PinPlacement','SystemMapGeometry','MapStartLocation','TrackFlightKeyframes','AlbumSleeveReveal','MapLyricsView','SynchronizedLyrics','MusicLoadingBar']
sources=[file('Bewie/'+n+'.swift','sourcecode.swift') for n in shared]
sources += [file(str(p.relative_to(root)),'sourcecode.swift') for p in sorted((root/'BewieTV').glob('*.swift'))]
assets=root/'BewieTV/Assets.xcassets';assets.mkdir(exist_ok=True)
for name in ['LaunchAlbumCover','PearlPin']:
 source=root/f'Bewie/Assets.xcassets/{name}.imageset';dest=assets/source.name
 if not dest.exists():shutil.copytree(source,dest)
info={'author':'xcode','version':1}
(assets/'Contents.json').write_text(json.dumps({'info':info},indent=2)+'\n')
resources=[file('BewieTV/TVLaunchScreen.storyboard','file.storyboard'),file('BewieTV/Assets.xcassets','folder.assetcatalog'),file('Bewie/Resources/Fonts/PTMono-Regular.ttf','file')]
resources += [file(str(p.relative_to(root)), 'text') for p in sorted((root/'Bewie/Resources/Lyrics').glob('*.lrc'))]
variants=[]
for p in sorted((root/'Bewie/Resources').glob('*.lproj/Public.strings')):
 r=obj('localized:'+p.parent.name,'PBXFileReference',lastKnownFileType='text.plist.strings',name=p.parent.stem,path=str(p.relative_to(root)),sourceTree='SOURCE_ROOT');variants.append(r)
resources.append(obj('public-localizations','PBXVariantGroup',children=variants,name='Public.strings',sourceTree='<group>'))
mainproduct=obj('product','PBXFileReference',explicitFileType='wrapper.application',path='Bewie.app',sourceTree='BUILT_PRODUCTS_DIR',includeInIndex=0)
extproduct=obj('extproduct','PBXFileReference',explicitFileType='wrapper.app-extension',path='MusicDownloaderTV.appex',sourceTree='BUILT_PRODUCTS_DIR',includeInIndex=0)
extsource=file('MusicDownloader/MusicDownloader.swift','sourcecode.swift')
products=obj('products','PBXGroup',children=[mainproduct,extproduct],name='Products',sourceTree='<group>')
group=obj('rootgroup','PBXGroup',children=sources+resources+[extsource,products],sourceTree='<group>')
settingsbase={'CLANG_ENABLE_MODULES':'YES','SWIFT_VERSION':'5.0','TVOS_DEPLOYMENT_TARGET':'26.4','SDKROOT':'appletvos','SUPPORTED_PLATFORMS':'appletvos appletvsimulator','TARGETED_DEVICE_FAMILY':'3','CODE_SIGN_STYLE':'Automatic','DEVELOPMENT_TEAM':plistlib.loads((root/'Configuration/ExportOptions-TestFlight.plist').read_bytes())['teamID'],'CURRENT_PROJECT_VERSION':'3','MARKETING_VERSION':'1.0','ENABLE_USER_SCRIPT_SANDBOXING':'YES'}
def configs(name,base):
 refs=[]
 for config in ['Debug','Release']:
  settings=dict(base)
  if config=='Debug':settings.update({'SWIFT_OPTIMIZATION_LEVEL':'-Onone','SWIFT_ACTIVE_COMPILATION_CONDITIONS':'DEBUG $(inherited)','DEBUG_INFORMATION_FORMAT':'dwarf','ONLY_ACTIVE_ARCH':'YES'})
  else:settings.update({'SWIFT_OPTIMIZATION_LEVEL':'-O','SWIFT_COMPILATION_MODE':'wholemodule','DEBUG_INFORMATION_FORMAT':'dwarf-with-dsym','VALIDATE_PRODUCT':'YES'})
  refs.append(obj(name+config,'XCBuildConfiguration',name=config,buildSettings=settings))
 return obj(name+'list','XCConfigurationList',buildConfigurations=refs,defaultConfigurationIsVisible=0,defaultConfigurationName='Release')
mainconfig=configs('main',{**settingsbase,'PRODUCT_NAME':'Bewie','PRODUCT_BUNDLE_IDENTIFIER':'bewie.atelierindustriel.be','GENERATE_INFOPLIST_FILE':'YES','INFOPLIST_FILE':'Configuration/TV-Info.plist','CODE_SIGN_ENTITLEMENTS':'Configuration/TV.entitlements','ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon','INFOPLIST_KEY_CFBundleDisplayName':'Bewie','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/Frameworks'})
extconfig=configs('extension',{**settingsbase,'PRODUCT_NAME':'MusicDownloaderTV','PRODUCT_BUNDLE_IDENTIFIER':'bewie.atelierindustriel.be.musicdownloader','GENERATE_INFOPLIST_FILE':'YES','INFOPLIST_FILE':'Configuration/TV-MusicDownloader-Info.plist','CODE_SIGN_ENTITLEMENTS':'Configuration/MusicDownloader.entitlements','SKIP_INSTALL':'YES','APPLICATION_EXTENSION_API_ONLY':'YES','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks'})
exttarget=obj('extensiontarget','PBXNativeTarget',name='MusicDownloaderTV',productName='MusicDownloaderTV',productReference=extproduct,productType='com.apple.product-type.extensionkit-extension',buildConfigurationList=extconfig,buildPhases=[phase('extsources','PBXSourcesBuildPhase',[extsource]),phase('extframeworks','PBXFrameworksBuildPhase',[]),phase('extresources','PBXResourcesBuildPhase',[])],buildRules=[],dependencies=[])
proxy=obj('extensionproxy','PBXContainerItemProxy',containerPortal=ident('project'),proxyType=1,remoteGlobalIDString=exttarget,remoteInfo='MusicDownloaderTV')
dep=obj('extensiondep','PBXTargetDependency',target=exttarget,targetProxy=proxy)
embedfile=obj('extensionembedfile','PBXBuildFile',fileRef=extproduct,settings={'ATTRIBUTES':['RemoveHeadersOnCopy']})
embed=obj('extensionembed','PBXCopyFilesBuildPhase',buildActionMask=2147483647,files=[embedfile],runOnlyForDeploymentPostprocessing=0,dstPath='$(EXTENSIONS_FOLDER_PATH)',dstSubfolderSpec=16,name='Embed Background Downloader')
maintarget=obj('maintarget','PBXNativeTarget',name='BewieTV',productName='Bewie',productReference=mainproduct,productType='com.apple.product-type.application',buildConfigurationList=mainconfig,buildPhases=[phase('sources','PBXSourcesBuildPhase',sources),phase('frameworks','PBXFrameworksBuildPhase',[]),phase('resources','PBXResourcesBuildPhase',resources),embed],buildRules=[],dependencies=[dep])
testsource=file('BewieTVTests/BewieTVUITests.swift','sourcecode.swift')
testproduct=obj('testproduct','PBXFileReference',explicitFileType='wrapper.cfbundle',path='BewieTVUITests.xctest',sourceTree='BUILT_PRODUCTS_DIR',includeInIndex=0)
objects[products]['children'].append(testproduct)
objects[group]['children'].append(testsource)
testconfig=configs('uitests',{**settingsbase,'PRODUCT_NAME':'BewieTVUITests','PRODUCT_BUNDLE_IDENTIFIER':'bewie.atelierindustriel.be.tvuitests','GENERATE_INFOPLIST_FILE':'YES','TEST_TARGET_NAME':'BewieTV','SKIP_INSTALL':'YES','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/Frameworks @loader_path/Frameworks'})
testproxy=obj('testproxy','PBXContainerItemProxy',containerPortal=ident('project'),proxyType=1,remoteGlobalIDString=maintarget,remoteInfo='BewieTV')
testdep=obj('testdep','PBXTargetDependency',target=maintarget,targetProxy=testproxy)
testtarget=obj('testtarget','PBXNativeTarget',name='BewieTVUITests',productName='BewieTVUITests',productReference=testproduct,productType='com.apple.product-type.bundle.ui-testing',buildConfigurationList=testconfig,buildPhases=[phase('testsources','PBXSourcesBuildPhase',[testsource]),phase('testframeworks','PBXFrameworksBuildPhase',[]),phase('testresources','PBXResourcesBuildPhase',[])],buildRules=[],dependencies=[testdep])
project=obj('project','PBXProject',attributes={'BuildIndependentTargetsInParallel':'YES','LastUpgradeCheck':'2720','TargetAttributes':{maintarget:{'CreatedOnToolsVersion':'27.2'},exttarget:{'CreatedOnToolsVersion':'27.2'}}},buildConfigurationList=configs('project',{'CLANG_ENABLE_MODULES':'YES','SWIFT_VERSION':'5.0','TVOS_DEPLOYMENT_TARGET':'26.4'}),compatibilityVersion='Xcode 15.0',developmentRegion='en',knownRegions=['en','fr','en-GB','de','es','es-MX','it','ja','pt-BR','Base'],mainGroup=group,productRefGroup=products,projectDirPath='',projectRoot='',targets=[maintarget,exttarget,testtarget])
def serialize(v,depth=0):
 if isinstance(v,dict):return '{\n'+''.join('\t'*(depth+1)+json.dumps(str(k))+' = '+serialize(x,depth+1)+';\n' for k,x in v.items())+'\t'*depth+'}'
 if isinstance(v,list):return '( '+', '.join(serialize(x,depth+1) for x in v)+' )'
 return str(v) if isinstance(v,int) else json.dumps(v)
projectdir=root/'BewieTV.xcodeproj';projectdir.mkdir(exist_ok=True)
(projectdir/'project.pbxproj').write_text('// !$*UTF8*$!\n'+serialize({'archiveVersion':1,'classes':{},'objectVersion':60,'objects':objects,'rootObject':project})+'\n')
reference=f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{maintarget}" BuildableName="Bewie.app" BlueprintName="BewieTV" ReferencedContainer="container:BewieTV.xcodeproj"/>'
scheme=f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2720" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{reference}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.PosixSpawn" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO" parallelizable="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{testtarget}" BuildableName="BewieTVUITests.xctest" BlueprintName="BewieTVUITests" ReferencedContainer="container:BewieTV.xcodeproj"/></TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.PosixSpawn" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable><BackgroundAssetPacksFolderResolver identifier="absolute:{root}/build/AssetPacks"/></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>'''
(projectdir/'xcshareddata/xcschemes/BewieTV.xcscheme').write_text(scheme)
plist={'BAAppGroupID':'group.bewie.atelierindustriel.be.music','BAHasManagedAssetPacks':True,'BAUsesAppleHosting':True,'ITSAppUsesNonExemptEncryption':False,'NSHumanReadableCopyright':'© 2026 Benoit Cazenave','NSLocationWhenInUseUsageDescription':'Bewie utilise votre position pour centrer la carte. Sans autorisation, la carte s’ouvre sur Notre-Dame de Paris.','UIRequiredDeviceCapabilities':['arm64'],'UIApplicationSceneManifest':{'UIApplicationSupportsMultipleScenes':False},'UILaunchStoryboardName':'TVLaunchScreen','UIAppFonts':['PTMono-Regular.ttf'],'UIBackgroundModes':['audio'],'CFBundleURLTypes':[{'CFBundleTypeRole':'Viewer','CFBundleURLName':'bewie.atelierindustriel.be','CFBundleURLSchemes':['bewie']}]}
(root/'Configuration/TV-Info.plist').write_bytes(plistlib.dumps(plist))
(root/'Configuration/TV.entitlements').write_bytes(plistlib.dumps({'com.apple.security.application-groups':['group.bewie.atelierindustriel.be.music']}))
print('Generated BewieTV project; shared source references:',len(shared))

# TV distribution requires an explicit hardware capability on the extension.
extplist=plistlib.loads((root/'Configuration/MusicDownloader-Info.plist').read_bytes())
extplist['UIRequiredDeviceCapabilities']=['arm64']
(root/'Configuration/TV-MusicDownloader-Info.plist').write_bytes(plistlib.dumps(extplist))
