//
//  SongSearchViewController.swift
//  GMusic
//
//  Created by Григорий Сухотин on 30.04.2021.
//

import UIKit
import Alamofire
import FirebaseAuth
import FirebaseDatabase
import AVKit
import MediaPlayer
import Network
import FBSDKLoginKit

class SongSearchViewController: UIViewController, SPTAppRemoteDelegate, SPTAppRemotePlayerStateDelegate {
    func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        print("connected")
        appRemote.playerAPI?.delegate = self
        appRemote.playerAPI?.subscribe()
    }
    
    private var pendingRequestWorkItem: DispatchWorkItem?
    
    var playerViewController: PlayerViewController?
    var playlists: [MusicPlaylist] = []
    var albums: [MusicPlaylist] = []
    var currentPlaylist: MusicPlaylist?
    var searchType = 0
    var accounts: [String] = []
    
    
    func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        print("failed")
    }
    
    func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        print("disconnected")
    }
    
    func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {
        if playerState.isPaused {
            if playerState.playbackPosition == 0 {
                print(playerState.playbackPosition)
                print(playerState.track.duration)
                print("stopped")
                isPaused = true
                trackView.isHidden = true
                if playerViewController != nil {
                    playerViewController?.dismiss(animated: true)
                }
            }else{
            playButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
            isPaused = true
            }
        }else{
            playButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
            isPaused = false
        }
        guard let currentTrack = currentTrack else {return}
        position = playerState.playbackPosition
        trackProgressView.progress = (Float(position)/Float(currentTrack.duration))
        trackNameLabel.text = playerState.track.name
        trackArtistLabel.text = playerState.track.artist.name
        if playerState.track.name == "--" {
            trackView.isHidden = true
        }
        
        guard let playerViewController = playerViewController else {
            guard let data = try? Data(contentsOf: URL(string: currentTrack.imageUrl!)!) else {return}
            trackImageView.image = UIImage(data: data)
            return}
        if playerViewController.isViewLoaded{
            if isPaused{
            playerViewController.playButton.image = UIImage(systemName: "play.fill")
            }else{
                playerViewController.playButton.image = UIImage(systemName: "pause.fill")
            }
        }
        guard let data = try? Data(contentsOf: URL(string: currentTrack.imageUrl!)!) else {return}
        trackImageView.image = UIImage(data: data)
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "dashboardToPlayerSegue" {
            guard let playerViewController = segue.destination as? PlayerViewController else {return}
            playerViewController.currentTrack = self.currentTrack
            playerViewController.songSearchViewController = self
            playerViewController.position = self.position
            self.playerViewController = playerViewController
        }else if segue.identifier == "dashboardToPlaylistSegue" {
            guard let playlistViewController = segue.destination as? PlaylistViewController else {return}
            playlistViewController.playlist = currentPlaylist!
            if searchType == 1 {
                playlistViewController.title = "Плейлист"
                playlistViewController.type = "playlist"
            }else{
                playlistViewController.title = "Альбом"
                playlistViewController.type = "album"
            }
            
        }
    }
    
    func setupRemoteTransportControls(){
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.addTarget { [unowned self] event in
            if isPaused {
                self.play()
                return .success
            }
            return .commandFailed
        }
        commandCenter.pauseCommand.addTarget { [unowned self] event in
            if !isPaused {
                self.play()
                return .success
            }
            return .commandFailed
        }
    }
    
    func setupNowPlaying() {
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = currentTrack!.name
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = Double(position/1000)
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = Double(currentTrack!.duration/1000)
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPaused ? 0.0 : 1.0
        if let imageUrl = currentTrack!.imageUrl {
            if imageUrl != "" {
            guard let data = try? Data(contentsOf: URL(string: imageUrl)!) else{return}
            let image = UIImage(data: data)!
            nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size, requestHandler: { size in
                return image
            })
            }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    func emptySearchSpotify(jamendo: Bool){
        let CLIENT_ID = "35c1dbc001224063a401b53ad72c3b6c"
        let jamendoClientId = "3dc76206"
        let CLIENT_SECRET = "2ef8ec9c2ad94148b1c535303d00bd93"
        var token = ""
        AF.request("https://accounts.spotify.com/api/token", method: .post, parameters: ["grant_type": "client_credentials"],encoding: URLEncoding.httpBody, headers: HTTPHeaders(["Authorization":"Basic "+Data("\(CLIENT_ID):\(CLIENT_SECRET)".utf8).base64EncodedString(), "Content-Type": "application/x-www-form-urlencoded"])).responseJSON { response in
            guard let data = response.value as? [String: Any] else {return}
            token = data["access_token"] as! String
            AF.request("https://api.spotify.com/v1/browse/featured-playlists", method: .get, parameters: ["grant_type": "client_credentials"],encoding: URLEncoding.queryString, headers: HTTPHeaders(["Authorization":"Bearer \(token)"])).responseJSON { response in
                guard let data = response.value as? [String: Any] else {return}
                
                    let items = (data["playlists"] as! [String: Any])["items"] as! [[String: Any]]
                for i in 0..<10 {
                    let item = items[i]
                    let name = item["name"] as! String
                    let artist = (item["owner"] as! [String: Any])["display_name"] as! String
                    let imageUrl = (item["images"] as! [[String: Any]])[0]["url"] as! String
                    let trackUrl = (item["tracks"] as! [String: Any])["href"] as! String
                    self.playlists.append(MusicPlaylist(name: name, provider: "spotify", artist: artist, imageUrl: imageUrl, tracksUrl: trackUrl, tracks: []))
                }
                let playlistId = (((data["playlists"] as! [String:Any])["items"] as! [[String:Any]])[0]["id"]) as! String
                AF.request("https://api.spotify.com/v1/playlists/\(playlistId)/tracks", method: .get, headers: HTTPHeaders(["Authorization":"Bearer \(token)"])).responseJSON { response in
                    guard let data = response.value as? [String: Any] else {return}
                    let items = data["items"] as! [[String: Any]]
                    for i in 0..<10 {
                        let name = ((items[i]["track"] as! [String: Any])["name"]) as! String
                        let artist = (((items[i]["track"] as! [String: Any])["artists"]) as! [[String: Any]])[0]["name"] as! String
                        let duration = ((items[i]["track"] as! [String: Any])["duration_ms"]) as! Int
                        let url = ((items[i]["track"] as! [String: Any])["uri"]) as! String
                        let imageUrl = ((((items[i]["track"] as! [String: Any])["album"]) as! [String: Any])["images"] as! [[String: Any]])[0]["url"] as! String
                        let track = MusicTrack(provider: "spotify", name: name, artist: artist, duration: duration, url: url, imageUrl: imageUrl)
                        
                        self.tracks.append(track)
                    }
                    AF.request("https://api.spotify.com/v1/browse/new-releases", method: .get, headers: HTTPHeaders(["Authorization": "Bearer \(token)"])).responseJSON { response in
                        guard let data = response.value as? [String: Any] else {return}
                        let albums = data["albums"] as! [String: Any]
                        let items = albums["items"] as! [[String: Any]]
                        for i in 0..<10 {
                            let item = items[i]
                            let name = item["name"] as! String
                            let artist = (item["artists"] as! [[String: Any]])[0]["name"] as! String
                            let imageUrl = (item["images"] as! [[String: Any]])[0]["url"] as! String
                            let id = item["id"] as! String
                            let album = MusicPlaylist(name: name, provider: "spotify", artist: artist, imageUrl: imageUrl, tracksUrl: "https://api.spotify.com/v1/albums/\(id)/tracks", tracks: [])
                            self.albums.append(album)
                        }
                        if jamendo {
                            print("now searching jamendo")
                            self.emptySearchJamendo()
                        }
                        self.tableView.reloadData()
                    }
                }
            }
        }
    }
    func emptySearchJamendo(){
        let jamendoClientId = "3dc76206"
        AF.request("https://api.jamendo.com/v3.0/tracks", method: .get, parameters: ["client_id": jamendoClientId], encoding: URLEncoding.queryString).responseJSON { response in
            guard let data = response.value as? [String: Any] else {return}
            let items = data["results"] as! [[String: Any]]
            for item in items {
                if (item["audiodownload_allowed"] as! Bool) == true{
                let track = MusicTrack(provider: "jamendo", name: item["name"] as! String, artist: item["artist_name"] as! String, duration: (item["duration"] as! Int)*1000, url: item["audiodownload"] as! String, imageUrl: item["image"] as! String)
                    print(track)
                self.tracks.append(track)
                }
            }
            AF.request("https://api.jamendo.com/v3.0/playlists/tracks", method: .get, parameters: ["client_id": jamendoClientId], encoding: URLEncoding.queryString).responseJSON { response in
                guard let data = response.value as? [String: Any] else {return}
                let items = data["results"] as! [[String: Any]]
                for item in items {
                    var playlist = MusicPlaylist(name: item["name"] as! String, provider: "jamendo", artist: item["user_name"] as! String, imageUrl: "", tracksUrl: nil, tracks: [])
                    let tracks = item["tracks"] as! [[String: Any]]
                    for track in tracks {
                        if (track["audiodownload_allowed"] as! Bool) == true{
                        playlist.tracks.append(MusicTrack(provider: "jamendo", name: track["name"] as! String, artist: track["artist_name"] as! String, duration: Int(track["duration"] as! String)!*1000, url: track["audiodownload"] as! String, imageUrl: track["image"] as! String))
                        }
                    }
                    self.playlists.append(playlist)
                }
                AF.request("https://api.jamendo.com/v3.0/albums/tracks", method: .get, parameters: ["client_id": jamendoClientId], encoding: URLEncoding.queryString).responseJSON { response in
                    guard let data = response.value as? [String: Any] else {return}
                    let items = data["results"] as! [[String: Any]]
                    for item in items {
                        var album = MusicPlaylist(name: item["name"] as! String, provider: "jamendo", artist: item["artist_name"] as! String, imageUrl: item["image"] as! String, tracksUrl: nil, tracks: [])
                        let tracks = item["tracks"] as! [[String: Any]]
                        for track in tracks {
                            if (track["audiodownload_allowed"] as! Bool) == true {
                                album.tracks.append(MusicTrack(provider: "jamendo", name: track["name"] as! String, artist: item["artist_name"] as! String, duration: Int(track["duration"] as! String)!*1000, url: track["audiodownload"] as! String, imageUrl: item["image"] as! String))
                            }
                        }
                        self.albums.append(album)
                        self.tableView.reloadData()
                    }
                }
            }
        }
    }
    
    func emptySearch() {
        print(accounts)
        tracks = []
        albums = []
        playlists = []
        if accounts.contains("spotify"){
            print("spotify found")
            if accounts.contains("jamendo"){
                print("jamendo found")
                emptySearchSpotify(jamendo: true)
            }else{
                print("JAMENDO not found")
                emptySearchSpotify(jamendo: false)
            }
        }else if accounts.contains("jamendo"){
            print("spotify not found, jamendo found")
            emptySearchJamendo()
        }
    }
    
    func searchSpotify(query: String, jamendo: Bool){
        let CLIENT_ID = "35c1dbc001224063a401b53ad72c3b6c"
        let jamendoClientId = "3dc76206"
        let CLIENT_SECRET = "2ef8ec9c2ad94148b1c535303d00bd93"
        var token = ""
        AF.request("https://accounts.spotify.com/api/token", method: .post, parameters: ["grant_type": "client_credentials"],encoding: URLEncoding.httpBody, headers: HTTPHeaders(["Authorization":"Basic "+Data("\(CLIENT_ID):\(CLIENT_SECRET)".utf8).base64EncodedString(), "Content-Type": "application/x-www-form-urlencoded"])).responseJSON { response in
            guard let data = response.value as? [String: Any] else {return}
            token = data["access_token"] as! String
            AF.request("https://api.spotify.com/v1/search", method: .get, parameters: ["q": query, "type" : "track,playlist,album", "limit": 10],encoding: URLEncoding.queryString, headers: HTTPHeaders(["Authorization":"Bearer \(token)"])).responseJSON { response in
                guard let data = response.value as? [String: Any] else {return}
                guard let tracks = data["tracks"] as? [String: Any] else {return}
                guard let playlists = data["playlists"] as? [String: Any] else {return}
                guard let albums = data["albums"] as? [String: Any] else {return}
                print(tracks)
                guard var items = tracks["items"] as? [[String: Any]] else {
                    print("fail")
                    return}
                for item in items {
                    let name = item["name"] as! String
                    let artist = (item["artists"] as! [[String: Any]])[0]["name"] as! String
                    let duration = item["duration_ms"] as! Int
                    let url = item["uri"] as! String
                    let imageUrl = ((item["album"] as! [String: Any])["images"] as! [[String: Any]])[0]["url"] as! String
                    var track = MusicTrack(provider: "spotify", name: name, artist: artist, duration: duration, url: url, imageUrl: imageUrl)
                    self.tracks.append(track)
                }
                 items = playlists["items"] as! [[String: Any]]
                for item in items {
                    let name = item["name"] as! String
                    let artist = (item["owner"] as! [String: Any])["display_name"] as! String
                    let imageUrl = (item["images"] as! [[String: Any]])[0]["url"] as! String
                    let trackUrl = (item["tracks"] as! [String: Any])["href"] as! String
                    var playlist = MusicPlaylist(name: name, provider: "spotify", artist: artist, imageUrl: imageUrl, tracksUrl: trackUrl, tracks: [])
                    self.playlists.append(playlist)
                    
                }
                items = albums["items"] as! [[String: Any]]
                for item in items {
                    let name = item["name"] as! String
                    let artist = (item["artists"] as! [[String: Any]])[0]["name"] as! String
                    let imageUrl = (item["images"] as! [[String: Any]])[0]["url"] as! String
                    let id = item["id"] as! String
                    var album = MusicPlaylist(name: name, provider: "spotify", artist: artist, imageUrl: imageUrl, tracksUrl: "https://api.spotify.com/v1/albums/\(id)/tracks", tracks: [])
                    self.albums.append(album)
                }
                if jamendo {
                    self.searchJamendo(query: query)
                }
                self.tableView.reloadData()
            }
        }
    }
    
    func searchJamendo(query: String) {
        print("searching jamendo")
        let jamendoClientId = "3dc76206"
        AF.request("https://api.jamendo.com/v3.0/tracks", method: .get, parameters: ["client_id": jamendoClientId, "search": query], encoding: URLEncoding.queryString).responseJSON { response in
            guard let data = response.value as? [String: Any] else {return}
            let items = data["results"] as! [[String: Any]]
            for item in items {
                if (item["audiodownload_allowed"] as! Bool) == true{
                let track = MusicTrack(provider: "jamendo", name: item["name"] as! String, artist: item["artist_name"] as! String, duration: (item["duration"] as! Int)*1000, url: item["audiodownload"] as! String, imageUrl: item["image"] as! String)
                self.tracks.append(track)
                }
            }
            AF.request("https://api.jamendo.com/v3.0/playlists/tracks", method: .get, parameters: ["client_id": jamendoClientId, "namesearch": query], encoding: URLEncoding.queryString).responseJSON { response in
                guard let data = response.value as? [String: Any] else {return}
                let items = data["results"] as! [[String: Any]]
                for item in items {
                    var playlist = MusicPlaylist(name: item["name"] as! String, provider: "jamendo", artist: item["user_name"] as! String, imageUrl: "", tracksUrl: nil, tracks: [])
                    let tracks = item["tracks"] as! [[String: Any]]
                    for track in tracks {
                        if (track["audiodownload_allowed"] as! Bool) == true{
                        playlist.tracks.append(MusicTrack(provider: "jamendo", name: track["name"] as! String, artist: track["artist_name"] as! String, duration: Int(track["duration"] as! String)!*1000, url: track["audiodownload"] as! String, imageUrl: track["image"] as! String))
                        }
                    }
                    self.playlists.append(playlist)
                }
                AF.request("https://api.jamendo.com/v3.0/albums/tracks", method: .get, parameters: ["client_id": jamendoClientId, "namesearch": query], encoding: URLEncoding.queryString).responseJSON { response in
                    guard let data = response.value as? [String: Any] else {return}
                    let items = data["results"] as! [[String: Any]]
                    for item in items {
                        var album = MusicPlaylist(name: item["name"] as! String, provider: "jamendo", artist: item["artist_name"] as! String, imageUrl: item["image"] as! String, tracksUrl: nil, tracks: [])
                        let tracks = item["tracks"] as! [[String: Any]]
                        for track in tracks {
                            if (track["audiodownload_allowed"] as! Bool) == true {
                                album.tracks.append(MusicTrack(provider: "jamendo", name: track["name"] as! String, artist: item["artist_name"] as! String, duration: Int(track["duration"] as! String)!*1000, url: track["audiodownload"] as! String, imageUrl: item["image"] as! String))
                            }
                        }
                        self.albums.append(album)
                        self.tableView.reloadData()
                    }
                }
            }
        }
    }
    
    var isPaused = false
    var player: AVAudioPlayer!
    var currentTrack: MusicTrack? = nil
    var tracks: [MusicTrack] = []
    var position: Int = 0
    var timer: Timer?
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var trackView: UIView!
    @IBOutlet weak var trackProgressView: UIProgressView!
    @IBOutlet weak var trackImageView: UIImageView!
    @IBOutlet weak var trackNameLabel: UILabel!
    @IBOutlet weak var trackArtistLabel: UILabel!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var searchBar: UISearchBar!
    @IBAction func trackViewClick(_ sender: Any) {
        performSegue(withIdentifier: "dashboardToPlayerSegue", sender: self)
    }
    
    func play(){
        print(currentTrack!.provider)
        if currentTrack!.provider == "spotify" {
        let sceneDelegate = self.view.window!.windowScene!.delegate as! SceneDelegate
        guard let playerApi = sceneDelegate.appRemote.playerAPI else {
            return
        }

        if isPaused {
            isPaused = !isPaused
            playerApi.resume()
            if timer == nil{
            timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(fireTimer), userInfo: nil, repeats: true)
            }
        }else{
            isPaused = !isPaused
            playerApi.pause()
        }
        }else{
            print(player.rate)
            if isPaused {
                player.play()
                playButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
                if let playerViewController = playerViewController {
                    playerViewController.playButton.image = UIImage(systemName: "pause.fill")
                }
            }else{
                player.pause()
                print(player.rate)
                playButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
                if let playerViewController = playerViewController {
                    playerViewController.playButton.image = UIImage(systemName: "play.fill")
                }
            }
            isPaused = !isPaused
        }
    }
    
    func seek(position: Int){
        if currentTrack!.provider == "spotify" {
            guard let sceneDelegate = self.view.window?.windowScene?.delegate as? SceneDelegate else {return}
        guard let playerApi = sceneDelegate.appRemote.playerAPI else {
            return
        }
        playerApi.seek(toPosition: position)
        }else{
            player.currentTime = Double(position/1000)
            self.position = position
            setupNowPlaying()
            trackProgressView.progress = Float(position) / Float(currentTrack!.duration)
        }
    }
    
    
    
    
    @IBAction func playButtonClick(_ sender: Any) {
        play()
    }
    @IBAction func searchTypeSelectionChanged(_ sender: UISegmentedControl)
    {
        searchType = sender.selectedSegmentIndex
        tableView.reloadData()
    }
    @IBAction func exitButtonClick(_ sender: Any) {
        let auth = Auth.auth()
        
        do {
            if Profile.current != nil {
                LoginManager().logOut()
            }
            try auth.signOut()
            performSegue(withIdentifier: "unwindFromSearchToLogin", sender: self)
        }catch {
            print("signout error")
        }
    }
    
    @objc func fireTimer(){
        if isPaused {return}
        if currentTrack!.provider != "spotify" {
            position = Int(player.currentTime * 1000)
            setupNowPlaying()
        }else{
            guard let sceneDelegate = view.window?.windowScene?.delegate as? SceneDelegate else {return}
            guard let playerApi = sceneDelegate.appRemote.playerAPI else {return}
            playerApi.getPlayerState { playerState, error in
                guard let playerState = playerState as? SPTAppRemotePlayerState else {return}
                self.position = playerState.playbackPosition
            }
        }
        if position < currentTrack!.duration {
            trackProgressView.progress = (Float(position)/Float(currentTrack!.duration))
        }
        guard let playerViewController = playerViewController else {return}
        playerViewController.position = position
        if playerViewController.position < currentTrack!.duration && playerViewController.isViewLoaded {
            playerViewController.trackPositionSlider.value = (Float(playerViewController.position)/Float(currentTrack!.duration))
            let seconds = playerViewController.position / 1000
            let secondsString = String(format: "%02d", seconds%60)
            playerViewController.positionLabel.text = "\(seconds/60):\(secondsString)"
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        print("appear")
        if let sceneDelegate = self.view.window?.windowScene?.delegate as? SceneDelegate {
        sceneDelegate.appRemote.delegate = self
            if sceneDelegate.appRemote.isConnected {
                sceneDelegate.appRemote.playerAPI?.delegate = self
                sceneDelegate.appRemote.playerAPI?.subscribe()
            }
        }
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        do{
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            UIApplication.shared.beginReceivingRemoteControlEvents()
        }catch{
            print("error setting audiosession")
        }
        self.trackView.isHidden = true
        let database = Database.database()
        let auth = Auth.auth()
        database.reference(withPath: "users").child(auth.currentUser!.uid).child("accounts").observe(.value) { snapshot in
            if snapshot.exists() {
                let data = snapshot.value as! [String]
                self.accounts = data
                print(self.accounts)
                self.trackView.isHidden = true
                self.searchBar.delegate = self
                self.searchBar.text = ""
                self.emptySearch()
            }
        }
        /*AF.request("https://api.jamendo.com/v3.0/tracks", method: .get, parameters: ["client_id": jamendoClientId], encoding: URLEncoding.queryString).responseJSON { response in
            guard let data = response.value as? [String: Any] else {return}
            let items = data["results"] as! [[String: Any]]
            self.tracks = []
            for item in items {
                let track = MusicTrack(provider: "jamendo", name: item["name"] as! String, artist: item["artist_name"] as! String, duration: (item["duration"] as! Int)*1000, url: item["audiodownload"] as! String, imageUrl: item["image"] as! String)
                self.tracks.append(track)
            }
            self.tableView.reloadData()
        }*/
        // Do any additional setup after loading the view.
    }

}

