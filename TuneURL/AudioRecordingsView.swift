import SwiftUI
import AVFoundation

struct AudioRecordingsView: View {
    @State private var recordings: [URL] = []
    @State private var audioPlayer: AVAudioPlayer?
    @State private var currentlyPlaying: URL?
    
    let folderURL: URL
    
    var body: some View {
        List(recordings, id: \.self) { fileURL in
            HStack {
                Text(fileURL.lastPathComponent)
                    .lineLimit(1)
                
                Spacer()
                
                if currentlyPlaying == fileURL {
                    Button("Stop") {
                        stopPlayback()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Play") {
                        playRecording(url: fileURL)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .navigationTitle("Audio Recordings")
        .onAppear(perform: loadRecordings)
    }
    
    private func loadRecordings() {
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles] // skip files like .DS_Store
            )
            recordings = fileURLs
        } catch {
            print("Failed to load recordings:", error)
        }
    }
    
    private func playRecording(url: URL) {
        do {
            print("Playing audio from:", url.absoluteString)
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
            currentlyPlaying = url
        } catch {
            print("Failed to play audio:", error)
        }
    }
    
    private func stopPlayback() {
        audioPlayer?.stop()
        currentlyPlaying = nil
    }
}
