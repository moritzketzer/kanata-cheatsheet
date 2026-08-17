import Testing
import Network

@Suite("TCP Reconnect")
struct TCPReconnectTests {
    @Test("waiting state retries (regression: client stranded after refused reconnect)")
    func waitingRetries() {
        let refused = NWError.posix(.ECONNREFUSED)
        #expect(KanataTCPClient.action(for: .waiting(refused)) == .retry)
    }

    @Test("failed state retries")
    func failedRetries() {
        #expect(KanataTCPClient.action(for: .failed(NWError.posix(.ECONNRESET))) == .retry)
    }

    @Test("ready state connects")
    func readyConnects() {
        #expect(KanataTCPClient.action(for: .ready) == .connected)
    }

    @Test("setup, preparing, and cancelled are ignored")
    func lifecycleIgnored() {
        #expect(KanataTCPClient.action(for: .setup) == .ignore)
        #expect(KanataTCPClient.action(for: .preparing) == .ignore)
        #expect(KanataTCPClient.action(for: .cancelled) == .ignore)
    }
}