extension SongSearchViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch searchType {
        case 0:
        print(tracks[indexPath.row].url)
        currentTrack = tracks[indexPath.row]
            guard let sceneDelegate = self.view.window?.windowScene?.delegate as? SceneDelegate else {return}
        switch currentTrack?.provider {
        case "spotify":
            guard var playerApi = sceneDelegate.appRemote.playerAPI else {
                sceneDelegate.appRemote.authorizeAndPlayURI(tracks[indexPath.row].url)
                trackView.isHidden = false
                timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(fireTimer), userInfo: nil, repeats: true)
                isPaused = false
                return
            }
            playerApi.play(tracks[indexPath.row].url) { result, error in
                print("success play")
                self.trackView.isHidden = false
                self.isPaused = false
            }
        default:
            let url = URL(string: currentTrack!.url)!
            guard let audioData = try? Data(contentsOf: url) else {return}
            guard let player = try? AVAudioPlayer(data: audioData) else {return}
            self.player = player
            self.player.delegate = self
            print("jamendo playing")
            self.player.play()
            self.setupRemoteTransportControls()
            self.setupNowPlaying()
            self.trackView.isHidden = false
            self.trackNameLabel.text = currentTrack!.name
            self.trackArtistLabel.text = currentTrack!.artist
            self.playButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
            if timer == nil {
                self.timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(fireTimer), userInfo: nil, repeats: true)
            }
            if let imageUrl = currentTrack!.imageUrl {
                if imageUrl != "" {
                    if let data = try? Data(contentsOf: URL(string: imageUrl)!){
                        self.trackImageView.image = UIImage(data: data)
                    }
                }
            }
            sceneDelegate.musicTrack = currentTrack
            sceneDelegate.isAvPlayerPlaying = true
            sceneDelegate.musicSourceViewController = self
            isPaused = false
        }
        case 1:
            currentPlaylist = playlists[indexPath.row]
            performSegue(withIdentifier: "dashboardToPlaylistSegue", sender: self)
        case 2:
            currentPlaylist = albums[indexPath.row]
            performSegue(withIdentifier: "dashboardToPlaylistSegue", sender: self)
        default:
            return
        }
    }
    
    func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        return UISwipeActionsConfiguration(actions: [UIContextualAction(style: .normal, title: "Добавить в библиотеку", handler: { action, view, handler in
            let database = Database.database()
            let auth = Auth.auth()
            switch self.searchType {
            case 0:
                database.reference(withPath: "users").child(auth.currentUser!.uid).child("tracks").observeSingleEvent(of: .value) { snapshot in
                    var tracks: [MusicTrack] = []
                    if let tracksDict = snapshot.value as? [NSDictionary] {
                        tracks = tracksDict.map({ track in
                            return MusicTrack(dict: track)
                        })
                    }
                    database.reference(withPath: "users").child(auth.currentUser!.uid).child("tracks").child("\(tracks.count)").setValue(self.tracks[indexPath.row].dict())
                }
            case 1:
                database.reference(withPath: "users").child(auth.currentUser!.uid).child("playlists").observeSingleEvent(of: .value) { snapshot in
                    var playlists: [MusicPlaylist] = []
                    if let playlistDict = snapshot.value as? [NSDictionary] {
                        playlists = playlistDict.map({ playlist in
                            return MusicPlaylist(dict: playlist)
                        })
                    }
                    database.reference(withPath: "users").child(auth.currentUser!.uid).child("playlists").child("\(playlists.count)").setValue(self.playlists[indexPath.row].dict())
                }
            case 2:
                database.reference(withPath: "users").child(auth.currentUser!.uid).child("albums").observeSingleEvent(of: .value) { snapshot in
                    var albums: [MusicPlaylist] = []
                    if let albumDict = snapshot.value as? [NSDictionary] {
                        albums = albumDict.map({ album in
                            return MusicPlaylist(dict: album)
                        })
                    }
                    database.reference(withPath: "users").child(auth.currentUser!.uid).child("albums").child("\(albums.count)").setValue(self.albums[indexPath.row].dict())
                }
            default:
                return
            }
        })])
    }
}

