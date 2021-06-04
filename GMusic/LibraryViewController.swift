//
//  LibraryViewController.swift
//  GMusic
//
//  Created by Григорий Сухотин on 26.05.2021.
//

import UIKit
import FirebaseAuth
import FirebaseDatabase
import AVFoundation
import CoreData
import MobileCoreServices
import FirebaseStorage
import MediaPlayer
import FBSDKLoginKit

class LibraryViewController: UIViewController {
    
    var tracks: [MusicTrack] = []
    var localTracks: [MusicTrack] = []
    var playlists: [MusicPlaylist] = []
    var albums: [MusicPlaylist] = []
    var currentPlaylist: MusicPlaylist?
    var player: AVAudioPlayer!
    var accounts: [String] = []
    var contentType: Int = 0
    var playerViewController: PlayerViewController?
    var currentTrack: MusicTrack?
    var isPaused = true
    var position = 0
    var timer: Timer?
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var trackView: UIView!
    @IBOutlet weak var trackProgressVIew: UIProgressView!
    @IBOutlet weak var trackImageView: UIImageView!
    @IBOutlet weak var trackNameLabel: UILabel!
    @IBOutlet weak var trackArtistLabel: UILabel!
    @IBOutlet weak var playButton: UIButton!
    
    @IBAction func contentTypeTabValueChanged(_ sender: UISegmentedControl) {
        contentType = sender.selectedSegmentIndex
        tableView.reloadData()
    }
    @IBAction func trackViewClick(_ sender: Any) {
        performSegue(withIdentifier: "libraryToPlayerSegue", sender: self)
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
        let database = Database.database()
        trackView.isHidden = true
        tableView.delegate = self
        tableView.dataSource = self
        let auth = Auth.auth()
        database.reference(withPath: "users").child(auth.currentUser!.uid).child("accounts").observe(.value) { snapshot in
            if snapshot.exists() {
                self.accounts = snapshot.value as! [String]
                self.tableView.reloadData()
            }
        }
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let managedObjectContext = appDelegate.persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<Track> = Track.fetchRequest()
        do{
            print("fetching")
            let results = try managedObjectContext.fetch(fetchRequest)
            let sortedResults = results.sorted { track1, track2 in
                return track1.id < track2.id
            }
            print(sortedResults)
            for item in sortedResults {
                var track = MusicTrack(provider: item.provider!, name: item.name!, artist: item.artist!, duration: Int(item.duration), url: item.url ?? "", imageUrl: "")
                track.localUrl = item.localUrl
                print(track)
                localTracks.append(track)
                managedObjectContext.delete(item)
            }
            try managedObjectContext.save()
            print("fetch success")
        }catch{
            print("error fetching")
        }
        database.reference(withPath: "users").child(auth.currentUser!.uid).child("tracks").observe(.value) { snapshot in
            self.tracks = []
            if snapshot.value == nil {return}
            guard let data = snapshot.value as? [NSDictionary] else {return}
            for item in data {
                let track = MusicTrack(dict: item)
                self.tracks.append(track)
            }
            print(self.localTracks.count)
            for i in 0..<self.tracks.count {
                if i == self.localTracks.count {
                    self.localTracks.append(self.tracks[i])
                    print("appended")
                }
            }
                for i in 0..<self.localTracks.count {
                    print(self.localTracks[i])
                    let trackCD = Track(context: managedObjectContext)
                    trackCD.name = self.localTracks[i].name
                    trackCD.artist = self.localTracks[i].artist
                    trackCD.duration = Int32(self.localTracks[i].duration)
                    trackCD.provider = self.localTracks[i].provider
                    trackCD.url = self.localTracks[i].url
                    trackCD.localUrl = self.localTracks[i].localUrl
                    trackCD.id = Int32(i)
                }
                do {
                    try managedObjectContext.save()
                }catch{
                    print("error saving tracks")
                }
            self.tableView.reloadData()
        }
        
        database.reference(withPath: "users").child(auth.currentUser!.uid).child("playlists").observe(.value) {snapshot in
            self.playlists = []
            if snapshot.value == nil {return}
            guard let data = snapshot.value as? [NSDictionary] else {return}
            for item in data {
                let playlist = MusicPlaylist(dict: item)
                self.playlists.append(playlist)
            }
            self.tableView.reloadData()
        }
        database.reference(withPath: "users").child(auth.currentUser!.uid).child("albums").observe(.value) {snapshot in
            self.albums = []
            if snapshot.value == nil {return}
            guard let data = snapshot.value as? [NSDictionary] else {return}
            for item in data {
                let album = MusicPlaylist(dict: item)
                self.albums.append(album)
            }
            self.tableView.reloadData()
        }
    }
    
