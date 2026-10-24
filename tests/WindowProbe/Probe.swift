import UIKit
import AVFoundation
import ObjectiveC

@main
final class ProbeApp: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Probe", sessionRole: session.role)
        configuration.delegateClass = ProbeScene.self
        return configuration
    }
}

final class ProbeScene: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        guard #available(iOS 26.0, *) else { fatalError("This probe requires iPadOS 26 or later") }
        let window = UIWindow(windowScene: scene)
        let controller = ProbeController()
        controller.preferredContentSize = MirrorWindowLayout.preferredSize(on: scene.screen.bounds.size)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        self.window = window
    }
}

@available(iOS 26.0, *)
final class ProbeController: UIViewController {
    private let picture = UIView()
    private var video = CGSize(width: 1080, height: 2340)
    private var reports: [[String: Any]] = []
    private var geometryErrors: [String] = []
    private let start = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        picture.backgroundColor = .cyan
        view.addSubview(picture)
        start.setTitle("Run window tests", for: .normal)
        start.accessibilityIdentifier = "runWindowTests"
        start.backgroundColor = .white
        start.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(start)
        NSLayoutConstraint.activate([
            start.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            start.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            start.widthAnchor.constraint(equalToConstant: 220),
            start.heightAnchor.constraint(equalToConstant: 60)
        ])
        start.addAction(UIAction { [weak self] _ in
            guard let self, self.reports.count < 3 else { return }
            self.start.isHidden = true
            self.runPhase(self.reports.count)
        }, for: .touchUpInside)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        picture.frame = AVMakeRect(aspectRatio: video, insideRect: view.bounds)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if ProcessInfo.processInfo.arguments.contains("--inspect-window-apis") {
            writeWindowAPIs(); return
        }
        if let scene = view.window?.windowScene { apply(in: scene) }
    }

    private func writeWindowAPIs() {
        let names = ["UIWindowScene", "UIScene", "UIWindowSceneGeometryPreferencesIOS",
            "UIWindowSceneGeometryPreferences", "UISceneSizeRestrictions", "FBSScene",
            "FBSSceneClientSettings", "FBSMutableSceneClientSettings",
            "UIApplicationSceneClientSettings", "UIMutableApplicationSceneClientSettings"]
        let terms = ["size", "frame", "geometry", "restric", "resiz", "clientsetting"]
        var interfaces: [[String: Any]] = []
        for name in names {
            guard let cls = NSClassFromString(name) else {
                interfaces.append(["class": name, "present": false]); continue
            }
            var count: UInt32 = 0
            var entries: [[String: String]] = []
            if let methods = class_copyMethodList(cls, &count) {
                for index in 0..<Int(count) {
                    let selector = NSStringFromSelector(method_getName(methods[index]))
                    if terms.contains(where: { selector.lowercased().contains($0) }) {
                        entries.append(["selector": selector,
                            "encoding": method_getTypeEncoding(methods[index]).map { String(cString: $0) } ?? ""])
                    }
                }
                free(methods)
            }
            interfaces.append(["class": name, "present": true, "methods": entries])
        }
        let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("window-apis.json")
        do {
            try JSONSerialization.data(withJSONObject: interfaces, options: [.prettyPrinted, .sortedKeys])
                .write(to: path, options: .atomic)
            start.accessibilityIdentifier = "windowAPIsReady"
        } catch { fatalError("Could not save window API metadata: \(error)") }
    }

    func apply(in scene: UIWindowScene, corrected: CGSize? = nil) {
        preferredContentSize = corrected ?? MirrorWindowLayout.preferredSize(on: scene.screen.bounds.size, picture: video)
        if let limits = scene.sizeRestrictions {
            limits.maximumSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            limits.minimumSize = preferredContentSize
            limits.maximumSize = preferredContentSize
        }
        setNeedsUpdateOfSupportedInterfaceOrientations()
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: .all)) { [weak self] error in
            let error = error as NSError
            self?.geometryErrors.append("\(error.domain):\(error.code) \(error.localizedDescription)")
        }
    }

    private func runPhase(_ phase: Int) {
        guard let scene = view.window?.windowScene else { return }
        geometryErrors = []
        video = phase == 1 ? CGSize(width: 1080, height: 498) : CGSize(width: 1080, height: 2340)
        apply(in: scene)
        view.setNeedsLayout()
        settlePhase(phase, corrections: 0)
    }

    private func settlePhase(_ phase: Int, corrections: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [self] in
            guard let window = view.window, let scene = window.windowScene else { return }
            view.layoutIfNeeded()
            if corrections < 3, let corrected = MirrorWindowLayout.correctedSize(
                window: window.bounds.size, content: view.bounds.size, picture: video) {
                apply(in: scene, corrected: corrected)
                view.setNeedsLayout()
                settlePhase(phase, corrections: corrections + 1)
                return
            }
            let actual = window.bounds.size
            let image = AVMakeRect(aspectRatio: video, insideRect: view.bounds)
            let physical = window.convert(window.bounds, to: scene.screen.coordinateSpace)
            let physicalImage = view.convert(image, to: scene.screen.coordinateSpace)
            func dimensions(_ size: CGSize) -> [CGFloat] { [size.width, size.height] }
            let gap = max(abs(image.minX), abs(image.minY), abs(view.bounds.maxX - image.maxX), abs(view.bounds.maxY - image.maxY))
            let sizeError = max(abs(actual.width - preferredContentSize.width), abs(actual.height - preferredContentSize.height))
            let physicalGap = max(abs(physical.minX - physicalImage.minX), abs(physical.minY - physicalImage.minY),
                abs(physical.maxX - physicalImage.maxX), abs(physical.maxY - physicalImage.maxY))
            let physicalFit = AVMakeRect(aspectRatio: video, insideRect: physical)
            let orientationGap = max(physical.width - physicalFit.width, physical.height - physicalFit.height) / 2
            reports.append([
                "phase": ["portrait", "landscape", "portrait_return"][phase],
                "corrections": corrections,
                "video": dimensions(video), "requested": dimensions(preferredContentSize),
                "window": dimensions(actual), "content": dimensions(view.bounds.size),
                "screen": dimensions(scene.screen.bounds.size),
                "effectiveGeometry": dimensions(scene.effectiveGeometry.coordinateSpace.bounds.size),
                "minimum": dimensions(scene.sizeRestrictions?.minimumSize ?? .zero),
                "maximum": dimensions(scene.sizeRestrictions?.maximumSize ?? .zero),
                "deviceIdiom": UIDevice.current.userInterfaceIdiom.rawValue,
                "interfaceOrientation": scene.effectiveGeometry.interfaceOrientation.rawValue,
                "geometryErrors": geometryErrors,
                "physicalWindow": dimensions(physical.size),
                "physicalEdgeGap": physicalGap, "orientationGap": orientationGap,
                "fullScreen": MirrorWindowLayout.isFullScreen(window: actual, screen: scene.screen.bounds.size),
                "edgeGap": gap, "sizeError": sizeError,
                "passed": gap <= 1 && sizeError <= 1 && physicalGap <= 1 && orientationGap <= 1
            ])
            let destination = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("window-report.json")
            do {
                try JSONSerialization.data(withJSONObject: reports, options: [.prettyPrinted, .sortedKeys])
                    .write(to: destination, options: .atomic)
                start.accessibilityIdentifier = phase < 2 ? "windowPhaseReady\(phase)" : "windowReportReady"
                start.setTitle(phase < 2 ? "Continue window tests" : "Window report ready", for: .normal)
                start.isHidden = false
            } catch { NSLog("Window probe report failed: %@", String(describing: error)) }
        }
    }
}
