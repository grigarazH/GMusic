//
//  PlaylistViewController.swift
//  GMusic
//
//  Created by Григорий Сухотин on 25.05.2021.
//

import UIKit
import Alamofire
import AVFoundation
import FirebaseDatabase
import MediaPlayer
import FBSDKLoginKit
import FirebaseAuth

class PlaylistViewController: UIViewController{
        
    var playlist: MusicPlaylist?
    
    
    var currentTrackId: Int = 0
    var position: Int = 0
    var isPaused = false
    var type = "playlist"

    @IBOutlet weak var playlistImageView: UIImageView!
    @IBOutlet weak var playlistTitle: UILabel!
    @IBOutlet weak var playlistArtist: UILabel!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var trackView: UIView!
    @IBOutlet weak var trackImageView: UIImageView!
    @IBOutlet weak var trackProgressBar: UIProgressView!
    @IBOutlet weak var trackTitle: UILabel!
    @IBOutlet weak var trackArtist: UILabel!
    @IBOutlet weak var trackPlayButton: UIButton!
    var playerViewController: PlayerViewController?
    var player: AVAudioPlayer!
    var timer: Timer?
    var isLoaded = false
    override func viewDidLoad() {
        super.viewDidLoad()
        do{
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            UIApplication.shared.beginReceivingRemoteControlEvents()
        }catch{
            print("error setting audiosession")
        }
        player = AVAudioPlayer()
        trackView.isHidden = true
        tableView.delegate = self
        tableView.dataSource = self
        guard let playlist = playlist else {return}
        playlistTitle.text = playlist.name
        playlistArtist.text = playlist.artist
        if playlist.provider == "spotify" {
            let CLIENT_ID = "35c1dbc001224063a401b53ad72c3b6c"
            let CLIENT_SECRET = "2ef8ec9c2ad94148b1c535303d00bd93"
            var token = ""
            AF.request("https://accounts.spotify.com/api/token", method: .post, parameters: ["grant_type": "client_credentials"],encoding: URLEncoding.httpBody, headers: HTTPHeaders(["Authorization":"Basic "+Data("\(CLIENT_ID):\(CLIENT_SECRET)".utf8).base64EncodedString(), "Content-Type": "application/x-www-form-urlencoded"])).responseJSON { response in
                guard let data = response.value as? [String: Any] else {return}
                token = data["access_token"] as! String
                AF.request(playlist.tracksUrl!, method: .get, headers: HTTPHeaders(["Authorization": "Bearer \(token)"])).responseJSON { response in
                    guard let data = response.value as? [String: Any] else {return}
                    let items = data["items"] as! [[String: Any]]
                    for item in items {
                        var track: [String: Any]
                        var imageUrl: String
                        if self.type == "playlist"{
                         track = item["track"] as! [String: Any]
                            let album = track["album"] as! [String: Any]
                            imageUrl = (album["images"] as! [[String: Any]])[0]["url"] as! String
                        }else{
                             track = item
                            imageUrl = playlist.imageUrl!
                        }
                        
                        let name = track["name"] as! String
                        let artist = (track["artists"] as! [[String: Any]])[0]["name"] as! String
                        let duration = track["duration_ms"] as! Int
                        let url = track["uri"] as! String
                        let trackItem = MusicTrack(provider: "spotify", name: name, artist: artist, duration: duration, url: url, imageUrl: imageUrl)
                        self.playlist?.tracks.append(trackItem)
                    }
                    self.isLoaded = true
                    self.tableView.reloadData()
                }
        }
        }else if playlist.provider == "custom" {
            let database = Database.database()
            database.reference(withPath: playlist.tracksUrl!).observeSingleEvent(of: .value) { snapshot in
                print(snapshot.exists())
                if snapshot.exists() {
                    let data = snapshot.value as! [NSDictionary]
                    let tracks = data.map { dict in
                        MusicTrack(dict: dict)
                    }
                    self.playlist?.tracks = tracks
                    self.isLoaded = true
                    self.tableView.reloadData()
                }
            }
        }
        guard let imageUrl = playlist.imageUrl else {return}
        if imageUrl == "" {return }
        guard let data = try? Data(contentsOf: URL(string: imageUrl)!) else {return}
        playlistImageView.image = UIImage(data: data)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if let sceneDelegate = self.view.window?.windowScene?.delegate as? SceneDelegate {
        sceneDelegate.appRemote.delegate = self
            if sceneDelegate.appRemote.isConnected {
                sceneDelegate.appRemote.playerAPI?.delegate = self
                sceneDelegate.appRemote.playerAPI?.subscribe()
            }
        }
    }
    
