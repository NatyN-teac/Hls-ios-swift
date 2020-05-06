//
//  ViewController.swift
//  pply
//
//  Created by Nathenael Tarekegn on 2/12/20.
//  Copyright © 2020 Nathenael Tarekegn. All rights reserved.
//

import UIKit
import PlayKit
import MediaPlayer
import DownloadToGo
import PlayKitProviders


let setSmallerOfflineDRMExpirationMinutes: Int? = nil

struct ExpectedValues: Decodable {
    let estimatedSize: Int64?
    let downloadedSize: Int64?
    let audioLangs: [String]?
    let textLangs: [String]?
}

func maybeSetSmallDuration(entry: PKMediaEntry) {
    if let minutes = setSmallerOfflineDRMExpirationMinutes {
        entry.sources?.forEach({ (source) in
            if let drmData = source.drmData, let fpsData = drmData.first as? FairPlayDRMParams {
                var lic = fpsData.licenseUri!.absoluteString
                lic.append(contentsOf: "&rental_duration=\(minutes*60)")
                fpsData.licenseUri = URL(string: lic)
            }
        })
    }
}



class Item{
    static let defaultEnv = "http://cdnapi.kaltura.com"
    var id:String
    var title:String
    var partnerId: Int?
    var url: URL?
    var entry:PKMediaEntry?
    var options: DTGSelectionOptions?
    var expected:ExpectedValues?
    
    convenience init(json: ItemJSON) {
        let title = json.title ?? json.id
        
        if let partnerId = json.partnerId {
            self.init(title, id: json.id, partnerId: partnerId, ks: json.ks, env: json.env, ott: json.ott ?? false, ottParams: json.ottParams)
        } else if let url = json.url {
            self.init(title, id: json.id, url: url)
        } else {
            fatalError("Invalid item, missing `partnerId` and `url`")
        }
        self.options = json.options?.toOptions()
    }
    
     init(_ title:String,id:String,url:String){
        self.id = id
        self.title = title
        self.url = URL(string: url)
        
        let source = PKMediaSource(id, contentUrl: URL(string: url))
        self.entry = PKMediaEntry(id, sources: [source])
        
        self.partnerId = nil
        
    
    }
    
    //constructor for ott
    init(_ title:String,id:String,partnerId:Int,ks:String? = nil,env:String? = nil,ott:Bool = false,ottParams: ItemOTTParamsJSON? = nil) {
        self.id = id
        self.title = title
        self.partnerId = partnerId
        self.url = nil
        
        let session = SimpleSessionProvider(serverURL: env ?? Item.defaultEnv, partnerId: Int64(partnerId), ks: ks)
        
        let provider: MediaEntryProvider
        
        if ott {
            let ottProvider = PhoenixMediaProvider().set(sessionProvider: session)
                .set(assetId: self.id)
                .set(type: .media)
            
            if let ottParams = ottParams {
                if let format = ottParams.format {
                    ottProvider.set(formats: [format])
                }
            }
            
            provider = ottProvider
            
        } else {
            provider = OVPMediaProvider(session)
                .set(entryId: id)
        }
        
        provider.loadMedia { (entry, error) in
            if let entry = entry {
                maybeSetSmallDuration(entry: entry)
                self.entry = entry
                
                print("entry: \(entry)")
                
            } else if let error = error {
                print("error: \(error)")
            }
        }
    }
}

struct OptionsJSON: Decodable {
    let audioLangs: [String]?
    let allAudioLangs: Bool?
    let textLangs: [String]?
    let allTextLangs: Bool?
    let videoCodecs: [String]?
    let audioCodecs: [String]?
    let videoWidth: Int?
    let videoHeight: Int?
    let videoBitrates: [String:Int]?
    let allowInefficientCodecs: Bool?
    