extension SongSearchViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch searchType {
        case 0:
            return tracks.count
        case 1:
            return playlists.count
        case 2:
            return albums.count
        default:
            return tracks.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: "trackSearchCell") as! MusicTableViewCell
        switch searchType{
        case 0:
            cell.trackNameLabel.text = tracks[indexPath.row].name
            cell.trackArtistLabel.text = tracks[indexPath.row].artist
            guard let imageData = try? Data(contentsOf: URL(string: tracks[indexPath.row].imageUrl!)!) else {return cell}
            cell.trackImageView.image = UIImage(data: imageData)
        case 1:
            cell.trackNameLabel.text = playlists[indexPath.row].name
            cell.trackArtistLabel.text = playlists[indexPath.row].artist
            guard let imageData = try? Data(contentsOf: URL(string: playlists[indexPath.row].imageUrl!)!) else {return cell}
            cell.trackImageView.image = UIImage(data: imageData)
        case 2:
            cell.trackNameLabel.text = albums[indexPath.row].name
            cell.trackArtistLabel.text = albums[indexPath.row].artist
            guard let imageData = try? Data(contentsOf: URL(string: albums[indexPath.row].imageUrl!)!) else {return cell}
            cell.trackImageView.image = UIImage(data: imageData)
        default:
            cell.trackNameLabel.text = tracks[indexPath.row].name
            cell.trackArtistLabel.text = tracks[indexPath.row].artist
            guard let imageData = try? Data(contentsOf: URL(string: tracks[indexPath.row].imageUrl!)!) else {return cell}
            cell.trackImageView.image = UIImage(data: imageData)
        }
        return cell
    }
    
    
}