    @IBAction func exitButtonClick(_ sender: Any) {
        let auth = Auth.auth()
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let managedObjectContext = appDelegate.persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<Track> = Track.fetchRequest()
        do{
            print("fetching")
            let results = try managedObjectContext.fetch(fetchRequest)
            for item in results {
                managedObjectContext.delete(item)
            }
            try managedObjectContext.save()
            print("delete success")
        }catch{
            print("error deleting")
        }
        do {
            if Profile.current != nil {
                LoginManager().logOut()
            }
            try auth.signOut()
            performSegue(withIdentifier: "unwindFromLibraryToLogin", sender: self)
        }catch {
            print("signout error")
        }
    }
    func play(){
        print(currentTrack!.provider)
        if currentTrack!.provider == "spotify" {
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
            trackProgressVIew.progress = Float(position) / Float(currentTrack!.duration)
        }
    }
    @IBAction func playButtonClick(_ sender: Any) {
        play()
    }
    
    @objc func fireTimer(){
        if isPaused {return}
        if currentTrack!.provider != "spotify" {
            position = Int(player.currentTime * 1000)
            setupNowPlaying()
        }else{
            guard let playerApi = (view.window?.windowScene?.delegate as? SceneDelegate)?.appRemote.playerAPI else {return}
            playerApi.getPlayerState { playerState, error in
                guard let playerState = playerState as? SPTAppRemotePlayerState else {return}
                self.position = playerState.playbackPosition
            }
        }
        if position < currentTrack!.duration {
            trackProgressVIew.progress = (Float(position)/Float(currentTrack!.duration))
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
        if let sceneDelegate = self.view.window?.windowScene?.delegate as? SceneDelegate {
        sceneDelegate.appRemote.delegate = self
            if sceneDelegate.appRemote.isConnected {
                sceneDelegate.appRemote.playerAPI?.delegate = self
                sceneDelegate.appRemote.playerAPI?.subscribe()
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "libraryToPlaylistSegue" {
            let playlistViewController = segue.destination as! PlaylistViewController
            playlistViewController.playlist = currentPlaylist
            if contentType == 1 {
                playlistViewController.title = "Плейлист"
                playlistViewController.type = "playlist"
            }else{
                playlistViewController.title = "Альбом"
                playlistViewController.type = "album"
            }
        }else if segue.identifier == "libraryToPlayerSegue" {
            let playerViewController = segue.destination as! PlayerViewController
            playerViewController.currentTrack = currentTrack
            playerViewController.position = self.position
            playerViewController.libraryViewController = self
            self.playerViewController = playerViewController
        }else if segue.identifier == "libraryToSelectPlaylistSegue" {
            self.navigationItem.backButtonTitle = "Назад"
            let controller = segue.destination as! SelectPlaylistTableViewController
            controller.track = currentTrack!
        }
    }
    @IBAction func menuClick(_ sender: Any) {
        let menuAlertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        menuAlertController.addAction(UIAlertAction(title: "Добавить плейлист", style: .default, handler: { action in
            self.performSegue(withIdentifier: "libraryToCreatePlaylistSegue", sender: self)
        }))
        menuAlertController.addAction(UIAlertAction(title: "Загрузить файл", style: .default, handler: { action in
            let documentPickerViewController = UIDocumentPickerViewController(documentTypes: [kUTTypeMP3 as String], in: .import)
            documentPickerViewController.delegate = self
            self.present(documentPickerViewController, animated: true)
        }))
        menuAlertController.addAction(UIAlertAction(title: "Отмена", style: .destructive))
        present(menuAlertController, animated: true)
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
}

extension LibraryViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "trackSearchCell") as! MusicTableViewCell
        switch contentType {
        case 0:
            cell.trackNameLabel.text = tracks[indexPath.row].name
            cell.trackArtistLabel.text = tracks[indexPath.row].artist
            guard let imageUrl = tracks[indexPath.row].imageUrl else {return cell}
            if imageUrl == "" {return cell}
            guard let data = try? Data(contentsOf: URL(string: imageUrl)!) else {return cell}
            cell.trackImageView.image = UIImage(data: data)
            if !accounts.contains(tracks[indexPath.row].provider) {
                if tracks[indexPath.row].provider != "custom" {
                    cell.isHidden = true
                }
            }
        case 1:
            cell.trackNameLabel.text = playlists[indexPath.row].name
            cell.trackArtistLabel.text = playlists[indexPath.row].artist
            guard let imageUrl = playlists[indexPath.row].imageUrl else {return cell}
            if imageUrl == "" {return cell}
            guard let data = try? Data(contentsOf: URL(string: imageUrl)!) else {return cell}
            cell.trackImageView.image = UIImage(data: data)
            if !accounts.contains(playlists[indexPath.row].provider) {
                if playlists[indexPath.row].provider != "custom" {
                    cell.isHidden = true
                }
            }
        case 2:
            cell.trackNameLabel.text = albums[indexPath.row].name
            cell.trackArtistLabel.text = albums[indexPath.row].artist
            guard let imageUrl = albums[indexPath.row].imageUrl else {return cell}
            if imageUrl == "" {return cell}
            guard let data = try? Data(contentsOf: URL(string: imageUrl)!) else {return cell}
            cell.trackImageView.image = UIImage(data: data)
            if !accounts.contains(albums[indexPath.row].provider) {
                if albums[indexPath.row].provider != "custom" {
                    cell.isHidden = true
                }
            }
        default:
            return cell
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch contentType {
        case 0:
            return tracks.count
        case 1:
            return playlists.count
        case 2:
            return albums.count
        default:
            return 0
        }
        
    }
    
    
}




extension LibraryViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch contentType {
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
            performSegue(withIdentifier: "libraryToPlaylistSegue", sender: self)
        case 2:
            currentPlaylist = albums[indexPath.row]
            performSegue(withIdentifier: "libraryToPlaylistSegue", sender: self)
        default:
            return
        }
    }
    func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if contentType == 0 {
            var actions =  [UIContextualAction(style: .normal, title: "Добавить в плейлист", handler: { action, view, handler in
                self.currentTrack = self.tracks[indexPath.row]
                                                    self.performSegue(withIdentifier: "libraryToSelectPlaylistSegue", sender: self)
                                                })]
            if localTracks[indexPath.row].provider != "spotify"  {
                actions.append(UIContextualAction(style: .normal, title: "Сохранить", handler: { action, view, handler in
                    let task = URLSession.shared.downloadTask(with: URL(string: self.tracks[indexPath.row].url)!) {
                        localUrl, response, error in
                        guard let localUrl = localUrl else {return}
                        do {
                            let documentsURL = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
                            print(documentsURL)
                            var savedURL: URL
                            if self.localTracks[indexPath.row].provider == "jamendo" {
                                savedURL = documentsURL.appendingPathComponent(self.localTracks[indexPath.row].name+".mp3")
                            }else{
                                savedURL = documentsURL.appendingPathComponent(self.localTracks[indexPath.row].name)
                            }
                            if FileManager.default.fileExists(atPath: savedURL.path) {
                                print("exists")
                                try FileManager.default.removeItem(at: savedURL)
                                print("deleted")
                            }
                            try FileManager.default.moveItem(at: localUrl, to: savedURL)
                            DispatchQueue.main.async {
                                let appDelegate = UIApplication.shared.delegate as! AppDelegate
                                let managedObjectContext = appDelegate.persistentContainer.viewContext
                                self.localTracks[indexPath.row].localUrl = savedURL.absoluteString
                                let fetchRequest: NSFetchRequest<Track> = Track.fetchRequest()
                                do{
                                    let results = try managedObjectContext.fetch(fetchRequest)
                                    let sortedResults = results.sorted { track1, track2 in
                                        return track1.id < track2.id
                                    }
                                    for item in sortedResults {
                                        managedObjectContext.delete(item)
                                    }
                                    print("delete success")
                                    for i in 0..<self.localTracks.count {
                                        print(self.localTracks[i])
                                        let trackCD = Track(context: managedObjectContext)
                                        trackCD.artist = self.localTracks[i].artist
                                        trackCD.duration = Int32(self.localTracks[i].duration)
                                        trackCD.name = self.localTracks[i].name
                                        trackCD.provider = self.localTracks[i].provider
                                        trackCD.url = self.localTracks[i].url
                                        trackCD.localUrl = self.localTracks[i].localUrl
                                    }
                                    do{
                                        try managedObjectContext.save()
                                        print("saved successfully")
                                        let saveSuccessAlert = UIAlertController(title: "Файл успешно сохранен", message: nil, preferredStyle: .alert)
                                        saveSuccessAlert.addAction(UIAlertAction(title: "ОК", style: .default))
                                        self.present(saveSuccessAlert, animated: true)
                                    }catch{
                                        print("error saving")
                                    }
                                }catch{
                                    print("error fetching")
                                }
                            }
                            
                        }catch {
                            print("error saving file")
                            
                        }
                        
                    }.resume()
                }))
            }
            return UISwipeActionsConfiguration(actions: actions)
        }
        return nil
    }
}

