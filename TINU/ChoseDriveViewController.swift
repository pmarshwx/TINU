//
//  ChoseDriveViewController.swift
//  TINU
//
//  Created by Pietro Caruso on 24/08/17.
//  Copyright © 2017 Pietro Caruso. All rights reserved.
//

import Cocoa

class ChoseDriveViewController: ShadowViewController, ViewID {
	let id: String = "ChoseDriveViewController"
	
    @IBOutlet weak var scoller: NSScrollView!
    @IBOutlet weak var ok: NSButton!
    @IBOutlet weak var spinner: NSProgressIndicator!
	
	private var itemOriginY: CGFloat = 0
	
	private let spacerID = "spacer"
	
    private var empty: Bool = false{
        didSet{
            if self.empty{
                scoller.drawsBackground = false
                scoller.borderType = .noBorder
                ok.title = TextManager.getViewString(context: self, stringID: "nextButtonFail")
                ok.isEnabled = true
            }else{
                //viewDidSetVibrantLook()
				
				if let document = scoller.documentView{
					if document.identifier?.rawValue == spacerID{
						document.frame = NSRect(x: 0, y: 0, width: self.scoller.frame.width - 2, height: self.scoller.frame.height - 2)
						if let content = document.subviews.first{
							content.frame.origin = NSPoint(x: document.frame.width / 2 - content.frame.width / 2, y: 0)
						}
						self.scoller.documentView = document
					}
				}
				
                ok.title = TextManager.getViewString(context: self, stringID: "nextButton")
                ok.isEnabled = false
				
				if look.supportsShadows() || look.usesSFSymbols() {
					scoller.drawsBackground = false
					scoller.borderType = .noBorder
				}else{
					scoller.drawsBackground = true
					scoller.borderType = .bezelBorder
				}
            }
        }
    }
    
    @IBAction func refresh(_ sender: Any) {
        updateDrives()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
		//"Choose the Drive or the Partition to turn into a macOS Installer"
		self.setTitleLabel(text: TextManager.getViewString(context: self, stringID: "title"))
		self.showTitleLabel()
		
		ok.title = TextManager.getViewString(context: self, stringID: "nextButton")
		
		if look.supportsShadows() || look.usesSFSymbols(){
			scoller.frame = CGRect.init(x: 0, y: scoller.frame.origin.y, width: self.view.frame.width, height: scoller.frame.height)
			scoller.drawsBackground = false
			scoller.borderType = .noBorder
			
		}else{
			scoller.frame = CGRect.init(x: 20, y: scoller.frame.origin.y, width: self.view.frame.width - 40, height: scoller.frame.height)
			scoller.drawsBackground = true
			scoller.borderType = .bezelBorder
		}
		
		/*
        if sharedInstallMac{
            titleLabel.stringValue = "Choose a drive or a partition to install macOS on"
        }*/
        
        updateDrives()
    }
	
	func makeAndDisplayItem(_ item: DiskutilObject!, _ to: inout [DriveView], _ origin: DiskutilObject! = nil, _ isGUIDwEFI: Bool = true){
		guard let d: DiskutilObject = ((origin == nil) ? item : origin) else{
			print("[UI creation] Invalid disk item!")
			return
		}
		
		let man = FileManager.default
		
		DispatchQueue.main.sync {
			
			let drivei = DriveView(frame: NSRect(x: 0, y: itemOriginY, width: DriveView.itemSize.width, height: DriveView.itemSize.height))
			let prt = Part(bsdName: d.DeviceIdentifier, fileSystem: .other, partScheme: isGUIDwEFI ? .gUID : .blank, hasEFI: isGUIDwEFI, size: d.Size, isDrive: (origin != nil) || !isGUIDwEFI, path: d.MountPoint)
			
			if isGUIDwEFI{
				//prt.name = man.displayName(atPath: d.MountPoint ?? "")
				//prt = Part(partitionBSDName: d.DeviceIdentifier, partitionName: drivei.appName, partitionPath: d.MountPoint!, partitionFileSystem: Part.FileSystem.other, partitionScheme: Part.PartScheme.gUID , partitionHasEFI: true, partitionSize: d.Size)
				prt.tmDisk = man.fileExists(atPath: d.MountPoint! + "/tmbootpicker.efi") || man.directoryExistsAtPath(d.MountPoint! + "/Backups.backupdb")
			}else{
				//prt.name = dm.getDriveName(from: d.DeviceIdentifier) ?? d.DeviceIdentifier
				//prt = Part(partitionBSDName: d.DeviceIdentifier, partitionName: drivei.appName, partitionPath: (item?.MountPoint == nil) ? "" : item.MountPoint!, partitionFileSystem: .other, partitionScheme: .blank, partitionHasEFI: false, partitionSize: d.Size)
				prt.apfsBDSName = d.DeviceIdentifier
			}
			
			log("        Item type: \(prt.isDrive ? "Drive" : "Partition")")
			log("        Item display name is: \(prt.displayName)")
			
			drivei.current = prt as UIRepresentable
			to.append(drivei)
			
		}
	}
    