extension SongSearchViewController: UISearchBarDelegate {
    
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        view.endEditing(true)
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        pendingRequestWorkItem?.cancel()
        let requestWorkItem = DispatchWorkItem { [weak self] in
            let CLIENT_ID = "35c1dbc001224063a401b53ad72c3b6c"
            let jamendoClientId = "3dc76206"
            let CLIENT_SECRET = "2ef8ec9c2ad94148b1c535303d00bd93"
            var token = ""
            self!.tracks = []
            self!.albums = []
            self!.playlists = []
            self!.tableView.reloadData()
            if(searchText == ""){
                self!.emptySearch()
            }else{
                if self!.accounts.contains("spotify"){
                    if self!.accounts.contains("jamendo"){
                        self!.searchSpotify(query: searchText, jamendo: true)
                    }else{
                        self!.searchSpotify(query: searchText, jamendo: false)
                    }
                }else if self!.accounts.contains("jamendo"){
                    self!.searchJamendo(query: searchText)
                }
            }
        }
        pendingRequestWorkItem = requestWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500),execute: requestWorkItem)
        }
}

extension SongSearchViewController: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        timer!.invalidate()
        print("finished")
        player.stop()
        trackView.isHidden = true
        if let playerViewController = playerViewController {
            playerViewController.dismiss(animated: true)
        }
        (view?.window?.windowScene?.delegate as? SceneDelegate)?.isAvPlayerPlaying = false
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [:]
    }
}




