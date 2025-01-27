//
//  EFIFolderReplacementManager.swift
//  TINU
//
//  Created by Pietro Caruso on 26/05/18.
//  Copyright © 2018 Pietro Caruso. All rights reserved.
//

import Foundation


#if useEFIReplacement && !macOnlyMode
	
	public final class EFIFolderReplacementManager{
		
		static var shared: EFIFolderReplacementManager! { return sharedi }
		static var sharedi: EFIFolderReplacementManager! = nil
		
		private var sharedEFIFolderTempData: [String : Data?]! = nil
		private var firstDir = ""
		private let refData = Data.init()
		
		private var cProgress: Double!
		private var oDirectory: String!
		private var missingFile: String!
		
		public var openedDirectory: String!{
			return oDirectory
		}
		
		public var copyProcessProgress: Double!{
			return cProgress
		}
		
		public var filesCount: Double!{
			return Double(sharedEFIFolderTempData.count)
		}
		
		public var missingFileFromOpenedFolder: String!{
			return missingFile
		}
		
		public var currentEFIFolderType: SupportedEFIFolders{
			return bootloader
		}
		
		private var bootloader: SupportedEFIFolders = .clover
		
		private var contentToCheck: [[String]]{
			switch bootloader {
				case .clover:
					return [["/BOOT/BOOTX64.efi"], ["/CLOVER/CLOVERX64.efi"], ["/CLOVER/config.plist"], ["/CLOVER/kexts"], ["/CLOVER/kexts/Other"], ["/CLOVER/drivers64UEFI", "/CLOVER/drivers/UEFI", "/CLOVER/drivers/BIOS", "/CLOVER/drivers64"]]
				case .openCore:
					return [["/BOOT/BOOTX64.efi"], ["/OC/OpenCore.efi"], ["/OC/config.plist"], ["/OC/Kexts"], ["/OC/Tools"], ["/OC/Drivers"], ["/OC/ACPI"]]
			}
		}
		
		public func saveEFIFolder(_ toPath: String) -> Bool{
			guard let c = checkSavedEFIFolder() else {
				log("No EFI Folder saved, impossible to proceed")
				return false
			}
			
			if !c {
				log("Saved EFI Folderis invalid, impossible to proceed")
				return false
			}
			
			let fm = FileManager.default
			
			let unit = 1 / filesCount
			
			cProgress = 0
			
			var res = true
			
			let cp = URL(fileURLWithPath: toPath, isDirectory: true)
			
			do{
				if fm.fileExists(atPath: toPath){
					try fm.removeItem(at: cp)
				}
			}catch let err{
				print("        EFI Folder delete error (\(toPath))\n                \(err.localizedDescription)")
				res = false
				
				cProgress = nil
				return false
			}
			
			for f in sharedEFIFolderTempData{
				
				let file = URL(fileURLWithPath: cp.path + f.key)
				
				let parent = file.deletingLastPathComponent()
				
				print("        Replacing EFI Folder file: \(file.path)")
				
				do{
					if !fm.fileExists(atPath: parent.path){
						try fm.createDirectory(at: parent, withIntermediateDirectories: true)
						print("      Creating EFI Folder subdirectory: \(parent.path)")
					}
				}catch let err{
					log("        EFI Folder subfolder error (\(parent.path))\n                \(err.localizedDescription)")
					res = false
					continue
				}
				
				do{
					
					if f.value != refData{
						
						try f.value!.write(to: file)
						
					}else{
						
						do{
							if !fm.fileExists(atPath: file.path) {
								try fm.createDirectory(at: file, withIntermediateDirectories: true)
								print("      Creating EFI Folder subdirectory: \(parent.path)")
							}
							
						}catch let err{
							print("        EFI Folder subfolder creation error (\(parent.path))\n                \(err.localizedDescription)")
							res = false
							continue
						}
						
					}
					
				}catch let err{
					print("        EFI Folder file error (\(file.path))\n                \(err.localizedDescription)")
					res = false
					continue
				}
				
				cProgress! += unit
				
			}
			
			cProgress = nil
			return res
		}
		
		public func unloadEFIFolder(){
		
			if sharedEFIFolderTempData == nil{
				return
			}
			
			for i in sharedEFIFolderTempData.keys{
				//in some instances
				if sharedEFIFolderTempData == nil{
					break
				}
				
				print("Removing value from the saved EFI folder: \(i)")
				sharedEFIFolderTempData[i] = nil
				sharedEFIFolderTempData.removeValue(forKey: i)
			}
			
			sharedEFIFolderTempData.removeAll()
			sharedEFIFolderTempData = nil
			
			print("Saved EFI folder cleaned and reset")
			
			oDirectory = nil
		}
		
		public func loadEFIFolder(_ fromPath: String, currentBootloader: SupportedEFIFolders) -> Bool!{
			Swift.print("Try to read EFI folder: \(fromPath)")
			
			bootloader = currentBootloader
			
			unloadEFIFolder()
			
			for c in contentToCheck{
				var check: Bool = false
				let fm = FileManager.default
				
				for i in c{
					check = check || fm.fileExists(atPath: fromPath + i)
					missingFile = i
				}
				
				if !check{
					log("EFI Folder does not contain this needed element: \(missingFile!)")
					return nil
				}
			}
			
			missingFile = nil
			
			sharedEFIFolderTempData = [:]
			
			firstDir = fromPath
			
			if scanDir(fromPath){
				if let check = checkSavedEFIFolder(){
					if !check{
						unloadEFIFolder()
						return nil
					}
				}else{
					unloadEFIFolder()
					return false
				}
			}else{
				unloadEFIFolder()
				return false
			}
			
			oDirectory = fromPath
			
			Swift.print("EFI folder readed with success")
			
			//print(sharedEFIFolderTempData)
			
			return true
		}
		
		private func scanDir(_ dir: String) -> Bool{
			Swift.print("Scanning EFI Folder's Directory: \n    \(dir)")
			var r = true
			let fm = FileManager.default
			
			do{
				let cont = try fm.contentsOfDirectory(atPath: dir)
				
				for d in cont{
					let file =  (dir + "/" + d)
					
					var id: ObjCBool = false;
					
					if !fm.fileExists(atPath: file, isDirectory: &id){ continue }
					
					var name = "/"
					
					if file != firstDir{
						//name = file.substring(from: firstDir.endIndex)
						name = String(file[firstDir.endIndex...])
					}
					
					Swift.print("        Item name: \(name)")
					
					let url = URL(fileURLWithPath: name, isDirectory: false)
					
					if id.boolValue{
						
						if url.deletingLastPathComponent().path == firstDir{
							if url.lastPathComponent != "BOOT" && url.lastPathComponent != "CLOVER" && url.lastPathComponent != "OC"{
								continue
							}
						}
						
						r = scanDir(file)
						
						sharedEFIFolderTempData[name] = refData
						
						Swift.print("Finished scanning EFI Folder's Directory on: \n    \(file)")
						
					}else{
						
						if url.lastPathComponent == ".DS_Store"{
							continue
						}
						
						Swift.print("        File ID: " + name)
						
						sharedEFIFolderTempData[name] = try Data.init(contentsOf: URL(fileURLWithPath: file))
					}
					
				}
				
				
			}catch let error{
				Swift.print("Open efi fodler error: \(error.localizedDescription)")
				r = false
			}
			
			return r
		}
		
		public func checkSavedEFIFolder() -> Bool!{
			print("Checking saved EFI folder")
			
			if sharedEFIFolderTempData == nil{
				print("No EFI folder saved")
				return nil
			}
			
			if sharedEFIFolderTempData.isEmpty{
				print("Saved EFI folder is empty")
				return false
			}
			
			var res = true
			
			for c in contentToCheck{
				for i in c{
					res = res || sharedEFIFolderTempData[i] == nil
					missingFile = i
				}
				
				if !res{
					res = false
					print("        Needed file missing from the saved EFI folder: " + missingFile)
				}
				
			}
			
			if res{
				print("Saved EFI folder checked and seems to be a proper EFI folder for the selected type")
				missingFile = nil
			}else{
				print("Saved EFI folder checked and does not seems to be a proper EFI folder for the selected type")
			}
			
			return res
		}
		
		public func resetMissingFileFromOpenedFolder(){
			missingFile = nil
		}
		
		class func reset(){
			if sharedi != nil{
				sharedi.unloadEFIFolder()
			}
			sharedi = nil
			sharedi = EFIFolderReplacementManager()
		}
		
	}


#endif
