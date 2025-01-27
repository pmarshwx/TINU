//
//  InstallerAppManager.swift
//  TINU
//
//  Created by Pietro Caruso on 10/06/18.
//  Copyright © 2018 Pietro Caruso. All rights reserved.
//

import Cocoa

extension CreationProcess{
	public /*final*/ class InstallerAppManager: CreationProcessSection, CreationProcessFSObject{
		
		//static let shared = InstallerAppManager()
		
		let ref: CreationProcess
		public let info: InfoPlist
		
		required init(reference: CreationProcess) {
			ref = reference
			info = InfoPlist(reference: reference)
		}
		
		public var neededFiles: [[String]]{
			//the first element of the first of this array of arrays should always be executable to look for
			//TODO: Maybe check for the base system, this search might be more difficoult
			return ([ ["/Contents/Resources/" + ref.executableName],["/Contents/Info.plist"],["/Contents/SharedSupport"], ["/Contents/SharedSupport/InstallESD.dmg", "/Contents/SharedSupport/SharedSupport.dmg"]])
		}
		
		public var current: InstallerAppInfo!{
			didSet{
				info.resetCache()
				ref.options.check()
			}
		}
		
		public var path: String!{
			return current?.url?.path
		}
		
		public func validate(at _app: URL?) -> InstallerAppInfo?{
			
			var ret = InstallerAppInfo(status: .usable, size: 0, url: nil)
			
			guard var app = _app else { return nil }
			if ref.disk.current == nil { return nil }
			
			print("Validating app at: \(app.path)")
			
			let manager = FileManager.default
			
			var tmpURL: URL?
			if let isAlias = FileAliasManager.process(app, resolvedURL: &tmpURL){
				if isAlias{
					app = tmpURL!
				}
			}else{
				print("  The finder alias for \"\(app.path)\" is broken, invalid app path")
				ret.status = .badAlias
				return ret
			}
			
			ret.url = app
			
			let needed = neededFiles
			var check: Int = needed.count
			var isCurrentExecutable = false
			for c in needed{
				if c.isEmpty{
					check-=1
					continue
				}
				
				var breaked = false
				for d in c{
					if manager.fileExists(atPath: app.path + d){
						check-=1
						breaked.toggle()
						break
					}
				}
				
				if !breaked{
					print(" The app is not valid because it lacks one of those required files/folders: ")
					for d in c{
						print("    \(d)")
						if d.contains(ref.executableName){
							isCurrentExecutable.toggle()
							break
						}
					}
					break
				}
			}
			
			if isCurrentExecutable{
				ret.status = .notInstaller
				return ret
			}
			
			if check != 0 {
				ret.status = .broken
				return ret
			}
			
			guard let sz = manager.directorySize(app) else {
				print("  Can't get the size of the installer app at: \(app.path)")
				return nil
			}
			
			ret.size = UInt64(sz)
			
			if !ref.disk.compareSize(to: UInt64(sz)){
				print(" The app is not valid because it's too big to fit on the target drive")
				ret.status = .tooBig
				return ret
			}
			
			if !self.isBigEnought(appSize: UInt64(sz)){
				print(" The app is not valid because it's too small to be a proper installer app")
				ret.status = .tooLittle
				return ret
			}
			
			print("The app seems to be valid")
			return ret
		}
		
		public func isBigEnought(appSize: UInt64) -> Bool{
			return appSize > 5 * UInt64(pow(10.0, 9.0))
		}
		
		public func listApps() -> [InstallerAppInfo]{
			
			print("Starting Installer App scanning")
			
			let fm = FileManager.default
			
			var foldersURLS = [URL?]()
			
			//TINU looks for installer apps in those folders: /Applications ~/Desktop /~Downloads ~/Documents
			
			if !Recovery.isActuallyOn{
				foldersURLS = [URL(fileURLWithPath: "/Applications"), fm.urls(for: .applicationDirectory, in: .systemDomainMask).first, fm.urls(for: .desktopDirectory, in: .userDomainMask).first, fm.urls(for: .downloadsDirectory, in: .userDomainMask).first, fm.urls(for: .documentDirectory, in: .userDomainMask).first, fm.urls(for: .allApplicationsDirectory, in: .systemDomainMask).first, fm.urls(for: .allApplicationsDirectory, in: .userDomainMask).first]
			}
			
			//print(foldersURLS)
			
			let driveb = dm.getMountPointFromPartitionBSDID(ref.disk.bSDDrive)
			
			for d in fm.mountedVolumeURLs(includingResourceValuesForKeys: [URLResourceKey.isVolumeKey], options: [.skipHiddenVolumes])!{
				let p = d.path
				
				if p == driveb{//} || sharedIsOnRecovery{
					continue
				}
				
				foldersURLS.append(d)
				
				var isDir : ObjCBool = false
				
				if fm.fileExists(atPath: p + "/Applications", isDirectory: &isDir){
					if isDir.boolValue && p != "/"{
						foldersURLS.append(URL(fileURLWithPath: p + "/Applications"))
					}
				}
				
				isDir = false
				
				if fm.fileExists(atPath: p + "/System/Applications", isDirectory: &isDir){
					if isDir.boolValue && p != "/"{
						foldersURLS.append(URL(fileURLWithPath: p + "/System/Applications"))
					}
				}
				
			}
			
			//print("This app will look for installer apps in: ")
			
			for pathURL in foldersURLS{
				
				guard let p = pathURL else { continue }
				
				//print("    " + p.path)
					
				do{
						
					for content in (try fm.contentsOfDirectory(at: p, includingPropertiesForKeys: nil, options: []).filter{ fm.directoryExistsAtPath($0.path) }){
						print("    " + content.path)
						foldersURLS.append(content)
					}
						
				} catch let err{
					print("Error while trying to retrive subfolders of: " + p.path + "\n" + err.localizedDescription)
				}
				
			}
			
			var ret = [InstallerAppInfo]()
			
			for dir in foldersURLS{
				
				guard let d = dir else { continue }
				
				if !fm.fileExists(atPath: d.path){
					continue
				}
				
				if d.pathExtension == "app"{
					continue
				}
				
				print("Scanning for usable apps in \(d.path)")
				//let fileNames = try manager.contentsOfDirectory(at: d, includingPropertiesForKeys: nil, options: []).filter{ $0.pathExtension == "app" }.map{ $0.path }
				
				do {
					appfor: for appURL in (try fm.contentsOfDirectory(at: d, includingPropertiesForKeys: nil, options: []).filter{ $0.pathExtension == "app" }) {
						
						if let dsk = ref.disk?.path{
							if !dsk.isEmpty{
								if appURL.path.starts(with: (dsk)){
									print("    Skipping \(appURL.path) because it belongs to the chosen drive")
									continue
								}
							}
						}
						
						guard let capp = self.validate(at: appURL) else {
							print("    Skipping \(appURL.path) because it can't be validated")
							continue
						}
						
						if capp.url == nil{
							print("    Skipping \(appURL.path) because it doesn't have a path setted")
							continue
						}
						
						var found = false
						for a in ret{
							if a.url == capp.url{
								found.toggle()
								break
							}
						}
						
						if found{
							print("    Skipping \(appURL.path) because it is a duplicate")
							continue
						}
						
						switch capp.status {
						case .usable, .broken, .tooBig, .tooLittle:
							print("    \(appURL.path) has been added to the apps list")
							ret.append(capp)
							break
						default:
							print("    Skipping \(appURL.path) because it is not an installer app or has errors")
							continue
						}
						
					}
				} catch let error as NSError {
					print("  Can't get contents of \(d.path)")
					print(error.localizedDescription)
				}
			}
			
			print(ret)
			
			return ret
		}
		
		
		public class InfoPlist: CreationProcessSection{
			
			let ref: CreationProcess
			
			required init(reference: CreationProcess) {
				ref = reference
			}
			
			private var cache: [String: Any]!
			private var internalBundleName: String!
			private var internalBundleVersion: String!
			
			deinit {
				cache = nil
				internalBundleName = nil
				internalBundleVersion = nil
			}
			
			//this variable tells to the app which is the bundle name of the selcted installer app
			public var bundleName: String!{
				if cache == nil{
					return nil
				}
				
				if (internalBundleName ?? "").isEmpty {
					guard let n = item(itemKey: "CFBundleDisplayName") else {return nil}
					internalBundleName = n
					return n
				}else{
					return internalBundleName
				}
			}
			
			//this is used for the app version
			public var bundleVersion: String!{
				if cache == nil{
					return nil
				}
				
				if (internalBundleVersion ?? "").isEmpty {
					guard let n = item(itemKey: "DTSDKBuild") else {return nil}
					internalBundleVersion = n
					return n
				}else{
					return internalBundleVersion
				}
			}
			
			public func resetCache(){
				cache = nil
				internalBundleName = nil
				internalBundleVersion = nil
				
				guard let sa = ref.app?.path else{
					print("can't get the target app bundle info because the user has not choosen any installer app")
					return
				}
				
				if !FileManager.default.fileExists(atPath: sa + "/Contents/Info.plist") {
					print("cant' find the needded file to get the bundle info for the selected installer app")
					return
				}
				
				do{
					let result = try DecodeManager.decodePlistDictionary(xml: try String.init(contentsOfFile: sa + "/Contents/Info.plist")) as? [String: Any]
					
					if let r = result{
						
						cache = r
						
						return
					}else{
						print("App bundle info not found or nil")
						return
					}
				}catch let error{
					print("error while getting the bundle info of the target app: \(error)")
					return
				}
				
			}
			
			//gets something from the Info.plist file lof the installer app
			public func item(itemKey: String) -> String!{
				if cache == nil{
					return nil
				}
				
				let result: String! = cache![itemKey] as? String
				
				if let r = result{
					
					if r.contains("\n") || r.isEmpty {
						print("Can't get app bundle \"\(itemKey)\" because it contains an illegal character or is empty")
						return nil
					}
					
					print("App bundle \"\(itemKey)\" got with success: \(r)")
					return result
					
				}else{
					
					print("App bundle \"\(itemKey)\" not found or nil")
					return nil
					
				}
			}
			
			//returns the version number of the mac os installer app, returns nil if it was not found, returns an epty string if it's an unrecognized version
			public func versionString() -> String!{
				print("Detecting app version")
				if bundleVersion != nil{
					var subVer = String(bundleVersion!.prefix(3))
					
					subVer.removeFirst()
					subVer.removeFirst()
					
					let hexString = UInt8(subVer, radix: 36)! - 10
					
					let ret = String(UInt(String(bundleVersion!.prefix(2)))! - 4) + "." + String(hexString)
					
					print("Detected app version (using the build number): \(ret)")
					return ret
				}
				
				if bundleName == nil{
					return nil
				}
				
				//fallback method, really not used a lot and not that precise, but it's tested to work
				
				let checkList: [UInt: ([String], [String])] = [17: (["12", "Monterey"], ["10.12"]), 16: (["big sur", "10.16", "11."], []), 15: (["catalina", "10.15"], []), 14: (["mojave", "10.14"], []), 13: (["high sierra", "high", "10.13"], []), 12: (["sierra", "10.12"], ["high"]), 11: (["el capitan", "el", "capitan", "10.11"], []), 10: (["yosemite", "10.10"], []), 9: (["mavericks", "10.9"], [])]
				
				let lc = bundleName!.lowercased()
				
				check: for item in checkList{
					for s in item.value.0{
						if lc.contains(s){
							var correct: Bool = true
							
							for t in item.value.1{
								if lc.contains(t){
									correct = false
									break
								}
							}
							
							if correct{
								print("Detected app version (using the bundle name): \(item.key)")
								return String(item.key)
							}else{
								continue check
							}
						}
					}
				}
				
				return ""
			}
			
			public func versionNumber() -> Float!{
				guard let v: String = versionString() else {return nil}
				
				if v.isEmpty{ return nil }
				
				print("detected version: \(v)")
				
				return Float(v)
			}
			
			//returns if the version of the installer app is the spcified version or a newer one
			public func supports(version: Float) -> Bool!{
				guard let ver: Float = versionNumber() else { return nil }
				return ver >= version
			}
			
			//returns if the installer app version is earlyer than the specified one
			public func goesUpTo(version: Float) -> Bool!{
				guard let ver: Float = versionNumber() else { return nil }
				return ver < version
			}
			
			//checks if the selected macOS installer application version has apfs support
			@inline(__always) public func notSupportsAPFS() -> Bool!{
				print("Checking if the installer app supports APFS")
				return goesUpTo(version: 13)
			}
			
			//checks if the installer app is a macOS mojave app
			@inline(__always) public func isNotMojave() -> Bool!{
				print("Checking if the installer app is MacOS Mojave")
				return goesUpTo(version: 14)
			}
			
			//checks if the selected mac os installer application does support using tinu from the recovery
			@inline(__always) public func notSupportsTINU() -> Bool!{
				print("Checking if the isntaller app supports TINU on recovery")
				return goesUpTo(version: 11)
			}
			
			#if !macOnlyMode
			@inline(__always) public func supportsIAEdit() -> Bool!{
				print("Checking if the installer app supports the creation of .IABootFiles folder")
				return !goesUpTo(version: 13.4) && goesUpTo(version: 14.0)
			}
			#endif
			
		}
		
	}
	
}

//typealias iam = InstallerAppManager