    func toOptions() -> DTGSelectionOptions {
        let opts = DTGSelectionOptions()
        
        opts.allAudioLanguages = allAudioLangs ?? false
        opts.audioLanguages = audioLangs
        
        opts.allTextLanguages = allTextLangs ?? false
        opts.textLanguages = textLangs
        
        opts.allowInefficientCodecs = allowInefficientCodecs ?? false
        
        if let codecs = audioCodecs {
            opts.videoCodecs = codecs.compactMap({ (tag) -> DTGSelectionOptions.TrackCodec? in
                switch tag {
                case "mp4a": return .mp4a
                case "ac3": return .ac3
                case "eac3", "ec3": return .eac3
                default: return nil
                }
            })
        }
        
        if let codecs = videoCodecs {
            opts.videoCodecs = codecs.compactMap({ (tag) -> DTGSelectionOptions.TrackCodec? in
                switch tag {
                case "avc1": return .avc1
                case "hevc", "hvc1": return .hevc
                default: return nil
                }
            })
        }
        
        opts.videoWidth = videoWidth
        opts.videoHeight = videoHeight
        
        if let bitrates = videoBitrates {
            for (codecId, bitrate) in bitrates {
                let codec: DTGSelectionOptions.TrackCodec
                switch codecId {
                case "avc1": codec = .avc1
                case "hevc", "hvc1": codec = .hevc
                default: continue
                }
                
                opts.setMinVideoBitrate(codec, bitrate)
            }
        }
        
        return opts
    }
}

struct ItemOTTParamsJSON: Decodable {
    let format: String?
}

struct ItemJSON: Decodable {
    let id: String
    let title: String?
    let partnerId: Int?
    let ks: String?
    let env: String?
    
    let url: String?
    
    let options: OptionsJSON?
    
    let expected: ExpectedValues?
    
    let ott: Bool?
    let ottParams: ItemOTTParamsJSON?
}



class ViewController: UIViewController {
    @IBOutlet weak var playerView: PlayerView!
    
    let cm = ContentManager.shared
    let lam = LocalAssetsManager.managerWithDefaultDataStore()
    var items = [Item]()
    var selectedDTGItem: DTGItem?
    var playerUrl: URL?
      
    var selectedItem: Item! {
        didSet{
            do {
                
                let item = try cm.itemById(selectedItem.id)
                selectedDTGItem = item
                
                DispatchQueue.main.async {
//                    self.statusLabel.text = item?.state.asString() ?? ""
                    print("status thing:",item?.state.asString())
                    if item?.state == .completed {
//                        self.progressView.progress = 1.0
                        print("completed...,",item?.state,item?.downloadedSize)
                        
                    } else if let downloadedSize = item?.downloadedSize, let estimatedSize = item?.estimatedSize, estimatedSize > 0 {
                        print("progress: ",Float(downloadedSize) / Float(estimatedSize))
//                        self.progressView.progress = Float(downloadedSize) / Float(estimatedSize)
                    } else {
//                        self.progressView.progress = 0.0
                    }
                }
                
            } catch  {
                print("error: \(error.localizedDescription)")
            }
        }
    }
    
    var player: Player?
    var urls = URL(string: "https://noamtamim.com/random/hls/test-enc-aes/multi.m3u8")
    
    let defaultAudioBitrateEstimation: Int = 64000
    override func viewDidLoad() {
        super.viewDidLoad()
        let jsonURL = Bundle.main.url(forResource: "items", withExtension: "json")!
        //        let jsonURL = URL(string: "http://localhost/items.json")!
        let json = try! Data(contentsOf: jsonURL)
        let loadedItems = try! JSONDecoder().decode([ItemJSON].self, from: json)
        
        items = loadedItems.map{Item(json: $0)}
        
        cm.setDefaultAudioBitrateEstimation(bitrate: defaultAudioBitrateEstimation)

        // initialize UI
        selectedItem = items.first!
        

        
       
    }

   
    @IBAction func playBtn(_ sender: Any) {
//        player!.play()
                player = PlayKitManager.shared.loadPlayer(pluginConfig: nil)
                player?.view = self.playerView
               var source = PKMediaSource(self.selectedItem.id, contentUrl: self.playerUrl)
                let mediaEntry = PKMediaEntry(self.selectedItem.id, sources: [source])
                player?.prepare(MediaConfig(mediaEntry: mediaEntry))
                player?.play()
             print("this is current player item",player?.currentTime)
        
            }
    
