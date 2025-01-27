//
//  DrivesManager.swift
//  TINU
//
//  Created by Pietro Caruso on 10/06/18.
//  Copyright © 2018 Pietro Caruso. All rights reserved.
//

import Foundation

public final class DrivesManager{
	
	static let shared = DrivesManager()
	
	private static var _id: String = ""
	private static var _out: String! = ""
	
	class func getPropertyInfoAny(_ id: String, propertyName: String) -> Any!{
		do{
			if id.isEmpty{
				return nil
			}
			
			//probably another check is needed to avoid having different devices plugged one after the other and all having the same id being used with the info from one
			if _id != id || _out == nil{
				_id = id
				_out = Command.getOut(cmd: "diskutil info -plist \"" + id + "\"")
				
				if _out.isEmpty{
					return nil
				}
				
			}
			
			if let dict = try DecodeManager.decodePlistDictionary(xml: _out) as? [String: Any]{
				return dict[propertyName]
			}
			
		}catch let err{
			print("Getting diskutil info property decoding error: \(err.localizedDescription)")
		}
		
		return nil
	}
	
	class func getPropertyInfoString(_ id: String, propertyName: String) -> String!{
		guard let pitm = getPropertyInfoAny(id, propertyName: propertyName) else{ return nil }
					
		let itm = "\(pitm)"
					
		if !itm.isEmpty{
			return itm
		}
		
		return nil
	}
	
	class func getPropertyInfoBool(_ id: String, propertyName: String) -> Bool!{
		return getPropertyInfoAny(id, propertyName: propertyName) as? Bool
	}
	
	class func getMountPointFromPartitionBSDID(_ id: String) -> String!{
		return  getPropertyInfoString(id, propertyName: "MountPoint")
	}
	
	//return the display name of drive from it's bsd id, used in different screens, called potentially many times during the app execution
	class func getDeviceBSDIDFromMountPoint(_ mountPoint: String) -> String!{
		return getPropertyInfoString(mountPoint, propertyName: "DeviceNode")
	}
	
	//gets the drive mount point from it's bsd name
	class func getBSDIDFromDriveName(_ path: String) -> String!{
		let res = Command.getOut(cmd: "df -lH | grep \"" + path + "\" | awk '{print $1}'")
		
		if res.isEmpty{
			return nil
		}
		
		return res
	}
	
	class func getDriveName(from deviceid: String) -> String!{
		var property = "MediaName"
		
		if #available(OSX 10.12, *){
			property = "IORegistryEntryName"
		}
	
		var name = getPropertyInfoString(deviceid, propertyName: property)
		
		if name != nil{
		
			if #available(OSX 10.12, *){
				name = name!.deletingSuffix(" Media")
			}
		
			name = name!.isEmpty ? "Untitled drive" : name
		
			print("------------Drive name: \(name!)")
		}else{
			print("------------Can't get the drive name for this drive")
		}
		
		return name
	}
	
	//gets the drive device name from it's device name
	class func getDeviceNameFromVolumeBSDID(_ id: String) -> String!{
		return getDriveName(from: getDriveBSDIDFromVolumeBSDID(volumeID: id))
	}
	
	//checks if the drive exists if it can find it's mount point
	class func driveIsMounted(id: String) -> Bool{
		return getMountPointFromPartitionBSDID(id) != nil
	}
	
	//checks if the drive exists if it can find it's bsd id from it's mount point
	class func driveHasID(path: String) -> Bool{
		return getBSDIDFromDriveName(path) != nil
	}
	
	//return the drive sbd id of a volume
	class func getDriveBSDIDFromVolumeBSDID(volumeID: String) -> String{
		var tmpBSDName = ""
		var ns = 0
		
		for cc in volumeID{
			let c = String(cc)
			if c.lowercased() == "s"{
				ns += 1
			}
			if ns == 1{
				if let _ = Int(c){
					tmpBSDName += c
				}
			}
		}
		
		return "disk" + tmpBSDName
	}
	
	class func hasDriveBSDID(volumeID: String) -> Bool{
		return getDriveBSDIDFromVolumeBSDID(volumeID: volumeID) == volumeID
	}
	
	class func getDriveIsRemovable(_ id: String) -> Bool!{
		var property = "Ejectable"
		
		if #available(OSX 10.12, *){
			property = "RemovableMediaOrExternalDevice"
		}
		
		return dm.getPropertyInfoBool(id, propertyName: property)
	}
	
}

typealias dm = DrivesManager
