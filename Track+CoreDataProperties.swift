//
//  Track+CoreDataProperties.swift
//  
//
//  Created by Григорий Сухотин on 27.05.2021.
//
//

import Foundation
import CoreData


extension Track {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Track> {
        return NSFetchRequest<Track>(entityName: "Track")
    }
    @NSManaged public var id: Int32
    @NSManaged public var artist: String?
    @NSManaged public var duration: Int32
    @NSManaged public var localUrl: String?
    @NSManaged public var name: String?
    @NSManaged public var provider: String?
    @NSManaged public var url: String?

}