extension LibraryViewController: SPTAppRemoteDelegate, SPTAppRemotePlayerStateDelegate {
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
        trackView.isHidden = true
    }
    
    func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {
        if playerState.isPaused {
            if !isPaused {
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
        trackProgressVIew.progress = (Float(position)/Float(currentTrack.duration))
        trackNameLabel.text = playerState.track.name
        trackArtistLabel.text = playerState.track.artist.name
        if playerState.track.name == "--" {
            trackView.isHidden = true
        }
        
        guard let playerViewController = playerViewController else {
            guard let imageUrl = currentTrack.imageUrl else {return}
            if imageUrl == "" {return}
            guard let data = try? Data(contentsOf: URL(string: imageUrl)!) else {return}
            trackImageView.image = UIImage(data: data)
            return}
        if playerViewController.isViewLoaded{
            if isPaused{
            playerViewController.playButton.image = UIImage(systemName: "play.fill")
            }else{
                playerViewController.playButton.image = UIImage(systemName: "pause.fill")
            }
        }
        guard let imageUrl = currentTrack.imageUrl else {return}
        if imageUrl == "" {return}
        guard let data = try? Data(contentsOf: URL(string: imageUrl)!) else {return}
        trackImageView.image = UIImage(data: data)
    }
    
    
}

extension LibraryViewController: UIDocumentPickerDelegate {

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        let localUrl = urls[0]
        let asset = AVURLAsset(url: localUrl)
        let duration = Int(CMTimeGetSeconds(asset.duration)) * 1000
        print(duration)
        let storage = Storage.storage()
        let auth = Auth.auth()
        let database = Database.database()
        print("begin uploading")
        guard let data = try? Data(contentsOf: localUrl) else {
            print("data file error")
            return}
        storage.reference().child(auth.currentUser!.uid).child("tracks").child(localUrl.lastPathComponent).putData(data, metadata: nil) { metadata, error in
            if let error = error {
                print(error.localizedDescription)
                return
            }
             storage.reference().child(auth.currentUser!.uid).child("tracks").child(localUrl.lastPathComponent).downloadURL { url, error in
                guard let url = url else {
                    print(error!.localizedDescription)
                    return}
                var track = MusicTrack(provider: "custom", name: urls[0].lastPathComponent, artist: "", duration: duration, url: url.absoluteString, imageUrl: "")
                database.reference(withPath: "users").child(auth.currentUser!.uid).child("tracks").child("\(self.tracks.count)").setValue(track.dict())
                    
                self.tableView.reloadData()
            }
            
        }
    }
}

extension LibraryViewController: AVAudioPlayerDelegate {
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
