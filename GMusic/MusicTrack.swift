//
//  MusicTrack.swift
//  GMusic
//
//  Created by Григорий Сухотин on 26.05.2021.
//

import Foundation

struct MusicTrack: Encodable, Equatable{
    var provider: String
    var name: String
    var artist: String
    var duration: Int
    var url: String
    var imageUrl: String?
    var localUrl: String?
    func dict() -> NSDictionary{
        return ["provider": provider, "name": name, "artist": artist, "duration": duration, "url": url, "imageUrl": imageUrl, "localUrl": localUrl]
    }
    init(dict: NSDictionary){
        self.provider = dict["provider"] as! String
        self.name = dict["name"] as! String
        self.artist = dict["artist"] as! String
        self.duration = dict["duration"] as! Int
        self.url = dict["url"] as! String
        self.imageUrl = dict["imageUrl"] as? String
        self.localUrl = dict["localUrl"] as? String
    }
    init(provider: String, name: String, artist: String, duration: Int, url: String, imageUrl: String){
        self.provider = provider
        self.name = name
        self.artist = artist
        self.duration = duration
        self.url = url
        self.imageUrl = imageUrl
    }
}