    func playPlaylist(){
        if !isLoaded {return}
        beginPlaying(position: 0)
        
    }
    func play(){
        if playlist!.tracks[currentTrackId].provider == "spotify" {
            guard let sceneDelegate = self.view.window?.windowScene?.delegate as? SceneDelegate else {return}
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
            if isPaused{
                trackPlayButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
                player.play()
            }else{
                trackPlayButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
                player.pause()
            }
            isPaused = !isPaused
            setupNowPlaying()
        }
    }
    func skipToNext(){
        if playlist!.tracks[currentTrackId] == playlist!.tracks.last!{
            return
        }
        currentTrackId += 1
        tableView.selectRow(at: IndexPath(row: currentTrackId, section: 0), animated: true, scrollPosition: .middle)
        beginPlaying(position: currentTrackId)
        
    }
    func skipToPrev(){
        if currentTrackId == 0 {
            return
        }
        currentTrackId -= 1
        beginPlaying(position: currentTrackId)
    }
    
    func seek(position: Int){
        if playlist!.tracks[currentTrackId].provider == "spotify" {
            guard let sceneDelegate = self.view.window?.windowScene?.delegate as? SceneDelegate else {return}
        guard let playerApi = sceneDelegate.appRemote.playerAPI else {
            return
        }
        playerApi.seek(toPosition: position)
        }else{
            player.currentTime = Double(position / 1000)
            self.position = position
            trackProgressBar.progress = Float(position) / Float(playlist!.tracks[currentTrackId].duration)
            if let playerViewController = playerViewController {
                playerViewController.trackPositionSlider.value = Float(position) / Float(playlist!.tracks[currentTrackId].duration)
            }
            setupNowPlaying()
        }
    }
    
