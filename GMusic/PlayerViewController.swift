//
//  PlayerViewController.swift
//  GMusic
//
//  Created by Григорий Сухотин on 16.05.2021.
//

import UIKit

class PlayerViewController: UIViewController {

    @IBOutlet weak var nameTF: UILabel!
    @IBOutlet weak var artistTF: UILabel!
    @IBOutlet weak var trackImageView: UIImageView!
    @IBOutlet weak var playButton: UIImageView!
    @IBOutlet weak var prevButton: UIImageView!
    @IBOutlet weak var forwardButton: UIImageView!
    @IBOutlet weak var trackPositionSlider: UISlider!
    @IBOutlet weak var positionLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    var currentTrack: MusicTrack?
    var trackIndex = 0
    var playType = "track"
    var position = 0
    var songSearchViewController: SongSearchViewController?
    var playlistViewController: PlaylistViewController?
    var libraryViewController: LibraryViewController?
    var offlineLibraryViewController: OfflineLibraryViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        guard let currentTrack = currentTrack else {return}
        nameTF.text = currentTrack.name
        artistTF.text = currentTrack.artist
        let seconds = currentTrack.duration / 1000
        let secondsString = String(format: "%02d", seconds%60)
        durationLabel.text = "\(seconds/60):\(secondsString)"
        positionLabel.text = "0:00"
        trackPositionSlider.value = Float(position)/Float(currentTrack.duration)
        playButton.isUserInteractionEnabled = true
        prevButton.isUserInteractionEnabled = true
        forwardButton.isUserInteractionEnabled = true
        if songSearchViewController != nil {
        if songSearchViewController!.isPaused {
            playButton.image = UIImage(systemName: "play.fill")
        }else{
            playButton.image = UIImage(systemName: "pause.fill")
        }
        }
        if playlistViewController != nil {
            if playlistViewController!.isPaused {
                playButton.image = UIImage(systemName: "play.fill")
            }else{
                playButton.image = UIImage(systemName: "pause.fill")
            }
        }
        if libraryViewController != nil {
            if libraryViewController!.isPaused {
                playButton.image = UIImage(systemName: "play.fill")
            }else{
                playButton.image = UIImage(systemName: "pause.fill")
            }
        }
        if offlineLibraryViewController != nil {
            if offlineLibraryViewController!.isPaused {
                playButton.image = UIImage(systemName: "play.fill")
            }else{
                playButton.image = UIImage(systemName: "pause.fill")
            }
        }
        if playType == "track" {
            prevButton.alpha = 0.5
            forwardButton.alpha = 0.5
        }else{
            if playlistViewController!.currentTrackId == 0 {
                prevButton.alpha = 0.5
            }else{
                prevButton.alpha = 1.0
            }
            if playlistViewController!.currentTrackId == playlistViewController!.playlist!.tracks.count-1 {
                forwardButton.alpha = 0.5
            }else{
                forwardButton.alpha = 1.0
            }
        }
        guard let imageUrl = currentTrack.imageUrl else {return}
        if imageUrl == "" {return}
        guard let imageData = try? Data(contentsOf: URL(string: imageUrl)!) else {return}
        trackImageView.image = UIImage(data: imageData)
        
        
    }
    

    @IBAction func playButtonClick(_ sender: UITapGestureRecognizer) {
        print("play")
        guard let songSearchViewController = songSearchViewController else {
            guard let playlistViewController = playlistViewController else {
                guard let libraryViewController = libraryViewController else {
                    guard let offlineLibraryViewController = offlineLibraryViewController else {return}
                    offlineLibraryViewController.play()
                    return
                }
                libraryViewController.play()
                return
            }
            playlistViewController.play()
            return
        }
        songSearchViewController.play()
    }
    
    @IBAction func prevButtonClick(_ sender: Any) {
        guard let playlistViewController = playlistViewController else {return}
        if playlistViewController.currentTrackId > 0 {
            playlistViewController.skipToPrev()
        }
    }
    @IBAction func nextButtonClick(_ sender: Any) {
        guard let playlistViewController = playlistViewController else {return}
        if playlistViewController.currentTrackId < playlistViewController.playlist!.tracks.count-1 {
            playlistViewController.skipToNext()
        }
    }
    
    @IBAction func trackSliderValueChanged(_ sender: UISlider, forEvent event: UIEvent) {
        if let touchEvent = event.allTouches?.first {
            switch touchEvent.phase {
            case .ended:
                guard let songSearchViewController = songSearchViewController else {
                    guard let playlistViewController = playlistViewController else {
                        guard let libraryViewController = libraryViewController else {
                            guard let offlineLibraryViewController = offlineLibraryViewController else {return}
                            let newPosition = Int(Float(currentTrack!.duration) * sender.value)
                            offlineLibraryViewController.seek(position: newPosition)
                            return}
                        let newPosition = Int(Float(currentTrack!.duration) * sender.value)
                        libraryViewController.seek(position: newPosition)
                        return
                    }
                    let newPosition = Int(Float(currentTrack!.duration) * sender.value)
                    playlistViewController.seek(position: newPosition)
                    return}
                let newPosition = Int(Float(currentTrack!.duration) * sender.value)
                songSearchViewController.seek(position: newPosition)
            default:
                let seconds = Int(Float(currentTrack!.duration) * sender.value) / 1000
                let secondsString = String(format: "%02d", seconds%60)
                positionLabel.text = "\(seconds/60):\(secondsString)"
            }
        }
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
