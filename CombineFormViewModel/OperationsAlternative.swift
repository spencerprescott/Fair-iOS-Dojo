//
//  OperationsAlternative.swift
//  CombineFormViewModel
//
//  Created by Spencer Prescott on 10/5/20.
//

import UIKit
import Combine

final class OperationsAlterativeViewController: UIViewController {
    private var cancellables = Set<AnyCancellable>()
    private lazy var taskPresenter = UITaskPresenter(view: view, spinnerStyle: 1)

    override func viewDidLoad() {

        // Chaining operations that depend on eachother
        // This mirrors how a queue would operate
        // If we design our network tasks in this way we could stop having to use an operation queue
        work1()
            .flatMap { value in self.work2(value) }
            .flatMap(work3)
            .sink { string in

            }
            .store(in: &cancellables)


        // This waits for these to network calls to finish and then sends the response to the sink
        let fetchUserInfo = FetchUserInfoTaskFactory().make()
        let fetchVehicleInfo = FetchVehicleInfoTask(id: "id").make()
        Publishers.CombineLatest(fetchUserInfo, fetchVehicleInfo)
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        // Operation Finished Normally, No Issues
                        break
                    case .failure(let error):
                        // Operation Failed
                        break
                    }
                },
                receiveValue: { userInfo, vehicleInfo in

                }
            )
            .store(in: &cancellables)


        taskPresenter
            .combine(fetchUserInfo, fetchVehicleInfo)
            .sink(receiveCompletion: { _ in }, receiveValue: { _, _ in})
            .store(in: &cancellables)

    }

    func work1() -> AnyPublisher<Int, Never> {
        return Just<Int>(1)
            .print()
            .eraseToAnyPublisher()
    }

    func work2(_ integer: Int) -> AnyPublisher<String, Never> {
        // The Future is like the operation. You do your work inside of it and notifiy the seal when you're done
        return Future { seal in
            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 8) {
                seal(.success("\(integer + 1)"))
            }
        }
        .print()
        .eraseToAnyPublisher()
    }

    func work3(_ string: String) -> AnyPublisher<String, Never> {
        return Just<String>(string + " Hi!")
            .print()
            .eraseToAnyPublisher()
    }
}






struct FetchUserInfoTaskFactory {
    func make() -> AnyPublisher<Any, Error> {
        return URLSession.shared
            .dataTaskPublisher(for: URL(string: "https://fair.com")!)
            .map(\.data)
            .map(Self.parse)
            .mapError { $0 as Error }
            .eraseToAnyPublisher()
    }

    private static func parse(data: Data) -> Any {
        // User object
        return 1
    }
}

struct FetchVehicleInfoTask {
    let id: String
    init(id: String) {
        self.id = id
    }

    func make() -> AnyPublisher<Any, Error> {
        return Future { seal in
            // This would be a grpc request and response
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                seal(.success(1))
            }
        }
        .map(Self.protoToSwiftObject)
        .eraseToAnyPublisher()
    }

    private static func protoToSwiftObject(proto: Any) -> Any {
        return proto
    }
}


struct UITaskPresenter {
    let view: UIView
    let spinnerStyle: Int

    func combine<A, B>(_ a: AnyPublisher<A, Error>, _ b: AnyPublisher<B, Error>) -> AnyPublisher<(A, B), Error> {
        return Publishers.CombineLatest(a, b)
            .handleEvents(
                receiveSubscription: { _ in
                    self.showSpinner()
                },
                receiveCompletion: { completion in
                    self.hideSpinner()
                    switch completion {
                    case .finished:
                        break
                    case .failure(let error):
                        self.showError(error)
                    }
                },
                receiveCancel: {
                    self.hideSpinner()
                }
            )
            .eraseToAnyPublisher()
    }

    private func showSpinner() {

    }

    private func hideSpinner() {

    }

    private func showError(_ error: Error) {

    }
}
