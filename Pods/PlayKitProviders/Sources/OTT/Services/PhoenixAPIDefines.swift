// ===================================================================================================
// Copyright (C) 2017 Kaltura Inc.
//
// Licensed under the AGPLv3 license, unless a different license for a 
// particular library is specified in the applicable library path.
//
// You may obtain a copy of the License at
// https://www.gnu.org/licenses/agpl-3.0.html
// ===================================================================================================

import Foundation


enum AssetTypeAPI: Int {
    case media
    case epg
    case recording
    
    var asString: String {
        switch self {
        case .media: return "media"
        case .epg: return "epg"
        case .recording: return "recording"
        }
    }
}

enum AssetReferenceTypeAPI: Int {
    case media
    case epgInternal
    case epgExternal
    
    var asString: String {
        switch self {
        case .media: return "media"
        case .epgInternal: return "epg_internal"
        case .epgExternal: return "epg_external"
        }
    }
}

enum PlaybackTypeAPI: Int {
    
    case trailer
    case catchup
    case startOver
    case playback
    
    var asString: String {
        switch self {
        case .trailer: return "TRAILER"
        case .catchup: return "CATCHUP"
        case .startOver: return "START_OVER"
        case .playback: return "PLAYBACK"
        }
    }
}
