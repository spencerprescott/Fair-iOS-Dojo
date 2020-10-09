//
//  Operations.swift
//  CombineFormViewModel
//
//  Created by Spencer Prescott on 10/5/20.
//

import UIKit
import Combine

open class AsynchronousOperation: Operation {
    public override var isAsynchronous: Bool {
        return true
    }

    public override var isExecuting: Bool {
        return state == .executing
    }

    public override var isFinished: Bool {
        return state == .finished
    }

    public override func start() {
        if self.isCancelled {
            state = .finished
        } else {
            state = .ready
            main()
        }
    }

    open override func main() {
        if self.isCancelled {
            state = .finished
        } else {
            state = .executing
        }
    }

    public func finish() {
        state = .finished
    }

    // MARK: - State management

    public enum State: String {
        case ready = "Ready"
        case executing = "Executing"
        case finished = "Finished"
        fileprivate var keyPath: String { return "is" + self.rawValue }
    }

    /// Thread-safe computed state value
    public var state: State {
        get {
            stateQueue.sync {
                return stateStore
            }
        }
        set {
            let oldValue = state
            willChangeValue(forKey: state.keyPath)
            willChangeValue(forKey: newValue.keyPath)
            stateQueue.sync(flags: .barrier) {
                stateStore = newValue
            }
            didChangeValue(forKey: state.keyPath)
            didChangeValue(forKey: oldValue.keyPath)
        }
    }

    private let stateQueue = DispatchQueue(label: "AsynchronousOperation State Queue", attributes: .concurrent)

    /// Non thread-safe state storage, use only with locks
    private var stateStore: State = .ready
}

open class PublishedResultOperation<SuccessType>: AsynchronousOperation {
    @Published
    internal var result: Result<SuccessType, Error>? {
        didSet {
            guard let result = result else { return }
            resultSubject.send(result)
        }
    }

    private let resultSubject = PassthroughSubject<Result<SuccessType, Error>, Never>()
    var resultPublisher: AnyPublisher<Result<SuccessType, Error>, Never> {
        return resultSubject.eraseToAnyPublisher()
    }
}

final class RandomNumberOperation: PublishedResultOperation<Int> {
    override func main() {
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self = self else { return }
            self.result = .success(Int.random(in: 0...100))
            self.finish()
        }
    }
}

final class OperationManger {
    private let queue = OperationQueue()

    func combine(_ a: RandomNumberOperation, _ b: RandomNumberOperation) -> AnyPublisher<(Result<Int, Error>, Result<Int, Error>), Never>  {
        let publisher = Publishers.CombineLatest(a.resultPublisher, b.resultPublisher)
            .eraseToAnyPublisher()
        queue.addOperations([a, b], waitUntilFinished: false)
        return publisher
    }

    func merge(_ a: RandomNumberOperation, _ b: RandomNumberOperation) -> AnyPublisher<Result<Int, Error>, Never> {
        let publisher = Publishers.Merge(a.resultPublisher, b.resultPublisher)
            .eraseToAnyPublisher()
        queue.addOperations([a, b], waitUntilFinished: false)
        return publisher
    }
}

final class OperationTestViewController: UIViewController {
    let manager = OperationManger()
    private var cancellables = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()

        manager
            .combine(.init(), .init())
            .sink { a, b in

            }
            .store(in: &cancellables)

        manager.merge(.init(), .init())
            .sink { result in

            }
            .store(in: &cancellables)

    }
}
