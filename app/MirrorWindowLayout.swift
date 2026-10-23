import CoreGraphics

enum MirrorWindowLayout {
    static func preferredSize(on screen: CGSize, picture: CGSize = .zero) -> CGSize {
        let ratio = picture.width.isFinite && picture.height.isFinite && picture.width > 0 && picture.height > 0
            ? picture.width / picture.height : 430.0 / 932.0
        let height = min(932, max(1, screen.height - 80), max(1, screen.width - 48) / ratio)
        return CGSize(width: height * ratio, height: height)
    }

    static func correctedSize(window: CGSize, content: CGSize, picture: CGSize) -> CGSize? {
        guard [window, content, picture].allSatisfy({
            $0.width.isFinite && $0.height.isFinite && $0.width > 0 && $0.height > 0
        }) else { return nil }
        let scale = min(content.width / picture.width, content.height / picture.height)
        let extraWidth = max(0, content.width - picture.width * scale)
        let extraHeight = max(0, content.height - picture.height * scale)
        guard max(extraWidth, extraHeight) > 0.5 else { return nil }
        // Requested bounds may never have taken effect; subtract only from the measured window.
        let target = CGSize(width: window.width - extraWidth, height: window.height - extraHeight)
        guard target.width > 0, target.height > 0 else { return nil }
        return target
    }

    static func isFullScreen(window: CGSize, screen: CGSize) -> Bool {
        guard window.width > 0, window.height > 0 else { return false }
        return abs(min(window.width, window.height) - min(screen.width, screen.height)) < 1
            && abs(max(window.width, window.height) - max(screen.width, screen.height)) < 1
    }
}
