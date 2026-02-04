import MultipeerConnectivity
import Flutter

class MPCManager: NSObject, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
    
    private let serviceType = "hydra-share"
    private var myPeerId: MCPeerID!
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser!
    private var browser: MCNearbyServiceBrowser!
    private var methodChannel: FlutterMethodChannel
    
    init(binaryMessenger: FlutterBinaryMessenger) {
        self.methodChannel = FlutterMethodChannel(name: "com.hydrashare/mpc", binaryMessenger: binaryMessenger)
        super.init()
        
        // Initialize Peer ID (User standard defaults or random)
        let deviceName = UIDevice.current.name
        self.myPeerId = MCPeerID(displayName: deviceName)
        
        // Initialize Session
        self.session = MCSession(peer: myPeerId, securityIdentity: nil, encryptionPreference: .required)
        self.session.delegate = self
        
        // Initialize Advertiser & Browser
        self.advertiser = MCNearbyServiceAdvertiser(peer: myPeerId, discoveryInfo: nil, serviceType: serviceType)
        self.advertiser.delegate = self
        
        self.browser = MCNearbyServiceBrowser(peer: myPeerId, serviceType: serviceType)
        self.browser.delegate = self
        
        setupMethodCallHandler()
    }
    
    private fun setupMethodCallHandler() {
        methodChannel.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else { return }
            
            switch call.method {
            case "startMPC":
                self.startMPC()
                result(true)
            case "stopMPC":
                self.stopMPC()
                result(true)
            case "sendData":
                self.handleSendData(call: call, result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
    
    func startMPC() {
        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
    }
    
    func stopMPC() {
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        session.disconnect()
    }
    
    // MARK: - Method Channel Handlers
    
    private func handleSendData(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Implementation for data transfer (future step)
        result(true)
    }
    
    // MARK: - MCNearbyServiceAdvertiserDelegate
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Auto-accept all invitations for now (Forest Mode philosophy)
        // In production, might want to verify context/PIN
        invitationHandler(true, self.session)
    }
    
    // MARK: - MCNearbyServiceBrowserDelegate
    
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        // Auto-invite found peers? Or just report them?
        // For simplicity: report to Flutter, let separate 'connect' call trigger invite
        // BUT, MPC often requires immediate invite for stability.
        // Let's invite immediately for seamless mesh (common pattern for AirDrop-like apps)
        browser.invitePeer(peerID, to: self.session, withContext: nil, timeout: 30)
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        // Report loss
    }
    
    // MARK: - MCSessionDelegate
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        var stateStr = "unknown"
        switch state {
        case .connected:
            stateStr = "connected"
            // Report to Flutter
            DispatchQueue.main.async {
                self.methodChannel.invokeMethod("onPeerFound", arguments: [
                    "id": peerID.displayName, // Using name as ID for MPC simplicity, ideally use specific UUID
                    "name": peerID.displayName,
                    "type": "mpc"
                ])
            }
        case .connecting:
            stateStr = "connecting"
        case .notConnected:
            stateStr = "disconnected"
        @unknown default:
            fatalError()
        }
        print("MPC Peer \(peerID.displayName) changed state to \(stateStr)")
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // Handle incoming data
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        // Handle incoming stream (files)
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        // Handle file resource
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        // Handle file completion
    }
}
