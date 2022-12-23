import XCTest
import OBSwiftSocket
import WSPublisher
import Combine
import CombineExtensions

final class OBSwiftSocketTests: XCTestCase {
    var session: OBSSessionManager!
    var observers: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        
        let connectionData = OBSSessionManager.ConnectionData(
            ipAddress: "192.168.1.102",
            port: 4455,
            password: "qhsZrtFMZID7wuiR",
            encodingProtocol: .json
        )
        session = OBSSessionManager(connectionData: connectionData)
        
        observers = []
    }
    
    func connectToOBS() throws -> AnyPublisher<Void, Error> {
        return try session.connect(events: nil)
    }
    
    func connectToOBS() async throws {
        try await session.connect()
    }
    
    func testGetInputKindsAsync() async {
        do {
            try await connectToOBS()
            
            try await self.session.waitUntilConnected
                .firstValue
            
            let resp = try await self.session.sendRequest(OBSRequests.GetInputKindList(unversioned: false))
            print(resp)
            
            XCTAssert(session.connectionState == .active)
        } catch {
            XCTFail("Error: \(error)")
        }
    }
    
    func testGetInputKinds() {
        let expectation = self.expectation(description: "Full Input Settings")
        
        do {
            try connectToOBS()
                .flatMap { self.session.waitUntilConnected }
                .first()
                .tryFlatMap { try self.session.sendRequest(OBSRequests.GetInputKindList(unversioned: false)) }
                .sink(receiveCompletion: { print("Sink completion:", $0); expectation.fulfill() },
                      receiveValue: { print("Value: \($0)") })
                .store(in: &observers)
        } catch {
            print("Error: \(error)")
        }
        
        wait(for: [expectation], timeout: 10)
    }
    
    func testGetStats() {
        let expectation = self.expectation(description: "OBS Stats")
        
        do {
            try connectToOBS()
                .flatMap { self.session.waitUntilConnected }
                .first()
                .tryFlatMap { try self.session.sendRequest(OBSRequests.GetStats()) }
                .sink(receiveCompletion: { print("Sink completion:", $0); expectation.fulfill() },
                      receiveValue: { print("Value: \($0)") })
                .store(in: &observers)
        } catch {
            print("Error: \(error)")
        }
        
        wait(for: [expectation], timeout: 10)
    }
    
    func testGetFullInputSettings() {
        let expectation = self.expectation(description: "Full Input Settings")
        
        do {
            try connectToOBS()
                .flatMap { self.session.waitUntilConnected }
                .first()
                .tryFlatMap { try self.session.getFullInputSettings(inputName: "StreamKit") }
//                .tryCompactMap { try $0.toCodable(InputSettings.ColorSource.self) }
//                .map(\.hexString)
                .sink(receiveCompletion: { print("Sink completion:", $0); expectation.fulfill() },
                      receiveValue: { print("Value: \($0)") })
                .store(in: &observers)
        } catch {
            print("Error: \(error)")
        }
        
        wait(for: [expectation], timeout: 10)
    }
    
    func testSceneItemListPublisherWithThreads() {
        let expectation1 = self.expectation(description: "Current Scene Item List 1")
        let expectation2 = self.expectation(description: "Current Scene Item List 2")
        
        do {
            try connectToOBS()
                .flatMap { self.session.$connectionState.setFailureType(to: Error.self) }
                .filter { $0 == .active }
                
                .subscribe(on: DispatchQueue.global())
//                .receive(on: DispatchQueue.global())
                
                .tryFlatMap { _ in try self.session.sceneListPublisher() }
                
                .receive(on: DispatchQueue.main)
                
                .print("Subscriber 1")
                .output(in: 0..<4)
                .sink(receiveCompletion: { print("Sink completion:", $0); expectation1.fulfill() },
                      receiveValue: { _ in })
                .store(in: &observers)
            
            session.$connectionState.setFailureType(to: Error.self)
                .filter { $0 == .active }
                .delay(for: .seconds(5), scheduler: DispatchQueue.main)
                .subscribe(on: DispatchQueue.global())
                
                .tryFlatMap { _ in try self.session.currentSceneNamePairPublisher() }
                
                .receive(on: DispatchQueue.main)
                
                .print("Subscriber 2")
                .output(in: 0..<4)
                .sink(receiveCompletion: { print("Sink completion:", $0); expectation2.fulfill() },
                      receiveValue: { _ in })
                .store(in: &observers)
        } catch {
            print(error)
        }
        
        wait(for: [expectation1, expectation2], timeout: 15)
    }
    
    func testListScenes() {
        let expectation = self.expectation(description: "List Scenes")
        
        do {
            try connectToOBS()
                .tryFlatMap { try self.session.sendRequest(OBSRequests.GetSceneList()) }
                .print("Test!")
                .sink(receiveCompletion: { print("Sink completion:", $0); expectation.fulfill() },
                      receiveValue: { print("Sink value:", $0) })
                .store(in: &observers)
        } catch {
            print(error)
        }
        
        wait(for: [expectation], timeout: 10)
    }
    
    func testListSceneItems() {
        let expectation = self.expectation(description: "List Scene Items")
        
        do {
            try connectToOBS()
                .tryFlatMap { _ in try self.session.activeSceneItemListPublisher() }
//                .tryMap { try $0.typedSceneItems() }
                .sink(receiveCompletion: { print("Sink completion:", $0); expectation.fulfill() },
                      receiveValue: { print("Sink value:", $0) })
                .store(in: &observers)
        } catch {
            print(error)
        }
        
        wait(for: [expectation], timeout: 10)
    }
    
    func testLogEvents() {
        let expectation = self.expectation(description: "Listened for Event")
        
        do {
            try connectToOBS()
                .tryFlatMap { _ in try self.session.listenForEvents(.MediaInputPlaybackStarted, .MediaInputPlaybackEnded) }
                .output(in: 0..<4)
                .sink(receiveCompletion: { print("Sink completion:", $0); expectation.fulfill() },
                      receiveValue: { print("Sink value:", $0) })
                .store(in: &observers)
        } catch {
            print(error)
        }
        
        wait(for: [expectation], timeout: 10)
    }
    
    func testConnectToOBS() {
        let expectationConnect = self.expectation(description: "Connected")
        
        do {
            try connectToOBS()
                .print()
                .sink(receiveCompletion: { result in
                    switch result {
                    case .failure(let err):
                        print("*TEST* Completion error:", err)
                        
                    case .finished:
                        print("*TEST* Completion success")
                    }
                    expectationConnect.fulfill()
                }, receiveValue: { _ in print("Received value") })
                .store(in: &observers)
        } catch {
            print(error)
        }
        
        wait(for: [expectationConnect], timeout: 15)
    }
}
