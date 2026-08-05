import AVFoundation

/// Converts microphone buffers into whatever format the speech analyzer asked for.
///
/// The input node's format is decided by the hardware and the audio session; the analyzer
/// publishes its own preferred format. They rarely match, and feeding a mismatched buffer
/// produces silence rather than an error, so the conversion is not optional.
final class BufferConverter {

    enum ConversionError: Error {
        case unableToCreateConverter
        case unableToAllocateBuffer
        case conversionFailed(NSError?)
    }

    /// Reused across buffers — building an `AVAudioConverter` per buffer at ~40 buffers a
    /// second would be wasteful.
    private var converter: AVAudioConverter?

    func convert(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) throws -> AVAudioPCMBuffer {
        let inputFormat = buffer.format
        guard inputFormat != format else { return buffer }

        if converter == nil
            || converter?.inputFormat != inputFormat
            || converter?.outputFormat != format {
            converter = AVAudioConverter(from: inputFormat, to: format)
            // Priming inserts leading silence, which would shift every timestamp.
            converter?.primeMethod = .none
        }

        guard let converter else { throw ConversionError.unableToCreateConverter }

        let ratio = converter.outputFormat.sampleRate / converter.inputFormat.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up))

        guard let output = AVAudioPCMBuffer(pcmFormat: converter.outputFormat, frameCapacity: capacity) else {
            throw ConversionError.unableToAllocateBuffer
        }

        var error: NSError?
        var consumed = false

        let status = converter.convert(to: output, error: &error) { _, inputStatus in
            // The callback may be invoked more than once per output buffer; the source
            // buffer must only be handed over the first time.
            defer { consumed = true }
            inputStatus.pointee = consumed ? .noDataNow : .haveData
            return consumed ? nil : buffer
        }

        guard status != .error else { throw ConversionError.conversionFailed(error) }
        return output
    }

    func reset() {
        converter?.reset()
    }
}
