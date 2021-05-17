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
    var currentPlaylist: [MusicTrack] = []
    var trackIndex = 0
    var position = 0
    override func viewDidLoad() {
        super.viewDidLoad()
        guard let data = try? Data(contentsOf: URL(string: "https://i.scdn.co/image/ab67616d0000b273c6d856ddd53fc870467fd8e3")!) else {return}
        playButton.image = UIImage(systemName: "pause.fill")
        if trackIndex < currentPlaylist.count {
            nameTF.text = currentPlaylist[trackIndex].name
            artistTF.text = currentPlaylist[trackIndex].artist
            trackPositionSlider.value = Float(position)/Float(currentPlaylist[trackIndex].duration)
            guard let data = try? Data(contentsOf: URL(string: currentPlaylist[trackIndex].imageUrl)!) else {return}
            trackImageView.image = UIImage(data: data)
        }
    }
    

    @IBAction func playButtonClick(_ sender: Any) {
        
    }
    @IBAction func prevButtonClick(_ sender: Any) {
    }
    @IBAction func nextButtonClick(_ sender: Any) {
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
