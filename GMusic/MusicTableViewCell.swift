//
//  MusicTableViewCell.swift
//  GMusic
//
//  Created by Григорий Сухотин on 30.04.2021.
//

import UIKit

class MusicTableViewCell: UITableViewCell {
    
    @IBOutlet weak var trackImageView: UIImageView!
    @IBOutlet weak var trackNameLabel: UILabel!
    @IBOutlet weak var trackArtistLabel: UILabel!
    

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
