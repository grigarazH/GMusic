//
//  SongSearchViewController.swift
//  GMusic
//
//  Created by Григорий Сухотин on 30.04.2021.
//

import UIKit
import Alamofire
import FirebaseAuth
import AVKit

class SongSearchViewController: UIViewController, SPTAppRemoteDelegate, SPTAppRemotePlayerStateDelegate {
    func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        print("connected")
        appRemote.playerAPI?.delegate = self
        appRemote.playerAPI?.subscribe()
    }
    
    private var pendingRequestWorkItem: DispatchWorkItem?
    
    func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        print("failed")
    }
    
    func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        print("disconnected")
        trackView.isHidden = true
    }
    
    func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {
        if playerState.isPaused {
            playButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
            isPaused = true
        }else{
            playButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
            isPaused = false
        }
        guard let currentTrack = currentTrack else {return}
        trackProgressView.progress = (Float(playerState.playbackPosition)/Float(currentTrack.duration))
        trackNameLabel.text = playerState.track.name
        trackArtistLabel.text = playerState.track.artist.name
        if playerState.track.name == "--" {
            trackView.isHidden = true
        }
        guard let data = try? Data(contentsOf: URL(string: currentTrack.imageUrl)!) else {return}
        trackImageView.image = UIImage(data: data)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "dashboardToPlayerSegue" {
            
        }
    }
    
    func emptySearch() {
        let CLIENT_ID = "35c1dbc001224063a401b53ad72c3b6c"
        let jamendoClientId = "3dc76206"
        let CLIENT_SECRET = "2ef8ec9c2ad94148b1c535303d00bd93"
        var token = ""
        AF.request("https://accounts.spotify.com/api/token", method: .post, parameters: ["grant_type": "client_credentials"],encoding: URLEncoding.httpBody, headers: HTTPHeaders(["Authorization":"Basic "+Data("\(CLIENT_ID):\(CLIENT_SECRET)".utf8).base64EncodedString(), "Content-Type": "application/x-www-form-urlencoded"])).responseJSON { response in
            guard let data = response.value as? [String: Any] else {return}
            token = data["access_token"] as! String
            AF.request("https://api.spotify.com/v1/browse/featured-playlists", method: .get, parameters: ["grant_type": "client_credentials"],encoding: URLEncoding.queryString, headers: HTTPHeaders(["Authorization":"Bearer \(token)"])).responseJSON { response in
                guard let data = response.value as? [String: Any] else {return}
                let playlistId = (((data["playlists"] as! [String:Any])["items"] as! [[String:Any]])[0]["id"]) as! String
                AF.request("https://api.spotify.com/v1/playlists/\(playlistId)/tracks", method: .get, headers: HTTPHeaders(["Authorization":"Bearer \(token)"])).responseJSON { response in
                    guard let data = response.value as? [String: Any] else {return}
                    let items = data["items"] as! [[String: Any]]
                    self.tracks = []
                    for i in 0..<10 {
                        let name = ((items[i]["track"] as! [String: Any])["name"]) as! String
                        let artist = (((items[i]["track"] as! [String: Any])["artists"]) as! [[String: Any]])[0]["name"] as! String
                        let duration = ((items[i]["track"] as! [String: Any])["duration_ms"]) as! Int
                        let url = ((items[i]["track"] as! [String: Any])["uri"]) as! String
                        let imageUrl = ((((items[i]["track"] as! [String: Any])["album"]) as! [String: Any])["images"] as! [[String: Any]])[0]["url"] as! String
                        var track = MusicTrack(provider: "spotify", name: name, artist: artist, duration: duration, url: url, imageUrl: imageUrl)
                        
                        self.tracks.append(track)
                    }
                    self.tableView.reloadData()
                }
            }
        }
    }
    
    var isPaused = false
    var player: AVAudioPlayer!
    var currentTrack: MusicTrack? = nil
    var tracks: [MusicTrack] = []
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
    @IBAction func playButtonClick(_ sender: Any) {
        let sceneDelegate = self.view.window!.windowScene!.delegate as! SceneDelegate
        guard var playerApi = sceneDelegate.appRemote.playerAPI else {
            return
        }

        if isPaused {
            playerApi.resume()
        }else{
            playerApi.pause()
        }
    }
    @IBAction func searchTypeSelectionChanged(_ sender: UISegmentedControl)
    {
        
    }
    @IBAction func exitButtonClick(_ sender: Any) {
        let auth = Auth.auth()
        do {
            try auth.signOut()
            performSegue(withIdentifier: "unwindFromSearchToLogin", sender: self)
        }catch {
            print("signout error")
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if let sceneDelegate = self.view.window?.windowScene?.delegate as? SceneDelegate {
        sceneDelegate.appRemote.delegate = self
        }
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        trackView.isHidden = true
        trackView.frame.size.width = 0
        self.searchBar.delegate = self
        print("begin authorization")
        let CLIENT_ID = "35c1dbc001224063a401b53ad72c3b6c"
        let jamendoClientId = "3dc76206"
        let CLIENT_SECRET = "2ef8ec9c2ad94148b1c535303d00bd93"
        var token = ""
        emptySearch()
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
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}

extension SongSearchViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print(tracks[indexPath.row].url)
        currentTrack = tracks[indexPath.row]
        let sceneDelegate = self.view.window!.windowScene!.delegate as! SceneDelegate
        switch currentTrack?.provider {
        case "spotify":
            guard var playerApi = sceneDelegate.appRemote.playerAPI else {
                sceneDelegate.appRemote.authorizeAndPlayURI(tracks[indexPath.row].url)
                trackView.isHidden = false
                return
            }
            playerApi.play(tracks[indexPath.row].url) { result, error in
                print("success play")
                self.trackView.isHidden = false
            }
        default:
            let url = URL(string: currentTrack!.url)!
            guard let audioData = try? Data(contentsOf: url) else {return}
            guard let player = try? AVAudioPlayer(data: audioData) else {return}
            self.player = player
            print("jamendo playing")
            self.player.play()
            self.trackView.isHidden = false
        }
        
    }
}