    func beginPlaying(position: Int){
        currentTrackId = position
        let currentTrack = playlist!.tracks[currentTrackId]
        guard let sceneDelegate = self.view.window?.windowScene?.delegate as? SceneDelegate else {return}
        switch currentTrack.provider {
        case "spotify":
            guard var playerApi = sceneDelegate.appRemote.playerAPI else {
                sceneDelegate.appRemote.authorizeAndPlayURI(currentTrack.url)
                trackView.isHidden = false
                if timer == nil{
                timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(fireTimer), userInfo: nil, repeats: true)
                }
                isPaused = false
                return
            }
            playerApi.play(currentTrack.url) { result, error in
                print("success play")
                if self.timer == nil{
                    self.timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(self.fireTimer), userInfo: nil, repeats: true)
                }
                self.trackView.isHidden = false
                self.isPaused = false
            }
        default:
            let url = URL(string: currentTrack.url)!
            guard let audioData = try? Data(contentsOf: url) else {return}
            guard let player = try? AVAudioPlayer(data: audioData) else {return}
            self.player = player
            print("jamendo playing")
            self.player.play()
            self.trackView.isHidden = false
            if timer == nil{
            timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(fireTimer), userInfo: nil, repeats: true)
            }
            isPaused = false
            setupRemoteTransportControls()
            setupNowPlaying()
        }
    }
    
    @objc func fireTimer(){
        if isPaused {return}
        let currentTrack = playlist!.tracks[currentTrackId]
        if currentTrack.provider != "spotify" {
            position = Int(player.currentTime * 1000)
            setupNowPlaying()
        }else{
            guard let playerApi = (view.window?.windowScene?.delegate as? SceneDelegate)?.appRemote.playerAPI else {return}
            playerApi.getPlayerState { playerState, error in
                guard let playerState = playerState as? SPTAppRemotePlayerState else {return}
                self.position = playerState.playbackPosition
            }
        }
        if position < currentTrack.duration {
            trackProgressBar.progress = (Float(position)/Float(currentTrack.duration))
        }
        guard let playerViewController = playerViewController else {return}
        playerViewController.position = position
        if playerViewController.position < currentTrack.duration && playerViewController.isViewLoaded {
            playerViewController.trackPositionSlider.value = (Float(playerViewController.position)/Float(currentTrack.duration))
            let seconds = playerViewController.position / 1000
            let secondsString = String(format: "%02d", seconds%60)
            playerViewController.positionLabel.text = "\(seconds/60):\(secondsString)"
        }
    }
    @IBAction func trackViewClick(_ sender: Any) {
        performSegue(withIdentifier: "playlistToPlayerSegue", sender: self)
    }
    @IBAction func playPlaylistButtonClick(_ sender: Any) {
        playPlaylist()
    }
    @IBAction func shuffleButtonClick(_ sender: Any) {
        guard var playlist = playlist else {return}
        self.playlist?.tracks = playlist.tracks.shuffled()
        tableView.reloadData()
    }
    @IBAction func playButtonClick(_ sender: Any) {
        play()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "playlistToPlayerSegue" {
            let playerViewController = segue.destination as! PlayerViewController
            playerViewController.currentTrack = playlist!.tracks[currentTrackId]
            playerViewController.playlistViewController = self
            playerViewController.playType = "playlist"
            self.playerViewController = playerViewController
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
    
    func setupNowPlaying() {
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = playlist!.tracks[currentTrackId].name
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentTime
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = Double(playlist!.tracks[currentTrackId].duration/1000)
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPaused ? 0.0 : 1.0
        if let imageUrl = playlist!.tracks[currentTrackId].imageUrl {
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
}

extension PlaylistViewController: SPTAppRemoteDelegate, SPTAppRemotePlayerStateDelegate {
    func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        print("connected")
        appRemote.playerAPI?.delegate = self
        appRemote.playerAPI?.subscribe()
    }
    
    func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        print("failed")
    }
    
    func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        print("disconnected")
    }
    
    func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {
        if playerState.isPaused {
            if !isPaused {
                currentTrackId += 1
                if currentTrackId == playlist!.tracks.count{
                print("stopped")
                isPaused = true
                trackView.isHidden = true
                if playerViewController != nil {
                    playerViewController?.dismiss(animated: true)
                }
                    return
                }else{
                    beginPlaying(position: currentTrackId)
                }
            }else{
            trackPlayButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
            isPaused = true
            }
        }else{
            trackPlayButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
            isPaused = false
        }
        position = playerState.playbackPosition
        let currentTrack = playlist!.tracks[currentTrackId]
        trackProgressBar.progress = (Float(position)/Float(currentTrack.duration))
        trackTitle.text = playerState.track.name
        trackArtist.text = playerState.track.artist.name
        if playerState.track.name == "--" {
            trackView.isHidden = true
        }
        
        guard let playerViewController = playerViewController else {
            guard let imageUrl = currentTrack.imageUrl else {return}
            if imageUrl == "" {return }
            guard let data = try? Data(contentsOf: URL(string: imageUrl)!) else {return}
            trackImageView.image = UIImage(data: data)
            return}
        if playerViewController.isViewLoaded{
            if isPaused{
            playerViewController.playButton.image = UIImage(systemName: "play.fill")
            }else{
                playerViewController.playButton.image = UIImage(systemName: "pause.fill")
            }
            if currentTrackId == 0 {
                playerViewController.prevButton.alpha = 0.5
            }else{
                playerViewController.prevButton.alpha = 1.0
            }
            if currentTrackId == playlist!.tracks.count-1 {
                playerViewController.forwardButton.alpha = 0.5
            }else{
                playerViewController.forwardButton.alpha = 1.0
            }
            playerViewController.currentTrack = currentTrack
            playerViewController.nameTF.text = playerState.track.name
            playerViewController.artistTF.text = playerState.track.artist.name
            let seconds = currentTrack.duration / 1000
            let secondsString = String(format: "%02d", seconds%60)
            playerViewController.durationLabel.text = "\(seconds/60):\(secondsString)"
        }
        guard let imageUrl = currentTrack.imageUrl else {return}
        if imageUrl == "" {return}
        guard let data = try? Data(contentsOf: URL(string: imageUrl)!) else {return}
        if playerViewController.isViewLoaded {
            playerViewController.trackImageView.image = UIImage(data: data)
        }
        trackImageView.image = UIImage(data: data)
    }
}

extension PlaylistViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        beginPlaying(position: indexPath.row)
    }
}

extension PlaylistViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let playlist = playlist else {return 0}
        return playlist.tracks.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "trackSearchCell") as! MusicTableViewCell
        let track = playlist!.tracks[indexPath.row]
        cell.trackNameLabel.text = track.name
        cell.trackArtistLabel.text = track.artist
        guard let imageUrl = track.imageUrl else {return cell}
        guard let data = try? Data(contentsOf: URL(string: imageUrl)!) else {return cell}
        cell.trackImageView.image = UIImage(data: data)
        return cell
    }
    
    
}

extension PlaylistViewController: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        timer!.invalidate()
        print("finished")
        player.stop()
        trackView.isHidden = true
        (view?.window?.windowScene?.delegate as? SceneDelegate)?.isAvPlayerPlaying = false
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [:]
    }
}

