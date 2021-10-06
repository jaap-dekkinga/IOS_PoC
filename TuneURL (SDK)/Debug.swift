//
//  Debug.swift
//  TuneURL (SDK)
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 9/27/21.
//  Copyright © 2021 TuneURL Inc. All rights reserved.
//

import Foundation

#if DEBUG

class Debug {

	static var recordingFolderURL: URL {
		let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
		return documentsDirectory.appendingPathComponent("Recordings/")
	}

	private func prepareRecordingsFolder()
	{
		let fileManager = FileManager.default
		let folderURL = Debug.recordingFolderURL

		// make sure the folder exists
		_ = try? fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)

		// delete every file in the folder
		if let folderContents = try? fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil, options: []) {
			for fileURL in folderContents {
				_ = try? fileManager.removeItem(at: fileURL)
			}
		}
	}

}

#endif // DEBUG

