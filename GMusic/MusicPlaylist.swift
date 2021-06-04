//
//  MusicPlaylist.swift
//  GMusic
//
//  Created by Григорий Сухотин on 26.05.2021.
//

import Foundation

struct MusicPlaylist: Encodable {
    var name: String
    var provider: String
    var artist: String
    var imageUrl: String?
    var tracksUrl: String?
    var tracks: [MusicTrack]
    func dict() -> NSDictionary {
        return ["name": name, "provider": provider, "artist": artist, "imageUrl": imageUrl, "tracksUrl": tracksUrl, "tracks": tracks]
    }
    
    init(dict: NSDictionary) {
        self.name = dict["name"] as! String
        self.provider = dict["provider"] as! String
        self.artist = dict["artist"] as! String
        self.imageUrl = dict["imageUrl"] as! String
        self.tracksUrl = dict["tracksUrl"] as? String
        self.tracks = []
    }
    init(name: String, provider: String, artist: String, imageUrl: String, tracksUrl: String?, tracks: [MusicTrack]){
        self.name = name
        self.provider = provider
        self.artist = artist
        self.imageUrl = imageUrl
        self.tracksUrl = tracksUrl
        self.tracks = tracks
    }
}