    func addItem(){
        guard let entry = self.selectedItem.entry else{
            print("no entry ")
            return
        }
        guard let mediaSource = lam.getPreferredDownloadableMediaSource(for: entry)else {
            print("no media source ")
            return
            
        }
        print("video to be downloaded: \(String(describing: mediaSource.contentUrl))")
        
        var item:DTGItem?
        do{
            item = try cm.itemById(entry.id)
            if item == nil {
                item = try cm.addItem(id: entry.id, url: mediaSource.contentUrl!)
            }
        }catch{
            print("item is not added ",error.localizedDescription)
            return
        }
        guard let dtgItem = item else{
            print("cant add item")
            return
        }
        
        print("status of item: ",dtgItem.state.asString())
        
        DispatchQueue.global().async {
            do{
                var options: DTGSelectionOptions
                
                options = DTGSelectionOptions()
                .setMinVideoHeight(300)
                    .setMinVideoBitrate(.avc1, 3_000_000)
                    .setMinVideoBitrate(.hevc, 5_000_000)
                    .setPreferredVideoCodecs([.hevc , .avc1])
                    .setPreferredAudioCodecs([.ac3,.mp4a])
                .setAllTextLanguages()
                .setAllAudioLanguages()
                
                options.allowInefficientCodecs = true
                
                try self.cm.loadItemMetadata(id: self.selectedItem.id, options: self.selectedItem.options)
                //    try self.cm.loadItemMetadata(id: self.selectedItem.id, preferredVideoBitrate: 300000)
                print("Item Metadata Loaded")
                try self.cm.startItem(id: self.selectedItem.id)
                
            }catch{
                DispatchQueue.main.async {
//                    self.toast("loadItemMetadata failed \(error)")
                    print("loadItemMetadata failed \(error)")
                }
            }
        }
    }
    
    @IBAction func downloadBtn(_ sender: Any) {

       
        
        
        do {
            addItem()
//            try self.cm.startItem(id: self.selectedItem.id)
//            let vallu = try self.cm.itemPlaybackUrl(id: self.selectedItem.id)
//            print("vall: ",vallu)
//
                        DispatchQueue.main.asyncAfter(deadline: .now() + 30.0, execute: {
                [weak self] in
                do{

                    guard let item = try self!.cm.itemById(self!.selectedItem.id)else{
                        return
                    }
                    print("item at this point:",item)
                    

                    if item.state == .completed{
                        let downloadedFileUlr = try self!.cm.itemPlaybackUrl(id: self!.selectedItem.id)
                        self?.playerUrl = downloadedFileUlr
                        
                        print("my file location: ",downloadedFileUlr)
                    }

                }catch{
                    print("no url;",error.localizedDescription)
                }
            })
            

        }catch{
            print("error",error.localizedDescription)
            
            
            
        }
        
      
        
        
        

       
            
//        DispatchQueue.main.async {
            
//        }
        
        
         
    }
    
    @IBAction func pauseBtn(_ sender: Any) {
//        player!.pause()
        do{
            
            guard let item = try self.cm.itemById(self.selectedItem.id)else{
                return
            }
            print("id:",self.selectedItem.id)
            
            if item.state == .completed{
                let downloadedFileUlr = try self.cm.itemPlaybackUrl(id: "k-720p")
                print("my file location: ",downloadedFileUlr)
            }
            
        }catch{
            print("no url;",error.localizedDescription)
        }
        
        
        
        
       
    }
}
