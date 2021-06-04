//
//  OfflineLibraryViewController.swift
//  GMusic
//
//  Created by Григорий Сухотин on 27.05.2021.
//

import UIKit
import CoreData
import AVFoundation
import MediaPlayer

class OfflineLibraryViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        do{
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback)
            try audioSession.setActive(true)
            UIApplication.shared.beginReceivingRemoteControlEvents()
        }catch{
            print("error setting session")
        }
        trackView.isHidden = true
        tableView.delegate = self
        tableView.dataSource = self
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let managedObjectContext = appDelegate.persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<Track> = Track.fetchRequest()
        do{
            print("beginning fetch")
            let results = try managedObjectContext.fetch(fetchRequest)
            for trackCD in results {
                print(trackCD)
                var track = MusicTrack(provider: trackCD.provider ?? "", name: trackCD.name ?? "", artist: trackCD.artist ?? "", duration: Int(trackCD.duration), url: trackCD.url ?? "", imageUrl: "")
                track.localUrl = trackCD.localUrl
                print(track)
                if track.localUrl != nil {
                    self.tracks.append(track)
                }
            }
            if tracks.count == 0 {
                let noInternetAlertController = UIAlertController(title: "Ошибка", message: "Нет подключения к интернету. Подключитесь к интернету и перезапустите приложение", preferredStyle: .alert)
                noInternetAlertController.addAction(UIAlertAction(title: "ОК", style: .default))
                present(noInternetAlertController, animated: true)
            }
            self.tableView.reloadData()

        }catch{
            print("error fetching tracks")
        }
                
    }
    
    var player: AVAudioPlayer!
    var position: Int = 0
    var tracks: [MusicTrack] = []
    var currentTrack: MusicTrack?
    var timer: Timer?
    var playerViewController: PlayerViewController?
    var isPaused = true
    
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var trackView: UIView!
    @IBOutlet weak var trackProgressView: UIProgressView!
    
    @IBOutlet weak var trackNameLabel: UILabel!
    @IBOutlet weak var trackArtistLabel: UILabel!
    @IBOutlet weak var playButton: UIButton!
    
    @IBAction func playButtonClick(_ sender: Any) {
        play()
    }
    
    func play(){
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
    
    func seek(position: Int){
        player.currentTime = Double(position/1000)
        self.position = position
        setupNowPlaying()
        trackProgressView.progress = Float(position) / Float(currentTrack!.duration)
    }
    
    @objc func fireTimer(){
        if isPaused {return}
        position = Int(player.currentTime * 1000)
        setupNowPlaying()
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
    @IBAction func trackViewClick(_ sender: Any) {
        performSegue(withIdentifier: "offlineLibraryToPlayerSegue", sender: self)
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
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "offlineLibraryToPlayerSegue" {
            let playerViewController = segue.destination as! PlayerViewController
            playerViewController.currentTrack = self.currentTrack
            playerViewController.offlineLibraryViewController = self
            playerViewController.position = self.position
            self.playerViewController = playerViewController
        }
    }
}

extension OfflineLibraryViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let sceneDelegate = view.window?.windowScene?.delegate as? SceneDelegate else {return}
        currentTrack = tracks[indexPath.row]
        let url = URL(string: currentTrack!.localUrl!)!
        print(url)
        
        do{
            let player = try AVAudioPlayer(contentsOf: url)
            self.player = player
            self.player.delegate = self
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
            sceneDelegate.musicTrack = currentTrack
            sceneDelegate.isAvPlayerPlaying = true
            sceneDelegate.musicSourceViewController = self
            isPaused = false
        }catch{
            print("error: \(error.localizedDescription)")
        }
        
    }
}

extension OfflineLibraryViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tracks.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "trackSearchCell") as! MusicTableViewCell
        cell.trackNameLabel.text = tracks[indexPath.row].name
        cell.trackArtistLabel.text = tracks[indexPath.row].artist
        return cell
    }
    
    
}

extension OfflineLibraryViewController: AVAudioPlayerDelegate {
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