extension SongSearchViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tracks.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: "trackSearchCell") as! MusicTableViewCell
        cell.trackNameLabel.text = tracks[indexPath.row].name
        cell.trackArtistLabel.text = tracks[indexPath.row].artist
        guard let imageData = try? Data(contentsOf: URL(string: tracks[indexPath.row].imageUrl)!) else {return cell}
        cell.trackImageView.image = UIImage(data: imageData)
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
            self!.tableView.reloadData()
            if(searchText == ""){
                self!.emptySearch()
            }else{
                AF.request("https://accounts.spotify.com/api/token", method: .post, parameters: ["grant_type": "client_credentials"],encoding: URLEncoding.httpBody, headers: HTTPHeaders(["Authorization":"Basic "+Data("\(CLIENT_ID):\(CLIENT_SECRET)".utf8).base64EncodedString(), "Content-Type": "application/x-www-form-urlencoded"])).responseJSON { response in
                    guard let data = response.value as? [String: Any] else {return}
                    token = data["access_token"] as! String
                    AF.request("https://api.spotify.com/v1/search", method: .get, parameters: ["q": searchText, "type" : "track", "limit": 10],encoding: URLEncoding.queryString, headers: HTTPHeaders(["Authorization":"Bearer \(token)"])).responseJSON { response in
                        guard let data = response.value as? [String: Any] else {return}
                        guard let tracks = data["tracks"] as? [String: Any] else {return}
                        print(tracks)
                        guard let items = tracks["items"] as? [[String: Any]] else {
                            print("fail")
                            return}
                        for item in items {
                            let name = item["name"] as! String
                            let artist = (item["artists"] as! [[String: Any]])[0]["name"] as! String
                            let duration = item["duration_ms"] as! Int
                            let url = item["uri"] as! String
                            let imageUrl = ((item["album"] as! [String: Any])["images"] as! [[String: Any]])[0]["url"] as! String
                            var track = MusicTrack(provider: "spotify", name: name, artist: artist, duration: duration, url: url, imageUrl: imageUrl)
                            print(track)
                            self!.tracks.append(track)
                        }
                        self!.tableView.reloadData()
                    }
                }
            }
        }
        pendingRequestWorkItem = requestWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500),execute: requestWorkItem)
        }
}


struct MusicTrack: Encodable {
    var provider: String
    var name: String
    var artist: String
    var duration: Int
    var url: String
    var imageUrl: String
}
