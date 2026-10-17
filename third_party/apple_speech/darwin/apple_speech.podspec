#
# MonkeyHub's local plugin: voice-message transcription with Apple's built-in
# on-device recognizer (SpeechAnalyzer, iOS 26 / macOS 26). Older OSes build
# fine and report unavailable.
#
Pod::Spec.new do |s|
  s.name             = 'apple_speech'
  s.version          = '0.1.0'
  s.summary          = 'On-device voice message transcription with Apple SpeechAnalyzer.'
  s.description      = <<-DESC
Transcribes an audio file with SpeechTranscriber (or DictationTranscriber for
languages SpeechTranscriber lacks), with word timings, asset install progress
and cancellation.
                       DESC
  s.homepage         = 'https://monkeyhub.app'
  s.license          = { :type => 'Proprietary' }
  s.author           = 'MonkeyHub'
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*.swift'
  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  s.ios.deployment_target = '15.0'
  s.osx.deployment_target = '12.0'
  s.frameworks       = 'Speech', 'AVFoundation', 'CoreMedia'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version    = '5.9'
end