    private func updateDrives(){
		
		print("--- Detectin usable drives and volumes")
		
        self.scoller.isHidden = true
        self.spinner.isHidden = false
        self.spinner.startAnimation(self)
		
		scoller.documentView = NSView()
		
		print("Preparation for detection started")
        
        ok.isEnabled = false
        
        self.hideFailureImage()
		self.hideFailureLabel()
		self.hideFailureButtons()
		
		//let man = FileManager.default
		
		cvm.shared.disk = cvm.DiskInfo(reference: cvm.shared.disk.ref)
        
        var drives = [DriveView]()
        
        self.ok.isEnabled = false
		
		itemOriginY = ((self.scoller.frame.height - 17) / 2) - (DriveView.itemSize.height / 2)
		
		print("Preparation for detection finished")
		
        //this code just does interpretation of the diskutil list -plist command
        DispatchQueue.global(qos: .background).async {
			
			print("Actual detection thread started")
            
            //just need to know which is the boot volume, to not allow the user to choose it
			let boot = dm.getDeviceBSDIDFromMountPoint("/")!
			var boot_drive = [dm.getDriveBSDIDFromVolumeBSDID(volumeID: boot)]
			let execp = Bundle.main.executablePath!
			
			print("Boot volume BSDID: \(boot)")
			
			//new Codable-Based storage devices search
			if let data = DiskutilManagement.DiskutilList.readFromTerminal(){
				log("Analyzing diskutil data to detect usable storage devices")
				
				for d in data.AllDisksAndPartitions{
					if d.DeviceIdentifier != boot_drive.first!{
						continue
					}
					
					guard let stores = d.APFSPhysicalStores else { continue }
					
					for s in stores {
						boot_drive.append(dm.getDriveBSDIDFromVolumeBSDID(volumeID: s.DeviceIdentifier))
					}
				}
				
				print("The boot drive devices are: ")
				print(boot_drive)
				
				alldiskFor: for d in data.AllDisksAndPartitions{
					log("    Drive: \(d.DeviceIdentifier)")
					
					if boot_drive.contains(d.DeviceIdentifier){
						log("        Skipping this drive, it's the boot drive or in the boot drive")
						continue
					}
					
					if d.hasEFIPartition(){ // <=> has and efi partition and has some sort of GPT or GUID partition table
						log("        Drive has EFI partition and is GUID")
						log("        All the partitions of the drive will be scanned in order to detect the usable partitions")
						for p in d.Partitions!{
							log("        Partition/Volume: \(p.DeviceIdentifier)")
							let t = p.getUsableType()
							
							log("            Partition/Volume content: \( t == DiskutilManagement.PartitionContentStrings.unusable ? "Other file system" : t.rawValue )")
							
							if t == .aPFSContainer || t == .coreStorageContainer{
								log("            Partition is a container disk")
								continue
							}
							
							if !cvm.shared.disk.meetsRequirements(size: p.Size){
								log("            Partition is not big enought to be used as a mac os installer or to house a macOS installation")
								continue
							}
							
							if !p.isMounted(){
								log("            Partition is not mounted, it needs to be mounted in order to be detected and usable with what we need to do later on")
								continue
							}
							
							if execp.contains(p.MountPoint!) {
								log("            TINU is running from this partition, skipping to the next drive")
								continue alldiskFor
							}
							
							log("            Partition meets all the requirements, it will be added to the dectected partitions list")
							
							self.makeAndDisplayItem(p, &drives)
							
							log("            Partition added to the list")
						}
					}else{
						log("        Drive is not GPT/GUID or doesn't seem to have an EFI partition, it will be detected only as a drive instead of showing the partitions as well")
					}
					
					if !cvm.shared.disk.meetsRequirements(size: d.Size){
						log("        Drive is not big enought for our purposes")
						continue
					}
					
					var ref: DiskutilObject!
					
					if d.isVolume(){
						if d.isMounted(){
							ref = d
						}
					}else{
						
						for p in d.Partitions!{
							if p.isMounted(){
								ref = p
								break
							}
						}
						
					}
					
					#if noUnmounted
					if ref == nil{
						log("        Drive has no mounted partitions, those are needed in order to detect a drive")
						continue
					}
					#endif
					
					log("        Drive seems to meet all the requirements for our purposes, it will be added to the list")
					
					self.makeAndDisplayItem(ref, &drives, d, false)
					
					log("        Drive added to list")
					
					
				}
			}
			
			DispatchQueue.main.sync {
				
				self.scoller.hasVerticalScroller = false
				
				var res = (drives.count == 0)
				
				//this is just to test if there are no usable drives
				if simulateNoUsableDrives {
					res = true
				}
				
				self.empty = res
				
				
				let set = res || Recovery.isOn
				self.topView.isHidden = set
				self.bottomView.isHidden = set
				
				self.leftView.isHidden = set
				self.rightView.isHidden = set
				
				if res{
					//fail :(
					self.scoller.isHidden = true
					
					if self.failureLabel == nil || self.failureImageView == nil || self.failureButtons.isEmpty{
						self.defaultFailureImage()
						//TextManager.getViewString(context: self, stringID: "agreeButtonFail")
						
						self.setFailureLabel(text: TextManager.getViewString(context: self, stringID: "failureText"))
						self.addFailureButton(buttonTitle: TextManager.getViewString(context: self, stringID: "failureButton"), target: self, selector: #selector(ChoseDriveViewController.openDetectStorageSuggestions))
						
						/*
						self.setFailureLabel(text: "No usable storage devices detected")
						self.addFailureButton(buttonTitle: "Why is my storage device not detected?", target: self, selector: #selector(ChoseDriveViewController.openDetectStorageSuggestions))
						*/
					}
					
					self.showFailureImage()
					self.showFailureLabel()
					self.showFailureButtons()
				}else{
					let content = NSView(frame: NSRect(x: 0, y: 0, width: 0, height: self.scoller.frame.size.height - 17))
					content.backgroundColor = NSColor.transparent
					
					self.scoller.hasHorizontalScroller = true
					
					var temp: CGFloat = 20
					for d in drives.reversed(){
						d.frame.origin.x = temp
						
						/*if !blockShadow{
							temp += d.frame.width + 15
						}else{
							temp += d.frame.width
						}*/
						
						temp += d.frame.width + (( look != .recovery ) ? 15 : 0)
						
						content.addSubview(d)
					}
					
					/*
					if !blockShadow{
						content.frame.size.width = temp + 5
					}else{
						content.frame.size.width = temp + 20
					}
					*/
					
					content.frame.size.width = temp + ((look != .recovery) ? 5 : 20)
					
					//TODO: this is not ok for resizable windows
					if content.frame.size.width < self.scoller.frame.width{
						let spacer = NSView(frame: NSRect(x: 0, y: 0, width: self.scoller.frame.width - 2, height: self.scoller.frame.height - 2))
						spacer.backgroundColor = NSColor.transparent
						
						spacer.identifier = NSUserInterfaceItemIdentifier(rawValue: self.spacerID)
						
						content.frame.origin = NSPoint(x: spacer.frame.width / 2 - content.frame.width / 2, y: 15 / 2)
						spacer.addSubview(content)
						self.scoller.documentView = spacer
					}else{
						self.scoller.documentView = content
					}
					
					if let documentView = self.scoller.documentView{
						documentView.scroll(NSPoint.init(x: 0, y: documentView.bounds.size.height))
					}
					
					self.scoller.usesPredominantAxisScrolling = true
					
				}
				
				self.scoller.isHidden = false
				self.spinner.isHidden = true
				self.spinner.stopAnimation(self)
				
			}
		}
	}
	
	
	private var tmpWin: GenericViewController!
	@objc func openDetectStorageSuggestions(){
		tmpWin = nil
		tmpWin = UIManager.shared.storyboard.instantiateController(withIdentifier: "DriveDetectionInfoVC") as? GenericViewController
		
		if tmpWin != nil{
			self.presentAsSheet(tmpWin)
		}
	}
	
	@IBAction func goBack(_ sender: Any) {
		if UIManager.shared.showLicense{
			let _ = swapCurrentViewController("License")
		}else{
			let _ = swapCurrentViewController("Info")
		}
		tmpWin = nil
	}
	
	@IBAction func next(_ sender: Any) {
		if !empty{
			
			let parseList = ["{diskName}" : cvm.shared.disk.current.driveName, "{partitionName}" : cvm.shared.disk.current.displayName]
				
			if cvm.shared.disk.warnForTimeMachine{
				if !dialogGenericWithManagerBool(self, name: "formatDialogTimeMachine", parseList: parseList){
					return
				}
			}
			
			if cvm.shared.disk.shouldErase{
				if !dialogGenericWithManagerBool(self, name: "formatDialog", parseList: parseList){
					return
				}
			}
			
			tmpWin = nil
			
			let _ = swapCurrentViewController("ChoseApp")
		}else{
			NSApplication.shared.terminate(sender)
		}
	}
	
	/*
    private func checkDriveSize(_ cc: [ArraySlice<String>], _ isDrive: Bool) -> Bool{
        var c = cc
        
        c.remove(at: c.count - 1)
        
        var sz: UInt64 = 0
        
        if c.count == 1{
            let f: String = (c.last?.last!)!
            var cl = c.last!
            cl.remove(at: cl.index(before: cl.endIndex))
            let ff: String = cl.last!
            
            c.removeAll()
            
            c.append([ff, f])
            
        }
        
        if var n = c.last?.first{
            if isDrive{
                n.remove(at: n.startIndex)
            }else{
                let s = String(describing: n.first)
                if s == "*" || s == "+"{
                    print("         volume size is not fixed, skipping it")
                    return false
                }
            }
            
            if let s = UInt64(n){
                sz = s
            }
        }
		
        if let n = c.last?.last{
			switch n{
			case "KB":
				sz *= get1024Pow(exp: 1)
				break
			case "MB":
				sz *= get1024Pow(exp: 2)
				break
			case "GB":
				sz *= get1024Pow(exp: 3)
				break
			case "TB":
				sz *= get1024Pow(exp: 4)
				break
			case "PB":
				sz *= get1024Pow(exp: 5)
				break
			default:
				if isDrive{
					print("     this drive has an unknown size unit, skipping this drive")
				}else{
					print("         volume size unit unkown, skipping this volume")
				}
				return false
			}
        }
        
        var minSize: UInt64 = 7 * get1024Pow(exp: 3) // 7 gb
        
        if sharedInstallMac{
            minSize = 20 * get1024Pow(exp: 3) // 20 gb
        }
        
        //if we are in a testing situation, size of the drive is not so much important
        if simulateCreateinstallmediaFail != nil{
            minSize = get1024Pow(exp: 3) // 1 gb
        }
        
        if sz <= minSize{
            if isDrive{
                print("     this drive is too small to be used for a macOS installer, skipping this drive")
            }else{
                print("     this volume is too small for a macOS installer")
            }
            return false
        }
        
        return true
    }
	
	private func get1024Pow(exp: Float) -> UInt64{
		return UInt64(pow(1024.0, exp))
	}*/
    
}
